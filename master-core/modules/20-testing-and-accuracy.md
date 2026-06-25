# Module 20 — Test-Driven Accuracy

Terse, project-agnostic rules. Apply when correctness must match an external oracle.

## Test-as-spec

- Pin the failing test (or oracle vector) FIRST; implement only until it passes.
- Treat tests and golden vectors as the spec. If docs and a test disagree, the test wins — fix the docs.
- Keep the spec doc and the code in sync in the same change; never let them drift apart.
- Make accuracy-critical behavior verified against an independent, external oracle, not self-asserted.

## Golden vectors

- Commit canonical reference outputs (framebuffers, logs, audio, encode/decode results).
- Update a canonical vector ONLY on intentional, reviewed behavior change. Accidental drift invalidates all prior results.
- Use one shared vector set to enforce parity between two implementations or code paths.
- Commit permissive/public-domain fixtures; gitignore proprietary oracles; degrade gracefully when absent.

## Determinism

- Hard contract: same seed + same input ⇒ byte-identical output.
- Inject seeds explicitly; preserve them across save/restore and replay.
- Keep wall-clock, OS RNG, thread scheduling, and unordered-map iteration order out of the core.
- Put rate control / timing jitter in the frontend, never in the deterministic core.

## Test layers

- Write unit tests in-module for single behaviors.
- Write integration tests in a separate suite for composition across modules.
- Add property-based tests for invariants (round-trips, idempotence, ordering).
- Add fuzz targets for parsers and any untrusted-input boundary.

## Exactness honesty

- Never present approximate output as exact.
- Propagate an exactness/confidence flag to every label, log line, and docstring.
- Add an honesty gate so the suite cannot claim support or accuracy it does not actually verify.

## Running suites

- Never run large suites unfiltered; scope by crate, file, or test-name substring.
- Run the full suite only in CI or pre-release.
- Run serially when debugging flakes.

## Gates

- Gate merges on a coverage threshold to prevent silent erosion.
- Add a regression gate for any fixed bug (the pinned test stays).

## Project-bound (keep in project stub, not here)

- Exact pass counts, percentages, named suites/corpora.
- Specific oracle tools, reference cores, hardware models.
- Per-project exact-vs-approximate feature flags.
- Performance baselines and timing budgets.

> Language commands: see master-core/lang/<lang>.md
