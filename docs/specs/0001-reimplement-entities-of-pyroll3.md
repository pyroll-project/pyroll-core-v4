# 0001 Reimplement entities of PyRolL 3

- Status: draft
- Related: ADR 0003, ADR 0004

## Goal

Implement entity types for units and profiles that mirror those of [PyRolL 3](https://github.com/pyroll-project/pyroll-core/tree/v.3.1.0) (latest release `v.3.1.0`), following ADR 0003 and ADR 0004.

## Scope

### In scope

Only these v3 classes are implemented:

- `TwoRollPass` (alias `RollPass`), `ThreeRollPass`
- `Transport`
- `Roll`
- the groove classes
- `Rotator`
- `PassSequence` (new alias `Sequence`; shadowing `typing.Sequence` is accepted, since it is seldom used in PyRolL-related code)
- `Profile` and its subclasses

### Out of scope

| Item                                                | Reason / future                                                             |
| --------------------------------------------------- | --------------------------------------------------------------------------- |
| Disk elements                                       | The concept is not needed anymore.                                          |
| Engines                                             | Skipped for now.                                                            |
| Hookimpls                                           | Become models, specified separately.                                        |
| Profile and groove geometry solvers                 | Become models.                                                              |
| Solver parameters                                   | Will be added in the solver routines.                                       |
| Activation energies and transformation temperatures | Skipped for now.                                                            |
| Plotting-related functionality                      | Will be provided as functions, since plotting now requires partial solving. |
| Technologically orientated geometry                 | Will be a plotting setting.                                                 |
| `flow_stress_function`                              | Removed.                                                                    |
| `PassSequence.solve_velocities_backward/forward`    | Solution logic, becomes models or solver functionality.                     |
| `CoolingPipe`                                       | Out of scope.                                                               |

## Requirements

### Class design

- All entity types derive from `PyRollBaseModel`.
- Use inheritance of pydantic classes where possible. Inheritance only serves to deduplicate code; assignability is modeled via discriminated unions.
- Abstract classes only serve to deduplicate code and are not assignable to properties holding nested entities.
- Use global classes only. Do not derive classes for each nested entity, as v3 does with nested classes like `TwoRollPass.Profile`, `TwoRollPass.InProfile` or `TwoRollPass.Roll`.
- Entities are mutable, for ease of definition by the user. Results are returned in new instances, rather than written into existing ones as in v3. Assignments shall be validated, too.

### Identification and discriminated unions

- Concrete classes are identified by a type literal in snake case, e.g. `'two_roll_pass'`.
- Class aliases are also available as type literals (discriminated union tags), e.g. `'roll_pass'`. The more precise tag is the canonical one and is used for serialization: `'two_roll_pass'` (alias `'roll_pass'`) and `'pass_sequence'` (alias `'sequence'`).
- Discriminated unions are fixed; new entity types are only added in the core (see ADR 0003).
- Do not use the `ValidateSubclasses` mechanism of `pyroll-pydantic-extensions`.

### Relations between entities

- Rolls are nested entities of roll passes, and grooves are nested entities of rolls.
- Units contain their in and out profiles. These are seldom set explicitly during process definition, except for the initial profile, which is set as the in profile of the first unit.
- The out profile of a unit and the in profile of the subsequent unit are separate objects, because the models connecting them may include changes, such as a rotation.
- `PassSequence` stores a plain list of discriminated unions, in which all roll pass and transport unit types and `Rotator` and nested pass sequences are possible.
- The rotation before roll passes is represented by a model, not a unit. The `Rotator` class only serves to manipulate a profile explicitly.

### Property set

- Every v3 hook becomes a property with the same name, except for the out-of-scope items listed above and these renames:

  | Entity      | v3 hook       | v4 property                   | Reason                                                                                                                                                  |
  | ----------- | ------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | `Profile`   | `strain`      | `equivalent_strain`           | Accumulated equivalent strain of the workpiece state; the name states which strain measure is meant.                                                    |
  | roll passes | `strain`      | `equivalent_strain_increment` | Equivalent strain applied within the pass (Δε), a change rather than a state. Avoids the same name with different meanings on profiles and roll passes. |
  | roll passes | `strain_rate` | `equivalent_strain_rate`      | Mean equivalent strain rate within the pass; renamed for consistency with `equivalent_strain_increment`.                                                |

- The v3 profile constructors (`Profile.round()`, `Profile.box()`, …, `Profile.from_*()`) are replaced entirely by distinct profile classes. The same holds for groove constructors. For `from_*` constructors, the class name and the name of its property are derived from the constructor name (`Profile.from_groove` -> `GrooveProfile.groove`). Exception: `Profile.from_polygon` gets no class of its own; a plain `Profile` with `cross_section` set replaces it.

- Entities do not reject over-specified inputs, e.g. both `radius` and `diameter` of a round profile, or both `width` and `filling` of a groove profile. Checking the consistency of given values is the solver's task.

- When a constructor reads a file, the file path (as `pathlib.Path`) shall be used as its property.

- Profile and groove geometry default values carry over from v3. Those sensible default values are intentional to not require the user to state e.g. `corner_radius=0` every time.

### Value types

- Physical units stay SI units, as in v3. Physical units therefore need no special handling anywhere.
- Spatially distributed properties allow regular grids and octrees in addition to a scalar.
  - Grids must use `ValidateGridShape`.
  - Octrees are not implemented for now and will follow later.
  - Typical examples:
    - `temperature`
    - `equivalent_strain` (profiles)
    - stresses (in all directions)
    - `flow_stress`, `elastic_modulus`
    - `density`
  - Surface and core temperature serve as proxies when temperature is spatially distributed. Either a model may calculate the grid by interpolation, if surface and core temperature are given, or they may be derived from the grid, if this is given.
- Typical counter-examples, which stay single values:
  - `draught`, `abs_draught`, `rel_draught`, `equivalent_strain_increment` (roll passes)
  - `height`, `width`, `length`
  - `cross_section` and any other shapely object
  - `time`
  - `classifiers` and `material` (sets of strings)
  - front and back tension
  - target values
- Classifiers are not identical to type literals. A classifier classifies a concrete instance; a type literal identifies the class.
- Classifiers are kept as strings, so plugins can extend them.
- `classifiers` is an ordinary property: like any other, it may be unknown and calculated by models, e.g. inferred from the cross-section geometry.

## Acceptance criteria

- Every in-scope v3 hook exists as a property, with the renames from the table applied (no `strain` or `strain_rate` properties left on profiles or roll passes).
- All properties without a v3 default default to None.
- A JSON round trip gives an equal object.
- Nested pass sequences, transports, roll passes, rolls and grooves validate from a dict through their type literals.
- Abstract classes are rejected as nested values.
- Alias tags validate, and serialization writes the canonical tag.
- Assigning an invalid value to a property raises a validation error.
- Grids of mismatching shape on one entity are rejected (`ValidateGridShape`).
