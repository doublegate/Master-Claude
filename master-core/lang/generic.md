# Language Overlay — Generic (fallback)

Use when no language-specific overlay fits, or for polyglot/infra repos. Replace the
placeholders with the project's real commands in the per-project managed block.

## Discover the project's commands first

- Look for a `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts, `scripts/`, or CI
  workflow (`.github/workflows/*.yml`) — the canonical build/test/lint commands usually live there.
- Mirror CI locally: whatever the CI gate runs is the source of truth for "green".

## Universal command slots (fill in)

- Build: `<project build command>`
- Test: `<project test command>` (+ how to run a single test)
- Lint / format gate: `<linter>` / `<formatter --check>`
- Coverage: `<coverage command>` (threshold enforced in CI)
- Security/deps audit: `<audit command>`; secrets via env only.

## Conventions

- Validate external input at boundaries; fail closed.
- Profile before optimizing; measure, don't guess.
- Keep docs and CHANGELOG in sync with behavior changes.

> Universal rules: see `master-core/AGENTS.base.md`. Topic depth: `master-core/modules/`.
