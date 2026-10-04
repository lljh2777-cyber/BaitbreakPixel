# Phase 4 final map abstraction · 0.26.4

## Scope and status

The user authorized completing the remaining P4.4–P4.6 work and its own tests continuously. This supersedes intermediate stop gates in older stage reports, which remain historical records. The engineering endpoint is a map-backed version of the same built-in `pond_v2`, not a new player map. Automated gates and remaining human-playtest limits are recorded in [the final validation report](../test-reports/PHASE04-MAP-FINAL-0.26.4.md).

The registry still exposes exactly `pond_v2`, revision 1, contract 1. Its authoritative geometry, order, capabilities and content hash are unchanged. Authority snapshot schema 16 and the role-specific wire formats remain unchanged; exact network BUILD is now 0.26.4. No procedural geometry, map-selection UI, new assets, Watergen merge, multi-rod or fish memory was added. This work only commits source, tests, documentation and selected evidence; it does not create an executable package or Release.

## Presentation data ownership

`MapPresentation.for_context(context)` exports the immutable context once into a cached read-only presentation adapter. It resolves `presentation_ref` by stable ID, not visual-array position. Each solid and plant retains its explicit authority `target_index`; plant binding does not subtract a fixed solid count. Group opacity remains the minimum of the corresponding original target opacities. Shore eligibility reads `shore_visible`; grass deformation reads `grass_binding`.

The adapter preserves all existing authored fields and exact polygon/target ordering. Its nested Dictionary/Array containers are read-only, including polygon point Arrays; mutable packed arrays are not exposed through the shared render cache. Public geometry comes from the context, while material seeds and plant art fields remain presentation-only.

Cache identity is the actual context, not its gameplay hash. Two definitions with the same authoritative hash may intentionally carry different visuals. A weak reference prevents the cache from retaining every finished world; stale entries are pruned when another context is installed. An equivalent new-round adapter can reuse prepared textures by comparing exported render values only when the context changes. Unchanged frames do not export polygons, rebuild bounds/textures, validate or hash the map.

`PondView.prepare_map` follows the displayed world, including the network replica. All map-specific water/depth layers, props and plant frames refresh together when needed. HOME navigation/progress, scenery, shadows and nest drawing use that same context. The logical HUD remains 640×360.

## Camera and projection

Camera extents use `max(map.size − viewport, 0)`. The observation camera's vertical travel also derives from map height, so taller maps can move beyond the former 120-pixel limit and maps smaller than the viewport never yield negative offsets.

Shore remains the existing pond-style projection. Its width, floor and water-surface reference derive from the selected context; surface is the established art offset `water.top − 13`, rather than the fish-boundary top itself. The arithmetic order, screen-space origin, perspective coefficients and rod geometry remain unchanged for pond_v2. Every production projection call now forwards the displayed world, including carried-net motion and fish direction. Historical no-world art/projection APIs explicitly select the registry default, while production paths always supply the current context.

The existing authored legacy depth rocks, leaves, beams and wood-spine coordinates remain a `legacy_pond` visual profile. They are not generic map bounds or authority geometry and do not appear in the unrelated fixture profile. Generic canvases, floor/water extents, particles and interaction silhouettes consume context dimensions. No new biome art is implied.

## Remaining authority/network dependency cleanup

- `World.Layout` and `World.SOLIDS` compatibility aliases were removed. Live scripts no longer import `pond_layout.gd`; that file remains independent legacy golden data with an explicit prohibition on new gameplay dependencies
- Network command sanitization requires the selected context. Both held cursor targets and reliable net-point events clamp against its size, after unchanged admission/timing checks
- Private/public NPC validators require explicit water bounds; there is no silent default-pond validator path
- Fish observation facts require explicit water. Both fish-network capture and validation now use the authority/resolved context water, fixing the last default-pond loose-food hint assumption without widening the public field allowlist
- The single production rope-detour caller supplies map-relative route-node limits. The existing node order, clipping and shortest-path algorithm remain unchanged

The inherited rope policy admitted only nodes in a western/shallow window. Its exact pond limits `(min_x=9, max_x=631, max_y=309)` are preserved by explicit water-relative policy: `water.left + 1`, `water.left + water.width × 623 / 1264`, and `water.top + water.height × 241 / 363`, calculated multiply-before-divide. These fractions preserve historical behavior tuning; they do not assert that arbitrary generated maps are reachable. The route cache also distinguishes limits, so equal obstacle data and anchor on another map cannot reuse the wrong filtered node set. Generated-map reachability is Phase 5 work.

## Test-only map and information boundaries

`tests/fixtures/phase04/fixture_rect_small.gd` authors an 800×360 map with shifted water, floor324, moved HOME/SPAWN, six sites and three stable wood/stone/grass features. It is absent from MapRegistry and export presets. Additional undersized, taller and shifted fixtures exercise camera and routing assumptions. A fixture can initialize an isolated test world, but snapshot and network admission deliberately reject its unregistered MapRef before mutation.

The real Main-scene native fixture covers fish view, HOME, shore, observation, net warning/sweep and return to the original pond. Every render preserves complete captured authority/RNG; an equivalent pond reset and a pond→fixture→pond roundtrip require all viewport pixels to match exactly. These fixtures are tests, not a hidden player map menu or a claim of generated-map playability.

## Explicit inherited net correction

`Net.begin_observation` formerly put integer `0` into dictionary field `net_action.age`. A same-tick toggle/A/B batch could commit before age advanced, leaving fish public packets rejected by the existing strict float guard. The producer now assigns `0.0`; the guard is unchanged. Before/after reproduction is retained separately from standard scenario equivalence, and injected integer-age packets still reject atomically. No timing, collision, route, QTE or NPC-capture rule was relaxed.

## Final proof design

The final driver freezes real commit `7efe59b5974a0da0042600c5817e66b3c2d23616` and runs one identical external harness under each project's actual `res://` root. The five scenario/setup/input/intervention functions are byte-locked to the original P4.0 tape. It compares each full authority tick and each checkpoint's full snapshot, RNG, fish/NPC observations, bait, Hook/QTE/wrap, net, statistics, and role wire bytes. Unlike the schema-transition stage, there are no map/schema metadata exclusions. Gzip is storage for raw framed bytes, not a replacement for content comparison.

Native evidence uses complete decoded RGBA pixels and unchanged original gameplay assertions. Source provenance uses pinned Git objects and direct source bytes. No bulk SHA256 source/image inventory is generated. The meaningful map-content hash and Git publication object identities retain their separate purposes.

Human feel, two physical machines/public-internet transport, Windows packaged execution and actual sound hardware remain outside this cloud automated proof. The final checklist is delivered after the authorized engineering work; it is not an intermediate stop gate and does not imply Phase 5 authorization.
