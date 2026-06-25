# 30 — Quality Gates, CI/CD & Profile-First Performance

## Why it matters

A quality gate is an automated yes/no that a change can merge — format, lint, tests, coverage, and platform builds, all run identically on every PR. Gates catch regressions when they are cheapest (before merge) and make "it works on my machine" irrelevant. Performance is part of quality, but only when measured: optimizing without a profile trades correctness for guesswork.

## Patterns

**Run format and lint as blocking gates with warnings-as-errors.**
A consistent formatter kills diff noise; a zero-warning lint bar stops slow rot.
Example: a check-only format pass plus a linter run that fails the build on any warning.

**Run the full test suite in CI on every PR.**
The only test result that matters is the one a clean machine produces.
Run unit, integration, and doc/example tests; mirror the exact commands locally before pushing.

**Reproduce the CI gate locally before opening a PR.**
Running the same commands locally turns CI from a guessing game into a confirmation.
Example: run the format-check, lint, and test commands CI uses, in that order, and only push when green.

**Set coverage thresholds: a baseline floor for the repo, a higher bar for core logic.**
A floor stops backsliding; a higher core bar concentrates rigor where bugs hurt most.
Track coverage in CI and treat a drop below the floor as a failure, not a warning.

**Fuzz untrusted-input and parser code paths continuously.**
Adversarial inputs find the edge cases hand-written tests miss; long-running fuzzers find them for free.
Example: persistent fuzz targets over parsers/protocol decoders, with crash count gated at zero.

**Build and test across a platform matrix.**
Code that only runs on the author's OS is untested on the OSes users actually run.
Example: a Linux/macOS/Windows matrix, plus a pinned minimum-toolchain job for compatibility.

**Build distributables for every supported platform/arch, not just the host.**
A release that fails to build for a target is discovered by users, not by you, unless CI builds it.
Example: cross-compiled binaries and multi-arch container images produced and smoke-tested in CI.

**Check platform/system dependencies before installing them in CI.**
Idempotent dependency setup keeps pipelines fast and reruns clean.
Example: guard a package install with a presence check so reruns skip already-satisfied deps.

**Gate documentation builds too.**
Broken doc links and uncompilable examples are defects; let CI catch them.
Example: build docs with warnings-as-errors and compile doc examples as tests.

**Use path filters / conditional jobs so doc-only changes still report success.**
Skipping heavy jobs for irrelevant changes keeps the required-checks signal honest.
Example: a docs-only PR reports the test gate as passed via a paths filter rather than running the full matrix.

**Profile before optimizing; never optimize on a hunch.**
The bottleneck is rarely where intuition points; a profile redirects effort to where it pays.
Example: capture a benchmark or flamegraph, find the hot path, change only that, re-measure.

**Keep hot paths allocation-free and abstraction-light.**
Per-iteration allocations and indirection dominate tight loops; fixed buffers and direct calls win.
Example: prefer fixed-size arrays over per-call heap allocation inside an inner loop.

**Measure, then document the result of every performance change.**
A perf change without a before/after number is unverifiable and un-reviewable.
Example: record the benchmark delta in the PR and gate against a regression threshold.

**Gate against performance regressions, not just correctness.**
Speed silently rots without a guard; a benchmark gate makes slowdowns visible at PR time.
Example: fail CI when a tracked benchmark regresses beyond an agreed margin.

## Language specifics

Concrete gate commands (formatter, linter, test runner, coverage, bench, fuzz harness) live in `master-core/lang/<lang>.md`. The universal rule is stated here once; the overlay supplies the exact `cargo`/`ruff`/`eslint`/etc. invocation per ecosystem.

## Project-bound — do NOT generalize

Keep these in the project's own stub, not here:

- Exact coverage percentages, test counts, and fuzz-execution totals for one repo.
- Specific lint/feature-flag combinations a single project must run (e.g. per-feature lint passes, mutually-exclusive feature sets).
- Concrete CI job names, timeout values, and platform-specific quirks (e.g. Windows timeout multipliers, a named flaky job).
- Performance baselines and targets tied to specific hardware (per-frame budgets, packets-per-second figures).
- Pinned tool versions and which rules that pin does/doesn't enforce.
- Repo-specific system-dependency install lists.

## Sources

- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/AGENTS.md` (Build/Test commands, Testing guidelines, fuzz)
- `/home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md` (Quality gates, hot-path/profile rules)
- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md` (coverage bars, weekly audit, performance notes)
- `/home/parobek/.claude/CLAUDE.md` (CI/CD best practices, profile-before-optimizing)
- `/home/parobek/Code/CLAUDE.md` (workspace testing patterns)
