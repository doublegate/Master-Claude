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
# Never touch the real Antigravity config: mc-sync/mc-apply/mc-doctor consult mc-agy.sh,
# which honours MC_AGY_PLUGIN_DIR (the plugin) and MC_AGY_FILE (legacy-block migration).
export MC_AGY_PLUGIN_DIR="$SBROOT/agy/plugins/master-claude"
export MC_AGY_FILE="$SBROOT/agy/GEMINI.md"
unset MC_AGY_INSTALLED MC_AGY_MAX_BYTES

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
check "imports are home-relative (@~/)" grep -q '^@~/\.claude/master-core/AGENTS.base.md' "$P/AGENTS.md"
checkn "no home path leaked into AGENTS.md" grep -qF "$HOME" "$P/AGENTS.md"

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
AH="$SBROOT/agyhome"
"$BIN/mc-mem-bridge.sh" --only agy --agy-home "$AH" >/dev/null 2>&1
checkn "mem-bridge agy dry-run wrote nothing" test -f "$AH/master-memory.md"
"$BIN/mc-mem-bridge.sh" --only antigravity --agy-home "$AH" --execute >/dev/null 2>&1 || true
check "mem-bridge writes the Antigravity digest" test -f "$AH/master-memory.md"
check "mem-bridge tells agy to read (not @import) the digest" sh -c "'$BIN/mc-mem-bridge.sh' --only agy --agy-home '$AH' | grep -q 'read $AH/master-memory.md'"
checkn "mem-bridge rejects an unknown target" "$BIN/mc-mem-bridge.sh" --only bogus

# --- 12a. an Antigravity workspace (.agents/) makes mc-apply pick --inline ----
G=$(mkrust agyworkspace)
mkdir -p "$G/.agents/skills"
"$BIN/mc-apply.sh" "$G" >/dev/null 2>&1 || true
checkn "mc-apply: .agents/ project gets no @import lines" grep -q '^@.*master-core' "$G/AGENTS.md"
check  "mc-apply: .agents/ project is inline" grep -q 'mode=inline' "$G/AGENTS.md"

