# Architecture — Distribution Model

How the shared core reaches a project and stays in sync.

## The single-source + symlink pattern

Per project, one canonical file holds the instructions: **`AGENTS.md`**. The other two agent
filenames are symlinks to it:

```
project/
  AGENTS.md            # canonical (slim, <200 lines)
  CLAUDE.md  -> AGENTS.md
  GEMINI.md  -> AGENTS.md
```

This is the accepted 2026 cross-tool convention: `AGENTS.md` is the Linux-Foundation-stewarded
standard read by 28+ tools; Claude reads `CLAUDE.md`, Gemini reads `GEMINI.md`; all three hit
the same bytes. Git tracks symlinks natively, so a clone/pull reproduces the setup with no
extra steps.

## The shared core lives in `~/.claude/master-core/`

`mc-install` ensures `~/.claude/master-core/` exists, pointing at this repo's `master-core/`
(symlink for a single-machine author = live edits; or a copied snapshot for stability). A
project's `AGENTS.md` references the shared modules from there.

## The generated `AGENTS.md`

```
AGENTS.base.md  (universal, always-inline)
      +
lang/<rust|python|typescript|generic>.md   (concrete commands)
      +
<<< MC-PROJECT-START >>>                    (managed-block markers)
   project-specific: build/test cmds, arch facts, gotchas
<<< MC-PROJECT-END >>>
```

The block markers separate **generated** content (re-synced safely) from **hand-authored**
project content (never overwritten). `mc-sync` only rewrites outside the markers.

### Seeding the block from an existing file (retrofit)

When a project already has a real `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` but no managed block,
`mc-install` **seeds** the project block from that file's body (precedence: `CLAUDE.md` →
`AGENTS.md` → `GEMINI.md`), stripping `@import`/marker lines and adding a banner. The original
is still backed up to `*.mc-bak`, but its project-specific content is **migrated**, not just
archived. This is what makes a retrofit a single command on projects with rich existing files.

De-duplicating the seeded block against the core is two-tier:

- `--trim` (deterministic) — HTML-comments lines matching known universal-rule patterns as
  `<!-- dup? ... -->`. Lossless and reversible; it flags, never deletes.
- `/mc-curate` (semantic) — an LLM pass that judges true duplication vs project-specific
  refinement and rewrites only the block. This is where real curation happens; pattern-matching
  alone can't tell "run clippy" (generic) from "clippy must pass with feature X" (project rule).

## `--import` vs `--inline` (the `@import` nuance)

`@import` is **Claude-specific** — Codex and Gemini do not expand it. Two install modes
resolve this:

| Mode | What happens | Use when |
|---|---|---|
| `--import` (default) | Always-apply rules inline in `AGENTS.md`; heavy modules referenced as `@~/.claude/master-core/modules/*.md`. Slimmest file. | Claude is the primary/only agent on the project. |
| `--inline` | Selected modules are baked into `AGENTS.md` so all three agents read identical content. Larger file. | Codex/Gemini are actively used on the project. |

Both keep the file as small as the goal allows; `--import` leans on Claude's loader, `--inline`
trades size for tri-agent parity. `mc-doctor` warns if an `--import` project also has active
`.codex`/`.gemini` usage (parity gap).

## Idempotency & safety

- Re-running `mc-install`/`mc-sync` is a no-op when nothing changed.
- Any pre-existing real `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` is backed up to `*.mc-bak` before
  being replaced by the canonical file or symlink.
- All `bin/` scripts are POSIX `sh`, no bashisms, no heredocs (fish-safe authoring), and print
  exactly what they changed.

## Lifecycle commands

| Command | Purpose |
|---|---|
| `mc-commands.sh [--global\|--project <dir>]` | One-time: register `commands/*.md` into `~/.claude/commands` so the slash commands resolve |
| **`/mc-setup [dir]`** | **One command: detect state, do everything, semantic de-dup, verify** |
| `/mc-setup-all [root]` | Workspace-wide: sweep every project, apply, de-dup the seeded ones |
| `mc-apply-all.sh [root] [--apply] [--exclude n]` | Shell sweep over all projects (dry-run default) |
| `mc-apply.sh <dir> [--inline\|--import] [--no-trim] [--dry-run]` | Smart deterministic orchestrator (state detect → right action → doctor) |
| `mc-install.sh <dir> [--lang x] [--inline\|--import] [--trim] [--modules <list>]` | Low-level: first-time setup / seed an existing file / subset of modules |
| `mc-sync.sh <dir>` | Pull updated core (preserves project block); reports the core version delta |
| `mc-doctor.sh <dir>` | Audit: file size, symlink integrity, version drift, parity gaps |
| `mc-doctor-all.sh [root]` | Audit every managed project under a workspace root |
| `mc-selfcheck.sh` | Validate this repo's own invariants (CI self-host gate) |
| `mc-promote.sh <dir> <slug> --date <d>` | Lift a project lesson into `memory-core/` |
| `/mem-synthesize` · `mc-mem-scan.sh` | Surface cross-project memory-promotion candidates |
| `mc-mem-bridge.sh [--execute]` | Digest `memory-core/` into the Codex/Gemini homes |
| `mc-retrofit.sh --dry-run <dir>` | Show what a migration would change (no writes) |
| `mc-commands.sh [--global]` | Register the slash commands into `~/.claude/commands` |

### State detection (how `mc-apply` / `/mc-setup` decide)

| Detected state | Trigger | Action | Follow-up |
|---|---|---|---|
| **new** | no real agent file | blank install | fill the stub from README/build files |
| **existing** | real `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` with content, no MC block | seed block + `--trim` | semantic `/mc-curate` de-dup |
| **managed** | `AGENTS.md` already has the MC block | `mc-sync` (refresh core) | none |

Mode is auto: `--inline` if `.codex`/`.gemini` are present in the project (tri-agent parity),
else `--import`. Override with explicit flags.
