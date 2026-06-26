#!/bin/sh
# mc-mem-scan.sh — surface cross-project memory-promotion candidates.
# Scans every per-project memory dir for facts that look generalizable but are not yet in the
# shared memory-core: (A) the same fact slug present in >= N projects, and (B) facts whose
# frontmatter already declares `scope: universal`. Read-only; prints a candidate list.
# Drives /mem-synthesize, which reviews the candidates and calls /mem-promote.
#
# Usage: mc-mem-scan.sh [--min-projects N] [--projects-root PATH]
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
ROOT="$HOME/.claude/projects"
MINP=2

while [ $# -gt 0 ]; do
  case "$1" in
    --min-projects) [ $# -gt 1 ] || { printf 'mc-mem-scan: --min-projects requires an argument\n' >&2; exit 1; }
                    MINP="$2"; shift 2 ;;
    --projects-root) [ $# -gt 1 ] || { printf 'mc-mem-scan: --projects-root requires an argument\n' >&2; exit 1; }
                     ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) printf 'mc-mem-scan: unknown arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done
[ -d "$ROOT" ] || { printf 'mc-mem-scan: no projects dir: %s\n' "$ROOT"; exit 0; }

TMPF=$(mktemp); trap 'rm -f "$TMPF" "$TMPF.2"' EXIT

# already-shared slugs (so we don't re-suggest)
shared() { for f in "$REPO_ROOT"/memory-core/*.md; do [ -e "$f" ] || continue
  b=$(basename "$f" .md); [ "$b" = MEMORY ] && continue; printf '%s\n' "$b"; done; }
is_shared() { shared | grep -qx "$1"; }

# collect: slug <TAB> project <TAB> scope
for d in "$ROOT"/*/memory; do
  [ -d "$d" ] || continue
  proj=$(basename -- "$(dirname -- "$d")")
  for f in "$d"/*.md; do
    [ -e "$f" ] || continue
    b=$(basename -- "$f" .md); [ "$b" = MEMORY ] && continue
    scope=$(sed -n 's/^[[:space:]]*scope:[[:space:]]*//p' "$f" | head -n 1)
    printf '%s\t%s\t%s\n' "$b" "$proj" "${scope:-}" >> "$TMPF"
  done
done
[ -s "$TMPF" ] || { printf 'mc-mem-scan: no project memory facts found under %s\n' "$ROOT"; exit 0; }

printf 'mc-mem-scan: candidates under %s (min-projects=%s)\n\n' "$ROOT" "$MINP"

# (A) same slug across >= MINP distinct projects, not yet shared
printf 'A) Recurring across projects (>= %s) and not yet in memory-core:\n' "$MINP"
hitsA=0
cut -f1,2 "$TMPF" | sort -u | cut -f1 | sort | uniq -c | sort -rn | while read -r n slug; do
  [ "$n" -ge "$MINP" ] || continue
  is_shared "$slug" && continue
  projs=$(awk -F'\t' -v s="$slug" '$1==s{print $2}' "$TMPF" | sort -u | tr '\n' ' ')
  printf '  - %-40s (%s projects): %s\n' "$slug" "$n" "$projs"
done
# count (separate, since the while ran in a subshell)
hitsA=$(cut -f1,2 "$TMPF" | sort -u | cut -f1 | sort | uniq -c | awk -v m="$MINP" '$1>=m{print $2}' \
  | while read -r s; do is_shared "$s" || echo x; done | wc -l | tr -d ' ')
[ "$hitsA" -eq 0 ] && printf '  (none)\n'

# (B) declared scope: universal anywhere, not yet shared
printf '\nB) Declared scope: universal and not yet in memory-core:\n'
awk -F'\t' 'tolower($3) ~ /universal/ {print $1"\t"$2}' "$TMPF" | sort -u > "$TMPF.2"
hitsB=0
cut -f1 "$TMPF.2" | sort -u | while read -r slug; do
  is_shared "$slug" && continue
  projs=$(awk -F'\t' -v s="$slug" '$1==s{print $2}' "$TMPF.2" | tr '\n' ' ')
  printf '  - %-40s :: %s\n' "$slug" "$projs"
done
hitsB=$(cut -f1 "$TMPF.2" | sort -u | while read -r s; do is_shared "$s" || echo x; done | wc -l | tr -d ' ')
[ "$hitsB" -eq 0 ] && printf '  (none)\n'

printf '\nmc-mem-scan: %s recurring + %s universal candidate(s). Review, then promote with\n' "$hitsA" "$hitsB"
printf '  bin/mc-promote.sh <project-dir> <slug> --date <today>   (or /mem-synthesize).\n'
