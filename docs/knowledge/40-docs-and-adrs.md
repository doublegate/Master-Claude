# 40 — Documentation-as-Spec, ADRs, CHANGELOG & ROADMAP

## Why it matters

Docs that lag code are worse than no docs: they actively mislead. Treating
the prose as the *specification* — and updating it in the same commit as the
behavior — keeps the description and the implementation from drifting apart.
A small, disciplined documentation surface (subsystem specs, ADRs, a single
CHANGELOG, a planning ROADMAP, and an immutable reference corpus) gives every
contributor and every agent one authoritative answer to "what is true now"
versus "why we decided this" versus "what is planned."

## Patterns

**Subsystem docs are the spec, not a history log — update them in the SAME
change as the code.** Each subsystem gets one living spec file describing
current behavior. When the code and its spec disagree, that is a bug to fix,
not a footnote. Pair the rule with an enforcement hook so it cannot be skipped.
*Example:* a behavior change to a component touches both the component source
and `docs/<subsystem>.md` in one reviewed change; reviewers reject a behavior
diff that leaves the matching spec untouched.

**When an executable oracle and the prose disagree, the oracle wins and the
prose is corrected.** If a test, golden output, or conformance suite contradicts
the doc, treat the passing artifact as the closed-form definition of correct and
rewrite the doc to match — never the reverse.

**One designated file is the single source of truth for status.** Pick one
`STATUS.md` (or equivalent) that carries the authoritative current-state matrix:
per-suite pass counts, coverage, feature/capability tiers, version policy.
Narrative summaries elsewhere (README intros, top-of-file blurbs) are allowed to
lag; they must point at the status file as canonical. *Example:* a CLAUDE.md
preamble explicitly notes "the summary above predates the latest line — STATUS.md
is the authoritative current-release record."

**ADRs capture decisions in Michael Nygard format: Context, Decision,
Consequences.** Store them numbered under `docs/adr/`. Each ADR records *why*
a choice was made and what it costs — rationale, not changelog. Never rewrite a
superseded ADR in place; add a new ADR that supersedes it and cross-link.
*Example:* a decision to defer a costly refactor lands as a dated ADR whose
Consequences section enumerates the residual issues that decision leaves open;
later docs reference that ADR number instead of re-arguing the tradeoff.

**CHANGELOG.md is the single source of truth for user-visible change, written
in the same PR as the change.** Maintain a `[Unreleased]` section; every PR that
alters user-facing behavior adds its entry there, enforced by a contribution
quality gate. At release time `[Unreleased]` is renamed to the version. Keep deep
engineering narrative (audit logs, lineage) out of the CHANGELOG — it tracks what
shipped, not how it was built.

**README carries the platform matrix, quick-start, and an architecture sketch —
nothing that duplicates the living specs.** It is the front door: what the
project is, which platforms/toolchains are supported, how to build/run in under a
minute, and a one-paragraph architecture orientation that links deeper. Keep it
fresh as a release task; let it point to STATUS and subsystem docs rather than
restating them.

**ROADMAP.md is the planning entry point and assigns stable ticket IDs.** Future
work lives in the roadmap (and its phase/sprint files), each item keyed by a
stable, citable ID so commits and PRs can reference it by name across its whole
lifecycle. The roadmap frames the release line and the path to the next major
milestone; it is the first file to read when asking "what is planned."

**Reference docs are immutable; updates go in dated supplements.** A research /
hardware / external-spec corpus (`ref-docs/` or similar) is frozen source
material. Never rewrite it in place — corrections and new findings land as new
dated supplemental files, preserving the original as a stable citation. Mark such
trees exempt from linters and reformatters so tooling does not churn them.

## Language specifics

- Rust: build docs under `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` in CI
  so doc examples and intra-doc links stay correct. Avoid intra-doc links to
  feature-gated dependencies in default doc builds — use plain code spans for
  names that only resolve under a non-default feature.
- Markdown: pin the markdown linter version in the pre-commit/CI gate; a newer
  local binary may report rules the pinned version lacks. Keep an ignore file for
  immutable/vendored trees, and disable rules that fight legitimate long
  technical tables or HTML banners by design.

## Project-bound — do NOT generalize

- Exact file numbering schemes (e.g. `00-ARCHITECTURE`, `10-PROJECT-STATUS`),
  specific subsystem filenames, ADR numbers, and the "quick-start reading order"
  are per-project conventions — adopt the *shape*, not the literal names.
- The choice of which file is "single source of truth" (STATUS vs README vs a
  Notion mirror) is project-specific; some projects mirror status into an external
  knowledge base and must keep both in sync.
- Domain rules like "never commit commercial ROMs" or a specific license choice
  are project policy, not portable doc practice.

## Sources

- /home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/AGENTS.md
- /home/parobek/Code/OSS_Public-Projects/AirGapSync/docs/PROJECT-STATUS.md
