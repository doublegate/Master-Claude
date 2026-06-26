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

## Enhancements backlog (recommendations) — DONE
- [x] **`/mem-synthesize`** — `commands/mem-synthesize.md` + `bin/mc-mem-scan.sh` surface
      cross-project promotion candidates (recurring slugs + `scope: universal`) for review.
- [x] **`mc-doctor` as a pre-commit / CI check** — `bin/mc-selfcheck.sh` runs in CI (self-host
      gate); `templates/pre-commit` runs `mc-doctor` before commit.
- [x] **Versioned `master-core`** — `master-core/VERSION`; `mc-install` stamps it, `mc-sync`
      reports the delta, `mc-doctor` flags drift.
- [x] **Tri-agent memory bridge** — `bin/mc-mem-bridge.sh` builds a `memory-core/` digest into
      `~/.codex` / `~/.gemini` (dry-run by default).
- [x] **`mc-install --modules <list>`** — install a curated subset (e.g. `--modules 10,30,60`).
- [x] **A workspace-wide `mc-doctor` sweep** — `bin/mc-doctor-all.sh` audits every managed project.
- [x] **Self-host CI** — `bin/mc-selfcheck.sh` validates symlinks/sizes/VERSION/frontmatter in CI.

## Decided (Phase-1 carryover)
- Keep concise illustrative examples in modules (don't strip further); use `--modules` for
  size-sensitive installs. Aggressive stripping trades clarity/adherence for marginal context
  savings the modules don't need (all are well under 200 lines).

## Decision log
- Distribution: installer + symlinks + `@import` (chosen with user).
- Existing files: additive only this effort; retrofit is dry-run until explicitly applied.
- Agents: all three, Claude-primary.
