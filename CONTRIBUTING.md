# Contributing

Thanks for your interest. This repo is small and opinionated; a few conventions keep it tight.

## Before you start

Read `AGENTS.md` — it is the canonical working agreement for this repo (and `CLAUDE.md` /
`GEMINI.md` are symlinks to it). The short version:

- **Read before write.** Inspect a file before editing; never blind-overwrite.
- **Curate, don't dump.** Every instruction module/doc stays **under 200 lines**, deduplicated,
  decision-based. CI enforces the 200-line limit.
- **Project-agnostic.** `master-core/` and `memory-core/` must not contain project-specific
  numbers or names — illustrative examples are fine, hard project facts are not.
- **POSIX sh, no heredocs.** `bin/` and `test/` scripts target `/bin/sh`, are idempotent, and
  back up before replacing (`*.mc-bak`).
- **Dry-run first** for anything that touches files outside this repo.

## Local checks (must pass before a PR)

```sh
shellcheck bin/*.sh test/run.sh     # lint
sh test/run.sh                      # sandboxed self-tests
```

CI (`.github/workflows/ci.yml`) runs both plus the curation guard on every push.

## Commits & PRs

- **Conventional Commits**: `feat|fix|docs|refactor|test|chore|perf|build|ci(scope): subject`,
  imperative, <=72 chars. One logical change per commit.
- **No emojis** anywhere.
- Update `CHANGELOG.md` in the same PR as any user-visible change.
- Keep PRs focused; describe what changed and how you verified it.

## Adding knowledge or modules

New competency content goes in `docs/knowledge/` (human-facing) with a matching, tighter module
in `master-core/modules/`. Keep the module terse and project-agnostic; put concrete commands in
`master-core/lang/<language>.md`.
