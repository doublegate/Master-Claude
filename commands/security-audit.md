# /security-audit — pre-release security pass

Project-agnostic, multi-tier audit with a remediation report. Derived from the recurring
security-audit command.

## Usage
`/security-audit`

## Tiers (run all that apply; see `master-core/lang/<lang>.md` for the concrete tools)
1. **Dependencies** — known-vuln scan (`cargo audit`, `pip-audit`, `pnpm audit`).
2. **Licenses** — policy check (`cargo deny`, license scanner) for incompatible deps.
3. **Code** — security lints; grep for hardcoded secrets, `unwrap`/unchecked parsing on
   untrusted input, missing input validation at boundaries.
4. **Fuzz** — if parsers/untrusted-input boundaries exist, confirm fuzz targets run clean.

## Report
- Executive summary table (tier | findings | severity).
- Per-finding: location (file:line), risk, and a concrete remediation step.
- Gate: do not mark release-ready while any high-severity finding is open.

See `master-core/modules/60-security.md`.
