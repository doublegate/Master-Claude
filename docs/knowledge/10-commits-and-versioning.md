# 10 — Commits, Semantic Versioning & Git Workflow

## Why it matters

Commit history and version numbers are the project's permanent, machine-readable changelog: automation, release tooling, and other contributors all read them. Consistent Conventional Commits + SemVer let CI categorize changes, generate release notes, and signal compatibility without anyone re-reading the diff. Sloppy here is cheap today and expensive at every future release.

## Patterns

**Use Conventional Commits for every commit.**
A typed, parseable subject lets automation classify the change and drive versioning.
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`. Optional scope.
Example: `feat(scanner): add UDP probe payloads` · `fix: skip texture upload on length mismatch`.

**Imperative mood, subject ≤ ~72 chars, no trailing period.**
Reads as a command ("add", not "added"/"adds"); short subjects stay legible in logs and UIs.
Example: `refactor: collapse bus borrow into single owner` — not `refactored the bus...`.

**Mark breaking changes explicitly.**
A `!` after type/scope or a `BREAKING CHANGE:` footer is the signal a MAJOR bump depends on.
Example: `feat(api)!: drop legacy save-state format` with a footer explaining the migration.

**Never commit unless explicitly asked.**
The user owns when history is written; an unrequested commit is hard to cleanly undo.
Stage and describe what you would commit, then wait for the go-ahead.

**Run pre-commit checks before every commit.**
Format, lint, and tests are cheaper to fix before the commit than after CI rejects it.
Treat the pre-commit hook as the same gate CI runs — green locally, green in CI.

**Branch as `<type>/<short-desc>` (or `<user>/<type>/<desc>`), off the default branch.**
A typed, hyphenated branch name communicates intent and groups related work.
Example: `fix/oam-row-corruption`, `feat/idle-scan`, `alice/perf/hot-path-alloc`.

**Never force-push to the default branch; keep branches current by rebasing onto upstream.**
Force-push to `main` rewrites shared history and breaks everyone's clone; rebasing your own branch keeps review diffs honest.
Example: `git fetch && git rebase upstream/main` before requesting review.

**Group related work into focused commits.**
One logical change per commit makes review, bisect, and revert tractable.
Avoid the catch-all "misc fixes" commit spanning four subsystems.

**Version with SemVer: MAJOR.MINOR.PATCH.**
The number alone tells a consumer whether an upgrade is safe.
Breaking → MAJOR; backward-compatible feature → MINOR; backward-compatible fix → PATCH.
Example: additive, off-by-default features land as MINOR and keep default builds behavior-identical.

**Update the CHANGELOG in the same change as the user-visible behavior.**
Decoupled changelogs drift and rot; same-PR updates stay accurate by construction.
Put entries under an `[Unreleased]` heading; the release ceremony promotes them to the version.

**Reference tickets/issues in commits and PRs.**
A stable ticket ID ties a commit back to its rationale and acceptance criteria.
Example: a commit body line `Refs T-PS-142` or a PR that links the issue it closes.

**Write PR descriptions that state motivation, changes, and testing performed.**
Reviewers approve intent and evidence, not just a diff.
Summarize why, list the concrete changes, and note exactly which checks you ran.

**Scale tag messages and release notes to the release's weight.**
A release is read long after the commits scroll off; the tag/notes are its lasting record.
Tag messages carry an executive summary + key changes; published release notes add install, platform matrix, and known issues. (Depth lives in the release-ceremony area.)

## Language specifics

Concrete command invocations (staging, signing, hooks, version-bump tooling) live in `master-core/lang/<lang>.md`. The patterns above are language-agnostic; the overlay supplies the exact `git`/tooling commands per ecosystem.

## Project-bound — do NOT generalize

Keep these in the project's own stub, not here:

- Exact subject-length cap or extra/forbidden commit types a single repo enforces.
- Repo-specific branch prefixes, protected-branch rules, and CODEOWNERS.
- The project's ticket-ID scheme and tracker location (e.g. a `T-XX-NNN` format).
- Concrete tag-message / release-note line-count targets and the per-release file workflow.
- Which exact files must change alongside code (a specific `CHANGELOG.md` path, status docs, Notion mirrors).
- Any "never commit X" content rule tied to the domain (e.g. never commit commercial test fixtures or secrets).

## Sources

- `/home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md` (Workflow conventions)
- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/AGENTS.md` (Commit & PR guidelines)
- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md` (Release standards)
- `/home/parobek/Code/CLAUDE.md` (workspace conventions)
- `/home/parobek/.claude/CLAUDE.md` (Conventional Commits, never-commit-unless-asked)
