# Phase 4.1 MapDefinition contract v1

## Scope and ownership

0.26.0 implements **P4.0 + P4.1 only**, following the new 2026-10-04 specification §79/§88 after the user accepted Phase 3. The built-in definition is not yet used by World, Snapshot, Network or Presentation. Those consumers still run the byte-preserved legacy `pond_layout.gd`; the only existing runtime changes are release display/log/build strings. No generated geometry, map menu, Watergen merge, new biome, multi-rod or memory behavior is authorized here.

Frozen baseline: `9d11fe8ae4bb7a49abe5fcd0e6f518ed0ebd3a92`, tree `377f935c054e6204d0b84075ef7b69cb72b5d6e1`, 0.25.5. It includes the user's Windows fingerprint correction and 0.25.5 release documentation. Historical reports retain their original gate status; Phase 3 acceptance is recorded in this new entry rather than backdated.

## API

- `PondV2Map.create()` constructs detached value data, including its Authority SHA-256
- `MapDefinition.canonical(definition)` returns a deterministic string for structurally valid contract-v1 data
- `MapDefinition.content_hash(definition)` hashes that canonical string
- `MapDefinition.map_ref(definition)` returns detached meta values; it is only a data API in P4.1, not a wire/snapshot format migration
- `MapValidator.validate(value)` returns `{valid, errors}` with no mutation, RNG, logging, scene loading or world effects
- `MapRegistry.load_map(id = "pond_v2", revision = 1)` returns `{valid, errors, definition}`; invalid/unknown lookup has an empty definition
- `MapRegistry.available_refs()` exposes only the validated built-in ref, detached on every call

Low-level canonical/hash helpers require structurally valid input. Validator checks structure first and only then recomputes the hash. Registry validates before returning a definition. Returned Dictionaries are mutable detached values, **not an immutable round context**: MapContext freezing and runtime caching belong to P4.2. New gameplay code must not add dependencies on the legacy facade or begin consuming this foundation before that gate.

## Value schema

| Field | Contract v1 |
| --- | --- |
| `meta` | `id: String`, positive integer `revision`, integer `contract_version = 1`, 64-character lowercase hexadecimal `content_hash` |
| `bounds` | positive `size: Vector2`, `water: Rect2`, `floor_y: number`, `net_area: Rect2`, ordered `vegetation_drag_zones: Array[Rect2]` |
| `anchors` | `player_spawn: Vector2`, `home: Vector2` |
| `bait_sites` | ordered distinct Vector2 positions, enough for the current four lifecycle slots |
| `interaction_features` | ordered feature records below; current pond has 40 |
| `visual_features` | `{id, kind: "solid"/"plant", legacy: Dictionary}` records retaining existing authoring values |
| `presentation` | `visual_profile_id: String`, `wood_groups: Array[Array[int]]` with old wood seed groups |

Feature records have exact fields: `id`, `kind` (`wood`, `stone`, `grass`), `compatibility_index`, `shape = {type: "polygon", points: PackedVector2Array}`, eight explicit Boolean `capabilities`, `fade_group_id`, `presentation_ref`. IDs are authored semantic names, not derived from the current index. `compatibility_index` is transitional ordering and must match the array position. Fade-group IDs resolve to a self-referencing representative. Visual references resolve by ID.

The new provider copies every legacy constant value into its own built-in data. It does not import or call PondLayout. The legacy file remains unchanged to provide an independent golden comparison and maintain the running game.

## Audited capabilities

| Capability | 18 wood/stone | 22 grass targets |
| --- | --- | --- |
| `fish_passable` | true | true |
| `net_blocking` | true | false |
| `rope_anchor` | true | true |
| `contact_fade` | true | true |
| `grass_binding` | false | true |
| `shore_visible` | true | true |
| `npc_spawn_blocking` | true | false |
| `fish_occluding` | true | false |

