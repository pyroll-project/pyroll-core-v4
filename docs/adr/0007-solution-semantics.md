# 0007 Solution semantics

- Status: proposed
- Date: 2026-11-25

## Context

ADR 0002 introduces a solution layer that evaluates the dependency graph built by the compiler (ADR 0006). In v3, results were written into the given unit and profile objects, and contradicting values were silently resolved by overwriting. This ADR defines how the solver evaluates the graph, how it treats defined properties and how results are returned. Terms follow the terminology in `docs/architecture.md`.

## Decision

- Models are evaluated and iterated using the information from the dependency graph.
- Tree-like subgraphs are evaluated feed-forward.
- Cyclic subgraphs are iterated until convergence.
- Defined properties are fixed and must hold in the solution. They are never used as starting values for iterating cycles and are never overwritten.
- If a defined property can also be calculated by an applicable model, the solver evaluates the model and checks that the result is consistent with the defined value. Inconsistencies are reported, naming the involved properties and models.
- Results are returned as new entity instances. The process definition stays unchanged and can be solved repeatedly, e.g. in parameter studies.
- Gradients are calculated along the graph from the models' derivative functions (pushforward and pullback, ADR 0005).

## Consequences

- Over-specified process definitions are detected instead of silently resolved: contradicting defined values are reported, rather than one of them being overwritten as in v3.
- Since process definitions are never modified by the solver, they can be reused and compared across solutions. This is a deliberate break with v3, where results were written into the given objects.

## Open questions

- Tolerances for the consistency check of defined properties and convergence criteria for cycle iteration: global, per property or per model?
