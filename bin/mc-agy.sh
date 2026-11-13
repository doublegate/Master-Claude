#!/bin/sh
# mc-agy.sh — give Antigravity CLI (agy) the Master-Claude core, globally, as an agy plugin.
#
# agy ignores @imports, so per-project imports never reach it. Instead this script maintains
# a generated plugin, ~/.gemini/config/plugins/master-claude/, whose rules agy loads in every
# session. The plugin holds the core inline: AGENTS.base.md, the modules, the language
# overlays and the memory-core digest. That is agy's equivalent of Claude's
# @~/.claude/master-core imports, it keeps projects in slim --import mode, and it leaves the
# user's own ~/.gemini/config/GEMINI.md untouched.
#
# Limits (agy's documented ones; verified with agy 1.5.6):
#   - each rule file is capped at 24,000 bytes and truncated beyond that, so the core is
#     packed into rules/AGENTS.md and, if needed, rules/GEMINI.md (agy loads both), each
#     kept under MC_AGY_MAX_BYTES (default 23500);
#   - always-on and global rules share a 20,000-token budget; rules over it are demoted to
#     path pointers. The full core is ~10k tokens; --modules / --no-memory make it smaller.
#
# Usage: mc-agy.sh install   [--modules LIST|none] [--no-memory] [--if-present] [--dry-run] [-q]
#        mc-agy.sh verify    [-q]           exit 0 if the plugin is current
#        mc-agy.sh uninstall [--dry-run]    remove the plugin
#   --modules LIST  comma-separated module number prefixes (e.g. 10,20,30); "none" = base
#                   rules + language overlays only. Default: all modules.
#   --no-memory     leave out the memory-core digest.
#   --full          everything (all modules + memory); resets a stamped slim choice.
#   The size choice is stamped in the plugin, so verify and mc-sync keep it.
# Env:   MC_AGY_PLUGIN_DIR (default ~/.gemini/config/plugins/master-claude)
#        MC_AGY_FILE       global GEMINI.md; a legacy MC-CORE block there is migrated away
#        MC_AGY_MAX_BYTES  per-rule-file byte budget (default 23500)
set -eu

die() { printf 'mc-agy: %s\n' "$1" >&2; exit 2; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CORE="$REPO_ROOT/master-core"
PLUGIN="${MC_AGY_PLUGIN_DIR:-$HOME/.gemini/config/plugins/master-claude}"
GLOBAL="${MC_AGY_FILE:-$HOME/.gemini/config/GEMINI.md}"
MAXB="${MC_AGY_MAX_BYTES:-23500}"
NAME=master-claude
# legacy (pre-plugin) managed block in the global GEMINI.md
LSTART='<!-- MC-CORE-START: managed by Master-Claude bin/mc-agy.sh; edits inside this block are overwritten -->'
LEND='<!-- MC-CORE-END -->'

CMD="${1:-}"
[ $# -gt 0 ] && shift
DRY=0; QUIET=0; IFPRESENT=0; MODULES=""; MEMORY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    -q|--quiet) QUIET=1 ;;
    --if-present) IFPRESENT=1 ;;
    --modules) [ $# -gt 1 ] || die "--modules requires an argument"; MODULES="$2"; shift ;;
    --no-memory) MEMORY=no ;;
    --full) MODULES=all; MEMORY=yes ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done
case "$CMD" in
  install|verify|uninstall) ;;
  -h|--help|help) sed -n '2,30p' "$0"; exit 0 ;;
  *) die "usage: mc-agy.sh install|verify|uninstall (try --help)" ;;
esac
[ -d "$CORE" ] || die "core not found: $CORE"

