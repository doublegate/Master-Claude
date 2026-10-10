# Security guidance

Additional review context for the `security-guidance` plugin's model-backed reviews
(end-of-turn diff review and commit/push review). Derived from `master-core/modules/60-security.md`
and the safety rules in `master-core/modules/50-architecture-patterns.md`.

Installed at `~/.claude/claude-security-guidance.md` (user scope, applies to every project).
Additive only: the plugin's built-in vulnerability checklist still applies, and a rule here
cannot suppress a built-in finding.

## Input validation

- Every value crossing a trust boundary must be validated at that boundary and converted once
  to a range-checked type. Downstream code may trust only the parsed, typed value.
- Prefer allowlists over denylists. Enumerate what is permitted, reject the rest explicitly.
- Bounds-check every length, offset, index, and tag read from untrusted bytes before use.
- Flag any `unwrap`, `expect`, `panic!`, `assert!`, non-null assertion, or bare index on a value
  that originated outside the process. Malformed input must produce a typed error, not a panic.
- Flag an unimplemented or unsupported branch that returns a success-shaped value. Reject
  explicitly instead of stubbing a path as though it worked.

## Secrets

- Secrets, keys, and tokens come from the environment or a secret store. Flag any literal that
  looks like a credential, including in tests, fixtures, and example configuration.
- Flag any secret, key, token, raw credential, or full request body reaching a log line, an
  error message, a panic message, or a serialized error response. Errors state what failed plus
  a correlation ID.
- Flag a new or modified `.env`, `.envrc`, or credential file in the diff.

## Privilege and blast radius

- Elevated privilege is acquired for the single operation that needs it and dropped immediately
  after. Flag any widening of the privileged window, especially one that spans parsing of
  untrusted input.
- Untrusted input is parsed in an unprivileged context.
- Prefer unforgeable, revocable capability tokens over ambient or global authority.
- Destructive or high-blast-radius operations require explicit confirmation and an audit-log
  entry (who, what, when, scope) written *before* the action.

## Resource exhaustion

- Concurrency is bounded by a semaphore; issuance is throttled by a token bucket.
- Large I/O is streamed to disk. Flag unbounded buffering of caller-controlled data in memory.
- Flag an unbounded loop, retry, or recursion whose termination depends on untrusted input.

## Unsafe and FFI

- Every `unsafe` block, FFI call, and raw pointer dereference carries a `// SAFETY:` comment
  stating the invariant relied on and who guarantees it (pointer validity, length, lifetime,
  null-termination). Flag any that does not.
- Vendored native libraries stay behind a single explicit shim layer.

## Data access

- Queries use an ORM, query builder, or parameterized statements. Flag any SQL, shell command,
  or path assembled by string concatenation or interpolation of caller-controlled data.
- Flag a path built from untrusted input without traversal normalization.
- Flag a multi-tenant query that does not filter by tenant or owner.

## What is out of scope here

Style, naming, formatting, performance, and test coverage. Report security defects only.
