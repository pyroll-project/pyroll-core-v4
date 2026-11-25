# 0002 Layered structure of simulation

- Status: proposed
- Date: 2026-11-25

## Context

PyRolL v4 is a rewrite. This ADR defines how a rolling process is described and how it is simulated, based on the shortcomings of PyRolL v3.x.

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

## Terminology

The architecture follows an Entity-Component-System (ECS) approach in a wider sense. ECS terms are mapped to domain terms as follows. These terms are used consistently in code and documentation.

| Term                   | ECS equivalent | Meaning                                                                                                                                               |
| ---------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Entity**             | entity         | An object of the rolling process: a profile (workpiece state) or a unit (processing step). Entity types are pydantic classes.                         |
| **Property**           | component      | A single field of an entity, e.g. roll gap, temperature field, cross-section. Its value may itself be an entity.                                      |
| **Model**              | system         | A physical model in the modelling and simulation sense: a mathematical relation that maps input properties to output properties of specific entities. |
| **Process definition** | —              | The complete set of entities a user defines for one simulation, including the initial profile and the units.                                          |
| **Model pool**         | —              | The set of models the user makes available to the solver for one simulation.                                                                          |
| **Defined property**   | —              | A property whose value is given in the process definition, explicitly or by a default value. Its value is fixed and must hold in the solution.        |
| **Type literal**       | —              | The tag that identifies the class of an entity, used as discriminator of discriminated unions, e.g. `'two_roll_pass'`.                                |
| **Classifier**         | —              | A string that classifies a concrete entity instance, e.g. by shape or material. Unlike type literals, classifiers can be extended by plugins.         |
| **Default model pool** | —              | The model pool used unless the user selects otherwise: the basic, generally applicable models included in pyroll-core.                                |

"Model" always means a physical model. Pydantic classes are called entity types, never models. "Pydantic model" is used only when referring to the library mechanism (`BaseModel`) itself.

## Decision

Simulation is split into three layers:

1. **Definition:** the user defines the process (initial profile and units with their known properties) and selects the model pool.
2. **Compilation:** a heuristic algorithm constructs a dependency graph. It starts from the sought properties and tries to find an evaluation route back to the known properties of the process definition.
3. **Solution:** the solver evaluates the models in the order given by the dependency graph and iterates locally over circular dependencies.

### Layer 1: Definition

#### Entities

- Entity types are pydantic classes that mirror real-world plants and objects. They are the ground truth about which data can exist in a rolling process, and they provide types, validation and JSON schemas for free.
- Almost every property may be missing (unknown) when the user defines the process. Missing properties are to be determined by models.
- Default values of entity types make a property defined. To have such a property calculated by models, the user must explicitly set it to unknown.
- Process definitions can be serialized and deserialized safely and easily, e.g. to JSON or YAML. Serialized process definitions carry the schema version of pyroll-core they were created with, and loading checks compatibility with the installed version.
- Key entity types:
  - **Profiles:** the initial workpiece shape and state, and the intermediate and final workpiece states.
  - **Units:** processing steps, including roll passes and transports (and thus inter-pass times). Later also furnaces and cooling.
  - **Container units:** define pass sequences and the splitting or merging of strands.
  - Later, separate entity types for things not related to the workpiece, e.g. power trains or cooling water processing.
- Entity types are defined in pyroll-core only. Plugins cannot add entity types; they extend the core with models and classifiers. Wherever several entity types are assignable, e.g. the units of a pass sequence, this is modeled by a discriminated union that is fixed when the core is built. This keeps pyroll-core the ground truth about which data can exist in a rolling process, and keeps process definitions exchangeable between installations with different plugins.

#### Property types

- Pure scalar measures, e.g. the roll gap, use their usual Python type (`float`, `int`, `str`).
- Quantities that may be spatially distributed are represented by a scalar (mean value), a regular grid (1D or 2D numpy array) or an octree.
- Choices are represented by enums that map to strings or integers.
- Geometry is represented by shapely objects. These can be mapped to octrees and used as masks over the regular grids and octrees of other properties.
- Scalar summaries of spatially distributed quantities, e.g. surface and core temperature, are separate properties. Models link them to the distributed property in both directions, e.g. interpolating a temperature grid from surface and core temperature, or deriving them from a given grid.
- All properties are in SI units. pyroll-core has no unit handling; converting units is left to possible frontends.

#### Models