say() { [ "$QUIET" -eq 1 ] || printf 'mc-agy: %s\n' "$1"; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

is_ours() { [ -f "$PLUGIN/plugin.json" ] && grep -q "\"name\": \"$NAME\"" "$PLUGIN/plugin.json"; }
has_legacy() { [ -f "$GLOBAL" ] && grep -qxF "$LSTART" "$GLOBAL"; }
stamp_of() { sed -n '1p' "$1" 2>/dev/null; }

# No explicit size options: reuse the stamped ones, so verify and mc-sync (install
# --if-present) regenerate exactly what the user chose.
if [ -z "$MODULES" ] && [ -z "$MEMORY" ] && [ -f "$PLUGIN/rules/AGENTS.md" ]; then
  OLD=$(stamp_of "$PLUGIN/rules/AGENTS.md")
  MODULES=$(printf '%s\n' "$OLD" | sed -n 's/.*| modules=\([^ |]*\).*/\1/p')
  MEMORY=$(printf '%s\n' "$OLD" | sed -n 's/.*| memory=\([^ |]*\).*/\1/p')
fi
[ "$MODULES" = all ] && MODULES=""

include_module() {
  [ -n "$MODULES" ] || return 0
  [ "$MODULES" = none ] && return 1
  base=$(basename -- "$1"); num=${base%%-*}
  case ",$MODULES," in *",$num,"*) return 0 ;; *) return 1 ;; esac
}

