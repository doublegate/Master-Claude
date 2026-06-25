# 20 — Test-Driven Accuracy

## Why it matters

When correctness is the product — an emulator that must match real hardware, a finance
tool that must match a bank statement, a worldgen search that must match the game's RNG —
"looks right" is not a standard. The test becomes the executable definition of correct, and
every change is measured against a fixed, external oracle rather than against opinion. This
discipline is what lets a long-lived project refactor aggressively without silently
regressing behavior: the oracle catches drift the moment it appears.

## Patterns

- **Pin the failing test FIRST, then implement to green.** Reverses the temptation to code
  then back-fill a test that merely rubber-stamps what you wrote. The pinned expectation is
  an independent target, so passing it means something. Example: before fixing a bus-conflict
  bug, commit the test that asserts the correct value and watch it fail — only then touch the
  implementation.

- **Tests / golden vectors ARE the spec; when docs and a test disagree, the test wins.**
  Prose drifts, a checked-in vector does not. The doc gets corrected to match the test, never
  the reverse. Example: a chip doc claims one timing; the hardware-derived golden log says
  another — update the doc, the log is canonical.

- **Determinism is a hard contract: same seed + same input ⇒ byte-identical output.**
  Without it, regression tests, replay, snapshot round-trips, and rollback are all impossible.
  Keep all non-determinism (wall-clock, OS RNG, thread scheduling, iteration order of unordered
  maps) out of the core; inject seeds explicitly and preserve them across save/restore.

- **Layer the test types — unit, integration, property-based, fuzz.** Each catches a
  different failure class: unit pins one behavior, integration pins composition, property
  tests find counterexamples to invariants, fuzzing finds crashes on hostile input. Example:
  in-module `#[cfg(test)]` units + a `tests/` integration suite + a property test that round-
  trips encode/decode + a fuzz target on the parser.

- **Enforce cross-language / cross-path parity with shared golden vectors.** When two
  implementations (a fast native core and a portable fallback, or a Rust path and a Python
  path) must agree, a single committed vector set is the contract both run against; a parity
  test fails if they diverge. Example: native and pure-language generators both replay the
  same canonical vectors and must produce identical results.

- **Golden vectors must not drift accidentally — update a canonical value ONLY on intentional
  behavior change.** A silently edited vector invalidates every prior result. Treat vector
  changes as reviewed, deliberate, commit-justified events.

- **Never present approximate output as exact — track which path produced a result.** When an
  exact and an approximate code path both exist, a flag (`exactness`, `uses_exact_*`) must
  propagate to every label, log line, and docstring so consumers know the confidence level.

- **Never run huge suites unfiltered — filter by name/pattern.** Multi-thousand-test suites
  cost minutes and bury the signal. Always scope to the crate, file, or test-name substring
  you are working on; run the full suite only in CI or before a release.

- **Gate merges on coverage and an honesty check.** A coverage threshold prevents silent
  erosion; an "honesty gate" prevents claiming support/accuracy a suite doesn't actually
  verify (e.g. a tier table asserting which features are truly tested vs. best-effort).

- **Separate committed permissive fixtures from gitignored proprietary ones.** Public-domain /
  CC0 test inputs live in-repo; commercial or copyrighted oracles stay local and gitignored,
  with the suite degrading gracefully when they are absent.

## Language specifics

Concrete invocations (filtered test runs, coverage flags, fuzz/property crates, bench
commands) live in the language overlays — see `master-core/lang/rust.md`,
`master-core/lang/python.md`, `master-core/lang/typescript.md`, and
`master-core/lang/generic.md`. The universal rule is stated here; the overlay supplies the
exact command.

## Project-bound — do NOT generalize

- Exact pass counts, percentages, and named test suites or ROM corpora.
- Specific golden-log oracles, reference implementations, or hardware model numbers.
- Per-project feature flags that toggle exact vs. approximate paths.
- Domain nomenclature (chip names, taxonomy versions, account types).
- Performance baselines and per-frame/per-op timing budgets.

These belong in each project's own CLAUDE.md / testing-strategy doc, not in shared knowledge.

## Sources

- `/home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md`
- `/home/parobek/Code/OSS_Public-Projects/RustySNES/CLAUDE.md`
- `/home/parobek/Code/Local_Only-Projects/mc-seed-finder/CLAUDE.md`
- `/home/parobek/Code/Commercial_Private-Projects/lobe-chat/CLAUDE.md`
- `/home/parobek/Code/OSS_Public-Projects/VeridianOS/CLAUDE.md`
