# /mc-setup-all — set up Master-Claude across the whole workspace

Workspace-wide version of `/mc-setup`. Sweeps every project under a root, applies the core to
each, and performs the semantic de-dup on the ones that were seeded. Big operation — preview first.

## Usage
`/mc-setup-all [root-dir]`  — root defaults to `~/Code`. Add `--inline`/`--import`/`--no-trim`
to force choices, `--exclude <name>` to skip projects.

## Steps (the agent performs these)
1. **Preview:** run `bin/mc-apply-all.sh <root>` (dry-run). Show the table (state + plan per
   project) and the `new=/existing=/managed=` tally. Confirm with the user before changing files
   — this touches many repos.
2. **Apply:** on confirmation, run `bin/mc-apply-all.sh <root> --apply`. Each project is installed
   per its state (seed+trim / sync / blank); existing files are backed up to `*.mc-bak`.
3. **Curate the seeded ones:** for each project the sweep lists under "Semantic de-dup still
   recommended", do the `/mc-curate` pass (de-dup its seeded block against the core), then
   `bin/mc-doctor.sh` it. Work through them one at a time; report progress.
4. **Summary:** projects touched, per-state counts, any doctor failures, and which still need
   manual attention.

## Safety
- Default is preview/dry-run; nothing changes until the user confirms `--apply`.
- Every modified file is backed up to `*.mc-bak`; the shared core is never touched.
- Skips known non-project working dirs and Master-Claude itself by default.
- Consider committing each repo (or running on a clean tree) before `--apply` so changes are easy
  to review/revert. See `docs/architecture/distribution-model.md`.
