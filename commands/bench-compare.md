# /bench-compare — statistical benchmark between two refs

Project-agnostic. Measures performance across two git refs and flags regressions/improvements.
Derived from the recurring bench-compare command.

## Usage
`/bench-compare <baseline-ref> <comparison-ref> [bench-target]`

## Steps
1. Confirm a benchmark harness exists (`master-core/lang/<lang>.md`: `cargo bench`,
   `pytest-benchmark`, `vitest bench`, or a project script). If none, stop and say so.
2. For each ref: checkout (clean tree required), build release, run the bench (warmup + >=10
   runs; use `hyperfine` for CLI-level timing).
3. Compute deltas; flag regression if >+5% slower, improvement if <-5% faster (else "noise").
4. Restore the original ref.
5. Report a table (metric | baseline | comparison | delta | verdict) + a one-line summary. Save
   raw results to the sprint `notes.md` if a sprint is active.

Profile-first rule: investigate any regression with a profiler before "fixing" it. See
`master-core/modules/30-quality-gates.md` and `50-architecture-patterns.md`.
