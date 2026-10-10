#!/bin/sh
# mc-commands.sh — register Master-Claude's shared agent assets where Claude Code finds them.
# Claude Code only discovers slash commands in ~/.claude/commands (global) or
# <project>/.claude/commands, and subagents in ~/.claude/agents. This symlinks (or copies)
# the repo's commands/*.md or agents/*.md into one of those so /mc-setup et al. become
# available, and so the scout/sweeper/verifier subagents resolve.
#
# Usage: mc-commands.sh [--global | --project <dir>] [--agents] [--copy] [--force] [--list]
#   --global (default)  install into ~/.claude/<kind>
#   --project <dir>     install into <dir>/.claude/<kind>
#   --agents            install agents/ instead of commands/ (kind = agents)
#   --copy              copy instead of symlink (default: symlink, so repo edits propagate)
#   --force             replace a colliding file (backs it up to *.mc-bak first)
#   --list              just list what would be installed and any collisions
set -eu

die() { printf 'mc-commands: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

KIND=commands
SCOPE=global
PROJDIR=''
COPY=0; FORCE=0; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --global) SCOPE=global; shift ;;
    --project) SCOPE=project; PROJDIR="${2:-}"; shift 2 ;;
    --agents) KIND=agents; shift ;;
    --commands) KIND=commands; shift ;;
    --copy) COPY=1; shift ;;
    --force) FORCE=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) die "unexpected arg: $1" ;;
  esac
done

SRC="$REPO_ROOT/$KIND"
[ -d "$SRC" ] || die "no $KIND/ dir in repo"
if [ "$SCOPE" = project ]; then
  [ -n "$PROJDIR" ] || die "--project needs a directory"
  DEST="$PROJDIR/.claude/$KIND"
else
  DEST="$HOME/.claude/$KIND"
fi

[ "$LIST" -eq 1 ] || mkdir -p "$DEST"
printf 'mc-commands: target %s\n' "$DEST"

n_ok=0; n_skip=0
for f in "$SRC"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename -- "$f")
  d="$DEST/$base"

  if [ "$LIST" -eq 1 ]; then
    if [ -e "$d" ] && [ ! -L "$d" ]; then printf '  COLLISION %s (real file exists)\n' "$base"
    else printf '  would install %s\n' "$base"; fi
    continue
  fi

  if [ -e "$d" ] && [ ! -L "$d" ]; then
    if [ "$FORCE" -eq 1 ]; then
      cp "$d" "$d.mc-bak"; rm -f "$d"
      printf '  [force] backed up existing %s -> %s.mc-bak\n' "$base" "$base"
    else
      printf '  [skip] %s already exists (use --force to replace)\n' "$base"
      n_skip=$((n_skip+1)); continue
    fi
  fi

  rm -f "$d"
  if [ "$COPY" -eq 1 ]; then cp "$f" "$d"; else ln -s "$f" "$d"; fi
  n_ok=$((n_ok+1))
done

[ "$LIST" -eq 1 ] && exit 0
printf 'mc-commands: installed %d %s, skipped %d. Restart Claude Code (or /reload) to pick them up.\n' "$n_ok" "$KIND" "$n_skip"
