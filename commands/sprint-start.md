# /sprint-start — begin a structured sprint

Project-agnostic. Scaffolds a sprint with a plan, task checklist, and working dirs. Derived
from the recurring sprint-lifecycle workflow across projects.

## Usage
`/sprint-start <sprint-id>`  — id is `<phase>.<sprint>` (e.g. `4.3`) or descriptive (`auth-hardening`).

## Steps
1. Validate the id format; refuse if a sprint dir with that id already exists.
2. Create `to-dos/<sprint-id>/` with: `plan.md` (goal, scope, non-goals), `tasks.md` (3-8 tasks
   with a critical-path note + what can run in parallel), and `notes.md` (running log).
3. Seed `tasks.md` from the goal: break into the smallest verifiable units; mark the finalize
   task (tests green + docs synced + CHANGELOG entry).
4. Record the sprint id + start date in `CLAUDE.local.md` under "Current phase/sprint".
5. Do NOT start coding — print the plan and the first task for confirmation.

See `master-core/modules/80-phase-sprint-workflow.md`.
