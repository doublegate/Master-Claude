# Phase 4 — Maintenance + Enhancements

Keep the system alive and improve it. **Status: ONGOING.**

## The keep-it-alive loop
- [ ] When a lesson generalizes (hits a 2nd project), run `/mem-promote` to lift it to
      `memory-core/`, then curate.
- [ ] When a `master-core/` module changes, run `bin/mc-sync.sh` on installed projects (or a
      sweep) so they pick up the update.
- [ ] Periodically run `bin/mc-doctor.sh` across installed projects; fix WARN/FAIL (oversized
      files, broken symlinks, parity gaps).
- [ ] Refresh `lastVerified` on memory facts; retire stale references.
- [ ] Keep every module/doc < ~200 lines (the curation rule); split if they grow.

## Enhancements backlog (recommendations)
- [ ] **`/mem-synthesize`** — periodically scan all project memory dirs and surface
      promotion candidates automatically.
- [ ] **`mc-doctor` as a pre-commit / CI check** — flag instruction files >200 lines,
      missing symlinks, or core drift before they land.
- [ ] **Versioned `master-core`** — semver the distributable core; `mc-sync` reports what changed.
- [ ] **Tri-agent memory bridge** — seed `memory-core/` into `~/.codex` / `~/.gemini` homes so
      Codex/Gemini share the curated facts (today only the instruction file is shared).
- [ ] **`mc-install --modules <list>`** — curated inline subset for size-sensitive projects.
- [ ] **A workspace-wide `mc-doctor` sweep script** — one command to audit every installed project.
- [ ] **Self-host CI** — a check that this repo's own `AGENTS.md` + symlinks stay valid.

## Decision log
- Distribution: installer + symlinks + `@import` (chosen with user).
- Existing files: additive only this effort; retrofit is dry-run until explicitly applied.
- Agents: all three, Claude-primary.
