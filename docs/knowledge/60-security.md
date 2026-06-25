# 60 — Security & Input Validation

## Why it matters

Most real-world failures in security-sensitive code are not exotic crypto breaks — they are untrusted input that was trusted, a privilege that was held too long, a secret that leaked into a log, or a parser that panicked on a malformed byte. These are cheap to prevent at the boundary and expensive to patch after a release. The rules below are the recurring, language-agnostic disciplines distilled from offensive-security scanners, microkernel capability systems, and encrypted-comms tooling. They apply to any code that touches data, privileges, or secrets it did not itself create.

## Patterns

**Validate every external input at the boundary, then trust the parsed value inward.**
Parse-don't-validate: convert raw bytes/strings into a typed, range-checked value once at the edge, and let the rest of the system rely on the type. Prefer allowlists (enumerate what is permitted) over denylists (enumerate what is forbidden) — denylists always miss a case.
Example: turn a user-supplied address string into a typed `IpAddr`/`CidrBlock` at intake; downstream code receives only valid values, never raw strings.

**Drop privileges immediately after you no longer need them.**
Acquire elevated capability for the one operation that requires it (e.g. opening a raw socket, binding a low port), then descend to an unprivileged context before processing any untrusted data. The window where the process is both privileged and parsing attacker-controlled input is the highest-value target — keep it as close to zero as possible.
Example: create the elevated resource → drop to a restricted user/capability set → enter the main loop that handles network input.

**Parse untrusted buffers with bounds checks and fallible returns — never `unwrap`/`panic` on external data.**
A malformed packet, file, or message must produce a handled error, not a crash. Every length, offset, and tag read from untrusted bytes is bounds-checked before use; the parser returns `Result`/`Option`/error-union rather than indexing blindly.
Example: a packet decoder returns `Err(Malformed)` on a truncated header instead of slicing past the buffer end.

**Treat denial-of-service as a first-class threat: bound concurrency, rate, and memory.**
Unbounded work is an attack surface. Cap in-flight operations with a semaphore, throttle issuance with a token-bucket rate limiter, and stream large I/O to disk instead of buffering it in memory. A burst allowance keeps the system responsive while the steady-state rate stays courteous and safe.
Example: a bounded-concurrency semaphore plus an adaptive token-bucket limiter so a scan or request flood cannot exhaust file descriptors or RAM.

**Keep secrets in the environment/secret store, never in source, and never in errors or logs.**
Credentials, keys, and tokens come from environment variables or a dedicated secret manager — never hardcoded, never committed. Error messages and logs surface what failed, not the sensitive value or internal detail that would aid an attacker.
Example: an auth error reports "authentication failed" with a correlation ID, not the token, query, or stack offsets.

**Use capability/least-privilege tokens instead of ambient authority where the platform allows.**
Grant each component exactly the rights it needs as an explicit, unforgeable token, rather than letting any caller act with global authority. Tokens carry a generation/revocation marker so access can be withdrawn.
Example: a driver receives a capability scoped to one MMIO region rather than blanket access to all device memory.

**Fuzz every parser that ingests untrusted input.**
Hand-written tests cover the cases you imagined; fuzzing finds the malformed inputs you did not. Stand up a fuzz harness for each format/protocol parser and run it regularly — the goal is "no input crashes the parser," enforced continuously, not once.
Example: a coverage-guided harness feeds random byte streams to the message decoder; any panic or hang is a tracked bug.

**Gate releases on a security audit checklist and a dependency audit.**
Before shipping, run a fixed checklist: input-validation coverage, privilege handling, secret hygiene, error-message review, and a dependency vulnerability scan. Make it a recurring cadence (e.g. weekly dep-audit), not a one-time pre-1.0 event.
Example: a pre-release gate that fails CI if the dependency audit reports a known-vulnerable transitive crate/package.

**Test security and offensive tooling across every platform it claims to support.**
Raw sockets, packet capture, privilege models, and filesystem semantics differ per OS; a tool that "works" only on the dev machine has untested attack and failure surface elsewhere. Run the suite on each supported platform and document behaviors that are expected to differ.
Example: a packet-crafting feature is exercised on Linux, macOS, and Windows, with platform-specific failures documented rather than silently ignored.

**Make destructive or dangerous operations require explicit confirmation and leave an audit trail.**
High-blast-radius actions (internet-scale scans, mass deletes, key rotation) prompt for confirmation and log who/what/when. Audit logging is part of the security posture, not an afterthought.
Example: an internet-scale operation requires a typed confirmation and records the scope to an audit log before proceeding.

## Language specifics

Concrete invocations — fuzz-harness frameworks, dependency-audit commands, the exact API for dropping privileges or marking unused results — live in `master-core/lang/<lang>.md`. The rules above are language-agnostic; the overlay supplies the per-ecosystem commands and idioms (e.g. fallible parsing, `#[must_use]`-style error enforcement, secret-loading helpers).

## Project-bound — do NOT generalize

Keep these in the project's own stub, not here:

- Exact rate-limiter burst sizes, concurrency caps, timeout values, and zero-copy thresholds.
- The specific privilege/capability model and which syscalls/resources require elevation.
- Domain-specific "never commit X" rules (commercial test fixtures, specific key material, ROM bytes).
- The project's concrete secret-store, env-var names, and config-discovery order.
- Platform quirks unique to one tool (e.g. a specific capture-driver init delay or loopback failure mode).
- The exact contents and line-count of that project's security-audit checklist document.

## Sources

- `/home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md` (Security Requirements: input validation, privilege drop, packet parsing, DoS prevention, audit)
- `/home/parobek/Code/OSS_Public-Projects/VeridianOS/CLAUDE.md` (capability tokens, least privilege, IPC rate limiting)
- `/home/parobek/Code/OSS_Public-Projects/SPECTRE/CLAUDE.md` (threat model, encryption, operational security, multi-platform test scripts)
- `/home/parobek/Code/Commercial_Private-Projects/PhantomProtocol/docs/GEMINI.md` (periodic source audits)
- `/home/parobek/.claude/CLAUDE.md` (security-conscious defaults, env vars, no sensitive info in errors)
