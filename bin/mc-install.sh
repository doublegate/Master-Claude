#!/bin/sh
# mc-install.sh — install the Master-Claude shared core into a project.
# Creates a slim canonical AGENTS.md and symlinks CLAUDE.md + GEMINI.md to it.
# POSIX sh. No bashisms, no heredocs. Idempotent. Backs up before replacing.
#
# Usage:
#   mc-install.sh <project-dir> [--lang rust|python|typescript|generic]
#                               [--inline|--import] [--core <path>] [--name <n>]
#
#   --import  (default) heavy modules referenced via @import (Claude expands them).
#   --inline  bake modules into AGENTS.md (full Claude/Codex/Gemini parity).
#   --trim    when seeding a block from an existing file, HTML-comment lines that
#             look like universal rules already in the core (lossless; review after).
#
set -eu

MARK_START='<<< MC-PROJECT-START >>>'
MARK_END='<<< MC-PROJECT-END >>>'

die() { printf 'mc-install: %s\n' "$1" >&2; exit 1; }

# Emit a seed file's body for the project block: always strip @import/marker lines.
# When TRIM=1, also HTML-comment lines resembling universal rules already in the core
# (lossless — commented, never deleted; the user/`/mc-curate` makes the final call).
body_filter() {
  if [ "${TRIM:-0}" -eq 1 ]; then
    grep -v -e '^@.*master-core/' -e 'MC-PROJECT-START' -e 'MC-PROJECT-END' "$1" | awk '
      BEGIN{ n=split("conventional commit|clippy|cargo fmt|ruff |eslint|never .*commit|force[- ]push|read before write|read.before.edit|semver|changelog|no emojis|test-driven|\\btdd\\b", a, "|") }
      { low=tolower($0); hit=0
        for(i=1;i<=n;i++){ if(low ~ a[i]){hit=1; break} }
        if(hit && $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*>/) print "<!-- dup? " $0 " -->"
        else print }'
  else
    grep -v -e '^@.*master-core/' -e 'MC-PROJECT-START' -e 'MC-PROJECT-END' "$1"
  fi
}

# --- resolve repo + core ---------------------------------------------------
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CORE_SRC="$REPO_ROOT/master-core"
CORE_LINK="$HOME/.claude/master-core"

PROJECT=""
LANG=""
MODE="import"
NAME=""
TRIM=0

while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG="${2:-}"; shift 2 ;;
    --inline) MODE="inline"; shift ;;
    --import) MODE="import"; shift ;;
    --trim) TRIM=1; shift ;;
    --core) CORE_SRC="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) PROJECT="$1"; shift ;;
  esac
done

[ -n "$PROJECT" ] || die "missing <project-dir> (try --help)"
[ -d "$PROJECT" ] || die "not a directory: $PROJECT"
[ -d "$CORE_SRC" ] || die "core not found: $CORE_SRC"
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)
[ -n "$NAME" ] || NAME=$(basename -- "$PROJECT")

# --- ensure ~/.claude/master-core points at the core (import mode needs it) -
mkdir -p "$HOME/.claude"
if [ ! -e "$CORE_LINK" ]; then
  ln -s "$CORE_SRC" "$CORE_LINK"
  printf '  linked %s -> %s\n' "$CORE_LINK" "$CORE_SRC"
fi

# --- detect language if not given ------------------------------------------
if [ -z "$LANG" ]; then
  if   [ -f "$PROJECT/Cargo.toml" ]; then LANG=rust
  elif [ -f "$PROJECT/pyproject.toml" ] || [ -f "$PROJECT/requirements.txt" ]; then LANG=python
  elif [ -f "$PROJECT/package.json" ]; then LANG=typescript
  else LANG=generic
  fi
fi
[ -f "$CORE_SRC/lang/$LANG.md" ] || die "no lang overlay: $LANG"

AGENTS="$PROJECT/AGENTS.md"

# --- build the project block (preserve > seed-from-existing > blank) --------
# Precedence:
#   1. A managed AGENTS.md already has a block -> keep it verbatim.
#   2. No managed block, but a real (non-symlink) agent file exists -> SEED the
#      block from its body so project-specific content is migrated, not just
#      backed up. @import and stray marker lines are stripped; a banner tells the
#      user to trim duplicated universal rules.
#   3. Nothing to seed from -> blank template.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
SEED_SRC=""
if [ -f "$AGENTS" ] && grep -q "$MARK_START" "$AGENTS" 2>/dev/null; then
  sed -n "/$MARK_START/,/$MARK_END/p" "$AGENTS" > "$TMP"
  printf '  preserving existing project block\n'
