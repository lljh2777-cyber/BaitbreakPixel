# P4.2 Authority MapContext · 0.26.1

## Scope and initialization

After the user accepted 0.26.0, this stage follows §79 of the map-abstraction specification. It installs the existing validated contract-v1 data into Authority. It does not implement P4.3 schema16/map-ref networking, P4.4 presentation migration, a map menu, generation, new collision rules, Watergen, multi-rod or fish memory.

`World._init()` obtains the registered `pond_v2` context before creating/resetting the angler or assigning the player spawn. `reset_world(config, definition = null) -> bool` builds a candidate context before changing the world, actors or RNG. A rejected definition or unknown/wrong-type registry selection returns false and updates only `map_errors`; the active context and round remain unchanged. Success installs the context and its cached exports, then executes the existing round-reset order and RNG tape.

The optional explicit definition is an isolated headless test seam. The normal game and closed Registry still select only `pond_v2` revision1. A round may obtain another context only by starting a complete new round. The public context property and context scalar properties ignore replacement attempts. There is no live geometry-edit API.

## Context and geometry contract

`MapContext.load_map(id, revision)` and `MapContext.from_definition(value)` return `{valid, errors, context}`; failure has `context = null`. Factories validate before constructing caches. Existing MapDefinition/Validator/Registry code and the canonical pond hash remain unchanged:

`794aea6774b6a6626a1f56a58a1e0db0811c30eb60ac35eb9c2f472788fa5ef4`

Context scalar access includes identity/revision/contract/hash, size/water/floor/net area, spawn and home. Geometry is compiled once into ordered interaction targets, feature lookup, bounds lookup, and independent capability subsets. `MapGeometry` owns polygon bounds, nearest-boundary/touches and coil construction without reading PondLayout. Contact tie-breaking, vertex order, all 65 coil samples, legacy target fields/types/order and compatibility indexes remain exact for pond_v2.

Godot read-only Dictionary/Array flags do not protect a nested PackedVector2Array. Consequently context private caches are never exposed directly. All collection getters and record lookups return deep detached exports; scalar and ID-based geometry queries use private caches. World exports targets, net blockers, spawn blockers, fish occluders and vegetation rectangles once when installing a context, then reuses those arrays throughout the round. No tick reparses data, validates/hashes the map, rebuilds polygons or requests another large collection export. Existing mutable `targets` test/compatibility records remain detached from the context.

The immutable context is an application ownership boundary, not a sandbox against arbitrary scripts accessing underscore-prefixed implementation members. Production consumers use its public API; tests verify all public exports, nested dictionaries/packed arrays, input mutation and property replacements cannot change context truth.

## Migrated consumers

| Consumer | Map source |
| --- | --- |
| World player spawn, home arrival/recovery | context anchors |
| Initial bait shuffle and lifecycle positions | detached ordered context bait sites; unchanged shuffle and hook/food draws |
| Bait suction / player free and hooked bounds | context water with existing radius/margins |
| NPC spawn / social movement / hook movement | map-relative spawn policy, cached spawn blockers, context fish bounds |
| Contact, fade, wrap selection and coils | stable targets, independent contact_fade/rope_anchor flags, MapGeometry |
| Net placement, route collisions and visible-fish masking | context net_area, separate net_blocking and fish_occluding lists |
| Vegetation movement drag / net cover | three independent context drag rectangles, never the 22 plant targets |
| Angler patrol, walk/cursor/cast/free tackle and surface clamps | context water/floor with preserved gameplay offsets |
| Fish AI flee/target/home and visible loose-food selection | context bounds/home and rope capability; Authority explicitly supplies water to observation |

Targets are never filtered or sorted to build the main index array. Capability caches filter without changing target identity or compatibility indexes. Fade grouping comes from explicit feature IDs; a non-self grass group is respected while the built-in self-group grass keeps its original missing legacy `fade_group` key. `fish_passable` records the existing pass-through policy; this stage does not invent behavior for false. `grass_binding` and `shore_visible` remain presentation metadata for later migration.

NPC's three historical ecology regions are now positioned/sized relative to the selected water. The original region proportions are gameplay tuning. Calculations multiply and divide double scalars before constructing Vector2 values, recovering every pond integer edge exactly and therefore preserving candidate coordinates and independent NPC RNG consumption. Candidates must remain within the selected fish bounds; the preexisting 64-attempt, home/bait/neighbour clearance and spent-ID behavior are retained.

## Deliberate remaining compatibility boundaries

- Snapshot remains schema15 with fixed `map_id = pond_v2`; public role formats and handshake are unchanged. Different-map snapshot/network interoperability is not supported or claimed. `World.Layout` and `World.SOLIDS` remain compatibility aliases for old callers, not Authority data sources
- `npc_fish_state.valid` retains its fixed-map bounds because it is a schema15 restore validator. FishObservation's optional two-argument helper has a once-loaded validated built-in-water default for the unchanged network adapter; Authority passes the context water explicitly
- Pond camera, pond/shore/scenery/art, visual grass deformation and projection remain legacy consumers. Fixture maps are deliberately not rendered or offered to players
- Rope receives context-derived obstacle geometry through Net. Its preexisting route-node policy `x = 9..631`, `y <= 309` remains unchanged to avoid changing current pond route results. This limits arbitrary-map exit routing and is a documented P4.5 hardcode item, not a completed generic Rope claim
- Small/extreme maps are not proved playable merely because structural validation passes. New fish-blocking semantics, spawn feasibility, route feasibility and generation reachability belong to later work
- The inherited same-tick observation-toggle + both net endpoints integer-age/fish-wire rejection is unchanged. Ordinary staged inputs and the retained negative diagnostic are reported separately

## Independent evidence and next gate

The immutable 0.26.0 source used here is `0a3e5af3dc3ca26f0909644505ff24a1de1fe06d`, tree `3bc012c3e84f2ad79872757c7d574c3a0234dab1`, including the user's release documentation and Python 3.11 extraction fix. The new differential driver preserves the original external behavior harness rather than regenerating an old model from the new context. Existing P4.1 source-lock logic remains unchanged as a historical gate.

See [0.26.1 validation and manual gate](../test-reports/PHASE04-MAP-AUTHORITY-0.26.1.md) for actual runs, assertion counts, pixels, failure boundaries and source hashes. Completing this stage stops before P4.3; automatic equivalence does not replace the user's feel/dual-role playtest.
