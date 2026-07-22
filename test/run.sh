#!/bin/sh
# test/run.sh — self-test harness for the Master-Claude tooling.
# Exercises install / symlinks / idempotency / seed / trim / mc-apply state detection /
# retrofit safety / doctor / self-guard in throwaway sandboxes. No network, no heredocs.
# Exit 0 if all checks pass, 1 otherwise.
set -eu

REPO=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BIN="$REPO/bin"
SBROOT=$(mktemp -d)
trap 'rm -rf "$SBROOT"' EXIT

FAILS=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS+1)); }
# check LABEL CMD...        -> pass when CMD succeeds
# checkn LABEL CMD...       -> pass when CMD fails (negated)
check()  { l=$1; shift; if "$@" >/dev/null 2>&1; then ok "$l"; else no "$l"; fi; }
checkn() { l=$1; shift; if "$@" >/dev/null 2>&1; then no "$l"; else ok "$l"; fi; }

mkrust() { d="$SBROOT/$1"; mkdir -p "$d"; printf '[package]\nname="t"\n' > "$d/Cargo.toml"; printf '%s' "$d"; }

printf 'master-claude self-tests\n'

# --- 1. install + symlink integrity ---------------------------------------
P=$(mkrust install)
"$BIN/mc-install.sh" "$P" >/dev/null
if [ -f "$P/AGENTS.md" ] && [ ! -L "$P/AGENTS.md" ]; then ok "AGENTS.md is canonical"; else no "AGENTS.md canonical"; fi
if [ "$(readlink "$P/CLAUDE.md")" = AGENTS.md ]; then ok "CLAUDE.md -> AGENTS.md"; else no "CLAUDE.md symlink"; fi
if [ "$(readlink "$P/GEMINI.md")" = AGENTS.md ]; then ok "GEMINI.md -> AGENTS.md"; else no "GEMINI.md symlink"; fi
check "import mode references core" grep -q '^@.*master-core/AGENTS.base.md' "$P/AGENTS.md"

# --- 2. doctor is clean on a fresh install --------------------------------
check "doctor exit 0" "$BIN/mc-doctor.sh" "$P"

# --- 3. idempotent sync preserves a hand-edited project block -------------
sed -i 's/<<< MC-PROJECT-START >>>/<<< MC-PROJECT-START >>>\nHANDEDIT-XYZ/' "$P/AGENTS.md"
"$BIN/mc-sync.sh" "$P" >/dev/null
check "sync preserves hand edit" grep -q 'HANDEDIT-XYZ' "$P/AGENTS.md"
if [ "$(grep -c 'MC-PROJECT-START' "$P/AGENTS.md")" = 1 ]; then ok "exactly one project block"; else no "one project block"; fi

# --- 4. seed from an existing CLAUDE.md migrates project content ----------
S=$(mkrust seed)
printf '# CLAUDE.md\n\nUse clippy as a gate.\n\n## Arch\n- Widget owns bus; FOO-42 stays on.\n' > "$S/CLAUDE.md"
"$BIN/mc-install.sh" "$S" --trim >/dev/null
check "seeded project content migrated" grep -q 'FOO-42' "$S/AGENTS.md"
check "original backed up to .mc-bak" test -f "$S/CLAUDE.md.mc-bak"
check "--trim comments duplicate rule" grep -q '<!-- dup?.*clippy' "$S/AGENTS.md"
check "--trim keeps project line live" grep -q '^- Widget owns bus; FOO-42 stays on.' "$S/AGENTS.md"

# --- 5. mc-apply state detection ------------------------------------------
apply_next() { "$BIN/mc-apply.sh" "$1" 2>&1 | sed -n 's/^MC-NEXT: //p' | head -1; }
N=$(mkrust applynew)
if [ "$(apply_next "$N")" = fill-stub ]; then ok "new -> fill-stub"; else no "new state"; fi
E=$(mkrust applyexist)
printf '# CLAUDE.md\nstuff\n' > "$E/CLAUDE.md"
if [ "$(apply_next "$E")" = curate ]; then ok "existing -> curate"; else no "existing state"; fi
if [ "$(apply_next "$E")" = none ]; then ok "managed -> none (idempotent)"; else no "managed state"; fi

# --- 6. inline mode bakes modules, no @import -----------------------------
I=$(mkrust inline)
"$BIN/mc-install.sh" "$I" --inline >/dev/null
checkn "inline has no @import" grep -q '^@.*master-core' "$I/AGENTS.md"
check  "inline baked base rules" grep -q 'Conventional Commits' "$I/AGENTS.md"

# --- 7. retrofit --dry-run writes nothing ---------------------------------
R=$(mkrust retrofit)
printf '# CLAUDE.md\nx\n' > "$R/CLAUDE.md"
"$BIN/mc-retrofit.sh" --dry-run "$R" >/dev/null 2>&1
checkn "dry-run wrote nothing" test -f "$R/AGENTS.md"