# --- 12c. mc-agy.sh: the core reaches Antigravity through a generated agy plugin ----
AGY="$BIN/mc-agy.sh"
PR="$MC_AGY_PLUGIN_DIR/rules"
mkdir -p "$(dirname -- "$MC_AGY_FILE")"
printf '# My own agy rules\n\nKEEP-ME-123\n' > "$MC_AGY_FILE"
checkn "agy: verify fails before install" "$AGY" verify -q
"$AGY" install --dry-run -q
checkn "agy: --dry-run writes nothing" test -e "$MC_AGY_PLUGIN_DIR"
"$AGY" install -q
check  "agy: install writes plugin.json" grep -q '"name": "master-claude"' "$MC_AGY_PLUGIN_DIR/plugin.json"
check  "agy: plugin.json is valid JSON" sh -c "command -v python3 >/dev/null || exit 0; python3 -c 'import json,sys; json.load(open(sys.argv[1]))' '$MC_AGY_PLUGIN_DIR/plugin.json'"
check  "agy: rules carry the base rules" sh -c "cat '$PR'/* | grep -q 'Conventional Commits'"
check  "agy: rules carry every module" sh -c "for m in '$REPO'/master-core/modules/*.md; do h=\$(grep -m1 '^#' \"\$m\"); cat '$PR'/* | grep -qxF \"\$h\" || exit 1; done"
check  "agy: rules carry the memory digest" sh -c "cat '$PR'/* | grep -q 'shared memory digest'"
check  "agy: full core is split over AGENTS.md + GEMINI.md" test -f "$PR/GEMINI.md"
check  "agy: every rule file is under agy's 24,000-byte cap" sh -c "for f in '$PR'/*; do [ \$(wc -c < \"\$f\") -le 23500 ] || exit 1; done"
check  "agy: the user's global GEMINI.md is untouched" grep -qx 'KEEP-ME-123' "$MC_AGY_FILE"
checkn "agy: no block is written into the global GEMINI.md" grep -q 'MC-CORE' "$MC_AGY_FILE"
check  "agy: verify passes when current" "$AGY" verify -q
S1=$(cat "$PR"/* | cksum); "$AGY" install -q; S2=$(cat "$PR"/* | cksum)
if [ "$S1" = "$S2" ]; then ok "agy: install is idempotent"; else no "agy: install idempotent"; fi
# doctor: Antigravity present (forced, so the test does not depend on agy being installed)
DP=$(mkrust agydoctor); "$BIN/mc-install.sh" "$DP" >/dev/null
check  "agy: doctor OK with a current plugin" sh -c "MC_AGY_INSTALLED=1 '$BIN/mc-doctor.sh' '$DP' | grep -q 'gets the core globally'"
check  "agy: doctor checks the 24,000-byte rule-file cap" sh -c "MC_AGY_INSTALLED=1 '$BIN/mc-doctor.sh' '$DP' | grep -q 'within agy.s 24,000-byte'"
# stale plugin (core changed): verify fails, doctor warns, mc-sync refreshes it
printf '\nstale\n' >> "$PR/AGENTS.md"
checkn "agy: verify detects a stale plugin" "$AGY" verify -q
check  "agy: doctor warns when the plugin is stale" sh -c "MC_AGY_INSTALLED=1 '$BIN/mc-doctor.sh' '$DP' | grep -q 'missing or stale'"
"$BIN/mc-sync.sh" "$DP" >/dev/null
check  "agy: mc-sync refreshes an existing plugin" "$AGY" verify -q
# with the plugin current, an .agents/ project stays slim (import mode)
G2=$(mkrust agyworkspace2); mkdir -p "$G2/.agents"
"$BIN/mc-apply.sh" "$G2" >/dev/null 2>&1 || true
check  "agy: .agents/ project stays import when agy has the core" grep -q 'mode=import' "$G2/AGENTS.md"
# slim plugins: the size choice is stamped and survives verify, sync and --full
"$AGY" install -q --modules none --no-memory
check  "agy: --modules none --no-memory is stamped" grep -q 'modules=none | memory=no' "$PR/AGENTS.md"
checkn "agy: slim plugin needs no second rule file" test -f "$PR/GEMINI.md"
checkn "agy: slim plugin has no modules" grep -q '^# 10 —' "$PR/AGENTS.md"
checkn "agy: slim plugin has no memory digest" grep -q 'shared memory digest' "$PR/AGENTS.md"
check  "agy: verify honours the stamped slim choice" "$AGY" verify -q
"$BIN/mc-sync.sh" "$DP" >/dev/null
check  "agy: mc-sync keeps the slim choice" grep -q 'modules=none | memory=no' "$PR/AGENTS.md"
"$AGY" install -q --modules 10
check  "agy: --modules 10 includes module 10" grep -q '^# 10 —' "$PR/AGENTS.md"
checkn "agy: --modules 10 excludes module 30" grep -q '^# 30 —' "$PR/AGENTS.md"
"$AGY" install -q --full
check  "agy: --full restores the whole core" test -f "$PR/GEMINI.md"
checkn "agy: --full clears the slim stamp" grep -q 'modules=' "$PR/AGENTS.md"
# budget enforcement: a core that cannot fit two rule files is refused, nothing written
checkn "agy: refuses a core that exceeds the rule-file budget" env MC_AGY_MAX_BYTES=4000 "$AGY" install -q --full
check  "agy: a refused install leaves the plugin intact" "$AGY" verify -q
# a foreign directory at the plugin path is never clobbered
FOREIGN="$SBROOT/agy/plugins/foreign"; mkdir -p "$FOREIGN"; printf '{"name": "other"}\n' > "$FOREIGN/plugin.json"
checkn "agy: refuses to overwrite a foreign plugin" env MC_AGY_PLUGIN_DIR="$FOREIGN" "$AGY" install -q
check  "agy: foreign plugin left as it was" grep -q '"other"' "$FOREIGN/plugin.json"
# migration: a legacy in-GEMINI.md block is removed on install, user text kept
{ printf '# My own agy rules\n\nKEEP-ME-123\n\n'
  printf '%s\n' '<!-- MC-CORE-START: managed by Master-Claude bin/mc-agy.sh; edits inside this block are overwritten -->'
  printf 'old core\n<!-- MC-CORE-END -->\n'; } > "$MC_AGY_FILE"
checkn "agy: verify flags a legacy global block" "$AGY" verify -q
"$AGY" install -q
checkn "agy: install migrates the legacy block away" grep -q 'MC-CORE' "$MC_AGY_FILE"
check  "agy: migration keeps the user's text" grep -qx 'KEEP-ME-123' "$MC_AGY_FILE"
check  "agy: migration backs up the global file" grep -q 'MC-CORE' "$MC_AGY_FILE.mc-bak"
"$AGY" uninstall -q
checkn "agy: uninstall removes the plugin" test -e "$MC_AGY_PLUGIN_DIR"
"$AGY" install --if-present -q
checkn "agy: --if-present never creates the plugin" test -e "$MC_AGY_PLUGIN_DIR"
check  "agy: doctor warns when agy lacks the core" sh -c "MC_AGY_INSTALLED=1 '$BIN/mc-doctor.sh' '$DP' | grep -q 'missing or stale'"
# the 24,000-byte cap check flags an oversized AGENTS.md
BIGP=$(mkrust agybig); "$BIN/mc-install.sh" "$BIGP" >/dev/null
awk 'BEGIN{for(i=0;i<500;i++) print "padding line padding line padding line padding line"}' >> "$BIGP/AGENTS.md"
check  "agy: doctor warns on an AGENTS.md over 24,000 bytes" sh -c "MC_AGY_INSTALLED=1 '$BIN/mc-doctor.sh' '$BIGP' | grep -q 'truncates rule files at 24,000 bytes'"

# --- 12b. import path style: opt-in absolute, sync keeps it, legacy converts ---
A=$(mkrust absimports)
"$BIN/mc-install.sh" "$A" --absolute-imports >/dev/null
check "--absolute-imports writes the expanded core path" grep -qF "@$HOME/.claude/master-core/AGENTS.base.md" "$A/AGENTS.md"
check "--absolute-imports is stamped" grep -q '^<!-- mc-core: .*imports=absolute' "$A/AGENTS.md"
"$BIN/mc-sync.sh" "$A" >/dev/null
check "sync keeps a stamped absolute choice" grep -qF "@$HOME/.claude/master-core/AGENTS.base.md" "$A/AGENTS.md"
check "doctor accepts stamped absolute imports" sh -c "'$BIN/mc-doctor.sh' '$A' | grep -q 'requested with --absolute-imports'"
# legacy: absolute imports without the stamp (written before the @~/ default)
sed -i 's/ | imports=absolute//' "$A/AGENTS.md"
check "doctor warns on unstamped absolute imports" sh -c "'$BIN/mc-doctor.sh' '$A' | grep -q 'embed your home path'"
"$BIN/mc-sync.sh" "$A" >/dev/null
check "sync converts legacy absolute imports to @~/" grep -q '^@~/\.claude/master-core/AGENTS.base.md' "$A/AGENTS.md"
checkn "no home path left after conversion" grep -qF "$HOME" "$A/AGENTS.md"

# --- 13-20. guards regression suite -----------------------------------------
GUARDS="$REPO/guards"
export GB="$GUARDS/guard-bash.sh"
. "$REPO/test/guard-tests.sh"

if [ "$FAILS" -eq 0 ]; then printf '\nALL PASS\n'; else printf '\n%d FAILED\n' "$FAILS"; fi
[ "$FAILS" -eq 0 ]
