# 80 — Phase / Sprint Workflow

## Why it matters

Large projects need a backbone that turns an open-ended roadmap into bounded,
shippable units of work with a clear "done." A two-level rhythm — long-lived
**phases** (foundation → … → polish/release) subdivided into short **sprints** —
gives every task a home, a stable identifier, and a lifecycle from kickoff to
release. A disciplined status surface (one durable status file plus a volatile
session-state file) lets any contributor or agent answer "where are we, what's
next" without re-deriving it from git history.

## Patterns

**Organize work as phases, each subdivided into sprints.** Phase 0 is
foundation; the final phase is polish/release; intermediate phases group a
coherent capability set. Sprints are the unit of execution inside a phase. Name
sprints `phase.sprint` (e.g. `4.15`, `6.3`) or descriptively
(`phaseN-<topic>`), and accept both forms in tooling. *Example:* a phase matrix
shows Phases 1–N with status, test counts, and key features per row; the active
phase lists its sprints with per-sprint objectives and completion percentage.

**Give every work item a stable ticket ID and cite it everywhere.** Use a
consistent scheme such as `T-PS-NNN` (phase-sprint-number). The ID is assigned in
the roadmap and referenced in branches, commits, and PRs across the item's whole
life so work stays traceable. The roadmap/phase files are where IDs are minted.

**Run a defined sprint lifecycle: start → execute → complete → report.** *Start*
validates the sprint ID format, handles an existing-directory conflict
(continue/archive/abort), and scaffolds a sprint workspace with a plan, a task
checklist, and implementation notes. *Execute* works the checklist. *Complete*
validates readiness (all tasks checked, full test suite green — prompt before
overriding either), gathers test/code/git metrics, updates docs and version,
and prepares the commit. *Report* writes a completion summary. Make each gate
fail-loud so a sprint cannot "complete" with red tests silently.

**Complete a phase with a heavier, end-to-end ceremony.** When a phase's sprints
all finish, run a multi-stage close: gap analysis (planned vs delivered), a
comprehensive documentation pass (README, CHANGELOG, ROADMAP, STATUS, all
subsystem docs, API docs), quality validation, an annotated tag + release, then
final verification (readiness checklist, smoke test, status-file update,
completion report). A phase close is where a version is typically cut.

**Keep one durable PROJECT-STATUS.md with a fixed skeleton.** Structure it:
executive summary → phase matrix (phase / status / focus / timeline / notes) →
feature or capability matrix → metrics snapshot → timeline → known
issues/limitations → remaining work (prioritized) → next steps → a readiness
checklist. This is the slow-moving authoritative state; update it at every sprint
and phase boundary. *Example:* a status file leads with an executive summary,
then completed-features-by-phase, code metrics, test results, platform support,
known limitations, and an overall "% production ready" checklist.

**Put volatile session state in a separate CLAUDE.local.md, never in the durable
docs.** The local file carries a timestamp, a current metrics snapshot, recent
decisions (rolling ~30 days), recent sessions (rolling ~7 days), and live sprint
progress. It is the working memory between sessions; the durable STATUS file is
the published state. Keep last-30-day decisions here and migrate stable ones into
a historical-decisions table in the durable docs.

> Session-state template: templates/CLAUDE.local.md

**Maintain a metrics snapshot and keep it honestly in sync.** A small table —
test count, coverage, latest release, CI cadence, active sprints — with a named
source per row. Update it (and any external mirror) on every status change so the
numbers in the badges, the status file, and the session file never diverge.

**Keep docs synchronized as sprints land — not at release.** Each sprint that
changes behavior propagates into the relevant guide docs, README tables, and any
knowledge mirror in the same change. Doc drift is a per-sprint defect, not a
release-time cleanup.

## Language specifics

- Rust: gather sprint/phase metrics from `cargo test --workspace` output and
  `git diff --stat`; gate completion on `cargo fmt --check` + `cargo clippy
  --workspace --all-targets -- -D warnings` + the full test run, mirroring CI.
- Tooling: scaffold sprint workspaces and completion reports in a scratch dir
  (`/tmp/<project>/sprint-<id>/`), not in the repo, so they don't pollute history.

## Project-bound — do NOT generalize

- The exact ticket-ID grammar, sprint-naming regex, phase count, and per-phase
  themes are per-project — port the two-level shape, not the labels.
- The specific status-file numbering and section order, and whether status is
  mirrored to an external knowledge base, are project conventions.
- Hour estimates for a phase close and the literal checklist item counts are
  illustrative, not normative.

## Sources

- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/AGENTS.md (phases/sprints, metrics snapshot)
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/.claude/commands/sprint-start.md
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/.claude/commands/sprint-complete.md
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/.claude/commands/phase-complete.md
- /home/parobek/Code/OSS_Public-Projects/AirGapSync/docs/PROJECT-STATUS.md
- /home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md (ROADMAP as planning entry, ticket IDs)
