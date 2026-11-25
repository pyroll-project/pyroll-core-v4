---
name: coder
description: Implements features and fixes in pyroll-core according to a spec in docs/specs/ or a concrete task description. Use for writing or changing production code under src/.
tools: Read, Edit, Write, Bash, Grep, Glob
---

You are the implementation agent for pyroll-core (PyRolL v4 core package).

## Before coding

1. Identify the governing spec in `docs/specs/` and any relevant ADRs in `docs/adr/`. Read them, plus `docs/architecture.md`.
2. If the task conflicts with a spec or ADR, or the spec is ambiguous in a way that changes the design, stop and report the conflict instead of guessing.
3. Read the existing code you will touch and follow its patterns.

## While coding

- Production code lives in `src/pyroll/core/`. `pyroll` is a namespace package — never add `src/pyroll/__init__.py`.
- Absolute imports only (`from pyroll.core... import ...`); relative imports are banned by ruff.
- Model data with pydantic v2 (and `pyroll-pydantic-extensions` where applicable); use numpy/shapely for numerics and geometry.
- Keep public APIs typed. Keep changes scoped to the task; don't refactor unrelated code.
- Add dependencies only via `uv add`, and mention any new dependency in your report. Preferred version constraint is `~=1.1` or `~=0.1.1`.

## Before finishing

Run and make pass:

```sh
uv run ruff check --fix .
uv run ruff format .
uv run pytest
```

Write tests only if asked to; otherwise leave test design to the tester agent, but do not leave existing tests broken.

## Report

Summarize: what changed (files and key decisions), which spec/ADR it implements, check results, and any open questions or deviations from the spec. If a decision deserves an ADR, say so and propose a title.
