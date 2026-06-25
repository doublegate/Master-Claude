# 10 — Commits, Versioning & Git Workflow

Conventions for commit messages, branches, and version numbers so history stays machine-readable and releases stay safe.

- Write every commit as a Conventional Commit: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`; optional `(scope)`.
- Keep the subject imperative, short, no trailing period; explain why in the body, not the subject.
- Mark breaking changes with `!` after type/scope or a `BREAKING CHANGE:` footer.
- Never commit unless the user explicitly asks; stage and describe, then wait.
- Run format, lint, and tests before committing; pass the same gate CI runs.
- Name branches `<type>/<short-desc>` (optionally `<user>/<type>/<desc>`), cut from the default branch.
- Never force-push the default branch; rebase your own branch onto upstream before review.
- Keep each commit one focused logical change; avoid catch-all commits across subsystems.
- Version with SemVer MAJOR.MINOR.PATCH: breaking → MAJOR, additive → MINOR, fix → PATCH.
- Ship additive, off-by-default changes as MINOR; keep default-build behavior unchanged.
- Update the CHANGELOG in the same change as any user-visible behavior; collect under `[Unreleased]`.
- Reference the ticket/issue ID in commits and PRs.
- In PRs, state motivation, list concrete changes, and note which checks you ran.
- Size tag messages and release notes to the release: summary + key changes minimum; more for headline releases.

> Language commands: see master-core/lang/<lang>.md
