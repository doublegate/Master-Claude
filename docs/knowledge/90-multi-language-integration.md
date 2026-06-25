# 90 — Multi-Language Integration

## Why it matters

Polyglot systems fail at the seams: the same algorithm implemented twice drifts, a hand-written FFI shim violates an invariant the other side assumed, a type that was safe in one language is `any` in another. These bugs are silent — the build passes, the tests pass on each side, and the two languages quietly disagree at runtime. The disciplines below keep a multi-language system honest: one source of truth for shared shapes, explicit safety contracts at native boundaries, and machine-checked parity where two languages must compute the same thing. They generalize across any combination of a systems language (FFI core) plus a scripting/UI language plus a typed web edge.

## Patterns

**Define each shared shape once, generate the per-language bindings.**
A contract — a message format, a record, an API request — should have exactly one authoritative definition (a schema/IDL), with bindings derived for every language that consumes it. Two hand-maintained copies drift; one schema with generated bindings cannot.
Example: a single `.proto`/schema produces both the Rust struct and the TypeScript type; changing the schema forces both to update.

**Cross a native boundary through a thin, explicitly-contracted FFI layer.**
Keep the FFI surface small and concentrated in one module, not sprinkled through the codebase. Every `unsafe`/native call carries a `// SAFETY:` comment stating the invariant it relies on (pointer validity, length, lifetime, null-termination). The unsafe boundary is the place reviewers look hardest, so make its contract legible.
Example: a hand-written FFI module wrapping a vendored C library, each extern call prefixed with the invariant it assumes and who guarantees it.

**Enforce cross-language parity with shared golden vectors.**
When the same logic exists in two languages (e.g. `algoX.py` and `algoX.rs`), pin its behavior to a canonical set of input→output vectors and run a test that asserts both implementations match them. A golden vector only changes when behavior changes *intentionally* — accidental drift silently invalidates every downstream result.
Example: a parity test that feeds identical seeds to the scripting and native implementations and fails if their outputs diverge from the committed vectors.

**Never present an approximation as the exact result across a boundary.**
When one binding path is exact and a fallback path is approximate, carry an explicit flag through every output, label, and docstring recording which was used. The consumer in another language cannot infer exactness from the value alone — it must be told.
Example: a result object carries an `exactness`/`uses_exact_X` field that every renderer and serializer preserves verbatim.

**Make the API boundary type-safe inside the system; speak REST/JSON only at the true edge.**
Between your own services and clients, prefer a typed contract (typed RPC client, generated client) so a field rename is a compile error, not a 4xx at runtime. Reserve untyped REST/JSON for the genuine external perimeter where you cannot control the other side.
Example: a typed RPC layer between the web app and its backend; a plain REST endpoint only for third-party integrations.

**Lint, format, and test each subproject with its own native toolchain.**
A polyglot repo is not one ecosystem — each language keeps its own linter, formatter, and test runner, and the aggregate gate runs all of them. Do not force one language's conventions onto another; do require every language's gate to pass before merge.
Example: a single "verify-all" entry point that runs the Rust, Python, and TypeScript gates in sequence and fails if any does.

**Isolate platform and feature variation behind conditional compilation / capability flags.**
Code that differs by OS, architecture, or optional native dependency is gated by explicit conditionals, with a defined behavior for each branch — including the "native extension absent" branch. The build must be coherent on every target, not just the developer's.
Example: a feature flag selects the exact native generator when the compiled extension is present and a pure-language fallback when it is not, with tests covering both.

**Keep the core dependency-light and push heavy/native deps behind optional extras.**
The shared core stays minimal (ideally standard-library-only) so it is portable and cheap to embed; native, platform-specific, or heavyweight dependencies live behind an opt-in extra/feature. This keeps the common path buildable everywhere and the expensive path opt-in.
Example: a zero-runtime-dependency core with the accelerated native binding gated behind an `accurate`/`native` extra.

**Establish a stable stream/transport contract between languages.**
When languages communicate over pipes/sockets/stdio, fix the contract: which stream carries results vs diagnostics, the framing, and the encoding. A consumer in another language pipes the output, so mixing data and logs on one stream breaks it.
Example: matching records always on stdout, all progress/diagnostics on stderr, so the output pipes cleanly into a downstream tool.

## Language specifics

Concrete binding generators, FFI frameworks (native extension tooling, WASM bindgen, typed-RPC stacks), per-language lint/format/test commands, and the conditional-compilation syntax live in `master-core/lang/<lang>.md`. The patterns here are language-agnostic; the overlay supplies the per-ecosystem mechanics and the exact build/test invocations for the multi-language gate.

## Project-bound — do NOT generalize

Keep these in the project's own stub, not here:

- The specific schema/IDL technology and the list of languages it generates bindings for.
- Which exact files are accuracy-critical parity pairs and where their golden vectors live.
- The concrete native-dependency build steps (submodules, C compiler, extension-copy paths).
- The project's exact feature-flag names and what each gates.
- The specific stdout/stderr/framing contract and which records go where.
- The target matrix (OS/arch) and the one "verify-all" command name for that repo.

## Sources

- `/home/parobek/Code/Local_Only-Projects/mc-seed-finder/CLAUDE.md` (FFI to vendored C, Python↔Rust parity, golden vectors, exactness flag, feature flags, stdout/stderr contract, stdlib-only core)
- `/home/parobek/Code/Local_Only-Projects/mc-seed-finder/GEMINI.md` (per-language conventions)
- `/home/parobek/Code/OSS_Public-Projects/SPECTRE/CLAUDE.md` (multi-crate workspace, Rust+TS+Docker, protobuf data pipeline, per-language standards, platform test scripts)
- `/home/parobek/Code/OSS_Public-Projects/VeridianOS/CLAUDE.md` (conditional compilation by arch, cfg gating, C library shims)
- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md` (typed output formats, cross-platform packet layer)
