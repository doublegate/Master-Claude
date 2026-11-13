# Architecture — Tri-Agent Interoperability

How one source of truth serves Claude Code, OpenAI Codex, and Google Antigravity CLI
(`agy`, the successor to the deprecated Gemini CLI).

## What each agent reads

| Agent | Instruction file | Memory / config home | Extras |
|---|---|---|---|
| **Claude Code** (primary) | `CLAUDE.md` (+ `@import`) | `~/.claude/projects/*/memory/` | skills, slash commands, `~/.claude/CLAUDE.md` global |
| **OpenAI Codex** | `AGENTS.md` | `~/.codex/` (`config.toml`) | project trust levels, plugins |
| **Antigravity CLI** (`agy`) | `AGENTS.md` and `GEMINI.md` | `~/.gemini/config/` (global `GEMINI.md`, `mcp_config.json`, `skills/`); app data in `~/.gemini/antigravity-cli/` | `.agents/` workspace dir (skills, teamwork state), plugins, ACP server |
| Gemini CLI (deprecated) | `GEMINI.md` (+ `@import`, no `~` expansion) | `~/.gemini/` | superseded by Antigravity CLI |

Claude is **primary** because it has the richest surface (skills, commands, structured memory,
`@import`). Codex and Antigravity are served by exporting the same canonical content under the
filenames they read.

## The bridge: one canonical file

Because `CLAUDE.md` and `GEMINI.md` are **symlinks to `AGENTS.md`**, all three agents read
identical instructions with zero duplication. The only asymmetry is `@import`:

- **Claude** expands `@~/.claude/master-core/modules/*.md` → gets the full module set.
- **Codex** ignores `@import` lines → gets whatever is **inline** in `AGENTS.md`.
- **Antigravity CLI** reads both `AGENTS.md` and `GEMINI.md` and ignores every `@import` line
  (relative, absolute and `~` alike) → gets only what is **inline**. The import lines reach it
  as plain text.
- **Gemini CLI** (deprecated) processed imports but never expanded `~`
  (`path.resolve(base, importPath)`). It only followed `--absolute-imports` paths, at the cost
  of embedding the home path.

Verified with `agy` 1.5.6 on 2026-11-13, using throwaway projects with codeword files:

- **Imports:** a codeword reached the model only when it was inline. Through `@~/`, an absolute
  path or `@./`, in `AGENTS.md` or `GEMINI.md`, it never arrived.
- **Both files:** when `AGENTS.md` and `GEMINI.md` held different content, agy loaded both.
- **Symlinks:** with `GEMINI.md` symlinked to `AGENTS.md`, the content arrived once (agy
  de-duplicates the pair), so the symlink layout causes no double loading.

This is exactly why `mc-install` offers `--inline` (bake modules in for full parity) vs
`--import` (lean on Claude's loader). Choose per project based on which agents are active.

### Antigravity gets the core globally: the `master-claude` agy plugin

agy ignores `@imports`, so per-project imports never reach it. `bin/mc-agy.sh install`
generates an agy plugin at `~/.gemini/config/plugins/master-claude/` (`plugin.json` +
`rules/`). Its rules hold the core inline: `AGENTS.base.md`, the modules, the language
overlays and the memory-core digest. agy loads plugin rules in every session, so this is
agy's equivalent of Claude's `@~/.claude/master-core` imports:

- Projects stay in slim `--import` mode, and nothing personal goes into their repositories.
- The user's own `~/.gemini/config/GEMINI.md` is never edited. An older version of
  `mc-agy.sh` put a block there; `install` migrates it away and backs up the file first.
- The plugin passes `agy plugin validate`. `mc-sync` refreshes it, `mc-doctor` reports OK
  when it is current and warns when it is missing or stale, and `mc-apply` keeps `.agents/`
  projects in import mode once it exists.

agy's documented limits, all confirmed with probes against agy 1.5.6:

- **24,000 bytes per rule file**, cut at a line boundary. This applies to global, plugin and
  project rule files alike, so a project `AGENTS.md` (especially a fully `--inline` one) over
  24,000 bytes loses its tail in agy. `mc-doctor` flags it. `mc-agy.sh` packs the core into
  `rules/AGENTS.md` and `rules/GEMINI.md` (agy loads both), each under 23,500 bytes, and
  refuses a core that would not fit.
- **20,000 tokens shared by all always-on and global rules.** Rules over budget are demoted to
  path pointers the agent can read on demand. The full core is about 10,000 tokens, which
  leaves room for the user's global rules and the project's rules. Measured: with the full
  plugin installed, the user's global rules, both core parts and the workspace `AGENTS.md` all
  loaded inline, with nothing truncated or demoted.
- `@[label](path)` includes exist (they count toward the 24 KB per file). Plain `@path`
  imports are not processed.

| `mc-agy.sh install` options | Rule files | Size | ~Tokens |
|---|---|---|---|
| `--full` (default: all modules + memory digest) | 2 | ~40 KB | ~10,000 |
| `--no-memory` | 2 | ~37 KB | ~9,100 |
| `--modules 10,20,30,60` | 1 | ~20 KB | ~4,900 |
| `--modules none --no-memory` (base rules + language overlays) | 1 | ~9 KB | ~2,200 |

The size choice is stamped in the plugin, so `verify` and `mc-sync` keep it. `--full` resets
it, and `mc-agy.sh uninstall` removes the plugin.

## Parity matrix

| Capability | Claude | Codex | Antigravity CLI |
|---|---|---|---|
| Reads canonical instructions | ✅ via `CLAUDE.md`→`AGENTS.md` | ✅ `AGENTS.md` | ✅ `AGENTS.md` (+ `GEMINI.md`→`AGENTS.md`, de-duplicated) |
| `@import` heavy modules | ✅ | ❌ (use `--inline`) | ❌ → `master-claude` agy plugin via `mc-agy.sh` |
| Structured persistent memory | ✅ `memory/` | partial (`~/.codex`) | partial (`~/.gemini/config`, `~/.gemini/antigravity-cli/brain`) |
| Slash commands / skills | ✅ | ✗ (own mechanisms) | own skills (`.agents/skills/`, `~/.gemini/config/skills/`) |

## Memory: no native cross-agent bridge

The three agents keep **independent** memory/config trees; there is no built-in shared memory.
Master-Claude's `memory-core/` is the closest thing to a bridge — a single curated fact set.
For Antigravity, `mc-agy.sh` embeds the digest in the plugin's rules, because agy
neither follows `@imports` nor reads other files on its own. For Codex, `mc-mem-bridge.sh`
writes it as `~/.codex/master-memory.md` and prints the line to add to Codex's `AGENTS.md`.
Cross-agent memory sync is tracked as a future enhancement (see `to-dos/04-PHASE-4-MAINTENANCE.md`).

## Practical guidance

- Default to `--import` (Claude-primary). For Antigravity, run `mc-agy.sh install` once per
  machine instead of inlining projects. Switch a project to `--inline` when Codex works there
  (`mc-apply` does this automatically for `.codex/` and `.gemini/`, and for `.agents/` only
  while the agy plugin is missing).
- Keep the **inline base** (`AGENTS.base.md`) genuinely universal — it is the only content
  guaranteed to reach every agent in every mode.
- On public repositories, `--inline` publishes the whole core into `AGENTS.md`. Keep
  `--import` there unless the other agents need parity, and never use `--absolute-imports`.
- Optionally generate `.codex`/`.agents` pointer files for discoverability (enhancement).
