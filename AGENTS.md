# AGENTS.md — Master-Claude

> Canonical agent-instruction file for **this** repo. `CLAUDE.md` and `GEMINI.md` are
> symlinks to this file (single source of truth — the same pattern this project ships).

## What this is

Master-Claude is the curated, **project-agnostic** synthesis of AI-agent knowledge built up
across ~89 codebases in `~/Code/` (Claude Code, Codex, Gemini), plus the tooling to install
and keep that knowledge in sync inside any project. See `README.md` and `docs/00-OVERVIEW.md`.

## Layout

- `docs/` — synthesized knowledge (human-facing); `docs/knowledge/` = the 16 competency areas;
  `docs/architecture/` = how Master-Claude itself works.
- `master-core/` — the **distributable** instruction modules installed into other projects.
- `memory-core/` — generalized cross-project memory facts (frontmatter schema v2).
- `commands/` · `skills/` · `templates/` — shared agent assets and project-type starters.
- `bin/` — POSIX `sh` tooling: `mc-apply`(+`-all`) smart orchestrators (state-detect →
  install/seed/sync → doctor), `mc-install`/`mc-sync`/`mc-doctor`/`mc-promote`/`mc-retrofit`,
  and `mc-commands` (registers the slash commands). Entry point: `/mc-setup`.
- `to-dos/` — phase-based execution TODOs.

## Working conventions (apply in this repo)

- **Read before write.** Inspect a file before editing; never blind-overwrite.
- **Curate, don't dump.** Every module/doc stays **<200 lines**, deduplicated, decision-based.
  LLM-bloated instruction files measurably underperform — keep it tight.
- **Project-agnostic.** Strip project-specific numbers/names from `master-core/` and
  `memory-core/`; illustrative examples are fine, hard project facts are not.
- **POSIX sh, fish-safe.** `bin/` scripts target `/bin/sh`, no bashisms, **no heredocs**
  (use `printf`/`tee`); idempotent; back up before replacing (`*.mc-bak`).
- **No emojis. Conventional Commits.** Never commit unless explicitly asked.
- **Dry-run first** for anything that touches files outside this repo (`mc-retrofit`).
- **Self-hosted.** This repo *sources* the core; don't run `mc-apply`/`/mc-setup` on it
  (the tooling refuses without `--self`). Edit `AGENTS.md` directly; `CLAUDE.md`/`GEMINI.md`
  are symlinks to it.

## Build / verify

- Shell lint: `shellcheck bin/*.sh`
- Slash commands live in `commands/`; register with `bin/mc-commands.sh --global` so they
  resolve (Claude Code only scans `~/.claude/commands`, not this repo's `commands/`).
- Tooling smoke test: run `bin/mc-install.sh` against a throwaway sandbox dir, confirm
  `CLAUDE.md`/`GEMINI.md` resolve via `readlink` and the file is <200 lines.

See `docs/architecture/distribution-model.md` for the install mechanism and the
`--inline` vs `--import` modes.
