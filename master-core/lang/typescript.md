# Language Overlay — TypeScript / JavaScript

Concrete commands for the universal rules. Detect the package manager from the lockfile
(`pnpm-lock.yaml` → pnpm, `bun.lockb` → bun, `package-lock.json` → npm) before running.

## Build / dev

- Install: `pnpm install` / `npm install` / `bun install` (match the lockfile)
- Dev: `pnpm dev`; Build: `pnpm build`

## Test / lint / format

- Test (Vitest): `pnpm vitest run` — **filter large suites**: `pnpm vitest run <pattern>`
- Single: `pnpm vitest run path/to/file.test.ts -t "case name"`
- Lint (gate): `pnpm eslint .`; Format: `pnpm prettier --check .` (apply: `--write`)
- Types (gate): `pnpm tsc --noEmit`

## Quality / security

- Coverage: `pnpm vitest run --coverage`; keep core high.
- Deps audit: `pnpm audit` / `npm audit`; secrets via env (`process.env`), never committed.
- End-to-end type safety at API boundaries (typed client / tRPC); REST only at edges.

## Conventions

- Validate external input (zod or equivalent) at boundaries; narrow `unknown`, avoid `any`.
- State: keep stores sliced and predictable; URL params for shareable state.
- Errors: typed results or thrown `Error` with context; never swallow silently.

> Universal rules: see `master-core/AGENTS.base.md`. Topic depth: `master-core/modules/`.
