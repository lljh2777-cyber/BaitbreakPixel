extends SceneTree
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Terrain = preload("res://scripts/watergen/water_visual_terrain.gd")
const Baker = preload("res://scripts/watergen/water_terrain_baker.gd")
const Dynamic = preload("res://scripts/watergen/water_dynamic_generator.gd")
const Seed = preload("res://scripts/watergen/water_visual_seed.gd")
const Raster = preload("res://scripts/watergen/water_raster.gd")
const PreviewCache = preload("res://tools/watergen/terrain_preview_cache.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("WG6_CONTRACT_PASS | ", title)
	else: failed += 1; push_error("WG6_CONTRACT_FAIL | " + title)

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

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	var map := Adapter.build(source.source_commit)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/terrain_profiles.json"))
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	var immutable := Map.canonical(map) + Map.canonical(profiles) + Map.canonical(visual)
	var authority := Adapter.authority_bytes()
	check(map.map_public_digest == "ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d", "frozen PondLayout digest")
	for seed in [-1, 2147483648, 42.0, "42", null]: check(not Terrain.generate(map, profiles.fern, seed).ok, "reject invalid seed " + str(seed))
	for profile in [null, {}, {"terrain_style": "bad"}]: check(not Terrain.generate(map, profile, 42).ok, "reject malformed profile")
	for field in ["terrain_relief", "ridge_count", "depression_count", "center_clearance", "bank_bias"]:
		for value in [-100, 99999, NAN, INF, "3"]:
			var bad: Dictionary = profiles.fern.duplicate(true)
			bad[field] = value
			check(not Terrain.generate(map, bad, 42).ok, "reject " + field + " " + str(value))
	var private_profile: Dictionary = profiles.fern.duplicate(true)
	private_profile["world"] = {}
	check(not Terrain.generate(map, private_profile, 42).ok, "unknown/private field rejected")
	var bad_map := map.duplicate(true)
	bad_map.world_size_px = [8192, 8192]
	bad_map.map_public_digest = Map.digest(bad_map)
	check(not Terrain.generate(bad_map, profiles.fern, 42).ok, "oversized map rejected before allocation")
	var hashes: Array = []
	var index := 0
	for id in ["fern", "ribbon", "lily", "root"]:
		var seed: int = [713284, 2649, 42, 731][index]
		index += 1
		var old_plan: Dictionary = Dynamic.generate(map, visual, seed).plan
		var plan: Dictionary = Terrain.generate(map, profiles[id], seed).plan
		check(plain(plan), "pure-value terrain plan " + id)
		var exact := Map.canonical(plan)
		check(exact == Map.canonical(Terrain.generate(map, profiles[id], seed).plan), "deterministic plan " + id)
		check(plan.ridges.size() == profiles[id].ridge_count * 2 and plan.depressions.size() == profiles[id].depression_count, "profile budgets control macro composition " + id)
		var other: Dictionary = Terrain.generate(map, profiles[id], seed + 4).plan
		check(plan.ridges != other.ridges and plan.stone_shelves != other.stone_shelves, "same style different seed changes geometry " + id)
		for name in ["flora", "microfauna", "distant_school", "debris"]:
			var rng := Seed.stream(seed, name, "future-budget")
			for count in 500: rng.randf()
		check(exact == Map.canonical(Terrain.generate(map, profiles[id], seed).plan), "ecology streams cannot perturb terrain " + id)
		check(Map.canonical(old_plan) == Map.canonical(Dynamic.generate(map, visual, seed).plan), "terrain cannot perturb existing atmosphere/foliage " + id)
		for depth in Terrain.DEPTHS:
			var bounded := true
			var smooth := true
			var previous := Terrain.surface_y(plan, depth, -148)
			for x in range(-147, 1428):
				var y := Terrain.surface_y(plan, depth, x)
				bounded = bounded and y >= 220 and y <= 515
				smooth = smooth and absf(y - previous) < 2.0
				previous = y
			check(bounded and smooth, "broad smooth bounded relief " + id + " " + depth)
		check(Terrain.surface_y(plan, "middle", 640) >= 422, "clear central bed " + id)
		var pixels := Baker.bake(plan, old_plan.palette, visual.parallax_compensation.distance)
		var repeat := Baker.bake(plan, old_plan.palette, visual.parallax_compensation.distance)
		for layer in ["far", "bed"]:
			check(pixels[layer].get_data() == repeat[layer].get_data(), "deterministic RGBA " + id + " " + layer)
			var upper := true
			for y in range(0, 190, 7):
				for x in range(0, pixels[layer].get_width(), 13): upper = upper and pixels[layer].get_pixel(x, y).a == 0
			check(upper, "upper water/HUD stays free of terrain " + id + " " + layer)
		hashes.append(Raster.digest(pixels.bed))
		var cache := PreviewCache.new()
		cache.terrain_profile = profiles[id]
		var combined: Dictionary = cache.generate(map, visual, seed).plan
		check(combined.layers == old_plan.layers and combined.atmosphere == old_plan.atmosphere, "terrain wrapper retains original plant/light descriptors " + id)
		var after := cache.bake(combined)
		cache.mode = "before"
		var old: Dictionary = cache.generate(map, visual, seed).plan
		var previous_pixels := cache.bake(old)
		check(cache.key(combined) != cache.key(old), "comparison mode has a distinct cache key " + id)
		for layer in ["water", "surface", "terrain", "foreground"]:
			check(after.layers[layer].rgba_sha256 == previous_pixels.layers[layer].rgba_sha256, "WG6 leaves existing layer pixels intact " + id + " " + layer)
		check(after.animation_atlas.get_data() == previous_pixels.animation_atlas.get_data(), "existing animation atlas remains byte-identical " + id)
		check(after.layers.distance.rgba_sha256 != previous_pixels.layers.distance.rgba_sha256 and after.layers.floor.rgba_sha256 != previous_pixels.layers.floor.rgba_sha256, "only intended ground layers change " + id)
		cache.mode = "terrain"
		var isolated: Dictionary = cache.generate(map, visual, seed).plan
		check(cache.key(combined) != cache.key(isolated), "terrain-only has a distinct cache key " + id)
		plan.ridges.clear()
		plan.profile.terrain_relief = 0
	check(hashes.size() == 4 and hashes[0] != hashes[1] and hashes[0] != hashes[2] and hashes[0] != hashes[3] and hashes[1] != hashes[2] and hashes[1] != hashes[3] and hashes[2] != hashes[3], "four distinct raster compositions")
	check(immutable == Map.canonical(map) + Map.canonical(profiles) + Map.canonical(visual), "generation/raster/output edits do not mutate inputs")
	check(authority == Adapter.authority_bytes(), "authority geometry and interaction target order remain byte-identical")
	print("WG6_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
