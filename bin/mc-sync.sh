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

printf 'mc-sync: re-syncing %s (lang=%s, %s)\n' "$(basename -- "$PROJECT")" "$LANG" "$MODE"
exec "$SCRIPT_DIR/mc-install.sh" "$PROJECT" --lang "$LANG" "$MODE"
