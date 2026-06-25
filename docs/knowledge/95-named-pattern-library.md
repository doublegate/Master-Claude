# 95 — Named Pattern Library

## Why it matters

A recurring solution that has no name gets re-derived (slightly differently) every time it is needed, and re-argued in every review. Giving a pattern a stable Name turns a paragraph of reasoning into a single token both humans and agents can invoke: "use Read-Before-Write here," "this is a Golden-Vector Parity case." The value is not the prose — it is the shared vocabulary plus a fixed structure so each pattern records its *rationale* (why it earned a name) alongside the rule. This file defines the naming discipline and seeds it with a handful of generalized, project-agnostic exemplars distilled from the corpus. Projects extend the library; they do not rewrite the discipline.

## The named-pattern discipline

Every entry uses the same five-part structure. Keep each part to a few lines — a named pattern is a reference card, not an essay.

- **Name** — short, memorable, capitalized (a noun phrase). The token people will actually say.
- **Problem** — the recurring situation/failure mode that triggers the pattern.
- **Solution** — the rule, stated imperatively in one or two sentences.
- **Implementation** — how it is typically realized, abstractly (no project-specific numbers).
- **Evidence / rationale** — *why* this earned a name: the concrete pain it prevents, drawn from real incidents.
- **Applies-to** — when to reach for it (and, where useful, when not to).

Rules for the library itself:
- One pattern = one stable Name. Do not silently redefine an existing Name; add a new one.
- Patterns are **mechanisms**, not measurements. Abstract away hardware-specific limits, exact chip names, and repo-specific jargon — a clamp value is project-bound; "validate a limit before applying an extreme setting, step toward it, roll back on failure" is the pattern.
- Deduplicate aggressively. If two entries differ only in domain, merge them under the more general Name.
- A pattern without a rationale is just a rule — record the pain it prevents.

## Exemplar patterns

**Central-State Ownership**
- *Problem*: shared mutable state reached from many places produces aliasing bugs, race conditions, and unclear ownership.
- *Solution*: give each piece of long-lived state a single owner accessed through one explicit, controlled handle; mutate only through that handle.
- *Implementation*: a global/once-initialized holder exposing `with(|state| …)`-style scoped access; mutation guarded by a lock inside the holder; ad-hoc globals eliminated, with each justified exception documented.
- *Evidence*: codebases that replaced scattered mutable globals with a single owned accessor eliminated whole classes of init-order and data-race bugs; the few remaining exceptions are explicitly justified and annotated.
- *Applies-to*: any cross-cutting state (managers, registries, caches). Not needed for short-lived local values.

**Read-Before-Write**
- *Problem*: blind writes overwrite content the author had not seen, destroying structure or concurrent edits.
- *Solution*: always read and understand a file/resource's current content before modifying it; edit in place rather than overwrite.
- *Implementation*: Read → analyze structure → plan change → apply a targeted edit; reserve full-write for genuinely new files.
- *Evidence*: a mandated, repo-spanning rule precisely because unconditional overwrites repeatedly clobbered existing work; it is the first rule in multiple project guides.
- *Applies-to*: every modification of an existing artifact. Skip only when creating a brand-new file.

**Dry-Run-First Destructive Op**
- *Problem*: operations that touch many files or external state are irreversible if wrong, and "wrong" is discovered only after damage.
- *Solution*: default any destructive/bulk operation to a no-op preview that reports exactly what *would* change; require explicit opt-in (and ideally typed confirmation) to execute.
- *Implementation*: a `--dry-run`-style default plus a backup of anything replaced; high-blast-radius actions demand a confirmation token and an audit-log entry.
- *Evidence*: retrofit/restore tooling defaults to preview, backs up replaced files, and gates execution on explicit confirmation — because a silent bulk mutation across a tree is unrecoverable.
- *Applies-to*: mass edits, restores, migrations, deletes, anything modifying state outside the current repo.

