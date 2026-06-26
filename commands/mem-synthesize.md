# /mem-synthesize — find and promote cross-project memory facts

Periodically surface memory facts that have generalized across projects and lift the good ones
into the shared `memory-core/`. The deterministic scan is `bin/mc-mem-scan.sh`; this command
adds the judgment and the promotion.

## Usage
`/mem-synthesize [--min-projects N]`  — default N=2.

## Steps (the agent performs these)
1. Run `bin/mc-mem-scan.sh` (pass `--min-projects` through). It lists two candidate sets:
   **(A)** the same fact slug present in ≥N projects, and **(B)** facts already marked
   `scope: universal` — both filtered to those not yet in `memory-core/`.
2. For each candidate, read the actual fact file(s) under
   `~/.claude/projects/<slug>/memory/<fact>.md` and decide:
   - **Generalizes** (a preference, a tool gotcha, a workflow rule true regardless of project)
     → promote it.
   - **Project-bound** (names a specific repo, number, chip, schema) → skip; leave it in place.
   - **Already covered** by an existing `memory-core/` fact → skip; optionally link it.
3. Promote each keeper: `bin/mc-promote.sh <project-dir> <slug> --date <today>` (supply today's
   date — scripts can't read the clock), then open `memory-core/<slug>.md` and curate: strip
   project specifics, set `scope: universal` + `lastVerified`, add `tags`, link related facts
   with `[[slug]]`, and confirm the `MEMORY.md` hook line reads well.
4. Report: which were promoted, which were skipped and why. Do not commit unless asked.

Promotion is one-directional (project → shared). See `docs/architecture/memory-architecture.md`.
