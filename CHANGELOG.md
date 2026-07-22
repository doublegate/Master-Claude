# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Enforcement layer (Phase 5)** — `guards/` + `bin/mc-guard.sh`. Master-Claude previously
  distributed only instructions, which a model may or may not follow. These are enforced by the
  harness itself: a `permissions.deny` rule set plus `PreToolUse` hooks that block destructive
  commands regardless of what the agent decides. `mc-guard.sh install|verify|audit|uninstall`
  merges into `~/.claude/settings.json` (backs up first, preserves foreign hooks, idempotent).
- **Dirty-aware git guard** — `guards/guard-bash.sh` blocks `git checkout <path>`, `restore`,
  `reset --hard`, `clean -f`, and bare `stash` **only when the target has uncommitted changes**.
  A static deny rule cannot make this distinction: those commands are legitimate on a clean tree
  and destroy unrecoverable work on a dirty one. Also blocks `sed -i`/`perl -i`, `sudo`,
  recursive removal of a home/workspace root, and recursive `chown` on the NTFS mount. Parses
  compound commands, wrappers, and env prefixes so the checks cannot be trivially evaded.
- **`guards/guard-write.sh`** — blocks Write/Edit to `.git` internals, `~/.ssh`, `/etc`, `.env`,
  and Claude Code settings files.
- **`bin/mc-guard.sh audit`** — read-only permission-surface audit across every project's
  `.claude/settings*.json`, flagging bare tool names in `allow` (which match every use of a tool)
  and indirection rules whose payload lives in a repo-editable file (`Bash(npm run *)` runs
  whatever `package.json` defines; `cargo test` compiles and runs `build.rs`).
- **Security-review rule files** — `guards/claude-security-guidance.md` and
  `guards/security-patterns.json` for the `security-guidance` plugin, derived from modules 60
  and 50; symlinked into `~/.claude/` by `mc-guard.sh install`.
- **Tiered subagents** — `agents/scout.md` (Haiku, read-only locator), `agents/sweeper.md`
  (Sonnet, fully-specified mechanical edits), `agents/verifier.md` (Sonnet, runs quality gates
  and reports verbatim). `bin/mc-commands.sh --agents` registers them.
- **Module 91 — Agent & Assistant System Architecture** (`master-core/modules/` +
  `docs/knowledge/`): five-layer split, tool-contract boundary, memory tiers with explicit
  read-after-write visibility, routing lanes, observability, and a failure-mode table. For
  projects where an LLM is a component rather than the deliverable.
- **Versioned core**: `master-core/VERSION`; `mc-install` stamps `<!-- mc-core: … -->` into the
  generated `AGENTS.md`; `mc-sync` reports the version delta and `mc-doctor` flags drift.
- **`mc-install --modules <list>`**: install only selected modules (e.g. `--modules 10,30,60`)
  to slim size-sensitive `--inline` projects.
- **`/mem-synthesize`** + `bin/mc-mem-scan.sh`: surface cross-project memory-promotion candidates
  (same fact in ≥N projects, or `scope: universal`) not yet in `memory-core/`.
- **`bin/mc-doctor-all.sh`**: audit every managed project under a workspace root in one command.
- **`bin/mc-selfcheck.sh`**: validate this repo's own invariants (symlinks, sizes, VERSION,
  memory frontmatter, doc/module alignment); wired into CI as the self-host gate.
- **`bin/mc-mem-bridge.sh`**: build a digest of `memory-core/` into the Codex/Gemini homes so
  all three agents can share the curated facts (dry-run by default).
- **Pre-commit hook template** (`templates/pre-commit`) running `mc-doctor` before commit.
- **CodeQL** workflow (`.github/workflows/codeql.yml`, `language: actions`) scanning the
  GitHub Actions workflows for script injection, missing permissions, and unvalidated inputs.
- **actionlint** workflow linting added to CI.
- **Claude PR reviewer**: the official Anthropic GitHub workflows
  (`.github/workflows/claude-code-review.yml` for automatic PR review +
  `.github/workflows/claude.yml` for `@claude` mentions), installed via `/install-github-app`
  and wired to the `CLAUDE_CODE_OAUTH_TOKEN` secret. (Replaces an earlier custom
  `.github/workflows/claude-review.yml` stub, removed as redundant.)
- **Dependabot** (`.github/dependabot.yml`) for the GitHub Actions ecosystem, keeping the
  SHA/digest-pinned third-party actions current.

### Changed

- `master-core/VERSION` 0.1.0 -> 0.2.0 (additive: new module + new tooling, no behavior removed).
- `master-core/AGENTS.base.md`: added a **Delegation** section (match the model to the work;
  delegate down to scout/sweeper/verifier) and a note that some rules are enforced by the
  harness, so a denial is a correct outcome rather than an obstacle to route around.
- `bin/mc-commands.sh`: now registers either `commands/` or `agents/` (`--agents`, `--commands`).
- `bin/mc-doctor.sh`: reports whether the enforcement layer is installed.
- `bin/mc-selfcheck.sh`: asserts guards are executable and the guard rule files parse.
- CI shellcheck now covers `guards/*.sh` alongside `bin/*.sh` and `test/run.sh`.
- **Markdown lint gate** — `.markdownlint.json` plus a version-pinned `markdownlint-cli2@0.22.0`
  CI step. Config records a rationale per exemption: `MD013` (line-length), `MD033` (inline
  HTML — the managed-block markers are HTML comments by design), `MD060` (hand-aligned tables)
  and `MD041` are disabled per module 40's rule about linters that fight legitimate technical
  formatting; `MD024` is scoped `siblings_only` for Keep a Changelog's repeated section
  headings. That took 1220 raw findings to 148 real ones, all now fixed: 137 auto-fixed
  (blanks around headings/lists/tables/fences), 7 emphasis-as-heading converted to real `###`
  headings in the pattern library, 4 code fences given a `text` language. Repo is at 0 errors
  across 70 files.
