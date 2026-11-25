# 0001 Build infrastructure

- Status: proposed
- Date: 2026-11-25

## Context

pyroll-core is a Python library published to PyPI as `pyroll-core`. It provides the module `pyroll.core`, in which `pyroll` is a namespace package shared with plugin packages. The build setup has to:

- ship only `pyroll/core` and never a `pyroll/__init__.py`, which would break the namespace for plugins,
- build reproducibly from a locked dependency set,
- generate Python code from Jinja templates at build time (for example repetitive data model or system code). The generated code must end up in the wheel without being maintained by hand.

The project was scaffolded with uv as the project manager and `uv_build` as the build backend. `uv_build` is fast and needs no configuration for simple pure-Python packages. However, it deliberately offers no extension points: no build hooks, no plugins and no dynamic metadata. Code generation during the build is therefore impossible with it.

The development environment is provided by devenv (Nix). It creates the venv, runs `uv sync` and provides the formatters (treefmt) and git hooks.

## Decision

- **Project and dependency management:** uv. Dependencies are declared in `pyproject.toml` and locked in `uv.lock`. Python tools are run through `uv run`.
- **Build backend:** hatchling (`hatchling.build`), replacing `uv_build`. `uv build` remains the build frontend.
- **Code generation:** a custom hatchling build hook (`hatch_build.py` at the project root, a `BuildHookInterface` subclass, registered under `[tool.hatch.build.targets.wheel.hooks.custom]`) renders the Jinja templates in `initialize()`. Jinja2 is declared as a dependency of the hook (the hook's `dependencies` option), not as a runtime dependency of pyroll-core.
  - The sdist ships the templates and the hook, not the generated code. The code is generated when the wheel is built, so a wheel built from the sdist is identical to one built from the repository.
  - Generated files are not committed. They are gitignored and added to the wheel through the hook's `build_data["artifacts"]` (hatchling skips gitignored files otherwise).
  - The hook also runs for editable installs (`version == "editable"`, i.e. `uv sync`), and writes the generated modules into the source tree so they are importable during development.
- **Wheel contents:** `only-include = ["src/pyroll/core"]` with `sources = ["src"]`, so that the wheel contains `pyroll/core/**` only and the namespace package stays intact.
- **Sdist contents:** an explicit, root-anchored whitelist (`/src/pyroll/core`, `/tests`, `/README.md`, `/LICENSE`). Hatchling's default is to include everything not gitignored, which would pull in dev-environment files. One of them, `.pre-commit-config.yaml`, is a symlink into the Nix store, and the resulting sdist cannot be unpacked.
- **Development environment:** devenv remains responsible for the toolchain (Python 3.14, uv, ruff, treefmt, git hooks). The build itself must not depend on Nix, so `uv build` works anywhere uv is available.

## Alternatives considered

- **Keep `uv_build`:** simplest and fastest, but cannot run build hooks, so templates would have to be rendered by a separate script and the output committed, with the risk of templates and generated code drifting apart. Migrating later would cost about the same as now, but would happen under time pressure.
- **setuptools:** code generation is possible via custom `build_py` commands, but that requires `setup.py`, and setuptools configuration is more verbose and partly legacy (`MANIFEST.in`). Hatchling's build hook interface does the same with `pyproject.toml` plus one small Python file.
- **Commit generated code, render with a pre-commit hook or a pytask task:** keeps the build backend trivial, but generated code would show up in diffs and reviews and could be edited by hand by mistake. Rejected.
- **scikit-build-core / meson-python:** only relevant if compiled extensions are introduced. This can be revisited in a separate ADR if that becomes necessary.

## Consequences

- Generated code exists only after a build or `uv sync`. Tools that read the source tree (pyright, ruff, tests) need an up-to-date editable install.
- uv caches the built editable install and does not rebuild it just because a template changed. The templates and the hook must therefore be listed in `[tool.uv] cache-keys` (together with `pyproject.toml`), so that `uv sync` regenerates code after a change.
- `/hatch_build.py` and the template directory must be added to the sdist whitelist.
- Further hatchling extension points (plugins such as `hatch-vcs`, dynamic metadata) are available later without changing the backend again.
- Builds are slightly slower than with `uv_build`, which is negligible for this project.
- Wheel and sdist contents are now explicit. New top-level files that belong in the sdist must be added to the whitelist in `pyproject.toml`.
- The hatchling version is constrained to `~=1.33`, following the dependency conventions in `docs/conventions.md`.

## Open questions

- Where do templates and generated modules live (e.g. `templates/` at the root and a `pyroll.core._generated` subpackage), and what input data drives the rendering? (decided in separate ADR)
- Should generated code be formatted (e.g. by ruff) before it is packaged? (deferred, decided in separate ADR)
