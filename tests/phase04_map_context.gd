extends SceneTree

const Context = preload("res://scripts/maps/map_context.gd")
const Geometry = preload("res://scripts/maps/map_geometry.gd")
const Definition = preload("res://scripts/maps/map_definition.gd")
const PondV2 = preload("res://scripts/maps/pond_v2_map.gd")
const Legacy = preload("res://scripts/pond_layout.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error("MAP_CONTEXT_FAIL | " + label)

func _init() -> void:
	var loaded := Context.load_map()
	check(loaded.valid and loaded.errors.is_empty() and loaded.context != null,"built-in loads through checked factory")
	if not loaded.valid: quit(1); return
	var context: RefCounted = loaded.context
	equivalence(context)
	detachment(context)
	capability_filtering()
	plain_array_contract()
	shared_grass_group()
	invalid_inputs()
	rng_isolation()
	print("PHASE04_MAP_CONTEXT | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)

func equivalence(context: RefCounted) -> void:
	check(context.id == "pond_v2" and context.revision == 1 and context.contract_version == 1,"map identity exact")
	check(context.content_hash == "794aea6774b6a6626a1f56a58a1e0db0811c30eb60ac35eb9c2f472788fa5ef4","existing Authority hash unchanged")
	check(context.map_ref == PondV2.create().meta,"complete map ref exact")
	check(context.size == Legacy.SIZE and context.water == Legacy.WATER and context.floor_y == Legacy.FLOOR,"map bounds exact")
	check(context.net_area == Legacy.NET_AREA and context.player_spawn == Legacy.SPAWN and context.home == Legacy.HOME,"net and anchors exact")
	check(context.bait_sites == Legacy.BAIT_SITES,"bait positions and ordering exact")
	check(context.vegetation_drag_zones == Legacy.GRASS,"three drag rectangles remain independent from grass targets")
	for radius: float in [0.0,7.0,12.0,17.0,31.5]:
		check(context.fish_bounds(radius) == Legacy.fish_bounds(radius),"fish radius inset exact " + str(radius))
	var expected := Legacy.interaction_targets()
	var actual: Array[Dictionary] = context.interaction_targets
	check(context.target_count() == expected.size() and actual.size() == expected.size(),"complete ordered target count")
	for index in expected.size():
		var reference: Dictionary = expected[index]
		var target: Dictionary = actual[index]
		check(target.keys().slice(0,reference.size()) == reference.keys(),"legacy field insertion order " + str(index))
		for key in reference:
			check(target.has(key) and target[key] == reference[key],"legacy target %d %s exact" % [index,key])
		check(target.has("fade_group") == reference.has("fade_group"),"no new fade_group on grass " + str(index))
		check(target.compatibility_index == index and not target.id.is_empty(),"explicit stable identity and compatibility index " + str(index))
		check(context.target_by_id(target.id) == target,"cached target lookup " + str(index))
		check(context.feature_by_id(target.id) == context.interaction_features[index],"cached feature lookup " + str(index))
		check(context.feature_bounds(target.id) == target.bounds,"cached bounds lookup " + str(index))
		check(Geometry.polygon_bounds(target.polygon) == reference.bounds,"generic cached bounds exact " + str(index))
		for point: Vector2 in [reference.bounds.position,reference.bounds.get_center(),reference.bounds.end,Vector2(-50,-50),Vector2(1500,600)]:
			check(Geometry.coil_at(target,point) == Legacy.coil_at(reference,point),"coil all values/loop order exact " + str(index))
			check(context.coil_at(target.id,point) == Legacy.coil_at(reference,point),"cached coil query exact " + str(index))
			check(Geometry.nearest_boundary(point,target.polygon) == Legacy.nearest_boundary(point,reference.polygon),"nearest boundary tie-break exact " + str(index))
			check(context.nearest_feature_boundary(target.id,point) == Legacy.nearest_boundary(point,reference.polygon),"cached boundary query exact " + str(index))
			for radius: float in [0.0,12.0,17.0]:
				check(Geometry.touches(point,radius,target.polygon) == Legacy.touches(point,radius,reference.polygon),"touches exact " + str(index))
				check(context.touches_feature(target.id,point,radius) == Legacy.touches(point,radius,reference.polygon),"cached touches exact " + str(index))
	for collection: Array in [context.net_blockers,context.npc_spawn_blockers,context.fish_occluders]:
		check(collection.size() == Legacy.SOLIDS.size(),"solid-only capability count")
		for index in collection.size():
			check(collection[index].points == Legacy.SOLIDS[index].points,"Rope points adapter exact " + str(index))
			check(collection[index].polygon == expected[index].polygon,"cached polygon exact " + str(index))
	check(not context.has_feature("unknown") and context.feature_by_id("unknown").is_empty() and context.target_by_id("unknown").is_empty(),"unknown lookup explicit empty values")
	check(not context.touches_feature("unknown",Legacy.SPAWN,12) and context.coil_at("unknown",Legacy.SPAWN).is_empty(),"unknown ID geometry fails closed")
	check(context.feature_bounds("unknown") == Rect2() and context.nearest_feature_boundary("unknown",Legacy.SPAWN) == Vector2(INF,INF),"unknown geometry cannot masquerade as known target")

func detachment(context: RefCounted) -> void:
	var source := PondV2.create()
	var created := Context.from_definition(source)
	check(created.valid,"definition factory checked success")
	var isolated: RefCounted = created.context
	var before: Array[Dictionary] = isolated.interaction_targets
	var first_id: String = before[0].id
	var first_point: Vector2 = before[0].polygon[0]
	source.meta.id = "mutated_source"
	source.bounds.water = Rect2(1,2,3,4)
	source.anchors.home = Vector2.ZERO
	source.bait_sites[0] = Vector2.ZERO
	source.interaction_features[0].shape.points[0] = Vector2.ZERO
	source.interaction_features[0].capabilities.net_blocking = false
	source.visual_features[0].legacy.points[0] = Vector2.ZERO
	check(isolated.id == context.id and isolated.water == context.water and isolated.home == context.home,"source scalar/nested mutation isolated")
	check(isolated.interaction_targets == before and isolated.bait_sites == context.bait_sites,"source packed/array mutation isolated")
	var targets: Array[Dictionary] = isolated.interaction_targets
	var polygon: PackedVector2Array = targets[0].polygon
	polygon[0] = Vector2(-900,-800)
	targets[0].capabilities.rope_anchor = false
	targets[0].bounds = Rect2()
	targets.reverse()
	check(isolated.interaction_targets == before,"export target nested array/dict/packed edits cannot modify cached context")
	for collection: Array in [isolated.net_blockers,isolated.npc_spawn_blockers,isolated.fish_occluders]:
		collection[0].points[0] = Vector2.ZERO
		var points: PackedVector2Array = collection[0].polygon
		points[0] = Vector2.ZERO
		collection[0].capabilities.net_blocking = false
		collection.clear()
	check(isolated.net_blockers == context.net_blockers and isolated.npc_spawn_blockers == context.npc_spawn_blockers and isolated.fish_occluders == context.fish_occluders,"all filtered packed caches detached")
	var features: Array[Dictionary] = isolated.interaction_features
	features[0].shape.points[0] = Vector2.ZERO
	features[0].capabilities.fish_occluding = false
	var looked_up: Dictionary = isolated.feature_by_id(first_id)
	looked_up.shape.points[0] = Vector2.ONE
	var target_lookup: Dictionary = isolated.target_by_id(first_id)
	target_lookup.polygon[0] = Vector2.ONE
	var baits: Array[Vector2] = isolated.bait_sites
	baits.clear()
	var drag: Array[Rect2] = isolated.vegetation_drag_zones
	drag[0] = Rect2()
	var visuals: Array[Dictionary] = isolated.visual_features
	visuals[0].legacy.points[0] = Vector2.ONE
	var presentation: Dictionary = isolated.presentation
	presentation.wood_groups[0][0] = -9
	var reference: Dictionary = isolated.map_ref
	reference.id = "other"
	check(isolated.feature_by_id(first_id).shape.points[0] == first_point,"feature and lookup packed writes isolated")
	check(isolated.target_by_id(first_id) == before[0] and isolated.feature_bounds(first_id) == before[0].bounds,"cached lookup/bounds stable after mutations")
	check(isolated.bait_sites == context.bait_sites and isolated.vegetation_drag_zones == context.vegetation_drag_zones,"scalar Array exports detached")
	check(isolated.visual_features == context.visual_features and isolated.presentation == context.presentation,"nested presentation exports detached")
	check(isolated.map_ref == context.map_ref,"map ref detached")
	isolated.id = "not_pond"
	isolated.revision = 99
	isolated.contract_version = 99
	isolated.content_hash = "not_a_hash"
	isolated.size = Vector2.ONE
	isolated.water = Rect2()
	isolated.floor_y = 1.0
	isolated.net_area = Rect2()
	isolated.player_spawn = Vector2.ZERO
	isolated.home = Vector2.ZERO
	isolated.map_ref = {}
	var empty_points: Array[Vector2] = []
	var empty_records: Array[Dictionary] = []
	var empty_rects: Array[Rect2] = []
	isolated.bait_sites = empty_points
	isolated.interaction_targets = empty_records
	isolated.interaction_features = empty_records
	isolated.net_blockers = empty_records
	isolated.npc_spawn_blockers = empty_records
	isolated.fish_occluders = empty_records
	isolated.vegetation_drag_zones = empty_rects
	isolated.visual_features = empty_records
	isolated.presentation = {}
	check(isolated.map_ref == context.map_ref and isolated.size == context.size and isolated.water == context.water,"identity/bounds property writes ignored")
	check(isolated.floor_y == context.floor_y and isolated.net_area == context.net_area and isolated.player_spawn == context.player_spawn and isolated.home == context.home,"anchor/net property writes ignored")
	check(isolated.interaction_targets == before and isolated.bait_sites == context.bait_sites and isolated.visual_features == context.visual_features,"collection property replacement ignored")
	check(isolated.touches_feature(first_id,first_point,12) == context.touches_feature(first_id,first_point,12),"internal query unaffected by all exposed edits")

func capability_filtering() -> void:
	var definition := PondV2.create()
	definition.meta.id = "test_capabilities"
	definition.interaction_features[0].capabilities.net_blocking = false
	definition.interaction_features[18].capabilities.net_blocking = true
	definition.interaction_features[1].capabilities.npc_spawn_blocking = false
	definition.interaction_features[19].capabilities.npc_spawn_blocking = true
	definition.interaction_features[2].capabilities.fish_occluding = false
	definition.interaction_features[20].capabilities.fish_occluding = true
	definition.visual_features.reverse()
	definition.meta.content_hash = Definition.content_hash(definition)
	var loaded := Context.from_definition(definition)
	check(loaded.valid,"capabilities fixture valid without registry registration")
	if not loaded.valid: return
	var context: RefCounted = loaded.context
	var net: Array[Dictionary] = context.net_blockers
	var npc: Array[Dictionary] = context.npc_spawn_blockers
	var vision: Array[Dictionary] = context.fish_occluders
	check(net.size() == 18 and net[0].compatibility_index == 1 and net[-1].compatibility_index == 18,"net uses flags and retains source ordering, including grass")
	check(npc.size() == 18 and npc[1].compatibility_index == 2 and npc[-1].compatibility_index == 19,"NPC spawning uses its own flags")
	check(vision.size() == 18 and vision[2].compatibility_index == 3 and vision[-1].compatibility_index == 20,"fish visibility uses its own flags")
	check(context.target_by_id("wood_root_trunk").name == "枯木","presentation references resolve by ID after visual reorder")
	check(context.interaction_targets.size() == 40,"capability filtering does not reorder/drop compatibility targets")

# Contract-v1 accepts both typed and ordinary Array containers. Typed runtime
# exports must work for every structurally valid definition, not just PondV2.
func plain_array_contract() -> void:
	var definition := PondV2.create()
	for key: String in ["bait_sites","interaction_features","visual_features"]:
		var plain: Array = []
		for entry in definition[key]: plain.append(entry)
		definition[key] = plain
	var plain_zones: Array = []
	for zone in definition.bounds.vegetation_drag_zones: plain_zones.append(zone)
	definition.bounds.vegetation_drag_zones = plain_zones
	var loaded := Context.from_definition(definition)
	check(loaded.valid,"ordinary Array containers remain valid contract data")
	if not loaded.valid: return
	var context: RefCounted = loaded.context
	check(context.bait_sites == Legacy.BAIT_SITES,"ordinary bait Array produces typed snapshot")
	check(context.vegetation_drag_zones == Legacy.GRASS,"ordinary zone Array produces typed snapshot")
	check(context.interaction_features.size() == 40 and context.visual_features.size() == 40,"ordinary record Arrays produce typed snapshots")

func shared_grass_group() -> void:
	var definition := PondV2.create()
	definition.interaction_features[18].fade_group_id = definition.interaction_features[20].id
	definition.interaction_features[1].fade_group_id = definition.interaction_features[20].id
	definition.meta.content_hash = Definition.content_hash(definition)
	var loaded := Context.from_definition(definition)
	check(loaded.valid,"shared cross-kind grass representative is valid")
	if not loaded.valid: return
	var context: RefCounted = loaded.context
	var targets: Array[Dictionary] = context.interaction_targets
	check(targets[18].fade_group == 20 and targets[1].fade_group == 20,"explicit fade representative used independently of target kind")
	check(not targets[20].has("fade_group"),"self-grouped grass retains legacy absence of numeric group")

func invalid_inputs() -> void:
	for lookup: Array in [["unknown",1],["pond_v2",2],["pond_v2",0]]:
		var loaded := Context.load_map(lookup[0],lookup[1])
		check(not loaded.valid and not loaded.errors.is_empty() and loaded.context == null,"unknown built-in identity rejected before context")
	for value in [null,{},[],"pond_v2",{"meta":{}}]:
		var invalid := Context.from_definition(value)
		check(not invalid.valid and not invalid.errors.is_empty() and invalid.context == null,"malformed definition rejected")
	var definition := PondV2.create()
	definition.interaction_features[0].shape.points[0] = Vector2(NAN,1)
	var bad := Context.from_definition(definition)
	check(not bad.valid and bad.context == null,"nonfinite polygon rejected")
	definition = PondV2.create()
	definition.bait_sites[0].x += 1
	bad = Context.from_definition(definition)
	check(not bad.valid and bad.context == null,"stale Authority hash rejected")
	definition = PondV2.create()
	definition.meta.content_hash = "0".repeat(64)
	bad = Context.from_definition(definition)
	check(not bad.valid and bad.context == null,"declared wrong hash rejected")

func rng_isolation() -> void:
	seed(491822)
	var expected := randf()
	seed(491822)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 912237
	var before: int = local_rng.state
	for index in 3:
		var loaded := Context.load_map()
		var context: RefCounted = loaded.context
		context.fish_bounds(12)
		context.touches_feature("wood_root_trunk",Vector2(330,220),12)
		context.coil_at("wood_root_trunk",Vector2(330,220))
		Context.from_definition({"invalid":true})
		Context.load_map("unknown")
	check(randf() == expected,"map load/validation/geometry consume zero global RNG")
	check(local_rng.state == before,"map work does not change caller RNG state")
