#!/bin/sh
# mc-sync.sh — re-pull the updated shared core into an already-installed project.
# Re-derives the project's language + mode from its AGENTS.md, then re-runs the
# installer (which preserves the hand-authored MC-PROJECT block). Idempotent.
#
# Usage: mc-sync.sh <project-dir>
set -eu

die() { printf 'mc-sync: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT="${1:-}"
[ -n "$PROJECT" ] || die "missing <project-dir>"
[ -d "$PROJECT" ] || die "not a directory: $PROJECT"
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)

AGENTS="$PROJECT/AGENTS.md"
[ -f "$AGENTS" ] || die "no AGENTS.md — run mc-install.sh first"
grep -q '<<< MC-PROJECT-START >>>' "$AGENTS" || die "AGENTS.md is not Master-Claude-managed"

# mode: presence of @import lines pointing at master-core => import, else inline
if grep -q '^@.*master-core/' "$AGENTS"; then MODE=--import; else MODE=--inline; fi

# language: re-detect from project files (same logic as install)
if   [ -f "$PROJECT/Cargo.toml" ]; then LANG=rust
elif [ -f "$PROJECT/pyproject.toml" ] || [ -f "$PROJECT/requirements.txt" ]; then LANG=python
elif [ -f "$PROJECT/package.json" ]; then LANG=typescript
else LANG=generic
fi

# report core version delta (read the stamp before re-installing overwrites it)
OLD_VER=$(sed -n 's/.*mc-core: \([^ |]*\).*/\1/p' "$AGENTS" | head -n 1)
NEW_VER=$(cat "$SCRIPT_DIR/../master-core/VERSION" 2>/dev/null || echo unknown)
if [ -n "$OLD_VER" ] && [ "$OLD_VER" != "$NEW_VER" ]; then
  printf 'mc-sync: core %s -> %s\n' "$OLD_VER" "$NEW_VER"
fi

# import paths: keep an explicit --absolute-imports choice (stamped "imports=absolute");
# otherwise (re)write home-relative @~/ imports. A legacy file with absolute imports but
# no stamp predates the home-relative default and is converted, which also removes the
# username those paths leak into a committed AGENTS.md.
ABS=""
if grep -q '^<!-- mc-core: .*imports=absolute' "$AGENTS"; then
  ABS=--absolute-imports
elif grep -q '^@/.*master-core/' "$AGENTS"; then
  printf 'mc-sync: converting absolute @imports to home-relative @~/ (use mc-install.sh --absolute-imports to keep them)\n'
fi

printf 'mc-sync: re-syncing %s (lang=%s, %s%s)\n' "$(basename -- "$PROJECT")" "$LANG" "$MODE" \
  "${ABS:+, $ABS}"
if [ -n "$ABS" ]; then
  "$SCRIPT_DIR/mc-install.sh" "$PROJECT" --lang "$LANG" "$MODE" "$ABS"
else
  "$SCRIPT_DIR/mc-install.sh" "$PROJECT" --lang "$LANG" "$MODE"
fi

# Keep Antigravity's global copy of the core current too (only refreshes an existing block;
# it never creates one — that is an explicit `mc-agy.sh install`).
"$SCRIPT_DIR/mc-agy.sh" install --if-present -q
