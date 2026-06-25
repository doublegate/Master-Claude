<<< MC-PROJECT-START >>>
## Project: {{PROJECT_NAME}}

> Hand-authored. `mc-sync` never overwrites content between the MC-PROJECT markers.
> Fill these in; delete prompts that don't apply. Keep it tight (this is per-project truth,
> not universal guidance — universal rules come from the imported/inlined core above).

- **What it is:** {{one-line description}}
- **Stack:** {{language(s), framework(s), key deps with versions}}
- **Build / run:** `{{build command}}` / `{{run command}}`
- **Test:** `{{test command}}` ({{single-test invocation}}; {{filtering note if suite is large}})
- **Lint / format gate:** `{{linter}}` / `{{formatter --check}}`

### Architecture — load-bearing facts
- {{cross-cutting decision 1 — e.g. who owns mutable state, the timing master, the dep direction}}
- {{cross-cutting decision 2}}

### Gotchas / institutional knowledge
- {{non-obvious thing that has bitten us — exact tool flag, platform quirk, hardware limit, etc.}}

### Where things live
- {{path}} — {{purpose}}

### Status / next
- See `CLAUDE.local.md` for volatile session state (current phase/sprint, recent decisions).
<<< MC-PROJECT-END >>>
