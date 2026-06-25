# 70 — Release Ceremony

## Why it matters

A release is a contract with users: it must be reproducible, traceable, and
reversible. Treating the cut as a *ceremony* — a fixed, gated sequence from
version detection to staged rollout — prevents duplicate or half-built releases,
makes every tag self-documenting, and lets a problem be rolled back against
documented criteria instead of a panic. The artifacts a release produces (an
annotated tag, written notes, multi-platform packages) are the durable record of
what shipped and why.

## Patterns

**Gate the cut behind a pre-release checklist; fail closed.** Before any tag,
run a deterministic checklist and refuse to proceed on a hard failure: working
tree clean, full test suite green, linter clean, docs build, CHANGELOG updated,
no known security advisories, CI green on the release commit, version strings
consistent across all manifests/README. Emit a PASS/FAIL/WARN tally and a written
report. *Example:* a `pre-release` routine runs ~10 numbered checks and aborts if
the version tag already exists or the working directory is dirty.

**Detect an existing release before creating one — never double-ship a version.**
Check whether the tag and published release already exist; if so, stop. A version
is immutable once published: bump the version or explicitly delete the stale tag,
don't overwrite. *Example:* the cut aborts with "tag vX already exists — update
the version or delete the tag."

**Tag messages carry an executive summary plus technical depth.** The annotated
tag is a standalone artifact: a short high-level summary up top, then features,
performance/metrics deltas, technical details, files changed, testing evidence,
and strategic value. Aim for substance (on the order of a hundred-plus lines for
a feature release), so the tag alone explains the release without external
context.

**Release notes extend the tag with everything a consumer needs to adopt.** The
published release contains the full tag content plus install instructions, the
platform/support matrix, asset download links, known issues, and upgrade notes.
It is longer than the tag because it serves users, not just history.

**Follow SemVer, and name the one release allowed to break compatibility.**
MAJOR for breaking changes, MINOR for additive features, PATCH for
bugfix/polish. Keep feature work additive and off-by-default so non-major
releases stay byte-compatible; reserve breaking save-state/format/API changes for
a single, clearly-announced major release that the docs flag in advance.
*Example:* every minor in a line ships new capabilities behind default-off flags
so the default build is byte-identical to the prior minor, with the breaking
"collapse" deferred to a named future major.

**Maintain an explicit packaging matrix.** Define, per release, which artifacts
ship: multi-arch container images, OS packages (`.deb`/`.rpm`/installers),
platform binaries per target triple, man pages, and checksums. Build them from a
release workflow so the set is reproducible rather than hand-assembled.

**Drive release builds from a workflow with a manual trigger.** A
`release.yml`-style pipeline builds and attaches the matrix on the version-tag
push, and also redeploys docs/demo sites on that tag. Expose a manual
`workflow_dispatch` trigger so a release (or re-run) can be launched on demand,
and keep release/docs builds idempotent.

**Stage the rollout; ship to beta/early channels before production, with written
kill criteria.** New platforms and risky features roll out through pre-production
channels (beta builds, sideload, TestFlight) before a production store/GA launch.
Document up front what would trigger a halt or rollback. *Example:* a mobile line
ships interim sideload + TestFlight foundations and explicitly *defers* the joint
app-store production launch until after the stabilizing major release, flipping
all production flags only at the final joint-launch version.

**Fix a written, ordered release process and follow it every time.** A typical
order: assemble release notes from sprint/phase completion docs → review the
commit range → run the pre-release gate → create the annotated tag → create the
release with assets → verify published artifacts → push. Consistency makes
releases auditable and lets the work be delegated.

## Language specifics

- Rust: derive the version from `Cargo.toml`; assert it matches the README and
  any embedded `CARGO_PKG_VERSION` checks before tagging. Cross-compile platform
  binaries via target triples / `cross`; for static musl builds use vendored TLS.
  Gate optional features so the default build stays reproducible.
- CI: pin toolchains in CI; build the packaging matrix with a release-tag-
  triggered workflow plus `workflow_dispatch`; attach checksummed assets.

## Project-bound — do NOT generalize

- Exact tag/notes line-count targets, the specific channel ladder (sideload →
  TestFlight → stores), and which version is the "breaking" one are per-project.
- License choice, store-account specifics, and client-identity strings (e.g. a
  required User-Agent token) are project policy, not portable practice.
- The literal scratch paths used to stage release notes are environment-specific.

## Sources

- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/CLAUDE.md (Release Standards)
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/.claude/commands/pre-release.md
- /home/parobek/Code/OSS_Public-Projects/ProRT-IP/.claude/commands/phase-complete.md
- /home/parobek/Code/OSS_Public-Projects/RustyNES/CLAUDE.md (release flags, staged mobile rollout, SemVer policy)
