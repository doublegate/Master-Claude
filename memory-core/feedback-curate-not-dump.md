---
name: feedback-curate-not-dump
description: keep instruction/memory files tight; bloat costs inference and reduces adherence
metadata:
  type: feedback
  scope: universal
  lastVerified: 2026-06-25
  tags: [docs, context, instruction-files]
---

Keep agent instruction files (`AGENTS.md`/`CLAUDE.md`/`GEMINI.md`) and memory facts short,
deduplicated, and decision-based.

**Why:** evidence across thousands of repos shows instruction files beyond ~150-200 lines give
diminishing returns and raise inference cost ~20-23% with no quality gain; auto-generated
"dumped" instruction files measurably underperform curated ones.

**How to apply:** target <200 lines per instruction file; state each rule once; cut generic
advice the model already knows; move depth into separate modules loaded on demand. Prefer
signal density over completeness-by-volume.