**Golden-Vector Parity**
- *Problem*: behavior that must stay constant (across two language implementations, or across versions) drifts silently, invalidating every downstream result.
- *Solution*: pin the behavior to a canonical set of input→output vectors and assert against them in CI; change a vector only on an *intentional* behavior change.
- *Implementation*: committed golden vectors; a parity/regression test that fails on any divergence; accidental drift treated as a hard failure, not a refresh.
- *Evidence*: accuracy-critical cores enforce Python↔native parity against canonical vectors precisely because undetected drift corrupts results invisibly.
- *Applies-to*: cross-language duplicates, serialization formats, deterministic algorithms. Not for genuinely nondeterministic output.

**Managed-Block Generated-vs-Hand-Authored**
- *Problem*: regenerating or syncing content into a file that also holds hand-written content clobbers the human edits — or hand edits clobber the generated part.
- *Solution*: separate machine-managed regions from hand-authored regions with explicit markers, and only ever rewrite the managed region.
- *Implementation*: clearly delimited managed blocks (or a managed file imported by a hand-owned one); the generator rewrites only inside the markers and preserves everything outside.
- *Evidence*: distribution/install tooling that injects modules into existing config files survives re-runs by confining itself to a managed block, leaving user content intact.
- *Applies-to*: codegen into shared files, config injection, doc sync. Not needed when the whole file is machine-owned.

**Feature-Flag Additive Change**
- *Problem*: new capability risks changing default behavior and breaking existing consumers.
- *Solution*: land new behavior behind an off-by-default flag so default builds stay behavior-identical; promote to default only after it proves out.
- *Implementation*: conditional compilation / runtime flag gating the new path; default path unchanged; both paths tested.
- *Evidence*: additive features shipped off-by-default keep default builds byte-for-byte equivalent, letting a release stay backward-compatible (a MINOR bump, not MAJOR).
- *Applies-to*: new optional capabilities, risky optimizations, platform-specific paths. Not for fixes that must apply universally.

**Context-Aware Validation**
- *Problem*: a validator that assumes one canonical state reports false failures when the system is correctly in a *different* valid mode, eroding trust in the check.
- *Solution*: detect the current operating mode first, then validate against that mode's expected state; flag only genuine mismatches.
- *Implementation*: mode/profile detection → mode-specific expectations → actionable messaging that names the detected mode.
- *Evidence*: optimization suites with multiple profiles eliminated confusing "failures" by making validation profile-aware instead of asserting one global ideal.
- *Applies-to*: systems with multiple legitimate configurations/profiles. Not for invariants that hold in every mode.

## Language specifics

Naming patterns is language-agnostic; the *implementation* mechanics (how a once-initialized owner, a dry-run flag, a feature gate, or a golden-vector test is written) live in `master-core/lang/<lang>.md`.

## Project-bound — do NOT generalize

Keep these in the project's own stub, not here:

- Patterns whose substance is a specific number/limit (overclock clamps, timeouts, buffer sizes) — those are project facts, not reusable mechanisms.
- Patterns naming a specific chip, OS feature, package manager, or domain entity in their core rule.
- A project's local Name for something already covered by a general pattern here (cross-reference instead).
- The exact file paths, marker syntax, or vector locations a single repo uses to realize a pattern.

## Sources

- `/home/parobek/Code/OSS_Public-Projects/Bazzite-Config/CLAUDE.md` (named patterns with explicit problem/solution/rationale: context-aware validation, transaction state, progressive-with-rollback, selective restore)
- `/home/parobek/Code/OSS_Public-Projects/VeridianOS/CLAUDE.md` (GlobalState single-owner pattern, feature-flag/cfg gating, static-mut elimination with justified exceptions)
- `/home/parobek/Code/Local_Only-Projects/mc-seed-finder/CLAUDE.md` (golden-vector parity, exactness flag discipline)
- `/home/parobek/Code/Master-Claude/AGENTS.md` (read-before-write, dry-run-first, managed-block distribution model)
- `/home/parobek/.claude/CLAUDE.md` (read-before-write mandate, additive-feature defaults)
