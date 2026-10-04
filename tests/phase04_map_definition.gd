extends SceneTree

const Definition = preload("res://scripts/maps/map_definition.gd")
const PondV2 = preload("res://scripts/maps/pond_v2_map.gd")
const Registry = preload("res://scripts/maps/map_registry.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const Legacy = preload("res://scripts/pond_layout.gd")
const World = preload("res://scripts/world_simulation.gd")
const POND_V2_REVISION_1_HASH := "794aea6774b6a6626a1f56a58a1e0db0811c30eb60ac35eb9c2f472788fa5ef4"
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error("MAP_DEFINITION_FAIL | " + label)

func reversed_dictionaries(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.reverse()
		for key in keys: result[key] = reversed_dictionaries(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child in value: result.append(reversed_dictionaries(child))
		return result
	return value

func reconstructed_targets(definition: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var indexes := {}
	for feature: Dictionary in definition.interaction_features:
		indexes[feature.id] = feature.compatibility_index
	for feature: Dictionary in definition.interaction_features:
		var polygon: PackedVector2Array = feature.shape.points
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		var legacy: Dictionary = definition.visual_features[feature.compatibility_index].legacy
		var target := {"name":legacy.get("name","水草" if feature.kind == "grass" else ("石头" if feature.kind == "stone" else "木枝")),
			"kind":feature.kind,"polygon":polygon,"bounds":bounds}
		if feature.kind != "grass": target.fade_group = indexes[feature.fade_group_id]
		result.append(target)
	return result

func equivalence(definition: Dictionary) -> void:
	check(definition.bounds.size == Legacy.SIZE,"SIZE exact")
	check(definition.bounds.water == Legacy.WATER,"WATER exact")
	check(definition.bounds.floor_y == Legacy.FLOOR,"FLOOR exact")
	check(definition.bounds.net_area == Legacy.NET_AREA,"NET_AREA exact")
	check(definition.bounds.vegetation_drag_zones == Legacy.GRASS,"all three separate Authority GRASS drag/visibility rectangles exact")
	check(definition.anchors.home == Legacy.HOME,"HOME exact")
	check(definition.anchors.player_spawn == Legacy.SPAWN,"SPAWN exact")
	check(definition.bait_sites == Legacy.BAIT_SITES,"bait positions AND order exact")
	check(definition.presentation.wood_groups == Legacy.WOOD_GROUPS,"connected-wood visual seed groups exact")
	check(definition.interaction_features.size() == 40,"18 solid + 22 interactive plant targets")
	for index in Legacy.SOLIDS.size():
		check(definition.visual_features[index].legacy == Legacy.SOLIDS[index],"all solid presentation fields/seed/name preserved " + str(index))
	for index in Legacy.PLANTS.size():
		check(definition.visual_features[index+18].legacy == Legacy.PLANTS[index],"all plant presentation fields preserved " + str(index))
	var expected := Legacy.interaction_targets()
	var actual := reconstructed_targets(definition)
	check(actual == expected,"complete ordered target values including names, polygons, bounds and fade groups equal")
	for index in expected.size():
		var feature: Dictionary = definition.interaction_features[index]
		var solid := index < Legacy.SOLIDS.size()
		check(feature.compatibility_index == index,"compatibility index " + str(index))
		check(feature.capabilities == {"fish_passable":true,"net_blocking":solid,"rope_anchor":true,"contact_fade":true,
			"grass_binding":not solid,"shore_visible":true,"npc_spawn_blocking":solid,"fish_occluding":solid},"audited capabilities " + str(index))
		check(feature.id == feature.presentation_ref,"stable public feature/presentation link " + str(index))
		for point: Vector2 in [expected[index].bounds.position,expected[index].bounds.get_center(),expected[index].bounds.end,Vector2(-50,-50),Vector2(1500,600)]:
			check(Legacy.coil_at(actual[index],point) == Legacy.coil_at(expected[index],point),"unchanged coil algorithm receives identical data index=" + str(index))
			check(Legacy.nearest_boundary(point,actual[index].polygon) == Legacy.nearest_boundary(point,expected[index].polygon),"boundary equality " + str(index))
			check(Legacy.touches(point,12,actual[index].polygon) == Legacy.touches(point,12,expected[index].polygon),"contact equality " + str(index))

func hash_contract(definition: Dictionary) -> void:
	var canonical := Definition.canonical(definition)
	var hashed := Definition.content_hash(definition)
	check(hashed == POND_V2_REVISION_1_HASH,"pinned contract-v1 pond_v2 revision1 canonical golden")
	check(hashed.length() == 64 and definition.meta.content_hash == hashed,"canonical SHA-256 recorded")
	check(canonical == Definition.canonical(reversed_dictionaries(definition)),"all Dictionary insertion orders ignored")
	check(hashed == Definition.content_hash(PondV2.create()),"fresh independently built definition same hash")
	var changed := definition.duplicate(true)
	changed.presentation.visual_profile_id = "different_visual_only"
	changed.presentation.wood_groups.reverse()
	changed.visual_features[0].legacy.seed = 99999
	changed.visual_features[18].legacy.kind = "cosmetic"
	changed.visual_features.reverse()
	check(Definition.content_hash(changed) == hashed,"profile/texture seeds/pure appearance/visual order do not affect Authority hash")
	changed = definition.duplicate(true)
	changed.meta.id = "alias"; changed.meta.revision = 2; changed.meta.content_hash = "ignored"
	check(Definition.content_hash(changed) == hashed,"map identity/revision/hash are separate from canonical gameplay content")
	changed = definition.duplicate(true)
	changed.bounds.floor_y += 0.00000001
	check(Definition.content_hash(changed) != hashed,"sub-decimal precision preserved without formatting loss")
	for field: String in ["size","water","net_area","vegetation_drag_zones"]:
		changed = definition.duplicate(true)
		if field == "size": changed.bounds[field].x += 1
		elif field == "vegetation_drag_zones": changed.bounds[field][0].position.x += 1
		else: changed.bounds[field].position.x += 1
		check(Definition.content_hash(changed) != hashed,"bounds authority covered: " + field)
	for field: String in ["home","player_spawn"]:
		changed = definition.duplicate(true); changed.anchors[field].x += 1
		check(Definition.content_hash(changed) != hashed,"anchor authority covered: " + field)
	changed = definition.duplicate(true); changed.bait_sites.reverse()
	check(Definition.content_hash(changed) != hashed,"bait order is gameplay data")
	changed = definition.duplicate(true); changed.interaction_features.reverse()
	check(Definition.content_hash(changed) != hashed,"target order is gameplay data, not sorted away")
	changed = definition.duplicate(true); changed.interaction_features[0].shape.points[0].x += 0.25
	check(Definition.content_hash(changed) != hashed,"each polygon point covered")
	changed = definition.duplicate(true); changed.interaction_features[0].id = "new_stable_id"
	check(Definition.content_hash(changed) != hashed,"stable feature identities covered")
	for key: String in Definition.CAPABILITY_KEYS:
		changed = definition.duplicate(true); changed.interaction_features[0].capabilities[key] = not changed.interaction_features[0].capabilities[key]
		check(Definition.content_hash(changed) != hashed,"capability hash: " + key)
	changed = definition.duplicate(true); changed.interaction_features[3].fade_group_id = changed.interaction_features[3].id
	check(Definition.content_hash(changed) != hashed,"existing world target-state fade grouping covered conservatively")
	print("POND_V2_MAP_HASH | ",hashed)

func isolation(definition: Dictionary) -> void:
	var a := Registry.load_map(); var b := Registry.load_map()
	check(a.valid and b.valid and a.definition == definition,"registry returns only validated built-in values")
	a.definition.interaction_features[0].shape.points[0] = Vector2.ZERO
	a.definition.visual_features[0].legacy.points[0] = Vector2.ONE
	a.definition.presentation.wood_groups[0][0] = 999
	a.definition.bait_sites[0] = Vector2.ZERO
	a.definition.meta.id = "mutated"
	check(b.definition == definition and Registry.load_map().definition == definition,"all nested lookup results are detached")
	var refs := Registry.available_refs(); refs[0].id = "mutated"
	check(Registry.available_refs()[0] == definition.meta,"registry map refs detached")
	for ref: Array in [["unknown",1],["pond_v2",0],["pond_v2",2],["fixture_rect_small",1],["",1]]:
		var result := Registry.load_map(ref[0],ref[1])
		check(not result.valid and not result.errors.is_empty() and result.definition.is_empty(),"unknown references fail atomically: " + str(ref))
	seed(83129)
	var expected_rng: Array = [randf(),randi(),randf()]
	seed(83129)
	for index in 10: Registry.load_map(); Validator.validate(definition); Definition.canonical(definition)
	check([randf(),randi(),randf()] == expected_rng,"loading, validation and hashing consume zero global RNG")
	var world := World.new(); world.reset_world({"seed":7231})
	var before := var_to_bytes(world.capture_snapshot())
	var rng_state: int = world.rng.state
	for index in 10: Registry.load_map()
	check(world.rng.state == rng_state and var_to_bytes(world.capture_snapshot()) == before,"unused data foundation cannot mutate world, NPCs or Authority RNG")
	world.free()
	var begin := Time.get_ticks_usec()
	for index in 100: Registry.load_map()
	print("MAP_LOAD_TIMING | 100_validated_loads_usec=",Time.get_ticks_usec()-begin," | not_a_per_tick_operation")

func _initialize() -> void:
	var definition := PondV2.create()
	var valid := Validator.validate(definition)
	check(valid.valid,"pond_v2 validates: " + str(valid.errors))
	equivalence(definition)
	hash_contract(definition)
	isolation(definition)
	print("PHASE04_MAP_DEFINITION_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed == 0 else 1)
