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

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
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
  if [ "$MODE" = import ]; then
    if grep -q '^<!-- mc-core: .*imports=absolute' "$AGENTS"; then
      ok "absolute @imports (requested with --absolute-imports; keep out of shared repos)"
    elif grep -q '^@/.*master-core/' "$AGENTS"; then
      warn "absolute @imports embed your home path (leaks the username if committed) — run mc-sync to switch to @~/"
    else ok "home-relative @~/ imports"; fi
  fi
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

# Antigravity CLI present on this machine? (MC_AGY_INSTALLED=1 forces it, for tests)
AGY=0
if [ "${MC_AGY_INSTALLED:-}" = 1 ] || command -v agy >/dev/null 2>&1 || [ -d "$HOME/.gemini/antigravity-cli" ]; then AGY=1; fi

# 3c. agy reads AGENTS.md/GEMINI.md but caps every rule file at 24,000 bytes (documented,
# verified with agy 1.5.6): anything past that is silently cut, in any mode.
if [ "$AGY" = 1 ] && [ -f "$AGENTS" ]; then
  BYTES=$(wc -c < "$AGENTS" | tr -d ' ')
  if [ "$BYTES" -gt 24000 ]; then
    warn "AGENTS.md is $BYTES bytes: Antigravity CLI truncates rule files at 24,000 bytes, so agy never sees the last $((BYTES - 24000)) — slim the project block (/mc-curate) or switch an --inline install to --import"
  else ok "AGENTS.md $BYTES bytes (within agy's 24,000-byte rule-file cap)"; fi
fi

# 4. tri-agent parity gap. Only Claude Code expands @imports: Codex and Antigravity CLI
# (agy, verified 1.5.6) read AGENTS.md/GEMINI.md but ignore every @import line; the
# deprecated Gemini CLI processes imports but cannot expand @~/. In import mode they all
# see only the project block.
if [ "${MODE:-none}" = import ]; then
  if [ -d "$PROJECT/.codex" ] || [ -d "$PROJECT/.gemini" ]; then
    warn "import mode + .codex/.gemini present: Codex/Gemini CLI miss the @import modules — consider --inline"
  fi
  # Antigravity CLI gets the core globally through the Master-Claude agy plugin that
  # bin/mc-agy.sh maintains (agy ignores @imports, so per-project imports never reach it).
  if [ "$AGY" = 1 ]; then
    AGY_PLUGIN="${MC_AGY_PLUGIN_DIR:-$HOME/.gemini/config/plugins/master-claude}"
    if "$SCRIPT_DIR/mc-agy.sh" verify -q; then
      ok "Antigravity CLI gets the core globally (agy plugin current: $AGY_PLUGIN)"
    else
      warn "Antigravity CLI (agy) is installed but the Master-Claude agy plugin is missing or stale, so agy misses the @import modules here — run: $SCRIPT_DIR/mc-agy.sh install"
    fi
  elif [ -d "$PROJECT/.agents" ]; then
    warn "import mode + .agents/ present but the Master-Claude agy plugin is not installed — run mc-agy.sh install"
  elif command -v gemini >/dev/null 2>&1; then
    warn "Gemini CLI (deprecated) installed: it cannot expand @~/ imports — use --inline if you run it here"
  fi
fi

# 5. stray backups
ls "$PROJECT"/*.mc-bak >/dev/null 2>&1 && warn "leftover *.mc-bak backups present (review/remove)"

# 6. enforcement layer (machine-wide, not per-project — reported here because this is the
# audit users actually run). Guards live in user settings and apply to every project.
GSETTINGS="$HOME/.claude/settings.json"
if [ -f "$GSETTINGS" ] && command -v jq >/dev/null 2>&1; then
  if jq -e 'any((.hooks.PreToolUse // [])[]; any((.hooks // [])[]; .command | test("guard-bash")))' \
       "$GSETTINGS" >/dev/null 2>&1; then
    nd=$(jq '(.permissions.deny // []) | length' "$GSETTINGS" 2>/dev/null || printf 0)
    ok "guards installed (permissions.deny: $nd rules)"
  else
    warn "guards not installed — run bin/mc-guard.sh install (enforcement is machine-wide)"
  fi
fi

printf 'mc-doctor: %d fail, %d warn\n' "$fails" "$warns"
[ "$fails" -eq 0 ]