else
  for cand in CLAUDE.md AGENTS.md GEMINI.md; do
    cp="$PROJECT/$cand"
    if [ -f "$cp" ] && [ ! -L "$cp" ] && [ -s "$cp" ]; then SEED_SRC="$cp"; break; fi
  done
  if [ -n "$SEED_SRC" ]; then
    sbase=$(basename -- "$SEED_SRC")
    {
      printf '%s\n' "$MARK_START"
      printf '## Project: %s\n\n' "$NAME"
      printf '%s\n' "> Seeded by Master-Claude from $sbase. Universal rules now come from the shared"
      printf '%s\n' "> core above. Original backed up as $sbase.mc-bak."
      if [ "$TRIM" -eq 1 ]; then
        printf '%s\n' "> Auto-trim ran: lines resembling universal rules are HTML-commented below as"
        printf '%s\n' "> \`<!-- dup? ... -->\`. Delete true duplicates; un-comment any that are actually"
        printf '%s\n' "> project-specific. Run /mc-curate for a semantic (LLM) pass."
      else
        printf '%s\n' "> Trim duplicated generic rules below, or re-run with --trim, or run /mc-curate."
      fi
      printf '\n'
      body_filter "$SEED_SRC"
      printf '\n%s\n' "$MARK_END"
    } > "$TMP"
    TRIM_NOTE=""
    if [ "$TRIM" -eq 1 ]; then TRIM_NOTE=" (auto-trim on)"; fi
    printf '  seeding project block from %s%s\n' "$sbase" "$TRIM_NOTE"
  else
    sed "s/{{PROJECT_NAME}}/$NAME/g" "$REPO_ROOT/templates/project-block.md" > "$TMP"
  fi
fi

# --- back up any real (non-symlink) agent files ----------------------------
for f in AGENTS.md CLAUDE.md GEMINI.md; do
  p="$PROJECT/$f"
  if [ -f "$p" ] && [ ! -L "$p" ]; then
    if [ "$f" != "AGENTS.md" ] || ! grep -q "$MARK_START" "$p" 2>/dev/null; then
      cp "$p" "$p.mc-bak"
      printf '  backed up %s -> %s.mc-bak\n' "$f" "$f"
    fi
  fi
done

# --- assemble the new AGENTS.md --------------------------------------------
{
  printf '%s\n' "<!-- Managed by Master-Claude. Universal rules come from the imported/inlined core."
  printf '%s\n' "     Edit only inside the MC-PROJECT block; mc-sync overwrites everything else. -->"
  printf '# AGENTS.md — %s\n\n' "$NAME"
  if [ "$MODE" = import ]; then
    printf '@%s/AGENTS.base.md\n' "$CORE_LINK"
    printf '@%s/lang/%s.md\n' "$CORE_LINK" "$LANG"
    for m in "$CORE_SRC"/modules/*.md; do
      [ -e "$m" ] || continue
      printf '@%s/modules/%s\n' "$CORE_LINK" "$(basename -- "$m")"
    done
  else
    cat "$CORE_SRC/AGENTS.base.md"; printf '\n'
    cat "$CORE_SRC/lang/$LANG.md"; printf '\n'
    for m in "$CORE_SRC"/modules/*.md; do
      [ -e "$m" ] || continue
      printf '\n---\n\n'; cat "$m"
    done
  fi
  printf '\n'
  cat "$TMP"
  printf '\n'
} > "$AGENTS"

# --- symlink the sibling agent filenames -----------------------------------
for f in CLAUDE.md GEMINI.md; do
  p="$PROJECT/$f"
  rm -f "$p"   # any real file here was already backed up to *.mc-bak above
  ln -s AGENTS.md "$p"
done

LINES=$(wc -l < "$AGENTS" | tr -d ' ')
printf 'mc-install: %s (lang=%s mode=%s) AGENTS.md=%s lines; CLAUDE.md/GEMINI.md -> AGENTS.md\n' \
  "$NAME" "$LANG" "$MODE" "$LINES"
[ "$MODE" = import ] && [ "$LINES" -gt 200 ] && printf '  note: >200 lines — review the project block.\n'
exit 0
