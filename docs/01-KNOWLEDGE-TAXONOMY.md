# 01 — Knowledge Taxonomy

The synthesized knowledge organizes into **16 competency areas**, clustered into the
`docs/knowledge/` documents and `master-core/modules/` modules below. Each area was derived by
sampling the corpus across languages and project categories (Rust, TS/JS, Python, multi-lang;
OSS / Commercial / Local / Forks / Clones).

## Source corpus (what was mined)

| Source | Count | Primary yield |
|---|---|---|
| `CLAUDE.md` | 97 | architecture, conventions, workflow narrative |
| `AGENTS.md` | 13 | lean operational command sets |
| `GEMINI.md` | 16 | CLAUDE.md-variant content |
| `CLAUDE.local.md` | 23 | session-state **format** (→ template) |
| `~/.claude/projects/*/memory/` | 18 dirs / 165 facts | user prefs, feedback, references |
| `*/.claude/commands/*.md` | 63 / 6 projects | 5 canonical workflows |
| `~/.claude/` global | 48 cmds, 34 skills | already-shared assets |

## The 16 areas → cluster mapping

| # | Competency area | Doc / module cluster | Generalizable |
|---|---|---|---|
| 1 | Commits & semantic versioning | `10-commits-and-versioning` | High |
| 2 | Test-driven accuracy (test-as-spec, golden vectors, determinism) | `20-testing-and-accuracy` | High |
| 3 | Quality gates (fmt/lint/coverage/fuzz CI) | `30-quality-gates` | High |
| 4 | Docs-as-spec + ADRs + CHANGELOG/ROADMAP | `40-docs-and-adrs` | High |
| 5 | Architecture by ownership (bus/scheduler, traits, one-way deps) | `50-architecture-patterns` | High |
| 6 | Security & input validation | `60-security` | High |
| 7 | Release ceremony (tag/notes/packaging matrix/staged rollout) | `70-release-ceremony` | High |
| 8 | Phase/sprint workflow (roadmaps, ticket IDs, lifecycle) | `80-phase-sprint-workflow` | High |
| 9 | Multi-language integration (shared contracts, FFI, parity) | `90-multi-language-integration` | Medium-High |
| 10 | Named pattern library (GlobalState, Transaction, Boot-opt …) | `95-named-pattern-library` | Medium |
| 11 | Git workflow (branching, no force-push, pre-commit) | folded into `10` | High |
| 12 | Multi-platform CI/CD (matrix, Docker, cross-compile) | folded into `30`/`70` | High |
| 13 | Profile-first performance | folded into `30`/`50` | High |
| 14 | Session-metadata tracking (`CLAUDE.local.md` template) | `templates/` + `40` | High (as format) |
| 15 | Database patterns (WAL, type-safe queries, migrations) | folded into `50` | Medium |
| 16 | Error handling (Result/Option, no-unwrap on untrusted) | folded into `60`/`50` | High |

> Areas 11–16 are real and recurring but cluster naturally under the primary nine docs to keep
> each module tight; the table records where each lives so nothing is lost.

## Generalizable vs project-bound (the curation rule)

**Keep (generalize):** workflow patterns, quality gates, architecture archetypes, doc
structure, release ceremony, security practices, language-agnostic command shapes.

**Drop (project-bound — stays in each project's stub):** hardware-specific tuning, exact tool
flags (QEMU `-enable-kvm`, Npcap init), file/LOC/test counts, performance baselines, feature
lists, domain nomenclature, institutional one-off knowledge.

## Language overlays

Language-specific *invocations* of the universal patterns live in `master-core/lang/`:
`rust.md` (cargo fmt/clippy/test/bench), `python.md` (ruff/pytest/venv), `typescript.md`
(eslint/vitest/pnpm), `generic.md` (fallback). The universal rule is stated once in a module;
the overlay supplies the concrete command.
