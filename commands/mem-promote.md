# /mem-promote — promote a project lesson into shared memory

Lifts a project-scoped memory fact that has generalized (proven useful in 2+ projects) into the
Master-Claude shared `memory-core/`, then prompts you to curate out the project specifics.

## Usage
`/mem-promote <project-dir> <fact-slug>`

## Steps
1. Run `bin/mc-promote.sh <project-dir> <fact-slug> --date <today>` (supply today's date — the
   script cannot read the clock).
2. Open the new `memory-core/<fact-slug>.md`: strip project-specific names/numbers, confirm
   `scope: universal` + `lastVerified`, add `tags`, and link related facts with `[[slug]]`.
3. Verify the `memory-core/MEMORY.md` hook line reads well (one-line hook, no content).
4. Leave the original project fact in place. Commit only when asked.

Promotion is one-directional (project -> shared). See
`docs/architecture/memory-architecture.md`.
