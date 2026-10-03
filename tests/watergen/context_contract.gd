extends SceneTree
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Contract = preload("res://scripts/watergen/public_map_context.gd")
const Layout = preload("res://scripts/pond_layout.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG0_CONTEXT_PASS | ", title)
	else:
		failed += 1
		push_error("WG0_CONTEXT_FAIL | " + title)

func reject(context: Dictionary, title: String) -> void:
	# Recompute digest so shape tests cannot pass merely due to a stale digest.
	context.map_public_digest = Contract.digest(context)
	var before := var_to_bytes(context)
	var validation := Contract.validate(context)
	check(not validation.ok and not validation.code.is_empty(), title)
	check(before == var_to_bytes(context), title + " rejects without mutation")

func run() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	var before := Adapter.authority_bytes()
	var context := Adapter.build(baseline.source_commit)
	check(Contract.validate(context).ok, "adapter output accepted")
	check(context.world_size_px == [1280, 480] and context.viewport_size_px == [640, 360], "fixed map and viewport")
	check(context.water_rect_px == [8, 68, 1264, 363] and context.floor_y_px == 433 and context.visual_surface_y_px == 55, "distinct physical and visual water surfaces")
	check(context.home_px == [60, 401] and context.spawn_px == [66, 385], "home/spawn unchanged")
	check(context.static_cover_records.size() == 40 and Layout.SOLIDS.size() == 18 and Layout.PLANTS.size() == 22, "all fixed covers copied")
	var targets := Layout.interaction_targets()
	for index in targets.size():
		var record: Dictionary = context.static_cover_records[index]
		var polygon := PackedVector2Array()
		for p in record.polygon_px: polygon.append(Vector2(p[0], p[1]))
		check(record.legacy_target_index == index and polygon == targets[index].polygon and record.bounds_px == Adapter.rectangle(targets[index].bounds) and record.fade_group == targets[index].get("fade_group", index), "target geometry/order/group " + str(index))
	check(before == Adapter.authority_bytes(), "adapter did not mutate Layout or targets")
	var original := Contract.canonical(context)
	var copy := Adapter.build(baseline.source_commit)
	copy.static_cover_records[0].polygon_px[0][0] = -99
	copy.static_cover_records[18].source.height = 1
	copy.wood_groups[0][0] = 99
	copy.bait_sites_px[0][0] = 99
	check(before == Adapter.authority_bytes() and original == Contract.canonical(context), "nested output mutation cannot reach Layout or another context")
	var reordered: Dictionary = {}
	var keys: Array = context.keys()
	keys.reverse()
	for key in keys: reordered[key] = context[key]
	check(Contract.canonical(context) == Contract.canonical(reordered), "canonical keys sorted")
	copy = context.duplicate(true)
	copy.source_commit = "0".repeat(40)
	check(Contract.digest(copy) == context.map_public_digest, "source audit commit excluded from map digest")
	copy = context.duplicate(true)
	copy.bait_sites_px.reverse()
	check(Contract.digest(copy) != context.map_public_digest, "array order included in map digest")
	for field in ["hook", "rng_seed", "world"]:
		copy = context.duplicate(true)
		copy[field] = 1
		reject(copy, "unknown/private field " + field)
	copy = context.duplicate(true)
	copy.schema_version = 2
	reject(copy, "unsupported schema")
	copy = context.duplicate(true)
	copy.world_size_px[0] = -1
	reject(copy, "negative dimensions")
	copy = context.duplicate(true)
	copy.world_size_px[0] = "1280"
	reject(copy, "wrong dimension type")
	for invalid in [NAN, INF]:
		copy = context.duplicate(true)
		copy.static_cover_records[0].polygon_px[0][0] = invalid
		reject(copy, "nonfinite polygon")
	copy = context.duplicate(true)
	copy.static_cover_records.resize(257)
	reject(copy, "object budget")
	copy = context.duplicate(true)
	copy.static_cover_records.clear()
	reject(copy, "empty map")
	copy = context.duplicate(true)
	copy.static_cover_records[0].legacy_target_index = 1
	reject(copy, "target reordering")
	copy = context.duplicate(true)
	copy.static_cover_records[18].source.hook = true
	reject(copy, "nested unknown field")
	copy = context.duplicate(true)
	copy.wood_groups[0][0] = 999
	reject(copy, "invalid wood member")
	copy = context.duplicate(true)
	copy.protected_regions[0].rect_px[2] = 0
	reject(copy, "empty protected region")
	copy = context.duplicate(true)
	copy.map_public_digest = "0".repeat(64)
	check(not Contract.validate(copy).ok, "digest mismatch")
	check(not Contract.validate(null).ok and not Contract.validate([]).ok, "non-map input")
	check(before == Adapter.authority_bytes(), "all rejection cases leave source unchanged")
	print("WG0_MAP_DIGEST | ", context.map_public_digest)
	print("WG0_CONTEXT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
