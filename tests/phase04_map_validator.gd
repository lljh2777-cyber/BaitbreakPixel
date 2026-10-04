extends SceneTree

const Definition = preload("res://scripts/maps/map_definition.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const PondV2 = preload("res://scripts/maps/pond_v2_map.gd")
class MetadataObject:
	extends RefCounted

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("MAP_VALIDATOR_FAIL | " + label)

func fixture() -> Dictionary:
	var result := {
		"meta": {"id":"validator_fixture", "revision":1, "contract_version":1, "content_hash":""},
		"bounds": {"size":Vector2(200, 140), "water":Rect2(10, 10, 180, 110), "floor_y":122.0, "net_area":Rect2(20, 20, 150, 90), "vegetation_drag_zones":[Rect2(150, 90, 20, 32)]},
		"anchors": {"player_spawn":Vector2(20, 30), "home":Vector2(20, 100)},
		"bait_sites": [Vector2(30, 40), Vector2(50, 40), Vector2(70, 40), Vector2(90, 40), Vector2(110, 40), Vector2(130, 40)],
		"interaction_features": [],
		"visual_features": [],
		"presentation": {"visual_profile_id":"validator_art", "wood_groups":[[1, 2]]},
	}
	for index in 2:
		var identity := "wood_fixture_%d" % index
		result.interaction_features.append({
			"id":identity, "kind":"wood", "compatibility_index":index,
			"shape":{"type":"polygon", "points":PackedVector2Array([Vector2(30 + 40 * index, 90), Vector2(50 + 40 * index, 90), Vector2(50 + 40 * index, 122), Vector2(30 + 40 * index, 122)])},
			"capabilities":{"fish_passable":true, "net_blocking":true, "rope_anchor":true, "contact_fade":true, "grass_binding":false, "shore_visible":true, "npc_spawn_blocking":true, "fish_occluding":true},
			"fade_group_id":identity, "presentation_ref":identity,
		})
		result.visual_features.append({"id":identity, "kind":"solid", "legacy":{"seed":index + 1, "name":"fixture"}})
	seal(result)
	return result

func seal(value: Dictionary) -> void:
	value.meta.content_hash = Definition.content_hash(value)

func changed(path: Array, replacement: Variant) -> Dictionary:
	var result := fixture()
	var target: Variant = result
	for index in path.size() - 1: target = target[path[index]]
	target[path[-1]] = replacement
	return result

func reject(value: Variant, label: String, snapshot: bool = true) -> void:
	var before := var_to_bytes(value) if snapshot else PackedByteArray()
	var result := Validator.validate(value)
	check(result.keys() == ["valid", "errors"] and result.valid == false and result.errors is Array and not result.errors.is_empty(), label + " rejected with structured errors")
	check(result.errors.get_typed_builtin() == TYPE_STRING, label + " errors are Array[String]")
	if snapshot: check(var_to_bytes(value) == before, label + " rejection leaves input untouched")

func accept(value: Dictionary, label: String) -> void:
	var before := var_to_bytes(value)
	var result := Validator.validate(value)
	check(result.valid and result.errors.is_empty(), label + " accepted: " + str(result.errors))
	check(var_to_bytes(value) == before, label + " validation leaves input untouched")

func freeze(value: Variant) -> void:
	if value is Dictionary:
		for key in value: freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for child in value: freeze(child)
		value.make_read_only()

func schema_rejections() -> void:
	for value in [null, true, 7, 2.5, "map", [], Vector2.ONE, Rect2(0, 0, 1, 1)]: reject(value, "non-dictionary root")
	var dictionaries: Array = [[], ["meta"], ["bounds"], ["anchors"], ["interaction_features", 0], ["interaction_features", 0, "shape"], ["interaction_features", 0, "capabilities"], ["visual_features", 0], ["presentation"]]
	for path in dictionaries:
		var extra := fixture()
		var target: Variant = extra
		for part in path: target = target[part]
		target["unknown_contract_key"] = true
		reject(extra, "unknown field " + str(path))
		var missing := fixture()
		target = missing
		for part in path: target = target[part]
		target.erase(target.keys()[0])
		reject(missing, "missing field " + str(path))
	var field_paths: Array = [
		["meta"], ["meta", "id"], ["meta", "revision"], ["meta", "contract_version"], ["meta", "content_hash"],
		["bounds"], ["bounds", "size"], ["bounds", "water"], ["bounds", "floor_y"], ["bounds", "net_area"], ["bounds", "vegetation_drag_zones"], ["bounds", "vegetation_drag_zones", 0],
		["anchors"], ["anchors", "player_spawn"], ["anchors", "home"], ["bait_sites"], ["bait_sites", 0],
		["interaction_features"], ["interaction_features", 0], ["interaction_features", 0, "id"], ["interaction_features", 0, "kind"], ["interaction_features", 0, "compatibility_index"], ["interaction_features", 0, "shape"], ["interaction_features", 0, "shape", "type"], ["interaction_features", 0, "shape", "points"], ["interaction_features", 0, "capabilities"], ["interaction_features", 0, "fade_group_id"], ["interaction_features", 0, "presentation_ref"],
		["visual_features"], ["visual_features", 0], ["visual_features", 0, "id"], ["visual_features", 0, "kind"], ["visual_features", 0, "legacy"],
		["presentation"], ["presentation", "visual_profile_id"], ["presentation", "wood_groups"], ["presentation", "wood_groups", 0], ["presentation", "wood_groups", 0, 0],
	]
	for capability in Validator.CAPABILITY_KEYS: field_paths.append(["interaction_features", 0, "capabilities", capability])
	var good := fixture()
	for path in field_paths:
		var original: Variant = good
		for part in path: original = original[part]
		for wrong in [null, true, 1, 1.0, "wrong", StringName("wrong"), Vector2.ZERO, Rect2(), [], {}, PackedVector2Array()]:
			if typeof(wrong) == typeof(original): continue
			if path == ["bounds", "floor_y"] and wrong is int: continue
			reject(changed(path, wrong), "wrong type " + str(path) + " <- " + type_string(typeof(wrong)))
	for path in [["meta", "id"], ["interaction_features", 0, "id"], ["visual_features", 0, "id"], ["presentation", "visual_profile_id"]]:
		reject(changed(path, " \t"), "empty identity " + str(path))
	for revision in [0, -1]: reject(changed(["meta", "revision"], revision), "invalid revision")
	for version in [0, 2]: reject(changed(["meta", "contract_version"], version), "unknown contract")
	for hash_value in ["", "0".repeat(63), "a".repeat(65), "A".repeat(64), "g".repeat(64), "0".repeat(64)]: reject(changed(["meta", "content_hash"], hash_value), "invalid content hash")
	reject(changed(["interaction_features", 0, "kind"], "bridge"), "unknown interaction kind")
	reject(changed(["visual_features", 0, "kind"], "shader"), "unknown visual kind")
	reject(changed(["interaction_features", 0, "compatibility_index"], 1), "wrong compatibility index")
	reject(changed(["interaction_features", 1, "id"], "wood_fixture_0"), "duplicate interaction ID")
	reject(changed(["visual_features", 1, "id"], "wood_fixture_0"), "duplicate visual ID")
	reject(changed(["interaction_features", 0, "fade_group_id"], "absent"), "dangling fade group")
	reject(changed(["interaction_features", 0, "presentation_ref"], "absent"), "dangling visual reference")
	var cyclic_group := fixture()
	cyclic_group.interaction_features[0].fade_group_id = "wood_fixture_1"
	cyclic_group.interaction_features[1].fade_group_id = "wood_fixture_0"
	reject(cyclic_group, "cyclic fade representatives")
	var shared_group := changed(["interaction_features", 1, "fade_group_id"], "wood_fixture_0")
	seal(shared_group)
	accept(shared_group, "shared group with self-representative")
	shared_group.interaction_features[0].capabilities.contact_fade = false
	reject(shared_group, "shared group without contact fade")
	reject(changed(["presentation", "wood_groups"], [[1, 1]]), "duplicate presentation group seeds")
	reject(changed(["presentation", "wood_groups"], [[0]]), "nonpositive presentation group seed")

func geometry_rejections() -> void:
	for path in [["bounds", "floor_y"], ["visual_features", 0, "legacy", "seed"]]:
		for number in [INF, -INF, NAN]: reject(changed(path, number), "nonfinite scalar " + str(path))
	for vector in [Vector2(NAN, 10), Vector2(10, INF), Vector2(-INF, 10)]:
		for path in [["bounds", "size"], ["anchors", "player_spawn"], ["anchors", "home"], ["bait_sites", 0]]: reject(changed(path, vector), "nonfinite vector " + str(path))
	for size in [Vector2.ZERO, Vector2(-1, 100), Vector2(100, -1), Vector2(1000001, 100)]: reject(changed(["bounds", "size"], size), "invalid map dimensions")
	for rectangle in [Rect2(), Rect2(0, 0, -1, 2), Rect2(-1, 0, 200, 140), Rect2(0, 0, 201, 140), Rect2(0, 0, INF, 1), Rect2(NAN, 0, 1, 1)]:
		reject(changed(["bounds", "water"], rectangle), "invalid water rectangle")
	reject(changed(["bounds", "net_area"], Rect2(0, 0, 20, 20)), "net outside water")
	for floor_value in [119.0, 141.0]: reject(changed(["bounds", "floor_y"], floor_value), "invalid floor")
	for rectangle in [Rect2(-1, 90, 10, 10), Rect2(190, 130, 20, 20), Rect2(10, 10, 0, 20)]: reject(changed(["bounds", "vegetation_drag_zones"], [rectangle]), "invalid vegetation drag zone")
	for path in [["anchors", "player_spawn"], ["anchors", "home"], ["bait_sites", 0]]:
		for point in [Vector2(0, 0), Vector2(190, 40), Vector2(20, 120)]: reject(changed(path, point), "out-of-water anchor/site " + str(path))
	var three_sites := fixture()
	three_sites.bait_sites.resize(3)
	reject(three_sites, "three bait sites cannot serve four lifecycle slots")
	check(Validator.MIN_BAIT_SITES == 4, "current lifecycle requires four active bait slots")
	for site_count in [4, 5, 6]:
		var supported_sites := fixture()
		supported_sites.bait_sites.resize(site_count)
		seal(supported_sites)
		accept(supported_sites, "%d sites serve current lifecycle" % site_count)
	reject(changed(["bait_sites", 1], Vector2(30, 40)), "duplicate bait site")
	reject(changed(["interaction_features", 0, "shape", "type"], "rect"), "unsupported geometry type")
	var invalid_polygons: Array = [
		[], [Vector2(30, 90), Vector2(50, 90)],
		[Vector2(30, 90), Vector2(30, 90), Vector2(50, 122)],
		[Vector2(30, 90), Vector2(40, 100), Vector2(50, 110)],
		[Vector2(30, 90), Vector2(50, 122), Vector2(30, 122), Vector2(50, 90)],
		[Vector2(-1, 90), Vector2(50, 90), Vector2(50, 122)],
		[Vector2(30, 90), Vector2(201, 90), Vector2(50, 122)],
		[Vector2(30, 90), Vector2(50, 90), Vector2(50, 141)],
		[Vector2(30, 90), Vector2(50, INF), Vector2(50, 122)],
		[Vector2(30, 90), Vector2(NAN, 90), Vector2(50, 122)],
		[Vector2(30, 90), Vector2(50, 90), Vector2(50, 122), Vector2(30, 90)],
		[Vector2(20, 20), Vector2(80, 20), Vector2(80, 80), Vector2(50, 20), Vector2(20, 80)],
	]
	for polygon in invalid_polygons: reject(changed(["interaction_features", 0, "shape", "points"], PackedVector2Array(polygon)), "invalid polygon")
	var concave := changed(["interaction_features", 0, "shape", "points"], PackedVector2Array([Vector2(20, 20), Vector2(80, 20), Vector2(50, 50), Vector2(80, 80), Vector2(20, 80)]))
	seal(concave)
	accept(concave, "simple concave polygon")
	concave.interaction_features[0].shape.points.reverse()
	seal(concave)
	accept(concave, "reversed polygon winding remains valid")
	var border := changed(["interaction_features", 0, "shape", "points"], PackedVector2Array([Vector2.ZERO, Vector2(200, 0), Vector2(200, 140), Vector2(0, 140)]))
	seal(border)
	accept(border, "whole-map boundary geometry is legal even outside water")

func authority_and_purity() -> void:
	var good := fixture()
	accept(good, "independent fixture")
	accept(PondV2.create(), "unchanged Pond V2 fixture")
	var frozen := fixture()
	freeze(frozen)
	accept(frozen, "read-only dictionaries and arrays")
	var integer_floor := changed(["bounds", "floor_y"], 122)
	check(Definition.content_hash(integer_floor) == good.meta.content_hash, "equivalent integer/float floor values have one authority hash")
	accept(integer_floor, "integer floor value")
	var empty_cover := fixture()
	empty_cover.interaction_features.clear()
	empty_cover.visual_features.clear()
	empty_cover.presentation.wood_groups.clear()
	seal(empty_cover)
	accept(empty_cover, "map without interaction or visual features")
	var cosmetic := good.duplicate(true)
	cosmetic.visual_features.reverse()
	cosmetic.visual_features[0].legacy.name = "new visual name"
	cosmetic.visual_features[0].legacy.tint = Color(0.2, 0.3, 0.4)
	cosmetic.presentation.visual_profile_id = "another_style"
	cosmetic.presentation.wood_groups.reverse()
	cosmetic.interaction_features[0].presentation_ref = "wood_fixture_1"
	check(Definition.content_hash(cosmetic) == good.meta.content_hash, "entire visual payload/presentation/ref excluded from authority hash")
	accept(cosmetic, "presentation-only changes retain valid authority")
	var reordered := good.duplicate(true)
	reordered.bait_sites.reverse()
	check(Definition.content_hash(reordered) != good.meta.content_hash, "bait order is authoritative")
	reject(reordered, "unsealed bait order change")
	reordered = good.duplicate(true)
	reordered.interaction_features.reverse()
	reject(reordered, "feature reordering with stale compatibility indexes")
	for index in reordered.interaction_features.size(): reordered.interaction_features[index].compatibility_index = index
	check(Definition.content_hash(reordered) != good.meta.content_hash, "reordered features with repaired indexes remain authority-different")
	reject(reordered, "unsealed feature order change")
	seal(reordered)
	accept(reordered, "new properly hashed semantic feature order")
	for capability in Validator.CAPABILITY_KEYS:
		var authority := good.duplicate(true)
		authority.interaction_features[0].capabilities[capability] = not authority.interaction_features[0].capabilities[capability]
		check(Definition.content_hash(authority) != good.meta.content_hash, "capability contributes to hash: " + capability)
		reject(authority, "unsealed capability mutation " + capability)
	var drag := changed(["bounds", "vegetation_drag_zones"], [Rect2(151, 90, 20, 32)])
	check(Definition.content_hash(drag) != good.meta.content_hash, "drag geometry contributes to hash")
	reject(drag, "unsealed vegetation authority mutation")
	var group := changed(["interaction_features", 1, "fade_group_id"], "wood_fixture_0")
	check(Definition.content_hash(group) != good.meta.content_hash, "fade grouping contributes to hash")
	reject(group, "unsealed fade group mutation")
	seed(481516)
	var expected := [randi(), randf(), randi()]
	seed(481516)
	for index in 5:
		Validator.validate(good)
		Validator.validate(changed(["meta", "id"], ""))
		Validator.validate(PondV2.create())
	check([randi(), randf(), randi()] == expected, "valid/invalid validation and map creation consume no global RNG")
	var result := Validator.validate(good)
	result.errors.append("caller mutation")
	check(Validator.validate(good).errors.is_empty(), "returned error arrays never share persistent state")

func unsafe_values_and_limits() -> void:
	var node := Node.new()
	var resource := Resource.new()
	var object := RefCounted.new()
	for unsafe in [node, resource, object, Callable(self, "fixture"), Signal(self, "process_frame"), RID()]:
		var payload := changed(["visual_features", 0, "legacy", "payload"], unsafe)
		reject(payload, "unsafe value rejected even inside excluded visual metadata", false)
		check(is_same(payload.visual_features[0].legacy.payload, unsafe), "unsafe input is not replaced")
	node.free()
	var typed_nodes: Array[Node] = []
	var typed_scripts: Array[MetadataObject] = []
	var typed_resources: Dictionary[String, Resource] = {}
	var typed_script_values: Dictionary[String, MetadataObject] = {}
	var typed_object_keys: Dictionary[RefCounted, String] = {}
	for unsafe_container in [typed_nodes, typed_scripts, typed_resources, typed_script_values, typed_object_keys]:
		reject(changed(["visual_features", 0, "legacy", "typed"], unsafe_container), "empty object-typed container", false)
	var cycle: Array = []
	cycle.append(cycle)
	var cyclic_array := changed(["visual_features", 0, "legacy", "cycle"], cycle)
	reject(cyclic_array, "cyclic Array", false)
	check(is_same(cycle[0], cycle), "cyclic array rejected without mutation")
	check("cyclic" in Validator.validate(cyclic_array).errors[0], "array cycle is explicitly detected before hashing")
	cycle.clear()
	var dictionary_cycle: Dictionary = {}
	dictionary_cycle.loop = dictionary_cycle
	var cyclic_dictionary := changed(["visual_features", 0, "legacy", "cycle"], dictionary_cycle)
	reject(cyclic_dictionary, "cyclic Dictionary", false)
	check(is_same(dictionary_cycle.loop, dictionary_cycle), "cyclic dictionary rejected without mutation")
	check("cyclic" in Validator.validate(cyclic_dictionary).errors[0], "dictionary cycle is explicitly detected before hashing")
	dictionary_cycle.clear()
	var mixed_cycle: Dictionary = {"children":[]}
	mixed_cycle.children.append(mixed_cycle)
	reject(changed(["visual_features", 0, "legacy", "cycle"], mixed_cycle), "mixed dictionary/array cycle", false)
	mixed_cycle.children.clear()
	var child := {"label":"shared but not cyclic"}
	var alias := changed(["visual_features", 0, "legacy", "aliases"], [child, child])
	accept(alias, "shared acyclic value subtrees")
	var too_deep: Dictionary = {}
	var current := too_deep
	for index in Validator.MAX_DEPTH + 2:
		current.next = {}
		current = current.next
	reject(changed(["visual_features", 0, "legacy", "deep"], too_deep), "depth ceiling")
	var excessive: Array = []
	excessive.resize(Validator.MAX_CONTAINER_ITEMS + 1)
	reject(changed(["visual_features", 0, "legacy", "large"], excessive), "container ceiling")
	reject(changed(["visual_features", 0, "legacy", "large"], "x".repeat(Validator.MAX_STRING_LENGTH + 1)), "string ceiling")
	var many_points := PackedVector2Array()
	many_points.resize(Validator.MAX_POLYGON_POINTS + 1)
	reject(changed(["interaction_features", 0, "shape", "points"], many_points), "polygon point ceiling")
	var broad: Array = []
	for outer in 40:
		var row: Array = []
		row.resize(1024)
		broad.append(row)
	reject(changed(["visual_features", 0, "legacy", "broad"], broad), "total value-node ceiling")
	var oversized_features: Array = []
	oversized_features.resize(Validator.MAX_FEATURES + 1)
	for path in [["interaction_features"], ["visual_features"], ["bait_sites"], ["bounds", "vegetation_drag_zones"], ["presentation", "wood_groups"]]:
		reject(changed(path, oversized_features), "feature-list ceiling " + str(path))
	var maximal_polygon := PackedVector2Array()
	for index in Validator.MAX_POLYGON_POINTS:
		maximal_polygon.append(Vector2(70, 70) + Vector2.from_angle(TAU * index / Validator.MAX_POLYGON_POINTS) * 40)
	var maximum := changed(["interaction_features", 0, "shape", "points"], maximal_polygon)
	seal(maximum)
	accept(maximum, "largest supported simple polygon")
	var bad_key := changed(["visual_features", 0, "legacy"], {3:"not a string key"})
	reject(bad_key, "non-string dictionary key")

func _initialize() -> void:
	schema_rejections()
	geometry_rejections()
	authority_and_purity()
	unsafe_values_and_limits()
	print("PHASE04_MAP_VALIDATOR_TESTS | passed=%d | failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
