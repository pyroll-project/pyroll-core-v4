# 0004 Property representation

- Status: proposed
- Date: 2026-11-25

## Context

Entities (ADR 0003) carry properties of very different kinds: plain scalars like the roll gap, choices, geometry like cross-sections, and quantities that may be spatially distributed over the workpiece, like temperature. Models (ADR 0005) must be able to rely on a small, fixed set of representations. Terms follow the terminology in `docs/architecture.md`.

## Decision

- Pure scalar measures, e.g. the roll gap, use their usual Python type (`float`, `int`, `str`).
- Quantities that may be spatially distributed are represented by a scalar (mean value), a regular grid (1D or 2D numpy array) or an octree.
- Choices are represented by enums that map to strings or integers.
- Geometry is represented by shapely objects. These can be mapped to octrees and used as masks over the regular grids and octrees of other properties.
- Scalar summaries of spatially distributed quantities, e.g. surface and core temperature, are separate properties. Models link them to the distributed property in both directions, e.g. interpolating a temperature grid from surface and core temperature, or deriving them from a given grid.
- All properties are in SI units. pyroll-core has no unit handling; converting units is left to possible frontends.

## Consequences

- Models can work with simple scalar summaries or with full distributions, and the compiler (ADR 0006) picks the route that fits the available models and known properties.
- Users and model authors must provide values in SI units; there is no runtime check for unit mistakes.
- shapely becomes a runtime dependency, as does numpy.

## Open questions

- Representation of octrees (deferred).
