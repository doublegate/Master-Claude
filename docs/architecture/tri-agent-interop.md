# Architecture — Tri-Agent Interoperability

How one source of truth serves Claude Code, OpenAI Codex, and Google Gemini.

## What each agent reads

| Agent | Instruction file | Memory / config home | Extras |
|---|---|---|---|
| **Claude Code** (primary) | `CLAUDE.md` (+ `@import`) | `~/.claude/projects/*/memory/` | skills, slash commands, `~/.claude/CLAUDE.md` global |
| **OpenAI Codex** | `AGENTS.md` | `~/.codex/` (`config.toml`) | project trust levels, plugins |
| **Google Gemini** | `GEMINI.md` | `~/.gemini/` (global `GEMINI.md`) | Antigravity IDE integration |

Claude is **primary** because it has the richest surface (skills, commands, structured memory,
`@import`). Codex and Gemini are served by exporting the same canonical content under their
filenames.

## The bridge: one canonical file

Because `CLAUDE.md` and `GEMINI.md` are **symlinks to `AGENTS.md`**, all three agents read
identical instructions with zero duplication. The only asymmetry is `@import`:

- **Claude** expands `@~/.claude/master-core/modules/*.md` → gets the full module set.
- **Codex / Gemini** ignore `@import` lines → get whatever is **inline** in `AGENTS.md`.

This is exactly why `mc-install` offers `--inline` (bake modules in for full parity) vs
`--import` (lean on Claude's loader). Choose per project based on which agents are active.

## Parity matrix

| Capability | Claude | Codex | Gemini |
|---|---|---|---|
| Reads canonical instructions | ✅ via `CLAUDE.md`→`AGENTS.md` | ✅ `AGENTS.md` | ✅ `GEMINI.md`→`AGENTS.md` |
| `@import` heavy modules | ✅ | ❌ (use `--inline`) | ❌ (use `--inline`) |
| Structured persistent memory | ✅ `memory/` | partial (`~/.codex`) | partial (`~/.gemini`) |
| Slash commands / skills | ✅ | ✗ (own mechanisms) | ✗ |

## Memory: no native cross-agent bridge

The three agents keep **independent** memory/config trees; there is no built-in shared memory.
Master-Claude's `memory-core/` is the closest thing to a bridge — a single curated fact set
that can be seeded into whichever agent's home is in use. Cross-agent memory sync is tracked as
a future enhancement (see `to-dos/04-PHASE-4-MAINTENANCE.md`).

## Practical guidance

- Default to `--import` (Claude-primary). Switch a project to `--inline` the moment Codex or
  Gemini start doing real work there, so they aren't missing the heavy modules.
- Keep the **inline base** (`AGENTS.base.md`) genuinely universal — it is the only content
  guaranteed to reach every agent in every mode.
- Optionally generate `.codex`/`.gemini` pointer files for discoverability (enhancement).
