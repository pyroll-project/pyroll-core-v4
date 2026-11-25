# Conventions

Coding conventions for pyroll-core. Rules enforced by tooling are configured in `pyproject.toml` (ruff) and `devenv.nix` (treefmt); this file records them together with the rules no tool enforces.

## Package layout

- `src/` layout built with hatchling (see ADR 0001); the importable module is `pyroll.core`, production code lives in `src/pyroll/core/`.
- `pyroll` is a **namespace package** so that plugin packages can share the `pyroll.*` namespace. Never add `src/pyroll/__init__.py`.

## Code style

- Absolute imports only, e.g. `from pyroll.core.entities import ...`. Relative imports are banned (ruff `flake8-tidy-imports`).
- Line length 120. Ruff rule sets: E, F, UP, B, SIM, I.
- Public APIs are fully typed.
- Model data with pydantic v2 (and `pyroll-pydantic-extensions` where applicable); use numpy for numerics and shapely 2 for geometry.

## Dependencies

- Add dependencies only via `uv add` / `uv add --dev`; never edit `uv.lock` by hand.
- Preferred version constraint is the compatible release operator: `~=1.1` or `~=0.1.1`.

## Tests

- Tests live in `tests/`, mirroring the package layout (`src/pyroll/core/entities/units.py` → `tests/entities/test_units.py`).
- Plain pytest functions and fixtures; use `pytest.mark.parametrize` for case tables. Fixtures and marks without parentheses (`@pytest.fixture`).
- Compare floats and arrays with tolerances (`pytest.approx`, `numpy.testing.assert_allclose`); compare geometries using shapely predicates (e.g. `equals_exact`) rather than object equality.
- Test through the public API; avoid asserting on private attributes.

## Commits

- Commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) standard.
- Allowed scopes are the following:
  - entity: anything related with entities (pydantic entity types and their properties)
  - model: anything related with models (physical models relating entity properties, see ADR 0005)
  - ai: anything related with ai config
- Split tests and implementation into separate commits (using `jj split`).
