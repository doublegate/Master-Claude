#!/bin/sh
# mc-selfcheck.sh — validate the Master-Claude repo's own invariants.
# Self-hosting check: AGENTS.md is canonical and <200 lines, CLAUDE.md/GEMINI.md symlink to it,
# every distributable module/doc is <200 lines, memory-core facts carry required frontmatter,
# and master-core/VERSION is present + semver-shaped. Exit 0 if all pass, 1 on any FAIL.
#
# Usage: mc-selfcheck.sh   (run from anywhere; resolves the repo relative to this script)
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

fails=0
ok()   { printf '  [OK]   %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; fails=$((fails+1)); }

printf 'mc-selfcheck: %s\n' "$REPO"

# 1. canonical AGENTS.md + sibling symlinks
A="$REPO/AGENTS.md"
if [ -f "$A" ] && [ ! -L "$A" ]; then ok "AGENTS.md is a canonical file"; else fail "AGENTS.md missing or is a symlink"; fi
for f in CLAUDE.md GEMINI.md; do
  if [ "$(readlink "$REPO/$f" 2>/dev/null)" = "AGENTS.md" ]; then ok "$f -> AGENTS.md"
  else fail "$f is not a symlink to AGENTS.md"; fi
done
if [ -f "$A" ]; then
  n=$(wc -l < "$A" | tr -d ' ')
  if [ "$n" -le 200 ]; then ok "AGENTS.md $n lines (<=200)"; else fail "AGENTS.md $n lines (>200)"; fi
fi

# 2. curation guard: every distributable module/doc <= 200 lines (single awk pass)
over=$(find "$REPO/master-core" "$REPO/memory-core" "$REPO/docs/knowledge" -name '*.md' \
  -exec awk 'FNR>200{n[FILENAME]=FNR} END{for(f in n) print f" ("n[f]")"}' {} + 2>/dev/null)
if [ -z "$over" ]; then ok "all modules/docs <=200 lines"; else fail "over 200 lines:
$over"; fi

# 3. version file present + semver-shaped
V="$REPO/master-core/VERSION"
if [ -f "$V" ]; then
  ver=$(tr -d ' \n' < "$V")
  case "$ver" in [0-9]*.[0-9]*.[0-9]*) ok "master-core/VERSION = $ver" ;; *) fail "VERSION not semver: '$ver'" ;; esac
else fail "master-core/VERSION missing"; fi

# 4. memory-core facts carry required frontmatter (name, description, type)
mem_bad=0
for f in "$REPO"/memory-core/*.md; do
  [ -e "$f" ] || continue
  b=$(basename -- "$f"); [ "$b" = MEMORY.md ] && continue
  for key in 'name:' 'description:' 'type:'; do
    grep -q "^[[:space:]]*$key" "$f" || { fail "$b missing frontmatter '$key'"; mem_bad=$((mem_bad+1)); }
  done
done
[ "$mem_bad" -eq 0 ] && ok "memory-core frontmatter complete"

# 5. every knowledge module has a matching master-core module and vice versa
miss=0
for d in "$REPO"/docs/knowledge/[0-9]*.md; do
  [ -e "$d" ] || continue
  b=$(basename -- "$d")
  [ -f "$REPO/master-core/modules/$b" ] || { fail "no master-core module for docs/knowledge/$b"; miss=$((miss+1)); }
done
for m in "$REPO"/master-core/modules/[0-9]*.md; do
  [ -e "$m" ] || continue
  b=$(basename -- "$m")
  [ -f "$REPO/docs/knowledge/$b" ] || { fail "no knowledge doc for master-core/modules/$b"; miss=$((miss+1)); }
done
[ "$miss" -eq 0 ] && ok "knowledge docs and core modules aligned"

printf 'mc-selfcheck: %d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]
