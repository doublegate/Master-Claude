# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
