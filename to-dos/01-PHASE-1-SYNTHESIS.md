# Phase 1 — Knowledge Synthesis

Mine the corpus, write curated docs + distributable modules. **Status: COMPLETE.**

- [x] `docs/knowledge/` for the 16 competency areas (clustered into 10 docs).
- [x] `master-core/modules/` 10 distributable modules (10–95), each well under 200 lines.
- [x] `master-core/AGENTS.base.md` (universal always-inline base).
- [x] `master-core/lang/{rust,python,typescript,generic}.md` overlays.
- [x] `memory-core/` seeded with generalized universal facts (schema v2) + `MEMORY.md`.
- [x] `templates/project-block.md` + `templates/CLAUDE.local.md`.

## Carryover / refinement (optional)
- [x] Completeness-critic pass: re-read all 10 modules together; remove cross-module
      duplication. Findings: profile-first is already canonical to module 30 only (the original
      30/50 example was stale). Consolidated golden-vector + exactness rules to module 20
      (module 90 now references it) and the migrate-stable-decisions line to module 80
      (removed the duplicate from module 40).
- [ ] Decide how aggressively to strip illustrative examples vs keep them (currently kept short).
- [ ] Promote any additional universal facts discovered later via `/mem-promote`.

Next: Phase 2 (`02-PHASE-2-DISTRIBUTION.md`).