# --- 8. self-guard refuses a real apply on the repo itself ----------------
checkn "self-guard refuses repo" "$BIN/mc-apply.sh" "$REPO"

# --- 9. --modules filters the inline bake -------------------------------------
M=$(mkrust modules)
"$BIN/mc-install.sh" "$M" --inline --modules 10,30 >/dev/null
check  "modules: 10 included" grep -q '^# 10 —' "$M/AGENTS.md"
check  "modules: 30 included" grep -q '^# 30 —' "$M/AGENTS.md"
checkn "modules: 20 excluded" grep -q '^# Module 20 —' "$M/AGENTS.md"
check  "modules: stamp records selection" grep -q 'modules=10,30' "$M/AGENTS.md"

# --- 10. version stamp present + doctor reports it ----------------------------
check "version stamp present" grep -q 'mc-core:' "$M/AGENTS.md"
if "$BIN/mc-doctor.sh" "$M" 2>&1 | grep -q 'core version'; then ok "doctor reports core version"; else no "doctor version"; fi

# --- 11. repo self-check passes ----------------------------------------------
check "mc-selfcheck passes on the repo" "$BIN/mc-selfcheck.sh"

# --- 12. mem-bridge dry-run builds a digest and writes nothing ----------------
BH="$SBROOT/codexhome"
"$BIN/mc-mem-bridge.sh" --only codex --codex-home "$BH" >/dev/null 2>&1
checkn "mem-bridge dry-run wrote nothing" test -f "$BH/master-memory.md"
"$BIN/mc-mem-bridge.sh" --only codex --codex-home "$BH" --execute >/dev/null 2>&1 || true
check "mem-bridge --execute writes digest" test -f "$BH/master-memory.md"