- `guard-bash.sh`: quote the separator inside `${_target%%"$NL"*}` (SC2295) — an unquoted
  expansion there is treated as a pattern.
- **Dependency refresh** (full audit of every pinned ref; this repo has no package manifests,
  so its dependencies are the workflow pins and the linter pin):
  - `anthropics/claude-code-action` `52113681` -> `fa7e2f0a` (the current `v1`; Claude Code
    2.1.193 -> 2.1.217, Agent SDK 0.3.193 -> 0.3.217), in `claude.yml` and
    `claude-code-review.yml`. Resolved by dereferencing the **annotated tag object** to its
    commit — `git/ref/tags/v1` returns the tag object's own SHA, which is not a commit and
    would have been an invalid pin.
  - `markdownlint-cli2` 0.22.0 -> 0.23.1 (markdownlint 0.41.1); verified the repo still
    reports 0 issues under the newer engine before pinning it.
  - `actions/checkout@v7`, `github/codeql-action@v4`, and `rhysd/actionlint`
    `1.7.12@sha256:b1934ee5…` verified already current and left unchanged. The actionlint
    digest was confirmed against the tag's **manifest-list** digest — `docker manifest
    inspect … .manifests[0].digest` returns a per-platform digest instead and falsely
    suggests the pin has drifted.
- `test/run.sh`: five new groups (13-17) covering dirty-vs-clean git behavior, in-place/sudo/
  evasion paths, guard-write protected paths, install idempotency with a foreign hook present,
  and clean uninstall.
- Completeness-critic pass over `master-core/modules/`: consolidated cross-module duplication.
  Module 20's *Golden vectors* and *Exactness honesty* rules are now the canonical home (module 90
  references them), and the "migrate stable decisions" rule moved to module 80 (removed the
  duplicate from module 40).

### Security

- `release.yml`: pass the `workflow_dispatch` tag input, event name, and resolved tag via
  `env:` instead of interpolating `${{ ... }}` directly into shell `run:` blocks. This closes
  the Actions script-injection vector (the prior charset validation ran *after* interpolation).
- Pin the installed Claude workflows (`claude.yml`, `claude-code-review.yml`) to match repo
  policy: `anthropics/claude-code-action` to an immutable commit SHA and `actions/checkout`
  aligned to `@v7`.

## [0.1.1] - 2026-06-25

### Fixed

- `release.yml`: normalize the `workflow_dispatch` `tag` input — strip a pasted
  `refs/tags/` prefix and validate the `v*` format — so manual releases don't fail on the
  common GitHub UI paste pattern.

### Changed

- `CHANGELOG.md`: attribute the release-workflow and README-badge entries to `[0.1.0]`
  (they shipped in the `v0.1.0` tag) instead of `[Unreleased]`.

## [0.1.0] - 2026-06-25

Initial release: the curated, project-agnostic synthesis of cross-project AI-agent knowledge,
plus the tooling to install and sync it into any project.

### Added

- **Knowledge base** (`docs/`): the 16 competency areas synthesized into `docs/knowledge/`,
  and the system's own design in `docs/architecture/` (distribution model, memory architecture,
  tri-agent interop).
- **Distributable core** (`master-core/`): `AGENTS.base.md` universal base, 10 topic modules,
  and 4 language overlays (rust/python/typescript/generic) — each curated under 200 lines.
- **Memory core** (`memory-core/`): generalized cross-project facts in frontmatter schema v2
  (`scope`/`lastVerified`/`tags`) with a project-to-shared promotion model.
- **Tooling** (`bin/`, POSIX sh): `mc-apply`/`mc-apply-all` smart orchestrators, `mc-install`
  (single-source `AGENTS.md` + `CLAUDE.md`/`GEMINI.md` symlinks; `--import`/`--inline`; seed +
  `--trim` for retrofits), `mc-sync`, `mc-doctor`, `mc-promote`, `mc-retrofit` (dry-run),
  `mc-commands` (register slash commands).
- **Commands** (`commands/`): `/mc-setup`, `/mc-setup-all`, `/mc-curate`, plus sprint-lifecycle,
  `ci-debug`, `bench-compare`, `security-audit`, `mem-promote`.
- **Templates**: project-block scaffold and a `CLAUDE.local.md` session-state template.
- **Verification**: `test/run.sh` self-test harness (18 sandboxed assertions) and a GitHub
  Actions workflow running shellcheck, the self-tests, and a <200-line curation guard.
- **Release packaging**: `.github/workflows/release.yml` builds a `master-claude-<tag>.tar.gz`
  distributable (+ sha256) and publishes a GitHub Release on `v*` tags (uses checked-in
  `docs/releases/<tag>.md` notes when present, falls back to auto-generated notes otherwise).
- **README**: CI/release/license/POSIX badges and a contributing/license footer.

[Unreleased]: https://github.com/doublegate/Master-Claude/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/doublegate/Master-Claude/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/doublegate/Master-Claude/releases/tag/v0.1.0
