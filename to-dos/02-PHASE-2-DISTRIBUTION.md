# Phase 2 — Distribution Tooling + Shared Commands

**Status: COMPLETE.**

- [x] `bin/mc-install.sh` — slim `AGENTS.md` + `CLAUDE.md`/`GEMINI.md` symlinks; `--import`
      (default) / `--inline`; language auto-detect; managed-block preservation; backups.
- [x] `bin/mc-sync.sh` — re-derive lang+mode, re-run install preserving the project block.
- [x] `bin/mc-doctor.sh` — audit (canonical file, symlink integrity, size, core link, parity gap).
- [x] `bin/mc-promote.sh` — project memory fact -> `memory-core/` (schema v2 + MEMORY hook).
- [x] Seed-from-existing: install migrates an existing CLAUDE.md/AGENTS.md/GEMINI.md body into
      the project block (not just backed up). `--trim` HTML-comments likely duplicates (lossless).
- [x] `commands/` — `sprint-start`, `sprint-complete`, `ci-debug`, `bench-compare`,
      `security-audit`, `mem-promote`, `mc-curate` (semantic block de-dup).
- [x] Tested in sandbox: install, symlink integrity, idempotent sync, inline parity, doctor 0/0.
- [x] `shellcheck` clean across all `bin/*.sh`.

## Carryover (optional)
- [ ] `--inline` currently bakes all modules (~490 lines); add `--modules <list>` to inline a
      curated subset for size-sensitive projects.
- [ ] Optional `.codex`/`.gemini` pointer-file generation for discoverability.

Next: Phase 3 (`03-PHASE-3-RETROFIT.md`).
