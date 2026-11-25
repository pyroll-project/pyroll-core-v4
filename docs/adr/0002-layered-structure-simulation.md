# 0002 Layered structure of simulation

- Status: proposed
- Date: 2026-11-25

## Context

PyRolL v4 is a rewrite. This ADR defines the overall structure of how a rolling process is described and how it is simulated, based on the shortcomings of PyRolL v3.x. Terms follow the terminology in `docs/architecture.md`.

### Shortcomings of PyRolL v3.x

From the user's point of view:

- Simulations become unstable and slow when several complex models are combined, e.g. the pillar and ring models.
- Hook resolution is expensive with complex models, and its logic is hard to understand.
- Implicit models can only be solved by fixed-point iteration.
- Some situations need special-cased solution algorithms, e.g. interstand tensions.
- Debugging is hard, and errors during solution are reported with overly general messages.

The underlying causes:

- Model dependencies are not known in advance, because they are resolved recursively during the solution.
- Model functions provide no derivatives.
- The single-responsibility principle is violated: unit and profile classes store data, contain solution logic and register models at the same time.

## Decision

The architecture follows an Entity-Component-System (ECS) approach in a wider sense: data (entities and their properties), physics (models) and solution logic are separated.

Simulation is split into three layers:

1. **Definition:** the user defines the process (initial profile and units with their known properties) and selects the model pool. See ADR 0003 (entities), ADR 0004 (property representation) and ADR 0005 (models).
2. **Compilation:** a heuristic algorithm constructs a dependency graph. It starts from the sought properties and tries to find an evaluation route back to the known properties of the process definition. See ADR 0006.
3. **Solution:** the solver evaluates the models in the order given by the dependency graph and iterates locally over circular dependencies. See ADR 0007.

## Alternatives considered

- **Keep the v3 approach (hooks resolved recursively during the solution):** this causes the shortcomings listed above, because no dependency information is available before the solution starts.

## Consequences

- Dependencies are known before the solution starts. Cycles, unreachable properties and inapplicable models can be detected and reported specifically at compilation time instead of failing generically during the solution.
- Only cyclic subgraphs need iteration. All other parts are evaluated once, which should reduce solution time and improve stability.
- Derivatives enable gradient-based solvers for cycles and gradients of results with respect to inputs.
- Data (entities), physics (models) and solution logic (compiler and solver) are separated into distinct responsibilities.
