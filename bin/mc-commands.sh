#!/bin/sh
# mc-commands.sh — register Master-Claude's command library where the agent can find it.
# Claude Code only discovers slash commands in ~/.claude/commands (global) or
# <project>/.claude/commands (project-scoped). This symlinks (or copies) the repo's
# commands/*.md into one of those so /mc-setup et al. become available.
#
# Usage: mc-commands.sh [--global | --project <dir>] [--copy] [--force] [--list]
#   --global (default)  install into ~/.claude/commands
#   --project <dir>     install into <dir>/.claude/commands
#   --copy              copy instead of symlink (default: symlink, so repo edits propagate)
#   --force             replace a colliding command (backs it up to *.mc-bak first)
#   --list              just list what would be installed and any collisions
set -eu

die() { printf 'mc-commands: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
SRC="$REPO_ROOT/commands"
[ -d "$SRC" ] || die "no commands/ dir in repo"

DEST="$HOME/.claude/commands"
COPY=0; FORCE=0; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --global) DEST="$HOME/.claude/commands"; shift ;;
    --project) DEST="${2:-}/.claude/commands"; shift 2 ;;
    --copy) COPY=1; shift ;;
    --force) FORCE=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) die "unexpected arg: $1" ;;
  esac
done

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
printf 'mc-commands: installed %d, skipped %d. Reload commands (restart Claude Code or /reload).\n' "$n_ok" "$n_skip"
