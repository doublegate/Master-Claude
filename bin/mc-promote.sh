#!/bin/sh
# mc-promote.sh — promote a project-scoped memory fact into the shared memory-core.
# Copies the fact, marks it scope=universal with today's date, and adds a MEMORY.md hook.
# The original project fact is left in place. You then curate the copy (strip specifics).
#
# Usage: mc-promote.sh <project-dir> <fact-slug> [--date YYYY-MM-DD]
#   <fact-slug> is the basename (without .md) of a file in that project's memory dir:
#   ~/.claude/projects/<path-slug>/memory/<fact-slug>.md
set -eu

die() { printf 'mc-promote: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
MEMCORE="$REPO_ROOT/memory-core"

PROJECT="${1:-}"; SLUG="${2:-}"
[ -n "$PROJECT" ] && [ -n "$SLUG" ] || die "usage: mc-promote.sh <project-dir> <fact-slug> [--date YYYY-MM-DD]"
shift 2 || true
DATE=""
while [ $# -gt 0 ]; do case "$1" in --date) DATE="${2:-}"; shift 2 ;; *) die "unknown flag: $1" ;; esac; done
[ -n "$DATE" ] || die "pass --date YYYY-MM-DD (scripts here cannot read the clock; supply it)"

[ -d "$PROJECT" ] || die "not a directory: $PROJECT"
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)

# project path -> ~/.claude/projects slug (leading-dash, slashes to dashes)
PSLUG=$(printf '%s' "$PROJECT" | sed 's#/#-#g')
SRC="$HOME/.claude/projects/$PSLUG/memory/$SLUG.md"
[ -f "$SRC" ] || die "fact not found: $SRC"

DST="$MEMCORE/$SLUG.md"
[ -e "$DST" ] && die "already promoted: $DST (edit it directly)"

# copy, then set scope=universal + lastVerified; leave content for manual curation
sed -e 's/^[[:space:]]*scope:.*$/  scope: universal/' \
    -e "s/^[[:space:]]*lastVerified:.*$/  lastVerified: $DATE/" \
    "$SRC" > "$DST"
# shellcheck disable=SC2016  # backticks are literal Markdown in the note, not command substitution
grep -q 'scope: universal' "$DST" || printf '\n> NOTE: add `scope: universal` + `lastVerified: %s` to frontmatter.\n' "$DATE" >> "$DST"

# add a MEMORY.md hook line (best-effort; dedupe)
HOOK="- [$SLUG]($SLUG.md) — promoted $DATE; curate to strip project specifics"
grep -q "($SLUG.md)" "$MEMCORE/MEMORY.md" 2>/dev/null || printf '%s\n' "$HOOK" >> "$MEMCORE/MEMORY.md"

printf 'mc-promote: copied %s -> %s\n' "$SLUG" "$DST"
printf '  next: edit %s to strip project-specific details, then commit.\n' "$DST"
