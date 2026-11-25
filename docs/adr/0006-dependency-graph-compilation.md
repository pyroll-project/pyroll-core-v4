# 0006 Dependency graph compilation

- Status: proposed
- Date: 2026-11-25

## Context

ADR 0002 introduces a compilation layer between definition and solution. From the process definition (ADR 0003) and the model declarations (ADR 0005), it must determine which models to evaluate, in which order, and where cyclic dependencies require iteration. Terms follow the terminology in `docs/architecture.md`.

## Decision

- The dependency graph is constructed from the known properties of the process definition and the model pool, starting from the sought properties and searching for an evaluation route back to the known ones.
- When several applicable models can calculate the same property, the one with the highest priority is preferred. Among models of equal priority, the one that adds fewer new nodes to the graph is preferred. The heuristic does not guarantee a globally minimal graph, since that problem is NP-hard in general.
- Graph construction may run into a dead end, e.g. because no applicable model or no known value exists for a required property. The compiler then keeps trying alternative routes and finally reports every dead end in one concise overview, listing the missing models or property values that would resolve each.
- The graph is bipartite, with property nodes and model nodes.
- The graph is analysed, in particular to detect cycles, and partitioned into subgraphs for local iteration.
- The graph usually consists of several connected components. They are joined by bridges made of multiple edges, typically between processing steps.
- The out profile of a unit and the in profile of the subsequent unit are separate entities. Properties are transferred between them by connecting models: by identity by default, or with a change, e.g. a rotation of the profile between roll passes.
- The graph is represented with `networkx`:
  - The important algorithms are already implemented, e.g. partitioning into strongly connected components (Tarjan) and finding cycles (Johnson).
  - Node types are flexible, since any hashable object can be a node.

## Alternatives considered

- **`pytensor` for graph representation and evaluation:** rejected.
  - It supports only directed acyclic graphs, but cyclic dependencies are essential here.
  - Its graph rewriting capabilities are not needed.
  - All models would have to be implemented as `Op`s, and new `Type`s would be needed, e.g. for shapely objects and operations.

## Consequences

- Missing models and missing property values are reported all at once at compilation time, before any model is evaluated.
- The chosen graph depends on model priorities and a heuristic, so it is not guaranteed to be minimal.
- Transfers between consecutive units are explicit models and can be overridden like any other model.
- `networkx` becomes a runtime dependency.
