#!/bin/sh
# mc-apply.sh — one smart, safe command to set up the Master-Claude core in ANY project.
# Detects whether the project is new, existing-unmanaged, or already-managed and does the
# right thing. Non-destructive (existing files are backed up to *.mc-bak; idempotent).
#
# Usage: mc-apply.sh <project-dir> [--inline|--import] [--no-trim] [--dry-run]
#
# Emits a final "MC-NEXT: <curate|fill-stub|none>" line so /mc-setup knows what (if any)
# semantic follow-up to perform. Exit 0 on success (doctor clean), non-zero otherwise.
set -eu

die() { printf 'mc-apply: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SELF_REPO=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT=""
FORCE_MODE=""
TRIM="--trim"
DRY=0
SELF=0

while [ $# -gt 0 ]; do
  case "$1" in
    --inline) FORCE_MODE="--inline"; shift ;;
    --import) FORCE_MODE="--import"; shift ;;
    --no-trim) TRIM=""; shift ;;
    --dry-run) DRY=1; shift ;;
    --self) SELF=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) PROJECT="$1"; shift ;;
  esac
done
[ -n "$PROJECT" ] || die "missing <project-dir> (try --help)"
[ -d "$PROJECT" ] || die "not a directory: $PROJECT"
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)
NAME=$(basename -- "$PROJECT")

# Guard: don't manage the Master-Claude repo itself — its AGENTS.md is the canonical
# source of the core, not a project to import the core into. (--self / dry-run override.)
if [ "$PROJECT" = "$SELF_REPO" ] && [ "$SELF" -eq 0 ] && [ "$DRY" -eq 0 ]; then
  die "refusing to run on the Master-Claude repo itself (it is self-hosted). Use --self to force."
fi

# --- detect state ----------------------------------------------------------
A="$PROJECT/AGENTS.md"
STATE="new"
SEED_SRC=""
if [ -f "$A" ] && grep -q '<<< MC-PROJECT-START >>>' "$A" 2>/dev/null; then
  STATE="managed"
else
  for cand in CLAUDE.md AGENTS.md GEMINI.md; do
    p="$PROJECT/$cand"
    if [ -f "$p" ] && [ ! -L "$p" ] && [ -s "$p" ]; then SEED_SRC="$p"; STATE="existing"; break; fi
  done
fi

# --- pick mode (auto: inline if Codex/Gemini are active here, else import) --
if [ -n "$FORCE_MODE" ]; then
  MODE="$FORCE_MODE"
elif [ -d "$PROJECT/.codex" ] || [ -d "$PROJECT/.gemini" ]; then
  MODE="--inline"
else
  MODE="--import"
fi

printf 'mc-apply: %s\n' "$PROJECT"
printf '  state=%s  mode=%s%s\n' "$STATE" "$MODE" "$( [ -n "$SEED_SRC" ] && printf '  seed=%s' "$(basename -- "$SEED_SRC")" )"

# --- dry-run just delegates to the retrofit preview ------------------------
if [ "$DRY" -eq 1 ]; then
  printf '  (dry-run) showing plan; nothing will change:\n\n'
  exec "$SCRIPT_DIR/mc-retrofit.sh" --dry-run "$PROJECT"
fi

# --- act on state ----------------------------------------------------------
NEXT="none"
case "$STATE" in
  managed)
    printf '  action: refresh shared core (mc-sync), preserve project block.\n'
    "$SCRIPT_DIR/mc-sync.sh" "$PROJECT"
    NEXT="none"
    ;;
  existing)
    printf '  action: seed project block from %s%s, then verify.\n' \
      "$(basename -- "$SEED_SRC")" "$( [ -n "$TRIM" ] && printf ' (auto-trim)' )"
    # shellcheck disable=SC2086  # MODE/TRIM are single tokens or empty by construction
    "$SCRIPT_DIR/mc-install.sh" "$PROJECT" $MODE $TRIM
    NEXT="curate"
    ;;
  new)
    printf '  action: fresh install with a blank project block.\n'
    # shellcheck disable=SC2086
    "$SCRIPT_DIR/mc-install.sh" "$PROJECT" $MODE
    NEXT="fill-stub"
    ;;
esac

# --- verify ----------------------------------------------------------------
printf '\n'
if "$SCRIPT_DIR/mc-doctor.sh" "$PROJECT"; then DOC=0; else DOC=1; fi

printf '\nmc-apply: done (%s). ' "$NAME"
case "$NEXT" in
  curate)    printf 'A block was seeded — semantic de-dup recommended.\n' ;;
  fill-stub) printf 'New project — fill in the blank project block.\n' ;;
  none)      printf 'Up to date.\n' ;;
esac
printf 'MC-NEXT: %s\n' "$NEXT"
exit "$DOC"
