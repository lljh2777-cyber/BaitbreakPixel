# Generated Ponds — Phase 5 / 0.27.5

## Runtime boundary

MapGenerationRequest → GeneratedPondV1 → MapValidator + MapPlayabilityValidator → existing MapDefinition → MapResolver → immutable MapContext → ordinary WorldSimulation.

No generated-world implementation, remote polygon transfer or gameplay branch per obstacle was introduced. Geometry, bait-site candidates and stable target/fade IDs are generated independently of the simulation RNG. The v1 recipe remains the original five scalar fields. The prototype's three pinned hashes remain unchanged.

The fixed balanced_pond_v1 envelope is 1280×480 with six bait sites and protected home/spawn/center/net regions. Admission includes bounded counts, density, NPC spawn clearance, distributed rope anchors, six proven clear net lift corridors and mixed open/blocked net lanes. These conservative spatial guarantees complement actual collision/routing and full-round tests; they do not prove human balance.

## Source, identity and routing

Built-in source: `{kind:"built_in", id:"pond_v2", revision:1}`.

Generated source: `{kind:"generated", generator_id:"generated_pond", generator_version:1, gameplay_profile:"balanced_pond_v1", map_seed:42}`.

MapRef remains `{id, revision, contract_version, content_hash}`. Map Contract stays at 1; routing policy is derived from the strictly validated source. Built-in routing keeps (9,631,309), generated routing uses (9,1271,430). Arbitrary test-only maps still fail production reference resolution.

MapResolver retains at most 16 immutable generated contexts. Setup regenerates and validates a missing context; network tick identity checks compare strict scalars against the selected recipe/reference, without regenerating or hashing geometry each tick.

## Persistence and network

Authority Snapshot schema17 and fish presentation schema3 require both recipe and MapRef. Restore regenerates (or uses a previously validated immutable cache), validates, checks exact identity, validates state, then installs. Unsupported schemas, generator versions, profiles, seeds, missing identity or hash mismatch fail before World mutation.

ENet requires exact build. The client's hello identifies its local valid map/build. The host's welcome selects the round recipe and reference. The client resolves these before enabling Ready. Ready/start/start_ack/state are bound to the selected recipe and reference. Both roles keep their existing information boundaries; generation metadata does not add hook truth, private NPC state or RNG to fish packets.

## Presentation

Watergen modules were selectively ported from feature/watergen 63112b1. WatergenPublicAdapter receives only MapContext and public presentation metadata. PublicMapContext v2 permits generated map IDs. It contains no World or actor reference.

Visual seed and the two-bundle GPU cache live in PondView. Named visual streams use explicit integer seed mixing, with no per-object SHA256 derivation. Pixel and state tests use direct comparisons. Only map/profile identity digests remain. Background relief is muted decoration; original geometry-driven wood/stone/interactive grass sprites and joined-tree opacity remain authoritative for visual interaction cues. Generic wood material centerlines now derive from actual generated polygons.

Classic rendering remains available. Generated rendering falls back to the existing geometry-driven scenery if a visual asset cannot prepare, reporting the failure without changing Authority.

## Player entry

Title → map button → classic/generated → manual/random/copy Seed. A saved map preference is local. R and ordinary replay retain it; New Map explicitly selects a new independent seed. Host settings carry the selected recipe, and the room displays Seed/generator version. Map selection is locked while connected. The developer `--map-seed=42` startup option remains available.

## Validation and limits

See [the completion report](../test-reports/PHASE05-COMPLETION.md) for automated and native results, 10,000 structural seeds, the 1,000-round matrix, extreme-seed corpus and playable package details. Source-only helpers are excluded from the PCK; JSON visual profiles are explicitly included.

The statistical controllers and image inspection cannot certify subjective map fairness or enjoyment. Final human acceptance in specification §52 remains the user's playtest decision. Multiple rods and cross-round fish memory remain outside P5.


## 0.28.0 — solid relief (generator v2)

New player selections use `generator_version:2`, `gameplay_profile:relief_pond_v2`, and Map Contract 2. V1 recipes, canonical geometry and classic behavior stay supported and unchanged. The explicit version arguments on Request.create / Resolver.generated select v2; their default 1 remains available to existing P5 fixtures/tools. Saved v1 selections stay v1 until the user applies a new selection.

Contract 2 adds a bounded, ordered `bounds.floor_profile` polyline. Its vertices are part of canonical Authority identity. `PondBed` supplies exact circle clearance against adjacent segments; player and NPC movement is substepped against the same surface. Tackle and detached/attached food are constrained above it. The bed is a separate net blocker, never a rope-anchor target or fading cover. Net planning, sweep and return use the original polygon solver with the bed included.

Wood groups remain joined; cover tops and six bait bands retain protected clearance. The v2 generator builds up to three broad rises, with the original low bed between them, and leaves the nest approach flat. Retry count stays bounded at 32; failures do not fall back to another map.

The view bakes an opaque soil layer from MapContext once per map and includes its profile in presentation cache matching. Both the fish view and observation view show the collision rim; shore view projects the same polygon. Watergen public v3 carries only the height polyline alongside the existing public metadata; v2 remains supported for flat maps. Ecology preview roots follow this public bed. New WG-6.2 decorative communities remain preview-only.

Snapshot schemas remain 17/3: recipe + MapRef reconstruct all geometry locally before installing state. Network exact-build is 0.28.0. No terrain or actor RNG is carried in a visual seed. Validation and limitations: [0.28.0 report](../test-reports/TERRAIN-0.28.0.md).
