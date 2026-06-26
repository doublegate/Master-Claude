#!/bin/sh
# mc-doctor.sh — audit a project's agent-instruction files.
# Read-only: checks canonical file, symlink integrity, size, core link, parity gaps.
# Exit 0 if no FAIL (warnings allowed), 1 if any FAIL.
#
# Usage: mc-doctor.sh <project-dir>
set -eu

PROJECT="${1:-}"
[ -n "$PROJECT" ] || { printf 'mc-doctor: missing <project-dir>\n' >&2; exit 2; }
[ -d "$PROJECT" ] || { printf 'mc-doctor: not a directory: %s\n' "$PROJECT" >&2; exit 2; }
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)

CORE_LINK="$HOME/.claude/master-core"
fails=0
warns=0
ok()   { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; warns=$((warns+1)); }
fail() { printf '  [FAIL] %s\n' "$1"; fails=$((fails+1)); }

printf 'mc-doctor: %s\n' "$PROJECT"

# 1. canonical AGENTS.md
AGENTS="$PROJECT/AGENTS.md"
if [ -f "$AGENTS" ] && [ ! -L "$AGENTS" ]; then
  ok "AGENTS.md present (canonical)"
  if grep -q '<<< MC-PROJECT-START >>>' "$AGENTS"; then ok "managed by Master-Claude"
  else warn "AGENTS.md present but not Master-Claude-managed"; fi
  LINES=$(wc -l < "$AGENTS" | tr -d ' ')
  if grep -q '^@.*master-core/' "$AGENTS"; then MODE=import; else MODE=inline; fi
  if [ "$MODE" = import ] && [ "$LINES" -gt 200 ]; then warn "import-mode AGENTS.md is $LINES lines (>200)"
  else ok "AGENTS.md size $LINES lines (mode=$MODE)"; fi
else
  fail "no canonical AGENTS.md"; MODE=none
fi

# 2. sibling symlinks
for f in CLAUDE.md GEMINI.md; do
  p="$PROJECT/$f"
  if [ -L "$p" ]; then
    tgt=$(readlink "$p")
    if [ "$tgt" = "AGENTS.md" ]; then ok "$f -> AGENTS.md"
    else warn "$f symlink points to '$tgt' (expected AGENTS.md)"; fi
  elif [ -e "$p" ]; then warn "$f is a real file, not a symlink to AGENTS.md"
  else warn "$f missing"; fi
done

# 3. shared core link (needed for import mode)
if [ -e "$CORE_LINK" ]; then ok "shared core present at $CORE_LINK"
elif [ "${MODE:-none}" = import ]; then fail "import mode but $CORE_LINK missing (broken @import)"
else warn "$CORE_LINK missing (ok for inline mode)"; fi

# 3b. core version drift
if [ -f "$AGENTS" ]; then
  INST_VER=$(sed -n 's/.*mc-core: \([^ |]*\).*/\1/p' "$AGENTS" 2>/dev/null | head -n 1)
  if [ -n "$INST_VER" ] && [ -f "$CORE_LINK/VERSION" ]; then
    CUR_VER=$(cat "$CORE_LINK/VERSION")
    if [ "$INST_VER" = "$CUR_VER" ]; then ok "core version $INST_VER (current)"
    else warn "core version $INST_VER installed, $CUR_VER available — run mc-sync"; fi
  elif [ -n "$INST_VER" ]; then ok "core version $INST_VER (current unknown)"
  elif [ "${MODE:-none}" != none ]; then warn "no mc-core version stamp (re-install to add)"; fi
fi

# 4. tri-agent parity gap
if [ "${MODE:-none}" = import ]; then
  if [ -d "$PROJECT/.codex" ] || [ -d "$PROJECT/.gemini" ]; then
    warn "import mode + .codex/.gemini present: Codex/Gemini miss @import modules — consider --inline"
  fi
fi

# 5. stray backups
ls "$PROJECT"/*.mc-bak >/dev/null 2>&1 && warn "leftover *.mc-bak backups present (review/remove)"

printf 'mc-doctor: %d fail, %d warn\n' "$fails" "$warns"
[ "$fails" -eq 0 ]
