# /ci-debug — diagnose a failing CI run

Project-agnostic. Reads the latest CI failure, categorizes it, and proposes a local repro +
targeted fix. Derived from the recurring ci-debug command.

## Usage
`/ci-debug [run-id]`  — defaults to the latest failed run on the current branch.

## Steps
1. Fetch the failing run: `gh run view <id> --log-failed` (or the platform equivalent).
2. Extract failed jobs/steps; categorize the error: test | build | lint/format | type |
   timeout | platform-specific | flaky.
3. Map to a local reproduction command (mirror what CI runs — see `master-core/lang/<lang>.md`).
4. Run the local repro; capture the real error.
5. Propose the smallest fix; if platform-specific (e.g. Windows-only), note the conditional.
6. Report: category, root cause with file:line evidence, repro command, proposed fix. Do not
   push.

See `master-core/modules/30-quality-gates.md`.
