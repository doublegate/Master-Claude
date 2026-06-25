# 50 — Architecture by Ownership

## Why it matters

Most architectural pain in a stateful system comes from two sources: ambiguous ownership of
mutable state (who is allowed to mutate what, and when) and tangled dependency cycles (module
A needs B which needs A, so neither can be tested or reasoned about alone). Deciding ownership
up front — one component owns the mutable subsystems, everyone else borrows — collapses a
whole class of borrow-checker fights, lock-ordering bugs, and "spooky action at a distance."
A one-directional dependency graph then makes every unit independently testable, fuzzable, and
benchmarkable. The same ownership discipline carries into databases (one source of truth,
versioned schema) and error handling (every fallible boundary returns a typed result).

## Patterns

- **One component owns all mutable subsystems; others borrow it.** A central Bus / Scheduler /
  context holds the subsystems; callers take a `&mut` (or a scoped handle) for the duration of
  a tick. Avoids the cycle where "A holds B, but B also needs A's state." Example: a Bus owns
  the peripherals and working memory; the processor borrows `&mut Bus` during each step.

- **Hand each consumer the narrowest interface it needs.** A subsystem that only reads two
  things should see a two-method trait, not the whole owner. Shrinks the blast radius of
  change and clarifies real dependencies. Example: a video unit sees a `VideoBus` trait
  (memory reads only), not the full Bus.

- **The dependency graph is strictly one-directional; no cross-module cycles.** Each unit
  depends only on those below it; a top-level crate ties them together. Result: each unit
  compiles and tests in isolation. Adding a back-edge breaks the invariant — don't. Example:
  the CPU crate has no dependency on the video or audio crates.

- **A single timing/clock master drives everything; subsystems advance on its divisor.** One
  scheduler ticks the master unit and steps each subsystem on its ratio — lockstep, not
  catch-up. Mid-step cross-subsystem events then "just work" without per-quirk patches.

- **Abstract at boundaries with traits/interfaces, not concrete structs.** Boundary behavior
  (a mapper, a storage backend, a provider) is a trait with default no-op hooks; concrete
  implementations slot in. Enables mocks and test doubles. Example: optional behavior hooks
  default to no-op so tests can override just one.

- **Gate mock / no-op hooks behind a test or feature flag.** Test-only seams (deterministic
  clocks, fake I/O) compile out of release builds, keeping the shipped path identical.

- **Every `unsafe` / FFI block carries a `// SAFETY:` comment stating the upheld invariant.**
  Forces the author to articulate why it is sound and gives reviewers a checklist. Confine
  `unsafe` to as few crates as possible (frontend, FFI shim).

- **Keep additive features default-off so the shipped path stays byte-identical.** New
  optional capability lives behind a flag that defaults off; with it off, native / portable /
  wasm builds are unchanged. De-risks every release.

### Database patterns

- **One database is the source of truth; use WAL (or equivalent) for concurrent reads.**
  Single-writer + WAL gives readers a consistent snapshot without blocking the writer.

- **Type-safe queries via an ORM / query builder / parameterized statements — never string
  concatenation.** Eliminates injection and catches schema mismatches at compile/test time.
  Example: a typed query layer or prepared statements with bound parameters.

- **Schema changes go through versioned, ordered migrations.** Each migration is numbered,
  forward-only by default, and replayable; the schema version is recorded.

- **Expose read-only query surfaces and JSON/YAML config overrides.** Read-only views for
  ad-hoc queries; declarative config files (with documented precedence) for per-deployment or
  per-item overrides instead of hardcoded constants.

### Error handling

- **Fallible operations return a typed result/optional; reserve panics for true invariants.**
  Propagate with the language's result type; an unexpected `None`/`Err` is data, not a crash.

- **Never unwrap/assert on untrusted input.** External data (files, network, user input) is
  validated and converted to a typed error, never force-unwrapped.

- **Error messages carry context — what failed, on which input, why.** Attach the offending
  value/path so the message is actionable, while never leaking secrets into logs or errors.

## Language specifics

Concrete forms — Rust `Result`/`Option` + trait objects + `#[cfg(test)]` seams, TS tRPC/ORM
layering, Python typed exceptions + SQLite WAL — live in the language overlays:
`master-core/lang/rust.md`, `master-core/lang/python.md`, `master-core/lang/typescript.md`,
`master-core/lang/generic.md`.

## Project-bound — do NOT generalize

- Specific subsystem/chip names, clock frequencies, and divisor ratios.
- Concrete crate/package layouts and binary names.
- Named ORMs, schema table lists, migration counts, taxonomy versions.
- Per-project feature-flag names and the exact default-off feature set.
- Layer diagrams tied to one stack (e.g. a specific UI→service→DB topology).

## Sources

- `/home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md`
- `/home/parobek/Code/OSS_Public-Projects/RustySNES/CLAUDE.md`
- `/home/parobek/Code/Commercial_Private-Projects/PFAS/CLAUDE.md`
- `/home/parobek/Code/Commercial_Private-Projects/lobe-chat/CLAUDE.md`
- `/home/parobek/Code/OSS_Public-Projects/VeridianOS/CLAUDE.md`
