# 90 — Multi-Language Integration

Project-agnostic rules for polyglot systems (FFI, shared contracts, cross-language parity). See `docs/knowledge/90-multi-language-integration.md` for rationale.

## Shared contracts
- Define each shared shape (message/record/API) ONCE in a schema/IDL.
- Generate per-language bindings from that schema; never hand-maintain parallel copies.
- A schema change must force every consuming language to update.

## FFI / native boundaries
- Keep the FFI surface thin and concentrated in one module, not scattered.
- Put a `// SAFETY:` comment on every unsafe/native call stating the invariant relied on.
- Name who guarantees each invariant (pointer validity, length, lifetime, null-termination).
- Wrap vendored native libraries behind a single explicit shim layer.

## Cross-language parity
- Pin duplicated logic (same algorithm in two languages) to shared golden vectors.
- Run a parity test asserting both implementations match the canonical vectors.
- Change a golden vector only when behavior changes intentionally; treat drift as a bug.
- Never present an approximation as exact; carry an exactness flag through every output/label/docstring.

## Type-safe boundaries
- Use a typed contract (typed RPC / generated client) between your own services.
- Make a field rename a compile error, not a runtime 4xx.
- Reserve untyped REST/JSON for the true external perimeter only.
- Fix the stream/transport contract: results vs diagnostics on separate streams, defined framing/encoding.

## Per-subproject toolchain
- Each language keeps its own linter, formatter, and test runner.
- Provide one aggregate gate that runs every language's checks and fails if any fails.
- Do not impose one language's conventions on another.

## Platform & feature variation
- Gate OS/arch/optional-dependency differences behind explicit conditional compilation / feature flags.
- Define behavior for every branch, including the "native extension absent" fallback.
- Test both the native-present and fallback paths.
- Keep the core dependency-light (ideally stdlib-only); push native/heavy deps behind an opt-in extra.

## Out of scope here (keep in project stub)
- The specific schema technology and generated-language list.
- Which files are parity pairs and where golden vectors live.
- Native build steps, feature-flag names, stream contract, target matrix, verify-all command.
