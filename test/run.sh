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

if [ "$FAILS" -eq 0 ]; then printf '\nALL PASS\n'; else printf '\n%d FAILED\n' "$FAILS"; fi
[ "$FAILS" -eq 0 ]
