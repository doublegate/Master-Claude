# Language Overlay — Rust

Concrete commands for the universal rules. Adjust to the project's actual toolchain.

## Build / test / lint

- Build: `cargo build` (release: `cargo build --release`)
- Test: `cargo test` (workspace: `cargo test --workspace`); single: `cargo test <name>`
- Format gate: `cargo fmt --check` (apply: `cargo fmt`)
- Lint gate: `cargo clippy --all-targets --all-features -- -D warnings`
- Docs build: `cargo doc --no-deps`

## Quality / security

- Coverage: `cargo llvm-cov` (or `cargo tarpaulin`)
- Bench: `cargo bench`; profile: `perf record` / flamegraph; measure before optimizing.
- Deps audit: `cargo audit`; licenses: `cargo deny check`
- Fuzz: `cargo fuzz run <target>` for parsers / untrusted-input boundaries.

## Conventions

- Hot loops: prefer fixed arrays over `Vec`, avoid per-iteration allocation.
- `unsafe` blocks require a `// SAFETY:` comment stating the upheld invariant; confine to FFI.
- Errors: `Result`/`Option` with context (`anyhow`/`thiserror`); never `unwrap` on untrusted input.
- Feature flags for additive work, default-off to preserve shipped behavior.

> Universal rules: see `master-core/AGENTS.base.md`. Topic depth: `master-core/modules/`.
