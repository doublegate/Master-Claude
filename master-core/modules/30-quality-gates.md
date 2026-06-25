# 30 — Quality Gates, CI/CD & Performance

Automated merge gates (format, lint, test, coverage, multi-platform build) plus profile-first performance discipline.

- Run format and lint as blocking gates; treat warnings as errors.
- Run the full suite (unit, integration, doc/example tests) in CI on every PR.
- Reproduce the CI gate locally with the same commands before opening a PR.
- Enforce a coverage floor for the repo and a higher bar for core logic; fail on drops below the floor.
- Fuzz untrusted-input and parser/protocol paths continuously; gate crash count at zero.
- Build and test across a platform matrix, including a pinned minimum-toolchain job.
- Build distributables for every supported platform/arch (cross-compile, multi-arch images) and smoke-test them in CI.
- Guard CI dependency installs with presence checks so reruns stay idempotent.
- Gate docs too: build with warnings-as-errors and compile doc examples.
- Use path filters / conditional jobs so doc-only changes still report required checks as passed.
- Profile before optimizing; never optimize on a hunch — capture a benchmark or flamegraph first.
- Change only the measured hot path, then re-measure.
- Keep hot paths allocation-free and abstraction-light; prefer fixed buffers over per-iteration allocation.
- Document the before/after number for every performance change.
- Gate against performance regressions, not only correctness; fail CI on tracked-benchmark slowdowns.

> Language commands: see master-core/lang/<lang>.md
