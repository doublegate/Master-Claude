# Module 50 — Architecture by Ownership

Terse, project-agnostic rules for stateful-system structure, data, and errors.

## Ownership of mutable state

- Give ONE component (Bus / Scheduler / context) ownership of all mutable subsystems.
- Have every other component borrow it (`&mut` or a scoped handle) for the duration of a step.
- Hand each consumer the narrowest interface it needs, not the whole owner.
- This avoids the "A holds B but B needs A" cycle and lock-ordering bugs.

## Dependency graph

- Keep the graph strictly one-directional; no cross-module cycles.
- Let a single top-level unit tie the lower units together.
- Ensure each unit compiles, tests, fuzzes, and benchmarks in isolation.
- Reject any back-edge that makes a unit depend on a peer.

## Timing / scheduling

- Use a single clock/timing master; advance every subsystem on its divisor (lockstep, not catch-up).
- Keep all timing authority in one scheduler so mid-step cross-subsystem events work without per-quirk patches.

## Abstraction boundaries

- Abstract boundaries with traits/interfaces, not concrete structs.
- Provide default no-op hooks for optional behavior.
- Gate mock / test-only seams behind a test or feature flag so release paths are unchanged.

## Safety

- Require a `// SAFETY:` comment on every unsafe / FFI block stating the upheld invariant.
- Confine unsafe to as few modules as possible (frontend, FFI shim).

## Feature flags

- Make additive features default-off.
- Keep shipped/native/portable/wasm builds byte-identical when optional features are off.

## Database

- Treat one database as the source of truth; enable WAL (or equivalent) for concurrent reads.
- Use an ORM / query builder / parameterized statements; never concatenate SQL strings.
- Apply schema changes via versioned, ordered, replayable migrations; record the version.
- Expose read-only query surfaces; allow JSON/YAML config overrides with documented precedence.

## Error handling

- Return a typed result/optional from fallible operations; reserve panics for true invariants.
- Never unwrap/assert on untrusted input; validate and convert to a typed error.
- Include context in error messages (what failed, which input, why); never leak secrets.

## Project-bound (keep in project stub, not here)

- Subsystem/chip names, clock frequencies, divisor ratios.
- Crate/package layout, binary names, layer topology diagrams.
- ORM/table names, migration counts, feature-flag names.

> Language commands: see master-core/lang/<lang>.md
