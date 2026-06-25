# 60 — Security & Input Validation

Project-agnostic security rules. Imperative, decision-based. See `docs/knowledge/60-security.md` for rationale.

## Input validation
- Validate ALL external input at the boundary; trust only the parsed, typed value inward.
- Prefer allowlists over denylists; enumerate what is permitted.
- Parse-don't-validate: convert raw bytes/strings to a range-checked type once, at the edge.
- Bounds-check every length/offset/tag read from untrusted bytes before use.
- Return `Result`/`Option`/error-union on malformed input; never `unwrap`/`panic` on external data.
- Reject unsupported inputs explicitly; never stub an unimplemented path as if it worked.

## Privilege
- Acquire elevated privilege only for the operation that needs it.
- Drop privileges immediately afterward; minimize the privileged-and-parsing window.
- Process untrusted input only in an unprivileged context.
- Prefer least-privilege capability tokens over ambient/global authority.
- Make capability tokens unforgeable and revocable (generation/version marker).

## DoS prevention
- Bound concurrency with a semaphore; cap in-flight operations.
- Throttle issuance with a token-bucket rate limiter; allow a small burst.
- Stream large I/O to disk; never buffer unbounded data in memory.
- Use adaptive limits that stay responsive while bounding worst case.

## Secrets & errors
- Load secrets from environment/secret store; never hardcode; never commit.
- Keep secrets, keys, tokens, and internal detail out of logs and error messages.
- Error messages state what failed plus a correlation ID, not sensitive values.

## Hardening & release gates
- Fuzz every parser that ingests untrusted input; goal = no input crashes it.
- Run a fixed security-audit checklist before each release.
- Run dependency vulnerability audits on a recurring cadence, not once.
- Test security/offensive tooling on every supported platform; document expected differences.
- Require explicit confirmation for destructive/high-blast-radius operations.
- Write an audit-log entry (who/what/when/scope) before performing dangerous actions.

## Out of scope here (keep in project stub)
- Exact burst sizes, concurrency caps, timeouts, zero-copy thresholds.
- The concrete privilege/capability model and elevation-requiring syscalls.
- Project-specific "never commit X" rules and env-var/secret-store names.
- Single-tool platform quirks.
