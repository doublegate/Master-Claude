# 95 — Named Pattern Library

Reusable, project-agnostic named patterns. See `docs/knowledge/95-named-pattern-library.md` for full structure and rationale.

## The discipline
- Give every recurring solution a stable, capitalized Name — a token humans and agents can invoke.
- Record each pattern as: Name — Problem — Solution — Implementation — Evidence/rationale — Applies-to.
- Patterns are mechanisms, not measurements; abstract away hardware limits, chip names, and repo jargon.
- One Name = one definition; add a new Name rather than silently redefining one.
- Deduplicate: merge entries that differ only by domain under the more general Name.
- A pattern without a rationale is just a rule — record the pain it prevents.

## Catalog (Name — when — rule)
- Central-State Ownership — cross-cutting mutable state — give each long-lived state one owner; mutate only through a single controlled, lock-guarded handle.
- Read-Before-Write — modifying any existing artifact — read and understand current content first; edit in place; full-write only for new files.
- Dry-Run-First Destructive Op — bulk/irreversible operations — default to a no-op preview that reports what would change; require explicit opt-in, backup, confirmation, and an audit entry to execute.
- Golden-Vector Parity — behavior that must stay constant across languages/versions — pin to canonical input→output vectors, assert in CI, change a vector only on intentional behavior change.
- Managed-Block Generated-vs-Hand-Authored — codegen/sync into a file with hand-written content — confine machine writes to explicitly marked regions; preserve everything outside.
- Feature-Flag Additive Change — new/risky capability — land it off-by-default so default builds stay behavior-identical; promote only after it proves out; test both paths.
- Context-Aware Validation — systems with multiple valid modes/profiles — detect the current mode first, validate against that mode's expectations, flag only genuine mismatches.
- Progressive-With-Rollback — applying an extreme/risky setting — step toward the target, validate stability at each step, auto-roll-back on failure (abstract the limit; never hardcode it as the pattern).

## Out of scope here (keep in project stub)
- Patterns whose substance is a specific number/limit, chip, OS feature, or package manager.
- A local Name for something already covered above — cross-reference instead.
- Exact paths, marker syntax, or vector locations a single repo uses.
