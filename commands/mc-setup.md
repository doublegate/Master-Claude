# /mc-setup — one command to fully set up Master-Claude in a project

The single entry point. Detects whether the project is new, existing, or already managed, does
everything safe and necessary, and performs the semantic follow-up itself. You type one thing.

## Usage
`/mc-setup [project-dir]`  — defaults to the current project. Add `--inline` / `--import` /
`--no-trim` to override the auto choices; add `--dry-run` to preview only.

## Steps (the agent performs these automatically)
1. Run `bin/mc-apply.sh <project-dir>` (pass through any flags). It will:
   - detect state (new / existing-unmanaged / already-managed),
   - pick `--inline` if `.codex`/`.gemini` are present, else `--import`,
   - seed + `--trim` an existing file, or `mc-sync` a managed one, or blank-install a new one,
   - run `mc-doctor` and print a final `MC-NEXT:` line.
2. Read the `MC-NEXT:` signal and continue without asking the user to run anything else:
   - **`MC-NEXT: curate`** — do the semantic de-dup now (the `/mc-curate` logic): read the
     seeded `AGENTS.md` block and the imported/inlined core, delete true duplicates (including
     confirmed `<!-- dup? ... -->` lines), keep project-specific content and refinements, and
     rewrite only the block. Then re-run `bin/mc-doctor.sh`.
   - **`MC-NEXT: fill-stub`** — populate the blank project block from what is safely inferable
     (README, `Cargo.toml`/`package.json`/`pyproject.toml`, build/CI files): stack, build/test
     commands, where-things-live. Confirm before asserting architecture facts you cannot verify.
   - **`MC-NEXT: none`** — already up to date; stop.
3. Report the final state in one short summary: state detected, what was done, doctor result,
   final `AGENTS.md` line count. Do not commit unless asked.

## Safety
Everything `mc-apply` calls backs up existing files to `*.mc-bak`, is idempotent, and never
touches the shared core. Use `--dry-run` first if you want a preview. See
`docs/architecture/distribution-model.md`.
