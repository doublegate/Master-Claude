# Phase 3 — Retrofit (dry-run)

Opt-in migration path for the ~126 existing agent files. **Status: DRY-RUN COMPLETE.**

- [x] `bin/mc-retrofit.sh --dry-run <project>` — prints the plan (what it would back up,
      regenerate, symlink) + a duplicate-content scan; **writes nothing**.
- [x] `--apply` intentionally refused (this effort ships dry-run only).
- [x] Refuses to run without `--dry-run`.
- [x] Verified against a real project (ProRT-IP): `git status` unchanged before/after.

## When you choose to actually retrofit (future, opt-in, per project)
- [ ] Validate dry-run output across Rust / TS / Python / multi-lang representatives.
- [ ] Implement `--apply` (gated, interactive confirm) once the dry-run output is trusted.
- [ ] Retrofit in small batches; run `mc-doctor.sh` after each; keep `*.mc-bak` until verified.
- [ ] Trim duplicated universal rules from project files, leaving them to the shared core.

Next: Phase 4 (`04-PHASE-4-MAINTENANCE.md`).
