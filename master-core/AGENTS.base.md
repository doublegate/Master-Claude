# Agent Working Agreement (Master-Core base)

> Universal, always-applied rules. This is the only content guaranteed to reach every agent in
> every install mode — keep it short and load-bearing. Heavier topic modules live in
> `master-core/modules/` (Claude `@import`s them; `--inline` bakes them in).

## Operating discipline

- **Read before write.** Inspect a file (Read/Grep/Glob) before editing; never blind-overwrite.
  For destructive or hard-to-reverse actions, confirm first unless explicitly authorized.
- **Curate, don't dump.** Prefer the smallest correct change. Match the surrounding code's
  style, naming, and comment density. Reuse existing utilities before writing new ones.
- **Report faithfully.** If tests fail, say so with the output. If a step was skipped, say so.
  State done-and-verified plainly; don't hedge or overclaim.
- **No emojis** in code, commits, comments, or docs. Precise technical language.

## Git & commits

- **Conventional Commits**: `feat|fix|docs|refactor|test|chore|perf|build|ci(scope): subject`,
  imperative, <=72 chars. One logical change per commit.
- **Never commit or push unless explicitly asked.** When asked, branch off the default branch
  first if you are on it. Do not force-push to a shared branch.
- Keep `CHANGELOG.md` updated in the same change as any user-visible behavior.

## Quality gates (run before declaring done)

- Format + lint + test must pass. Treat lint warnings as errors where the project does.
- Add/adjust tests with the change; for accuracy-critical paths, write the failing test first.
- Profile before optimizing; don't micro-optimize without a measurement.

## Documentation discipline

- Update the relevant doc in the **same change** as the code (docs-as-spec).
- Record non-obvious cross-cutting decisions as short ADRs; don't bury rationale in commit logs.

## Security baseline

- Validate external input at boundaries; never `unwrap`/trust unvalidated data.
- Secrets via environment variables only; never hardcode; never leak secrets in errors or logs.
- Some rules are enforced by the harness, not by you: `permissions.deny` entries and the
  `guards/` PreToolUse hooks block destructive commands outright. A denial is a correct
  outcome, not an obstacle — read the reason and take the suggested route instead of
  looking for a way around it.

## Delegation

- Match the model to the work. Mechanical work does not need the most expensive model.
- Delegate down: **scout** (locate files/symbols, read-only) and **verifier** (run the
  quality gates and report verbatim) for chores; **sweeper** for a transformation that is
  already fully specified. Keep design, diagnosis, and judgement on the primary model.
- Delegate a broad search rather than running the sweep inline when the intermediate file
  listings would be noise; you need the conclusion, not the dump.
- Give a subagent an explicit spec. A subagent starts with a fresh context and cannot see
  the reasoning that led to the request, so ambiguity becomes a wrong uniform change.

## Project-specific section

Everything above is universal. Concrete build/test/lint commands, architecture facts, and
project gotchas belong in the per-project managed block of this file (`<<< MC-PROJECT-... >>>`)
or in `master-core/lang/<language>.md` for language defaults — not here.
