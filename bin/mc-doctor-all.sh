#!/bin/sh
# mc-doctor-all.sh — audit every Master-Claude-managed project under a workspace root.
# Enumerates projects (depth 1-2, like mc-apply-all), runs mc-doctor on each that has a
# managed AGENTS.md, and prints a one-line-per-project summary. Read-only.
#
# Usage: mc-doctor-all.sh [root-dir] [--all] [--exclude <name>]...
#   --all   also list projects with no managed AGENTS.md (default: skip them).
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SELF_REPO=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
ROOT="$HOME/Code"
SHOW_ALL=0
SKIP="Archive Backups Dev_Test docs HPC_User_Forum metasploitable3-workspace Resume_Personal-Parobek Rust_Test Master-Claude Undertow node_modules target vendor .venv .git .bmad-core gpu-burn-git"

while [ $# -gt 0 ]; do
  case "$1" in
    --all) SHOW_ALL=1; shift ;;
    --exclude) [ $# -gt 1 ] || { printf 'mc-doctor-all: --exclude requires an argument\n' >&2; exit 1; }
               SKIP="$SKIP $2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) printf 'mc-doctor-all: unknown flag: %s\n' "$1" >&2; exit 1 ;;
    *) ROOT="$1"; shift ;;
  esac
done
[ -d "$ROOT" ] || { printf 'mc-doctor-all: not a directory: %s\n' "$ROOT" >&2; exit 1; }
ROOT=$(CDPATH='' cd -- "$ROOT" && pwd)

skipped() { case " $SKIP " in *" $1 "*) return 0 ;; esac; return 1; }
is_project() {
  [ -d "$1/.git" ] || [ -f "$1/Cargo.toml" ] || [ -f "$1/package.json" ] || \
  [ -f "$1/pyproject.toml" ] || [ -f "$1/go.mod" ] || [ -f "$1/requirements.txt" ] || \
  [ -f "$1/CLAUDE.md" ] || [ -f "$1/AGENTS.md" ] || [ -f "$1/GEMINI.md" ]
}
managed() { [ -f "$1/AGENTS.md" ] && grep -q '<<< MC-PROJECT-START >>>' "$1/AGENTS.md" 2>/dev/null; }

list_projects() {
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    db=$(basename -- "$d"); skipped "$db" && continue
    dd=${d%/}; [ "$dd" = "$SELF_REPO" ] && continue
    if is_project "$dd"; then printf '%s\n' "$dd"
    else
      for s in "$d"*/; do
        [ -d "$s" ] || continue
        sb=$(basename -- "$s"); skipped "$sb" && continue
        ss=${s%/}; [ "$ss" = "$SELF_REPO" ] && continue
        is_project "$ss" && printf '%s\n' "$ss"
      done
    fi
  done
}

printf 'mc-doctor-all: auditing managed projects under %s\n\n' "$ROOT"
printf '  %-46s %s\n' "PROJECT" "RESULT"
printf '  %-46s %s\n' "-------" "------"

n_managed=0; n_fail=0; n_warn=0; n_unmanaged=0
# Use a temp file (not `for p in $(...)`) so paths with spaces survive and the counters,
# which are mutated in the loop, are not lost to a pipeline subshell.
PLIST=$(mktemp); trap 'rm -f "$PLIST"' EXIT
list_projects | sort > "$PLIST"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  rel=${p#"$ROOT"/}
  if managed "$p"; then
    n_managed=$((n_managed+1))
    out=$("$SCRIPT_DIR/mc-doctor.sh" "$p" 2>&1) || true
    summary=$(printf '%s\n' "$out" | sed -n 's/^mc-doctor: \([0-9].*\)/\1/p' | tail -n 1)
    printf '  %-46s %s\n' "$rel" "$summary"
    case "$summary" in *"0 fail"*) : ;; *) n_fail=$((n_fail+1)) ;; esac
    case "$summary" in *" 0 warn"*) : ;; *) n_warn=$((n_warn+1)) ;; esac
  elif [ "$SHOW_ALL" -eq 1 ]; then
    n_unmanaged=$((n_unmanaged+1))
    printf '  %-46s %s\n' "$rel" "(not managed)"
  fi
done < "$PLIST"

UNMANAGED_NOTE=""
if [ "$SHOW_ALL" -eq 1 ]; then UNMANAGED_NOTE=", $n_unmanaged unmanaged"; fi
printf '\nmc-doctor-all: %d managed (%d with failures, %d with warnings)%s\n' \
  "$n_managed" "$n_fail" "$n_warn" "$UNMANAGED_NOTE"
[ "$n_fail" -eq 0 ]
