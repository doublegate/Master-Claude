# Skills

Multi-phase workflow skills shared across projects. Skills differ from `commands/` (one-shot):
they encode multi-step processes.

## Current state

The user's three mandatory skills already live globally at `~/.claude/skills/` and apply to all
projects automatically:

- `feature-implementation-tdd` — mandatory for all features.
- `systematic-debugging` — mandatory for all debugging.
- `security-audit-workflow` — mandatory for security reviews.

Because they are already global, they are **not duplicated here** (curate-don't-dump). This
folder holds only skills that are specific to the Master-Claude system itself, or new
cross-project skills distilled from the corpus that are not yet global.

## Candidates to promote here later
- A `sprint-lifecycle` skill composing `/sprint-start` -> work -> `/sprint-complete`.
- A `retrofit-project` skill wrapping `mc-retrofit` (dry-run) -> review -> `mc-install`.

Add a skill only when it is genuinely multi-phase and reused across projects.
