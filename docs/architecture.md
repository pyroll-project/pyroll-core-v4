# Architecture of PyRolL v4

This file provides an overview over the architecture of PyRolL in versions 4 and above. The decisions behind it are recorded in `docs/adr/`.

## Overview

The architecture follows an Entity-Component-System (ECS) approach in a wider sense: data (entities and their properties), physics (models) and solution logic are separated. Simulation is split into three layers (ADR 0002):

1. **Definition:** the user defines the process (initial profile and units with their known properties) and selects the model pool.
   - Entities: ADR 0003
   - Property representation: ADR 0004
   - Model declaration: ADR 0005
2. **Compilation:** a heuristic algorithm constructs a dependency graph from the sought properties back to the known properties of the process definition (ADR 0006).
3. **Solution:** the solver evaluates the models in the order given by the dependency graph and iterates locally over circular dependencies (ADR 0007). Models that turn out to be inapplicable to solution-time values, e.g. classifiers, send the solution back to compilation for a new route.

## Terminology

ECS terms are mapped to domain terms as follows. These terms are used consistently in code and documentation.

| Term                   | ECS equivalent | Meaning                                                                                                                                               |
| ---------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Entity**             | entity         | An object of the rolling process: a profile (workpiece state) or a unit (processing step). Entity types are pydantic classes.                         |
| **Property**           | component      | A single field of an entity, e.g. roll gap, temperature field, cross-section. Its value may itself be an entity.                                      |
| **Model**              | system         | A physical model in the modelling and simulation sense: a mathematical relation that maps input properties to output properties of specific entities. |
| **Process definition** | —              | The complete set of entities a user defines for one simulation, including the initial profile and the units.                                          |
| **Model pool**         | —              | The set of models the user makes available to the solver for one simulation.                                                                          |
| **Defined property**   | —              | A property whose value is given in the process definition, explicitly or by a default value. Its value is fixed and must hold in the solution.        |
| **Type literal**       | —              | The tag that identifies the class of an entity, used as discriminator of discriminated unions, e.g. `'two_roll_pass'`.                                |
| **Classifier**         | —              | A string classifying a concrete instance, e.g. by shape or material; a type literal instead identifies the class. An ordinary property (ADR 0003).    |
| **Default model pool** | —              | The model pool used unless the user selects otherwise: the basic, generally applicable models included in pyroll-core.                                |

"Model" always means a physical model. Pydantic classes are called entity types, never models. "Pydantic model" is used only when referring to the library mechanism (`BaseModel`) itself.
