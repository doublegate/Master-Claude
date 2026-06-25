# /sprint-complete — finalize a sprint or phase

Project-agnostic completion gate. Will not finalize unless the readiness checks pass.

## Usage
`/sprint-complete <sprint-id>`

## Readiness gates (fail-closed — stop and report on any failure)
1. Working tree clean (or only intended changes staged).
2. Format + lint gates pass (see `master-core/lang/<lang>.md`).
3. Full/filtered test suite passes; coverage not regressed.
4. Docs updated in-sync (README/STATUS/subsystem docs), CHANGELOG entry added.

## Steps (after gates pass)
1. Gather a metrics snapshot (version, tests, coverage) into the sprint `notes.md`.
2. Update `CLAUDE.local.md`: move the sprint to COMPLETE, add a "recent decisions" row.
3. If this closes a phase/release: bump version per SemVer, write the annotated tag message
   (executive summary + technical depth) and release notes. Do NOT push/tag unless asked.
4. Print a short stakeholder summary (what shipped, what deferred + why).

See `master-core/modules/70-release-ceremony.md` and `80-phase-sprint-workflow.md`.
