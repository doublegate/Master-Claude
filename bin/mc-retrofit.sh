#!/bin/sh
# mc-retrofit.sh — show what installing the shared core into an EXISTING project would change.
# DRY-RUN ONLY by design: it never writes, never deletes, never symlinks. It prints a plan and
# leaves `git status` clean. Apply is intentionally not implemented in this effort.
#
# Usage: mc-retrofit.sh --dry-run <project-dir>
set -eu

die() { printf 'mc-retrofit: %s\n' "$1" >&2; exit 1; }

DRY=0; PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --apply) die "--apply is not supported yet (this effort ships dry-run only). Aborting; nothing changed." ;;
    -*) die "unknown flag: $1" ;;
    *) PROJECT="$1"; shift ;;
  esac
done
[ "$DRY" -eq 1 ] || die "refusing to run without --dry-run (safety). Nothing changed."
[ -n "$PROJECT" ] || die "missing <project-dir>"
[ -d "$PROJECT" ] || die "not a directory: $PROJECT"
PROJECT=$(CDPATH='' cd -- "$PROJECT" && pwd)

printf 'mc-retrofit (DRY-RUN): %s\n' "$PROJECT"
printf '  No files will be changed.\n\n'

# language detection (same as installer)
if   [ -f "$PROJECT/Cargo.toml" ]; then LANG=rust
elif [ -f "$PROJECT/pyproject.toml" ] || [ -f "$PROJECT/requirements.txt" ]; then LANG=python
elif [ -f "$PROJECT/package.json" ]; then LANG=typescript
else LANG=generic
fi
printf 'Detected language: %s\n\n' "$LANG"

# seed-source detection (same precedence as mc-install)
SEED_SRC=""
A="$PROJECT/AGENTS.md"
if ! { [ -f "$A" ] && grep -q '<<< MC-PROJECT-START >>>' "$A" 2>/dev/null; }; then
  for cand in CLAUDE.md AGENTS.md GEMINI.md; do
    cp="$PROJECT/$cand"
    if [ -f "$cp" ] && [ ! -L "$cp" ] && [ -s "$cp" ]; then SEED_SRC="$cp"; break; fi
  done
fi

printf 'PLAN:\n'
# AGENTS.md
if [ -f "$A" ] && grep -q '<<< MC-PROJECT-START >>>' "$A" 2>/dev/null; then
  printf '  - AGENTS.md: already Master-Claude-managed; would re-sync core, PRESERVE project block.\n'
elif [ -n "$SEED_SRC" ]; then
  sbase=$(basename -- "$SEED_SRC")
  nlines=$(grep -vc -e '^@.*master-core/' -e 'MC-PROJECT-START' -e 'MC-PROJECT-END' "$SEED_SRC")
  if [ -f "$A" ] && [ "$sbase" = AGENTS.md ]; then
    printf '  - AGENTS.md: exists (unmanaged) -> back up to AGENTS.md.mc-bak, then regenerate;\n'
  else
    printf '  - AGENTS.md: absent -> create canonical file (core + %s overlay + project block);\n' "$LANG"
  fi
  printf '      project block SEEDED from %s (%s lines preserved, not just backed up).\n' "$sbase" "$nlines"
else
  printf '  - AGENTS.md: absent -> would create canonical file (core + %s overlay + BLANK project block).\n' "$LANG"
fi
# siblings
for f in CLAUDE.md GEMINI.md; do
  p="$PROJECT/$f"
  if [ -L "$p" ]; then printf '  - %s: already a symlink -> would repoint to AGENTS.md.\n' "$f"
  elif [ -f "$p" ]; then printf '  - %s: real file -> would back up to %s.mc-bak, then symlink to AGENTS.md.\n' "$f" "$f"
  else printf '  - %s: absent -> would create symlink to AGENTS.md.\n' "$f"
  fi
done

# duplicate-content heuristic: universal rules already present in an existing CLAUDE/AGENTS
printf '\nDUPLICATE-CONTENT SCAN (rules the shared core would supersede):\n'
SRC=""
for cand in "$PROJECT/CLAUDE.md" "$PROJECT/AGENTS.md"; do
  if [ -f "$cand" ] && [ ! -L "$cand" ]; then SRC="$cand"; break; fi
done
if [ -n "$SRC" ]; then
  hits=0
  for pat in 'Conventional Commits' 'clippy' 'cargo fmt' 'ruff' 'never .*commit' 'force-push' 'read before' 'SemVer' 'CHANGELOG'; do
    if grep -qiE "$pat" "$SRC" 2>/dev/null; then
      printf '  - matches core rule: "%s" (in %s)\n' "$pat" "$(basename "$SRC")"
      hits=$((hits+1))
    fi
  done
  [ "$hits" -eq 0 ] && printf '  - none detected; existing file looks project-specific (good).\n'
  printf '  (These could be trimmed from the project file and left to the shared core — review manually.)\n'
else
  printf '  - no unmanaged CLAUDE.md/AGENTS.md to scan.\n'
fi

if [ -n "$SEED_SRC" ]; then
  printf '\nSEEDED PROJECT-BLOCK PREVIEW (first lines that would be migrated into the block):\n'
  grep -v -e '^@.*master-core/' -e 'MC-PROJECT-START' -e 'MC-PROJECT-END' "$SEED_SRC" \
    | grep -v '^[[:space:]]*$' | head -6 | sed 's/^/    | /'
  printf '    ... (full content preserved; add --trim to auto-comment likely duplicates,\n'
  printf '         then run /mc-curate for a semantic de-dup pass)\n'
fi

printf '\nTo apply later, you would run: mc-install.sh "%s" --lang %s [--inline|--import] [--trim]\n' "$PROJECT" "$LANG"
printf 'mc-retrofit: DRY-RUN complete. git status is unchanged.\n'