# --- build the pieces, in order ------------------------------------------------
mkdir -p "$TMP/pieces" "$TMP/plugin/rules"
# piece() must run in this shell (stdin redirection, never a pipe: a pipeline would put it
# in a subshell, the counter would not advance, and every piece would overwrite the first).
n=0
piece() { n=$((n+1)); cat > "$TMP/pieces/$(printf '%03d' "$n")"; }
piece < "$CORE/AGENTS.base.md"
for m in "$CORE"/modules/*.md; do
  [ -e "$m" ] || continue
  include_module "$m" || continue
  piece < "$m"
done
{
  printf '# Language overlays\n\n'
  printf '%s\n' "Apply only the overlay that matches the current project's language."
  for l in "$CORE"/lang/*.md; do [ -e "$l" ] || continue; printf '\n'; cat "$l"; done
} > "$TMP/lang"
piece < "$TMP/lang"
if [ "$MEMORY" != no ]; then
  "$SCRIPT_DIR/mc-mem-bridge.sh" --stdout > "$TMP/memory"
  piece < "$TMP/memory"
fi

VERSION=$(cat "$CORE/VERSION" 2>/dev/null || echo unknown)
SUM=$(cat "$TMP"/pieces/* | cksum | awk '{print $1 "-" $2}')
OPTS=""
[ -n "$MODULES" ] && OPTS="$OPTS | modules=$MODULES"
[ "$MEMORY" = no ] && OPTS="$OPTS | memory=no"
STAMP="<!-- mc-core: $VERSION | content=$SUM$OPTS -->"

# --- pack the pieces into at most two rule files under the byte budget -----------
header() {   # $1 = part number
  if [ "$1" = 1 ]; then printf '%s\n' "$STAMP"; fi
  printf '# Master-Claude shared core (part %s)\n\n' "$1"
  printf '%s\n' "Generated by Master-Claude bin/mc-agy.sh; do not edit (regenerate instead)."
  printf '%s\n' "Universal rules Claude Code loads through @imports in Master-Claude projects. Apply"
  printf '%s\n' "them in every project; a project's own AGENTS.md/GEMINI.md refines them and wins."
}
part=1; header 1 > "$TMP/part1"
for p in "$TMP"/pieces/*; do
  { printf '\n---\n\n'; cat "$p"; } > "$TMP/next"
  cur=$(wc -c < "$TMP/part$part" | tr -d ' '); add=$(wc -c < "$TMP/next" | tr -d ' ')
  if [ $((cur + add)) -gt "$MAXB" ]; then
    [ "$part" = 1 ] || die "the core does not fit agy's two rule files (${MAXB} bytes each); slim it with --modules or --no-memory"
    part=2; header 2 > "$TMP/part2"
    cur=$(wc -c < "$TMP/part2" | tr -d ' ')
    [ $((cur + add)) -le "$MAXB" ] || die "one core piece alone exceeds ${MAXB} bytes"
  fi
  cat "$TMP/next" >> "$TMP/part$part"
done
cp "$TMP/part1" "$TMP/plugin/rules/AGENTS.md"
[ "$part" = 2 ] && cp "$TMP/part2" "$TMP/plugin/rules/GEMINI.md"
{
  printf '{\n'
  printf '  "name": "%s",\n' "$NAME"
  printf '  "description": "Master-Claude shared core rules for Antigravity (generated by Master-Claude bin/mc-agy.sh; do not edit)",\n'
  printf '  "version": "%s"\n' "$VERSION"
  printf '}\n'
} > "$TMP/plugin/plugin.json"

TOTAL=$(cat "$TMP"/plugin/rules/* | wc -c | tr -d ' ')
TOKENS=$((TOTAL / 4))

is_current() { is_ours && diff -rq "$TMP/plugin" "$PLUGIN" >/dev/null 2>&1; }

remove_legacy() {   # migrate the old in-GEMINI.md block away (user text kept, backup made)
  has_legacy || return 0
  if [ "$DRY" -eq 1 ]; then say "dry-run: would remove the legacy MC-CORE block from $GLOBAL"; return 0; fi
  cp -p "$GLOBAL" "$GLOBAL.mc-bak"
  awk -v s="$LSTART" -v e="$LEND" '
    $0 == s { skip = 1; next }
    skip && $0 == e { skip = 0; next }
    !skip { line[++k] = $0 }
    END { while (k > 0 && line[k] ~ /^[[:space:]]*$/) k--; for (i = 1; i <= k; i++) print line[i] }
  ' "$GLOBAL.mc-bak" > "$GLOBAL"
  say "removed the legacy MC-CORE block from $GLOBAL (backup: $GLOBAL.mc-bak)"
}

# --- commands ---------------------------------------------------------------------
case "$CMD" in
  verify)
    if has_legacy; then say "legacy MC-CORE block in $GLOBAL (run: mc-agy.sh install to migrate)"; exit 1; fi
    if ! is_ours; then say "Master-Claude agy plugin not installed at $PLUGIN (run: mc-agy.sh install)"; exit 1; fi
    if is_current; then say "plugin current ($VERSION, ~$TOKENS tokens) at $PLUGIN"; exit 0; fi
    say "plugin at $PLUGIN is stale (core changed; run: mc-agy.sh install)"; exit 1 ;;

  install)
    if [ "$IFPRESENT" -eq 1 ] && ! is_ours && ! has_legacy; then exit 0; fi
    if [ -e "$PLUGIN" ] && ! is_ours; then die "$PLUGIN exists and is not the Master-Claude plugin; not touching it"; fi
    remove_legacy
    if is_current; then say "already current at $PLUGIN"; exit 0; fi
    if [ "$DRY" -eq 1 ]; then
      say "dry-run: would write $PLUGIN ($part rule file(s), $TOTAL bytes, ~$TOKENS of agy's 20,000-token rules budget)"
      exit 0
    fi
    mkdir -p "$PLUGIN/rules"
    rm -f "$PLUGIN/rules/AGENTS.md" "$PLUGIN/rules/GEMINI.md"
    cp "$TMP/plugin/plugin.json" "$PLUGIN/plugin.json"
    cp "$TMP"/plugin/rules/* "$PLUGIN/rules/"
    say "wrote $PLUGIN ($part rule file(s), $TOTAL bytes, ~$TOKENS of agy's 20,000-token rules budget)" ;;

  uninstall)
    remove_legacy
    if ! is_ours; then say "no Master-Claude agy plugin at $PLUGIN"; exit 0; fi
    if [ "$DRY" -eq 1 ]; then say "dry-run: would remove $PLUGIN"; exit 0; fi
    rm -rf "$PLUGIN"
    say "removed $PLUGIN" ;;
esac
