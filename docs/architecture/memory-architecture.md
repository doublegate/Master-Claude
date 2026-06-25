# Architecture — Memory Architecture

How persistent agent *memory* (as distinct from instruction files) is generalized, stored, and
promoted.

## Two tiers

| Tier | Location | Holds |
|---|---|---|
| **Project** | `~/.claude/projects/<path-slug>/memory/` | Project-specific pitfalls, references, goals |
| **Shared (Master)** | `memory-core/` in this repo (→ optionally `~/.claude/global-memory/`) | The generalized ~65% subset: user prefs, cross-project feedback, reusable references |

Promotion is **one-directional: project → shared**, and a fact is promoted once it has proven
useful in **2+ projects**. Shared facts are never copied back down — projects reference the
shared tier.

## Frontmatter schema v2 (backward-compatible)

Current facts use `name / description / type / originSessionId`. Schema v2 **adds three
fields**; old files remain valid (missing fields treated as defaults).

```yaml
---
name: <short-kebab-slug>
description: <one-line hook used for recall>
metadata:
  type: user | feedback | project | reference
  scope: universal | project        # NEW — drives promote/keep decisions
  lastVerified: YYYY-MM-DD           # NEW — aging awareness
  tags: [<tag>, ...]                 # NEW — cross-cutting search
  originSessionId: <uuid>            # preserved when present
---
<body. For feedback/project follow with **Why:** and **How to apply:** lines.
Link related memories with [[other-slug]].>
```

### Field semantics

- **type** — unchanged taxonomy. `user` = who the user is; `feedback` = how the agent should
  work (with the why); `project` = ongoing work facts; `reference` = pointers to resources.
- **scope** — `universal` facts are promotion candidates; `project` facts stay put.
- **lastVerified** — lets `mc-doctor`/promotion flag stale facts (e.g. references to a tool that
  changed). Convert relative dates to absolute when writing.
- **tags** — free-form, enables grep-style cross-cutting recall across the 16 areas.

## MEMORY.md index rule

Each memory dir keeps a `MEMORY.md` index: **one line per fact, hook only, never the content.**

```markdown
# Memory Index
- [Title](slug.md) — one-line hook
```

`memory-core/MEMORY.md` follows the same rule for the shared tier.

## Promotion workflow (`mc-promote`)

1. Point at a project's fact (slug) that has generalized.
2. The script copies it into `memory-core/`, **strips project-specific specifics**, sets
   `scope: universal` + `lastVerified: <today>`, and adds the `MEMORY.md` hook line.
3. The original project fact is left in place (optionally annotated `promoted: <slug>`).

## What gets generalized (from the corpus)

Already-identified universal facts to seed `memory-core/`: user preferences (no emojis,
Conventional Commits, TDD-first, read-before-write), shell/system patterns (fish has no
heredocs → `printf|tee`), and reusable tool-gotcha references. Project-bound facts
(emulator accuracy traces, OS kernel phases, app-specific schemas) stay in their project tier.
