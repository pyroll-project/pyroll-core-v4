# 0005 Model declaration

- Status: proposed
- Date: 2026-11-25

## Context

In v3, models were registered as hooks on unit and profile classes, and their dependencies were only discovered recursively during the solution (see ADR 0002). For the compiler (ADR 0006) to build a dependency graph in advance, every model has to declare what it needs, what it provides and when it is applicable. Terms follow the terminology in `docs/architecture.md`.

## Decision

- The model pool holds the models that relate the properties of entities to each other.
- Each model declares the input properties it needs and the output properties it can calculate.
- Inputs and outputs address properties on multiple levels, since a property is only identified by its entity, the entity's role and the property name, e.g. the temperature of the in profile of a roll pass.
- Inputs and outputs carry additional constraints that determine whether a model is applicable. Constraints may refer to type literals, classifiers and the values of any other defined property, e.g. restricting a model to two-roll passes or to profiles of a specific material.
- Inputs and outputs are declared by type annotations on the model functions. These annotations are generated from the entity types' pydantic schemas (ADR 0003) and therefore represent the properties that can exist.
- Models may be assigned an integer priority, which defaults to 0. When several applicable models can calculate the same property, the one with the higher priority wins. This allows plugins to override core models by assigning a higher priority.
- Models may have parameters, e.g. fit coefficients of empirical model functions. They are set when the model instance is created.
- In addition to the model function, a model may define its inverse function, pushforward and pullback. If these are not defined explicitly, they are estimated numerically from the model function.
- pyroll-core includes basic, generally applicable models, which form the default model pool. Plugins provide further models. The plugin interface is decided in a separate ADR.

## Consequences

- Model authors have to declare inputs and outputs explicitly and should provide derivatives where numerical estimation is inaccurate or expensive.
- Model function signatures depend on types generated from the entity schemas. These types could be produced by the build-time code generation from ADR 0001.
- Models from pyroll-core and from plugins live in one model pool. Conflicts between them are resolved by priority, so model selection can be controlled explicitly. Models of equal priority competing for the same property are only distinguished by the graph-size heuristic of the compiler (ADR 0006), so plugin authors should assign priorities deliberately.

## Open questions

- Syntax of multi-level property addressing in model input and output declarations.
- Plugin interface (separate ADR).
