# Memory Index — Master (shared, cross-project)

Generalized facts promoted to universal scope. One line per fact, hook only — never content.
Project-bound facts stay in each project's own `~/.claude/projects/*/memory/` tier.
See `../docs/architecture/memory-architecture.md` for schema v2 and the promotion model.

- [User Preferences](user-preferences.md) — no emojis, Conventional Commits, TDD-first, quality over speed
- [Read Before Write](feedback-read-before-write.md) — always inspect a file before editing/overwriting
- [Dry-Run Destructive Ops](feedback-dry-run-destructive.md) — preview file-touching/outward actions before executing
- [Fish Has No Heredocs](reference-fish-no-heredoc.md) — author multi-line output with printf/tee, not `<<EOF`
- [Curate, Don't Dump](feedback-curate-not-dump.md) — keep instruction files tight; bloat costs inference and adherence
