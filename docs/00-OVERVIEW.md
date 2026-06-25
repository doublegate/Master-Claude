# 00 — Overview

## Mission

Turn a year of fragmented, project-trapped AI-agent knowledge into **one curated, reusable
system** that works regardless of which project it is applied to, and which makes that
knowledge effortless to adopt in any new or existing codebase, for all three agents in use
(Claude Code, OpenAI Codex, Google Gemini).

## The problem it solves

Knowledge lived in ~150 in-repo instruction files + 165 per-project memory facts + 63 project
commands. It was: **duplicated** (the same commit/test/release conventions re-written per
repo), **trapped** (a lesson learned in project A never reaches project B), and **uneven**
(some repos exhaustively documented, others nearly empty). Bootstrapping a new project meant
re-deriving conventions the agents already knew elsewhere.

## The solution, in one diagram

```
   ~/Code/*  (89 projects, 3 agents)
        │  harvest + curate (one-time + ongoing promotion)
        ▼
   Master-Claude/
     docs/knowledge/   ← human-readable synthesis (16 areas)
     master-core/      ← slim distributable modules  ─┐
     memory-core/      ← generalized facts            │ bin/mc-install
     commands/ skills/ templates/                     │
        │                                             ▼
        └──────────────────────────────►  any project/
                                            AGENTS.md   (canonical, slim)
                                            CLAUDE.md  -> AGENTS.md
                                            GEMINI.md  -> AGENTS.md
                                            + @import ~/.claude/master-core/* (Claude)
```

## What "good" looks like

- A new project is productive in **one command**: `mc-install.sh <dir> --lang <x>`.
- A lesson learned anywhere can be **promoted once** and is then available everywhere.
- The shared core is **small enough to always load** and curated enough to **always be right**.
- Existing projects are **never disturbed** unless their owner opts into a retrofit.

## Economics / why small matters

Research across thousands of repos: instruction files beyond ~150–200 lines deliver
diminishing returns and raise inference cost ~20–23% with no quality gain; auto-generated
("dumped") instruction files measurably **underperform** curated ones. Master-Claude therefore
optimizes for **signal density**: short modules, deduplicated rules, decisions not narration.

## Success metrics

- Time-to-productive on a new project: one command, <1 min.
- Duplication: shared conventions authored **once**, referenced everywhere.
- Coverage: the 16 competency areas each have a curated module + human doc.
- Safety: zero unintended modifications to existing projects (retrofit dry-run proven).

## Where to go next

- `01-KNOWLEDGE-TAXONOMY.md` — the 16 areas and where each came from.
- `architecture/distribution-model.md` — how install/sync/symlink/@import work.
- `architecture/memory-architecture.md` — memory schema v2 + promotion model.
- `architecture/tri-agent-interop.md` — Claude/Codex/Gemini parity.
- `../to-dos/` — the phased build plan.
