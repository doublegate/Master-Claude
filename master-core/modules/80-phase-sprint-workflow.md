# 80 — Phase / Sprint Workflow

- Organize work as long-lived phases subdivided into short sprints.
- Make Phase 0 foundation and the final phase polish/release; group coherent capability sets in between.
- Treat the sprint as the unit of execution; name it `phase.sprint` or descriptively, and accept both forms in tooling.
- Give every work item a stable ticket ID (e.g. `T-PS-NNN`) minted in the roadmap.
- Cite the ticket ID in branches, commits, and PRs across the item's whole lifecycle.
- Run the sprint lifecycle: start, execute, complete, report.
- On start: validate the sprint-ID format, resolve any existing-dir conflict (continue/archive/abort), scaffold plan + task checklist + notes.
- On execute: work the checklist.
- On complete: validate readiness (all tasks checked, full suite green), prompting before any override.
- On complete: gather test/code/git metrics, update docs and version, prepare the commit.
- On report: write a completion summary.
- Make every gate fail-loud; never let a sprint complete with red tests silently.
- Close a phase with a heavier ceremony: gap analysis, full doc pass, quality validation, tag + release, final verification.
- Cut a version at the phase close, not mid-sprint.
- Keep one durable PROJECT-STATUS.md with a fixed skeleton.
- Status skeleton: exec summary, phase matrix, feature/capability matrix, metrics snapshot, timeline, known issues, prioritized remaining work, next steps, readiness checklist.
- Update the durable status file at every sprint and phase boundary.
- Put volatile session state in a separate CLAUDE.local.md, never in the durable docs.
- Local session state: timestamp, current metrics snapshot, recent decisions (~30d), recent sessions (~7d), live sprint progress.
- Migrate stable decisions from the local file into the durable historical-decisions table.
- Maintain a metrics snapshot table (tests, coverage, latest release, CI cadence, active sprints) with a named source per row.
- Keep badges, status file, and session file numbers in sync on every status change.
- Propagate each behavior-changing sprint into guide docs, README tables, and any mirror in the same change.
- Gather metrics from test output and `git diff --stat`; gate completion on format + lint + full test run mirroring CI.
- Scaffold sprint workspaces and reports in a scratch dir, not in the repo.

> Session-state template: templates/CLAUDE.local.md
