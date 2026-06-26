#!/bin/sh
# mc-apply-all.sh — run mc-apply across every project under a workspace root.
# DRY-RUN by default (prints a plan table, changes nothing). Pass --apply to act.
#
# Usage: mc-apply-all.sh [root-dir] [--apply] [--inline|--import] [--no-trim]
#                        [--exclude <name>]...
#
# Projects are detected at depth 1-2 under <root-dir> (categories hold projects one level in,
# plus a few root-level projects). A directory is a project if it has .git or a build/agent
# file. node_modules/target/vendor and known non-project working dirs are skipped.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SELF_REPO=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

ROOT="$HOME/Code"
APPLY=0
PASS=""
SKIP="Archive Backups Dev_Test docs HPC_User_Forum metasploitable3-workspace Resume_Personal-Parobek Rust_Test Master-Claude Undertow node_modules target vendor .venv .git .bmad-core gpu-burn-git"

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --inline|--import|--no-trim) PASS="$PASS $1"; shift ;;
    --exclude) SKIP="$SKIP ${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    -*) printf 'mc-apply-all: unknown flag: %s\n' "$1" >&2; exit 1 ;;
    *) ROOT="$1"; shift ;;
  esac
done
[ -d "$ROOT" ] || { printf 'mc-apply-all: not a directory: %s\n' "$ROOT" >&2; exit 1; }
ROOT=$(CDPATH='' cd -- "$ROOT" && pwd)

skipped() { case " $SKIP " in *" $1 "*) return 0 ;; esac; return 1; }
is_project() {
  [ -d "$1/.git" ] || [ -f "$1/Cargo.toml" ] || [ -f "$1/package.json" ] || \
  [ -f "$1/pyproject.toml" ] || [ -f "$1/go.mod" ] || [ -f "$1/requirements.txt" ] || \
  [ -f "$1/CLAUDE.md" ] || [ -f "$1/AGENTS.md" ] || [ -f "$1/GEMINI.md" ]
}

# --- enumerate project roots (depth 1, else depth 2) -----------------------
list_projects() {
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    db=$(basename -- "$d"); skipped "$db" && continue
    dd=${d%/}
    [ "$dd" = "$SELF_REPO" ] && continue
    if is_project "$dd"; then printf '%s\n' "$dd"
    else
      for s in "$d"*/; do
        [ -d "$s" ] || continue
        sb=$(basename -- "$s"); skipped "$sb" && continue
        ss=${s%/}
        [ "$ss" = "$SELF_REPO" ] && continue
        is_project "$ss" && printf '%s\n' "$ss"
      done
    fi
  done
}

PROJECTS=$(list_projects | sort)
[ -n "$PROJECTS" ] || { printf 'mc-apply-all: no projects found under %s\n' "$ROOT"; exit 0; }

MODE_LABEL="DRY-RUN (no changes)"; [ "$APPLY" -eq 1 ] && MODE_LABEL="APPLY"
printf 'mc-apply-all: %s under %s\n\n' "$MODE_LABEL" "$ROOT"
printf '  %-44s %-9s %-11s %s\n' "PROJECT" "STATE" "NEXT/PLAN" "RESULT"
printf '  %-44s %-9s %-11s %s\n' "-------" "-----" "---------" "------"

c_new=0; c_exist=0; c_man=0; c_fail=0
CURATE_LIST=""

for p in $PROJECTS; do
  rel=${p#"$ROOT"/}
  if [ "$APPLY" -eq 1 ]; then
    # shellcheck disable=SC2086
    if out=$("$SCRIPT_DIR/mc-apply.sh" "$p" $PASS 2>&1); then rc=0; else rc=$?; fi
    state=$(printf '%s\n' "$out" | sed -n 's/.*state=\([a-z]*\).*/\1/p' | head -n 1)
    next=$(printf '%s\n' "$out" | sed -n 's/^MC-NEXT: \(.*\)/\1/p' | head -n 1)
    doc=$(printf '%s\n' "$out" | sed -n 's/^mc-doctor: \(.*\)/\1/p' | tail -n 1)
    [ "$rc" -ne 0 ] && { doc="ERR ${doc:-}"; c_fail=$((c_fail+1)); }
    [ "$next" = curate ] && CURATE_LIST="$CURATE_LIST $p"
    plan="${next:-?}"
  else
    # shellcheck disable=SC2086
    out=$("$SCRIPT_DIR/mc-apply.sh" "$p" --dry-run $PASS 2>&1) || true
    state=$(printf '%s\n' "$out" | sed -n 's/.*state=\([a-z]*\).*/\1/p' | head -n 1)
    case "$state" in
      new) plan="install-blank" ;;
      existing) plan="seed+trim" ;;
      managed) plan="sync" ;;
      *) plan="?" ;;
    esac
    doc="-"
  fi
  case "$state" in new) c_new=$((c_new+1));; existing) c_exist=$((c_exist+1));; managed) c_man=$((c_man+1));; esac
  printf '  %-44s %-9s %-11s %s\n' "$rel" "${state:-?}" "$plan" "$doc"
done

printf '\nmc-apply-all: %s | new=%d existing=%d managed=%d%s\n' \
  "$MODE_LABEL" "$c_new" "$c_exist" "$c_man" "$( [ "$c_fail" -gt 0 ] && printf ' errors=%d' "$c_fail" )"

if [ "$APPLY" -eq 1 ] && [ -n "$CURATE_LIST" ]; then
  printf '\nSemantic de-dup still recommended (run /mc-curate or /mc-setup in each):\n'
  for p in $CURATE_LIST; do printf '  - %s\n' "${p#"$ROOT"/}"; done
elif [ "$APPLY" -eq 0 ]; then
  printf 'Re-run with --apply to act. Seeded (existing) projects will then want /mc-curate.\n'
fi
