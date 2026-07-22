# Master-Claude

[![CI](https://github.com/doublegate/Master-Claude/actions/workflows/ci.yml/badge.svg)](https://github.com/doublegate/Master-Claude/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/doublegate/Master-Claude?sort=semver)](https://github.com/doublegate/Master-Claude/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-89e051.svg)](https://pubs.opengroup.org/onlinepubs/9699919799/)

**The single, curated, project-agnostic synthesis of everything AI agents have learned across
`~/Code/` — plus the tooling to drop that knowledge into any project and keep it in sync.**

Over a year of work across ~89 codebases, three coding agents (Claude Code, OpenAI Codex,
Google Gemini) accumulated a large body of conventions, lessons, and workflows — scattered
across 97 `CLAUDE.md`, 13 `AGENTS.md`, 16 `GEMINI.md`, 23 `CLAUDE.local.md`, 165 memory facts,
and 63 custom commands. Master-Claude consolidates the **generalizable** subset into one
maintained source and makes it instantly available in new or existing projects.

## First-time setup (once per machine)

Register the slash commands so Claude Code can find them (it only scans `~/.claude/commands/`
and `<project>/.claude/commands/`, not this repo's `commands/`):

```sh
bin/mc-commands.sh --global     # symlinks commands/*.md -> ~/.claude/commands/ (collision-safe)
bin/mc-commands.sh --agents     # symlinks agents/*.md   -> ~/.claude/agents/
bin/mc-guard.sh    install      # enforcement layer: deny rules + PreToolUse guards
```

Then restart Claude Code (or reload) so `/mc-setup`, `/mc-setup-all`, `/mc-curate` appear.
Hooks load at session start, so the guards arm on the next session, not the current one.

## Quick start

**One command does everything.** Inside any project (new or existing), run:

```text
/mc-setup
```

It detects the project's state (new / existing / already-managed), installs the shared core the
right way (seeding + de-duplicating an existing `CLAUDE.md` when present, auto-choosing inline vs
import), performs the semantic de-dup, and verifies — no other steps. `/mc-setup --dry-run`
previews without changing anything.

Whole workspace at once? `/mc-setup-all` (or `bin/mc-apply-all.sh` for the shell sweep) previews
every project under `~/Code`, then applies + de-dups on confirmation.

Prefer the shell? `bin/mc-apply.sh <project>` does the deterministic parts (everything except the
LLM de-dup) in one call. Individual tools remain available:

```sh
bin/mc-apply-all.sh                           # dry-run sweep of every project (--apply to act)
bin/mc-apply.sh   /path/to/project            # smart: detect state + do the right thing
bin/mc-install.sh /path/to/project --lang rust [--inline] [--trim]   # low-level install
bin/mc-doctor.sh  /path/to/project            # audit (size, drift, missing symlinks)
bin/mc-promote.sh /path/to/project "slug" --date YYYY-MM-DD          # lesson -> shared memory
bin/mc-retrofit.sh --dry-run /path/to/project # preview a retrofit (never modifies)
bin/mc-guard.sh   audit                       # read-only permission-surface audit (all projects)
bin/mc-guard.sh   verify                      # is the enforcement layer installed and intact?
```

## How it fits together

| Layer | Folder | Role |
|---|---|---|
| Knowledge (read) | `docs/knowledge/` | The 16 competency areas, human-facing |
| Distributable core | `master-core/` | Slim modules installed into projects (<200 lines each) |
| Memory | `memory-core/` | Generalized cross-project facts (schema v2) |
| Enforcement | `guards/` | Deny rules + PreToolUse hooks the **harness** enforces, not the model |
| Assets | `commands/`, `agents/`, `skills/`, `templates/` | Shared agent assets + starter stubs |
| Tooling | `bin/` | apply · apply-all · install · sync · doctor · promote · retrofit · commands · guard |
| Verification | `test/`, `.github/` | self-test harness + CI (shell/workflow/markdown lint, tests, curation guard) |
| Plan | `to-dos/` | Phase-based execution roadmap |

## Design principles

- **Single source of truth.** `AGENTS.md` is canonical; `CLAUDE.md`/`GEMINI.md` symlink to it
  (the 2026 cross-tool standard). One edit updates all three agents.
- **Curated, not generated.** Every doc/module is deduplicated and decision-based, kept under
  ~200 lines — bloated instruction files cost inference and reduce adherence.
- **Project-agnostic.** Hard project specifics live in each project's own stub section, never
  in the shared core.
- **Additive & safe.** Installing/retrofitting backs up existing files; retrofit is dry-run
  by default and changes nothing until you say so.
- **Enforce what must not be violated.** Instructions shape what an agent *tries*; only
  permission rules and hooks decide what it *may do*. `guards/` covers the small set of actions
  that destroy unrecoverable work — and only in the destructive case, so the guard stays
  trustworthy: `git checkout <path>` is blocked on a dirty tree and allowed on a clean one.

Start with `docs/00-OVERVIEW.md`, then `docs/01-KNOWLEDGE-TAXONOMY.md`.

## Contributing & license

Conventions and local checks are in [`CONTRIBUTING.md`](CONTRIBUTING.md) (and the canonical
[`AGENTS.md`](AGENTS.md)). Release history is in [`CHANGELOG.md`](CHANGELOG.md). Licensed under
the [MIT License](LICENSE).
