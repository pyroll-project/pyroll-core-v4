# 0003 Entities

- Status: proposed
- Date: 2026-11-25

## Context

ADR 0002 splits simulation into definition, compilation and solution. In the definition layer, the user describes the rolling process as a set of entities with their known properties. This ADR defines how entity types are implemented, who may define them, and how process definitions are stored. Terms follow the terminology in `docs/architecture.md`.

## Decision

- Entity types are pydantic classes that mirror real-world plants and objects. They are the ground truth about which data can exist in a rolling process, and they provide types, validation and JSON schemas for free.
- Almost every property may be missing (unknown) when the user defines the process. Missing properties are to be determined by models.
- Default values of entity types make a property defined. To have such a property calculated by models, the user must explicitly set it to unknown.
- Process definitions can be serialized and deserialized safely and easily, e.g. to JSON or YAML. Serialized process definitions carry the schema version of pyroll-core they were created with, and loading checks compatibility with the installed version.
- Key entity types:
  - **Profiles:** the initial workpiece shape and state, and the intermediate and final workpiece states.
  - **Units:** processing steps, including roll passes and transports (and thus inter-pass times). Later also furnaces and cooling.
  - **Container units:** define pass sequences and the splitting or merging of strands.
  - Later, separate entity types for things not related to the workpiece, e.g. power trains or cooling water processing.
- Entity types are defined in pyroll-core only. Plugins cannot add entity types; they extend the core with models and classifiers. Wherever several entity types are assignable, e.g. the units of a pass sequence, this is modeled by a discriminated union over type literals that is fixed when the core is built.

## Consequences

- pyroll-core stays the ground truth about which data can exist in a rolling process, and process definitions stay exchangeable between installations with different plugins. Every process definition can be validated without knowing which plugins are installed.
- New entity types, and new properties of existing ones, require a change and release of pyroll-core, even if only one plugin needs them.
- Users must be aware that default values make properties defined. A property with a default is only calculated by models after explicitly setting it to unknown.
- Saved process definitions are tied to a schema version, so renaming or removing properties in pyroll-core requires a compatibility strategy for older files.
- The entity schemas are the source for the types used in model declarations (ADR 0005), which could be produced by the build-time code generation from ADR 0001.

## Open questions

- Schema versioning scheme of serialized process definitions and the compatibility strategy for older files.
