# Language Overlay — Python

Concrete commands for the universal rules. Adjust to the project's actual toolchain.

## Environment / build

- Use a virtualenv: `python -m venv .venv && . .venv/bin/activate`
- Install (editable, dev extras): `pip install -e ".[dev]"`
- Prefer `pyproject.toml` for config; pin tool versions.

## Test / lint / format

- Test: `pytest -v` (coverage: `pytest --cov=. --cov-report=term-missing`)
- Single: `pytest path/to/test.py::TestClass::test_name`
- Lint + format (gate): `ruff check .` and `ruff format --check .` (apply: `ruff format .`)
- Types (if used): `mypy .` or `pyright`

## Quality / security

- Coverage thresholds enforced in CI; keep core paths high.
- Deps audit: `pip-audit`; never commit secrets — load via env (`os.environ`) or `.env` (gitignored).
- Golden-vector tests for any numeric/accuracy-critical logic; cross-check against a reference.

## Conventions

- Errors: raise specific exceptions with context; validate external input at boundaries.
- Native extensions (PyO3/cffi): each `unsafe`/FFI surface documents its invariant.
- Don't run massive suites unfiltered — filter by path/marker during iteration.

> Universal rules: see `master-core/AGENTS.base.md`. Topic depth: `master-core/modules/`.
