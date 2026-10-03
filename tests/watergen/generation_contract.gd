extends SceneTree
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const Generator = preload("res://scripts/watergen/water_visual_generator.gd")
const Baker = preload("res://scripts/watergen/water_visual_baker.gd")
const Cache = preload("res://scripts/watergen/water_visual_cache.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG1_CONTRACT_PASS | ", title)
	else:
		failed += 1
		push_error("WG1_CONTRACT_FAIL | " + title)

func plain(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not key is String or not plain(value[key]): return false
		return true
	if value is Array:
		for item in value:
			if not plain(item): return false
		return true
	return value is String or value is int or value is bool or (value is float and is_finite(value))

func objects(plan: Dictionary, layer: int, kind: String) -> Array:
	return plan.layers[layer].objects.filter(func(value): return value.kind == kind)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	var map := Adapter.build(source.source_commit)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond.json"))
	var before := Map.canonical(map) + Map.canonical(profile)
	var authority := Adapter.authority_bytes()
	check(Profile.validate(profile).ok, "one shipped profile accepted")
	for bad in [-1, 2147483648, 42.0, "42", null]:
		var result := Generator.generate(map, profile, bad)
		check(not result.ok and not result.has("plan"), "seed rejected with no partial plan: " + str(bad))
	for field in ["hook_probability", "world", "food_efficiency"]:
		var invalid := profile.duplicate(true)
		invalid[field] = 1
		check(not Generator.generate(map, invalid, 42).ok, "unknown profile field " + field)
	for value in [-1, 401, 1.5, NAN, INF, "160"]:
		var invalid := profile.duplicate(true)
		invalid.composition.gravel_count = value
		check(not Profile.validate(invalid).ok, "invalid gravel budget " + str(value))
	var invalid := profile.duplicate(true)
	invalid.beams.width_px_range = [80, 30]
	check(not Profile.validate(invalid).ok, "inverted range")
	invalid = profile.duplicate(true)
	invalid.palette.water_deep = "#zzzzzz"
	check(not Profile.validate(invalid).ok, "invalid palette")
	invalid = profile.duplicate(true)
	invalid.palette.hook = "#ffffff"
	check(not Profile.validate(invalid).ok, "nested private field")
	invalid = profile.duplicate(true)
	invalid.parallax_compensation.distance = [0.22, 0.08]
	check(Profile.validate(invalid).code == "PARALLAX_REQUIRES_WG2", "unsupported nonzero parallax rejected, not ignored")
	invalid = profile.duplicate(true)
	invalid.generator_version = "wg-2.0"
	check(not Profile.validate(invalid).ok, "unknown generator version")
	var sparse := profile.duplicate(true)
	sparse.beams.count_range = [0, 0]
	for key in Profile.CLUMP_LIMITS: sparse.composition[key] = [0, 0]
	sparse.composition.gravel_count = 0
	sparse.composition.mote_count = 0
	var sparse_plan: Dictionary = Generator.generate(map, sparse, 42).plan
	check(objects(sparse_plan, 0, "beam").is_empty() and objects(sparse_plan, 1, "clump").is_empty() and objects(sparse_plan, 2, "pad").is_empty() and objects(sparse_plan, 3, "clump").is_empty() and objects(sparse_plan, 4, "gravel").is_empty() and objects(sparse_plan, 5, "clump").is_empty(), "zero budgets actually remove their named object kinds")
	var dense := profile.duplicate(true)
	dense.beams.count_range = [8, 8]
	for key in Profile.CLUMP_LIMITS: dense.composition[key] = [Profile.CLUMP_LIMITS[key], Profile.CLUMP_LIMITS[key]]
	dense.composition.gravel_count = 400
	dense.composition.mote_count = 128
	var dense_plan: Dictionary = Generator.generate(map, dense, 42).plan
	check(objects(dense_plan, 0, "beam").size() == 8 and objects(dense_plan, 1, "clump").size() == 32 and objects(dense_plan, 2, "pad").size() == 16 and objects(dense_plan, 3, "clump").size() == 24 and objects(dense_plan, 4, "gravel").size() == 400 and objects(dense_plan, 5, "clump").size() == 12, "maximum budgets honored")
	check(Baker.bake(dense_plan).ok, "maximum object budgets bake within fixed raster size")
	var invalid_map := map.duplicate(true)
	invalid_map.world_size_px = [8192, 8192]
	invalid_map.map_public_digest = Map.digest(invalid_map)
	check(not Generator.generate(invalid_map, profile, 42).ok, "oversized raster rejected before allocation")
	var plans: Array = []
	for visual_seed in [42, 731, 2649, 713284]:
		var result := Generator.generate(map, profile, visual_seed)
		check(result.ok and plain(result.plan), "pure plan " + str(visual_seed))
		check(Map.canonical(result.plan) == Map.canonical(Generator.generate(map, profile, visual_seed).plan), "plan repeat " + str(visual_seed))
		plans.append(result.plan)
	check(Map.canonical(plans[0]) != Map.canonical(plans[1]), "different seeds produce different plans")
	var plan: Dictionary = plans[0]
	var base := Baker.bake(plan)
	var repeat := Baker.bake(plan)
	for layer in Profile.LAYERS:
		check(base.layers[layer].rgba_sha256 == repeat.layers[layer].rgba_sha256, "pixel repeat " + layer)
	var more := profile.duplicate(true)
	more.composition.mote_count += 1
	var more_plan: Dictionary = Generator.generate(map, more, 42).plan
	var more_pixels := Baker.bake(more_plan)
	for index in 6:
		if index != 1:
			check(Map.canonical(plan.layers[index]) == Map.canonical(more_plan.layers[index]), "mote count leaves other plan layer unchanged " + str(index))
			var layer: String = Profile.LAYERS[index]
			check(base.layers[layer].rgba_sha256 == more_pixels.layers[layer].rgba_sha256, "mote count leaves other pixels unchanged " + layer)
	check(objects(plan, 1, "clump") == objects(more_plan, 1, "clump"), "motes never reorder clumps")
	check(objects(plan, 1, "mote") == objects(more_plan, 1, "mote").slice(0, int(profile.composition.mote_count)), "mote object prefix stable")
	more = profile.duplicate(true)
	more.composition.gravel_count += 1
	more_plan = Generator.generate(map, more, 42).plan
	check(objects(plan, 4, "gravel") == objects(more_plan, 4, "gravel").slice(0, int(profile.composition.gravel_count)), "gravel prefix stable")
	more = profile.duplicate(true)
	more.beams.width_px_range = [100, 100]
	more.beams.depth_px_range = [420, 420]
	more.beams.lean_px_range = [-160, -160]
	more.beams.intensity_range = [0.12, 0.12]
	more_plan = Generator.generate(map, more, 42).plan
	var changed_beam: Dictionary = objects(more_plan, 0, "beam")[0]
	check(changed_beam.width == 100 and changed_beam.depth == 420 and changed_beam.lean == -160 and changed_beam.intensity == 0.12, "beam ranges reach the raster plan")
	check(Baker.bake(more_plan).layers.water.rgba_sha256 != base.layers.water.rgba_sha256, "beam parameters change water pixels")
	more = profile.duplicate(true)
	more.composition.open_center_x_fraction = [0.48, 0.52]
	more_plan = Generator.generate(map, more, 42).plan
	check(objects(plan, 1, "clump") != objects(more_plan, 1, "clump"), "open center changes edge composition")
	more = profile.duplicate(true)
	more.palette.water_deep = "#123a48"
	more_plan = Generator.generate(map, more, 42).plan
	check(plan.profile_id == more_plan.profile_id and plan.profile_digest != more_plan.profile_digest and Cache.key(plan) != Cache.key(more_plan), "cache keys include profile content")
	var altered: Dictionary = plan.duplicate(true)
	altered.palette.water_deep = "#ffffff"
	altered.layers[0].objects.clear()
	check(before == Map.canonical(map) + Map.canonical(profile) and authority == Adapter.authority_bytes(), "generation/bake/output mutations leave input and Layout intact")
	var opaque := true
	var image: Image = base.layers.water.image
	for x in range(0, 1280, 19):
		for y in range(0, 480, 13): opaque = opaque and image.get_pixel(x, y).a == 1.0
	for corner in [Vector2i(0, 0), Vector2i(1279, 0), Vector2i(0, 479), Vector2i(1279, 479)]: opaque = opaque and image.get_pixelv(corner).a == 1.0
	check(opaque, "water base opaque across sample grid and borders")
	print("WG1_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