# --- 13. guards: git destructive is dirty-aware ------------------------------
# The whole point of doing this as a hook rather than a permissions.deny rule is that
# `git checkout <file>` is fine on a clean tree and unrecoverable on a dirty one.
GUARDS="$REPO/guards"
GB="$GUARDS/guard-bash.sh"
GREPO="$SBROOT/guardrepo"
mkdir -p "$GREPO"
( cd "$GREPO" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'orig\n' > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1

# gdeny LABEL COMMAND -> pass when the guard denies; gallow -> pass when it does not
gjson() { jq -Rn --arg c "$1" --arg d "$GREPO" \
            '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'; }
gout()  { gjson "$1" | sh "$GB" 2>/dev/null; }
gdeny() { if [ -n "$(gout "$2")" ]; then ok "$1"; else no "$1"; fi; }
gallow(){ if [ -n "$(gout "$2")" ]; then no "$1"; else ok "$1"; fi; }

gallow "guard: checkout allowed on clean tree" "git checkout f.txt"
gallow "guard: reset --hard allowed on clean tree" "git reset --hard"
printf 'dirty\n' > "$GREPO/f.txt"
gdeny  "guard: checkout denied on dirty tree" "git checkout f.txt"
gdeny  "guard: checkout -- denied on dirty tree" "git checkout -- f.txt"
gdeny  "guard: restore denied on dirty tree" "git restore f.txt"
gdeny  "guard: reset --hard denied on dirty tree" "git reset --hard"
gallow "guard: branch switch still allowed" "git checkout -b feature"
gallow "guard: read-only git still allowed" "git status --short"

# --- 14. guards: in-place edits, sudo, and evasion paths ---------------------
gdeny  "guard: sed -i denied" "sed -i 's/a/b/' f.txt"
gdeny  "guard: sed -n -i denied (the 0-byte truncation case)" "sed -n -i 's/a/b/' f.txt"
gdeny  "guard: perl -pi denied" "perl -pi -e 's/a/b/' f.txt"
gallow "guard: sed without -i allowed" "sed -n '1,5p' f.txt"
gallow "guard: perl -MList::Util not read as -i" "perl -MList::Util -e 'print 1'"
gdeny  "guard: sudo denied" "sudo systemctl restart foo"
gdeny  "guard: env-prefixed sudo denied" "FOO=bar sudo id"
gdeny  "guard: wrapped sed -i denied" "timeout 30 sed -i 's/a/b/' f.txt"
gdeny  "guard: compound subcommand denied" "echo hi && git reset --hard"
gdeny  "guard: rm -rf of a home root denied" "rm -rf ~"
gallow "guard: ordinary build commands unaffected" "cargo test --all"

# --- 15. guard-write blocks protected paths ----------------------------------
GW="$GUARDS/guard-write.sh"
wout()  { jq -Rn --arg p "$1" '{tool_name:"Write",tool_input:{file_path:$p}}' | sh "$GW" 2>/dev/null; }
wdeny() { if [ -n "$(wout "$2")" ]; then ok "$1"; else no "$1"; fi; }
wallow(){ if [ -n "$(wout "$2")" ]; then no "$1"; else ok "$1"; fi; }
wdeny  "guard-write: settings.json blocked" "$SBROOT/p/.claude/settings.json"
wdeny  "guard-write: .git internals blocked" "$SBROOT/p/.git/config"
wdeny  "guard-write: .env blocked" "$SBROOT/p/.env"
wallow "guard-write: ordinary source file allowed" "$SBROOT/p/src/main.rs"

# --- 16. mc-guard install is idempotent and preserves foreign hooks ----------
# Regression guard for the real failure mode: the live settings.json already carries an
# unrelated PreToolUse/Bash hook (rtk), and a merge that replaced the array would delete it.
GS="$SBROOT/settings.json"
printf '%s' '{"permissions":{"allow":["Bash"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/usr/bin/foreign-hook"}]}]}}' > "$GS"
"$BIN/mc-guard.sh" install --settings "$GS" >/dev/null 2>&1
check "mc-guard: foreign hook preserved" grep -q 'foreign-hook' "$GS"
check "mc-guard: guard-bash registered" grep -q 'guard-bash.sh' "$GS"
check "mc-guard: guard-write registered" grep -q 'guard-write.sh' "$GS"
check "mc-guard: deny rules merged" grep -q 'git reset --hard' "$GS"
check "mc-guard: existing allow untouched" grep -q '"Bash"' "$GS"
B1=$(jq -S . "$GS")
"$BIN/mc-guard.sh" install --settings "$GS" >/dev/null 2>&1
B2=$(jq -S . "$GS")
if [ "$B1" = "$B2" ]; then ok "mc-guard: install is idempotent"; else no "mc-guard: install is idempotent"; fi
check "mc-guard: verify passes after install" "$BIN/mc-guard.sh" verify --settings "$GS"

# --- 17. mc-guard uninstall is clean and reversible --------------------------
"$BIN/mc-guard.sh" uninstall --settings "$GS" >/dev/null 2>&1
checkn "mc-guard: guard-bash removed" grep -q 'guard-bash.sh' "$GS"
checkn "mc-guard: deny rules removed" grep -q 'git reset --hard' "$GS"
check  "mc-guard: foreign hook survived uninstall" grep -q 'foreign-hook' "$GS"
check  "mc-guard: settings still valid JSON" jq -e . "$GS"

# --- 18. settings clobber: block the write, never the read -------------------
# Regression: an earlier version tested the whole command string for a '>' and a settings
# path anywhere in it, so `jq . ~/.claude/settings.json >/dev/null` was denied. Reading a
# settings file is legitimate and common; only a write to one is a clobber.
gallow "guard: reading settings with an unrelated redirect" \
       'jq -e . ~/.claude/settings.json >/dev/null && echo ok'
gallow "guard: reading settings via cat" "cat ~/.claude/settings.json | jq .permissions"
gdeny  "guard: redirect onto settings blocked" 'echo "{}" > ~/.claude/settings.json'
gdeny  "guard: append onto settings blocked" 'echo "{}" >> ~/.claude/settings.local.json'
gdeny  "guard: tee onto settings blocked" "cat x.json | tee ~/.claude/settings.json"
gdeny  "guard: cp onto settings blocked" "cp /tmp/evil.json ~/.claude/settings.json"

# --- 19. `cd repo && git ...` is judged against the repo, not the session cwd ------
# Regression, found live: the guard checked dirtiness against the hook's cwd, so
# `cd repo && git checkout f.txt` passed the check and destroyed the file. The cd-prefixed
# form is how most of these commands are actually written, so this case is load-bearing.
# Note the payload cwd here is deliberately NOT the repo.
ojson() { jq -Rn --arg c "$1" --arg d "$SBROOT" \
            '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'; }
oout()  { ojson "$1" | sh "$GB" 2>/dev/null; }
odeny() { if [ -n "$(oout "$2")" ]; then ok "$1"; else no "$1"; fi; }
oallow(){ if [ -n "$(oout "$2")" ]; then no "$1"; else ok "$1"; fi; }

# $GREPO is dirty at this point (group 13 left it modified)
odeny  "guard: cd+checkout judged against the target repo" \
       "cd $GREPO && git checkout f.txt"
odeny  "guard: cd+reset judged against the target repo" \
       "cd $GREPO && git reset --hard"
odeny  "guard: git -C judged against the named repo" \
       "git -C $GREPO checkout f.txt"
( cd "$GREPO" && git checkout f.txt ) >/dev/null 2>&1   # clean it
oallow "guard: cd+checkout allowed once that repo is clean" \
       "cd $GREPO && git checkout f.txt"

if [ "$FAILS" -eq 0 ]; then printf '\nALL PASS\n'; else printf '\n%d FAILED\n' "$FAILS"; fi
[ "$FAILS" -eq 0 ]