- The model pool holds the models that relate the properties of entities to each other.
- Each model declares the input properties it needs and the output properties it can calculate.
- Inputs and outputs address properties on multiple levels, since a property is only identified by its entity, the entity's role and the property name, e.g. the temperature of the in profile of a roll pass. The exact syntax is an open question.
- Inputs and outputs carry additional constraints that determine whether a model is applicable. Constraints may refer to type literals, classifiers and the values of any other defined property, e.g. restricting a model to two-roll passes or to profiles of a specific material.
- Inputs and outputs are declared by type annotations on the model functions. These annotations are generated from the entity types' pydantic schemas and therefore represent the properties that can exist.
- Models may be assigned an integer priority, which defaults to 0. When several applicable models can calculate the same property, the one with the higher priority wins. This allows plugins to override core models by assigning a higher priority.
- Models may have parameters, e.g. fit coefficients of empirical model functions. They are set when the model instance is created.
- In addition to the model function, a model may define its inverse function, pushforward and pullback. If these are not defined explicitly, they are estimated numerically from the model function.
- pyroll-core includes basic, generally applicable models, which form the default model pool. Plugins provide further models. The plugin interface is decided in a separate ADR.

### Layer 2: Compilation

- The dependency graph is constructed from the known properties of the process definition and the model pool.
- When several applicable models can calculate the same property, the one with the highest priority is preferred. Among models of equal priority, the one that adds fewer new nodes to the graph is preferred. The heuristic does not guarantee a globally minimal graph, since that problem is NP-hard in general.
- Graph construction may run into a dead end, e.g. because no applicable model or no known value exists for a required property. The compiler then keeps trying alternative routes and finally reports every dead end in one concise overview, listing the missing models or property values that would resolve each.
- The graph is bipartite, with property nodes and model nodes.
- The graph is analysed, in particular to detect cycles, and partitioned into subgraphs for local iteration.
- The graph usually consists of several connected components. They are joined by bridges made of multiple edges, typically between processing steps.
- The out profile of a unit and the in profile of the subsequent unit are separate entities. Properties are transferred between them by connecting models: by identity by default, or with a change, e.g. a rotation of the profile between roll passes.
- The graph is represented with `networkx`:
  - The important algorithms are already implemented, e.g. partitioning into strongly connected components (Tarjan) and finding cycles (Johnson).
  - Node types are flexible, since any hashable object can be a node.

### Layer 3: Solution

- Models are evaluated and iterated using the information from the dependency graph.
- Tree-like subgraphs are evaluated feed-forward.
- Cyclic subgraphs are iterated until convergence.
- Defined properties are fixed and must hold in the solution. They are never used as starting values for iterating cycles and are never overwritten.
- If a defined property can also be calculated by an applicable model, the solver evaluates the model and checks that the result is consistent with the defined value. Inconsistencies are reported, naming the involved properties and models.
- Results are returned as new entity instances. The process definition stays unchanged and can be solved repeatedly, e.g. in parameter studies.
- Gradients are calculated along the graph from the models' derivative functions (pushforward and pullback).

## Alternatives considered

- **Keep the v3 approach (hooks resolved recursively during the solution):** this causes the shortcomings listed above, because no dependency information is available before the solution starts.
- **`pytensor` for graph representation and evaluation:** rejected.
  - It supports only directed acyclic graphs, but cyclic dependencies are essential here.
  - Its graph rewriting capabilities are not needed.
  - All models would have to be implemented as `Op`s, and new `Type`s would be needed, e.g. for shapely objects and operations.

## Consequences

- Dependencies are known before the solution starts. Cycles, unreachable properties and inapplicable models can be detected and reported specifically at compilation time instead of failing generically during the solution.
- Only cyclic subgraphs need iteration. All other parts are evaluated once, which should reduce solution time and improve stability.
- Derivatives enable gradient-based solvers for cycles and gradients of results with respect to inputs.
- Data (entities), physics (models) and solution logic (compiler and solver) are separated into distinct responsibilities.
- Model authors have to declare inputs and outputs explicitly and should provide derivatives where numerical estimation is inaccurate or expensive.
- Model function signatures depend on types generated from the entity schemas. These types could be produced by the build-time code generation from ADR 0001.
- New entity types, and new properties of existing ones, require a change and release of pyroll-core, even if only one plugin needs them. In return, every process definition can be validated without knowing which plugins are installed.
- Models from pyroll-core and from plugins live in one model pool. Conflicts between them are resolved by priority, so model selection can be controlled explicitly. Models of equal priority competing for the same property are only distinguished by the graph-size heuristic, so plugin authors should assign priorities deliberately.
- Over-specified process definitions are detected instead of silently resolved: contradicting defined values are reported, rather than one of them being overwritten as in v3.
- Since process definitions are never modified by the solver, they can be reused and compared across solutions. This is a deliberate break with v3, where results were written into the given objects.
- Users must be aware that default values make properties defined. A property with a default is only calculated by models after explicitly setting it to unknown.
- Saved process definitions are tied to a schema version, so renaming or removing properties in pyroll-core requires a compatibility strategy for older files.
- `networkx` becomes a runtime dependency.

## Open questions

- Syntax of multi-level property addressing in model input and output declarations.
- Tolerances for the consistency check of defined properties and convergence criteria for cycle iteration: global, per property or per model?
- Schema versioning scheme of serialized process definitions and the compatibility strategy for older files.
- Representation of octrees (deferred).
- Plugin interface (separate ADR).