These express existing consumer behavior; no consumer has been rewritten to use them. Fish movement passes through solids, while NPC spawning excludes solids. `grass_binding` describes existing presentation-only stem deformation. Authority rope targets retain the exact legacy polygons. `shore_visible` is eligibility for existing shore drawing, not a promise that an object is on screen.

The **three `GRASS` Rect2 zones are separate Authority data**. They affect player movement and net observation visibility; they are not the 22 plants or their target silhouettes. They are saved and hashed under `bounds.vegetation_drag_zones` without merging/recomputing. Plant authoring fields are retained as presentation metadata, while their already-derived interactive polygons are hashed as Authority.

## Canonical grammar and hash

Canonical UTF-8 text starts with `baitbreak-map-contract-v1\n`, followed by a JSON array with this fixed positional grammar:

1. contract version
2. bounds array: size, water, floor_y, net_area, vegetation-drag zones
3. anchors array: player_spawn, home
4. bait sites in current order
5. interaction features in current order: ID, kind, compatibility index, shape type, ordered polygon points, fixed-order capability booleans, fade-group ID

A point is `[x, y]`; a rectangle is `[position, size]`. Every scalar geometry number is encoded as its exact IEEE-754 double **little-endian 8-byte lowercase hex string**. Int/float representations of the same number normalize; negative zero normalizes to positive zero. No decimal precision rounding, Dictionary iteration, Object identity, `var_to_bytes(dictionary)` or engine Variant hash participates. JSON contains only explicit arrays, strings, integers and booleans. SHA-256 is computed over this exact UTF-8 text.

Array ordering is deliberate Authority data during index compatibility. Do not sort features by ID, reorder bait sites or rotate polygon vertices merely for aesthetics. Dictionary insertion order is ignored. Numeric geometry is preserved exactly rather than snapped or quantized.

Hash includes all map-affecting geometry, feature identity/kind/order, eight capabilities, and the existing world target-state fade grouping. Fade grouping is conservatively included because the current world captures target opacity by index; cosmetic color/texture values remain separate.

Hash excludes meta id/revision/hash (these are independently checked map identity), feature `presentation_ref`, `visual_features`, and `presentation`. Thus a texture seed, material name, decorative appearance, visual ordering/profile or visual seed cannot change Authority compatibility. No actual Texture/Image/Node/Resource/Callable may enter the value graph, including script-typed empty containers. Unknown Authority fields reject rather than being silently unhashed.

Current pond_v2 revision1 contract1 hash:

`794aea6774b6a6626a1f56a58a1e0db0811c30eb60ac35eb9c2f472788fa5ef4`

The first-stage tests establish same-process, cross-process and Dictionary-order stability. The report distinguishes tested engines/hosts from untested architectures; the explicit encoding is intended for portability, not a claim that every machine was exercised.

## Validation boundaries

Validation is pure and bounded: container/value/depth/string ceilings, supported types, finite numbers, exact field keys, unique IDs, required references and stable compatibility indexes. Geometry requires positive map/water/net extents, water within map, net area within water, floor between water bottom and map bottom, anchors/sites within the existing half-open water bounds, and distinct sites.

Feature polygons require 3–128 finite vertices, map containment, nonzero area, no consecutive duplicates/zero-length edges and no crossing/nonadjacent touching edges. Whole-map containment is intentional: old solid x=6 lies outside water x=8, and solids/plants/drag zones extend to floor433 beyond water bottom431. Do not reject the unchanged pond by applying water containment to all cover.

The fixture used by adversarial tests is not registered or selectable. This is not reachability, food-supply feasibility, arbitrary terrain acceptance or a generated-map solver. Any future widening of the contract needs explicit tests/version review. Hash authenticity is not cryptographic origin/signature trust; it detects content mismatch only.

## Next gate

Stop after this data foundation. P4.2 may later introduce MapContext, cached MapGeometry, World initialization and Authority consumers, with independent old/new simulation/RNG/observation equality. Snapshot schema16/map_ref handshake comes after that; current schema15 and the existing protocol are unchanged except exact BUILD=0.26.0. Presentation migration, fixture consumers and final human equivalence remain later gates.
