# Phase 5 — Enforcement + Delegation

Make the rules that must never be violated *impossible* rather than discouraged, and stop
spending the primary model on chores. **Status: COMPLETE (initial rollout).**

## Why

Phases 0-4 distribute knowledge: `master-core/` modules, `memory-core/` facts, `commands/`,
`skills/`. All of it is instructions to a model — probabilistic. Permission rules and hooks are
enforced by the harness itself and fire deterministically every time.

The gap was measurable. Before this phase the machine's `~/.claude/settings.json` had:
bare `"Bash"`, `"Write"`, `"Edit"` in `permissions.allow` (a bare tool name matches *every* use),
`skipAutoPermissionPrompt: true`, no `permissions.deny` at all, and exactly one hook — unrelated.
Three memory facts existed specifically because a prose rule had already failed in practice
(`sed -i` truncating a file to 0 bytes; sudo without a TTY tripping faillock; destroying
uncommitted work with `git checkout`).

## Delivered

- [x] `guards/guard-lib.sh` — hook payload parsing, deny envelope, compound-command splitting,
      wrapper/env-prefix normalization.
- [x] `guards/guard-bash.sh` — sudo, in-place stream edits, dirty-aware destructive git,
      removal of a home/workspace root, recursive chown on the NTFS mount, settings clobber.
- [x] `guards/guard-write.sh` — `.git` internals, `~/.ssh`, `/etc`, `.env`, settings files.
- [x] `guards/deny-rules.json` — the static first line (18 rules).
- [x] `bin/mc-guard.sh` — `install | verify | audit | uninstall`; backs up, merges, idempotent.
- [x] `guards/claude-security-guidance.md` + `guards/security-patterns.json` — rule files for
      the `security-guidance` plugin, symlinked into `~/.claude/` on install.
- [x] `agents/{scout,sweeper,verifier}.md` + `bin/mc-commands.sh --agents`.
- [x] Module 91 (+ knowledge doc) — agent/assistant system architecture.
- [x] `test/run.sh` groups 13-17; `mc-selfcheck` and `mc-doctor` report on the layer; CI lints
      `guards/`.

## Design decisions

**Two layers, not one.** `permissions.deny` is cheap and evaluated before `ask`/`allow`, so it
holds even against a bare `"Bash"` allow. But the Claude Code docs are explicit that Bash rules
constraining *arguments* are fragile, and a rule cannot consult `git status`. So static rules
cover the unconditionally-wrong commands and the hook does the robust parse.

**Deny, not allowlist.** Replacing the blanket `allow` with a curated allowlist was considered
and rejected: it would generate permission prompts throughout an autonomous session for no
safety gain, because `deny` already wins over `allow`. The bare allows remain; `mc-guard.sh
verify` reports them as a WARN so the posture stays visible.

**Dirty-aware, not blanket.** `git checkout <path>` is correct on a clean tree and destroys
unrecoverable work on a dirty one. Blocking it unconditionally would train the operator to
disable the guard. Only the destructive case is blocked, and the deny reason names the
non-destructive alternative (`git show HEAD:<path>`).

**Narrow static sed rule.** `Bash(sed *-i*)` also matches any filename containing `-i`
(`sed -e 's/x/y/' build-init.sh`), so the static rule matches only the leading form; the hook
parses the argument list properly and catches clustered (`-ni`) and wrapped forms.

## Two bugs found by live testing, both now regression-tested

Sandbox tests that construct the hook payload by hand pass a `cwd` explicitly and so miss how
commands are really written. Both of these passed the unit tests and failed against a live
session; groups 18 and 19 in `test/run.sh` exist because of them.

1. **`cd repo && git checkout f.txt` was allowed and destroyed the file.** The guard checked
   dirtiness against the hook payload's `cwd` (the session directory) rather than the directory
   the `cd` moved into. The `cd &&` form is how most such commands are written, so the guard was
   close to useless in practice. Fixed by tracking `cd`/`pushd` across the compound command, and
   by resolving candidate paths against `git -C <dir>` when present.
2. **`jq . ~/.claude/settings.json >/dev/null` was denied.** The settings-clobber check tested
   the whole command string for a `>` and a settings path *anywhere* in it, so any command that
   read settings while redirecting something unrelated was blocked. Fixed by running the check
   per-subcommand and matching the redirect *target*, not a mention.

The lesson generalizes: a guard that is wrong in the permissive direction gives false
confidence, and one that is wrong in the restrictive direction gets disabled. Test against a
live session before trusting either.

## Known limitations — do not claim otherwise

- **Guards see tool calls, not what those calls do.** `sh ./script.sh` is judged as
  `sh ./script.sh`; a `sed -i` *inside* that script is invisible to the hook.
- **The check runs before any of the command runs.** In a compound line, state changes made by
  an earlier subcommand are not visible to the check of a later one, so
  `git add f && git commit -m x && git checkout f` is denied even though the tree would be
  clean by the time `checkout` ran. Split it into separate calls. Conservative in the safe
  direction; not worth solving by simulating the shell.
- **Not a sandbox.** A determined agent that can write and then execute a file has paths around
  any of this. The goal is preventing accident and reflex, not containing an adversary.
- **`mv` onto a settings file is not blocked** — `mc-guard.sh` itself needs it. The Write/Edit
  tool path and shell redirect/tee/cp are blocked.
- **The security plugin never blocks.** All three layers report; none gate a write, a commit, or
  a push. The reviewer also reads the diff it is reviewing, so it is prompt-injectable. It sits
  *under* the module 30 gates, not in place of them.
- **Hooks load at session start.** Installing mid-session does not arm them until the next one.

## Explicit non-goals

- **No automated memory consolidation / "dreaming".** A consolidation agent with broad memory
  access can promote a local note to global scope or resolve a conflict the wrong way, and the
  memory bank encodes hard-won specifics that a merge would flatten. `/mem-synthesize` and
  `/mc-curate` stay manual and periodic.
- **No AI-control research tooling** (control evals, ControlArena, inspect-swe, certified model
  access). Interesting, and not what this repo is for.

## Follow-ups

- [ ] Sweep `bin/mc-sync.sh` across managed projects so they pick up module 91 and the
      `AGENTS.base.md` delegation section (workspace root is done).
- [ ] Re-run `bin/mc-guard.sh audit` after any project adds permissions; consider trimming the
      widest indirection rules (`Bash(npm run:*)`, `Bash(pnpm *)`) in the noisiest projects.
- [ ] Watch `~/.claude/security/log.txt` for the first week; tune `security-patterns.json` if a
      rule proves noisy.
