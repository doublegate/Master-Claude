# /mc-curate — semantically de-duplicate a seeded project block

After `mc-install`/`mc-retrofit` seeds a project's `AGENTS.md` block from its old `CLAUDE.md`,
the block still contains rules that the shared core already covers. The installer's `--trim`
flag can only pattern-match; this command does the real (semantic) judgment.

## Usage
`/mc-curate [project-dir]`  — defaults to the current project.

## Steps
1. Read the project's `AGENTS.md` block (between the `MC-PROJECT` markers) and the shared core
   it imports/inlines (`~/.claude/master-core/AGENTS.base.md` + `modules/*` + `lang/<lang>.md`).
2. For each line/rule in the block, decide:
   - **Duplicate** of a core rule with no project-specific detail -> remove it.
   - **Project-specific** (exact commands, architecture facts, gotchas, version pins, named
     patterns, hardware limits) -> keep, even if it touches a universal topic.
   - **Refinement** of a core rule (project tightens/overrides it) -> keep, and note it overrides.
3. Rewrite ONLY the content between the markers. Never touch the imported core lines, the header,
   or the markers themselves. Preserve any `<!-- dup? ... -->` lines you confirm are true
   duplicates by deleting them; un-comment ones that were project-specific.
4. Show a diff and the final block line count; aim to leave the file lean (<200 lines).
5. Do not commit.

Safety: the original is in `<file>.mc-bak`; nothing is lost. See
`docs/architecture/distribution-model.md`.
