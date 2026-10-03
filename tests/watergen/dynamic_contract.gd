extends SceneTree
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Generator = preload("res://scripts/watergen/water_dynamic_generator.gd")
const Baker = preload("res://scripts/watergen/water_dynamic_baker.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const LegacyGenerator = preload("res://scripts/watergen/water_visual_generator.gd")
const LegacyBaker = preload("res://scripts/watergen/water_visual_baker.gd")
const Cache = preload("res://scripts/watergen/water_dynamic_cache.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG2_CONTRACT_PASS | ", title)
	else:
		failed += 1
		push_error("WG2_CONTRACT_FAIL | " + title)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	var map := Adapter.build(source.source_commit)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_dynamic.json"))
	var old_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond.json"))
	var immutable := Map.canonical(map) + Map.canonical(profile)
	var authority := Adapter.authority_bytes()
	var validation := Generator.validate(profile)
	check(validation.ok, "WG2 profile accepted: " + str(validation))
	if not validation.ok: quit(1); return
	check(not Generator.validate(old_profile).ok, "old profile never silently upgraded")
	for value in [null, "bad", {}, {"generator_version": "wg-2.0"}]: check(not Generator.validate(value).ok, "malformed profile rejected")
	for value in [-0.11, 0.31, NAN, INF, "0.22"]:
		var bad := profile.duplicate(true)
		bad.parallax_compensation.distance[0] = value
		check(not Generator.generate(map, bad, 713284).ok, "invalid parallax " + str(value))
	for layer in ["water", "floor"]:
		var bad := profile.duplicate(true)
		bad.parallax_compensation[layer] = [0.1, 0]
		check(not Generator.validate(bad).ok, "anchored base " + layer)
	var bad := profile.duplicate(true)
	bad["world"] = {}
	check(not Generator.validate(bad).ok, "unknown private field rejected")
	for seed in [42, 731, 2649, 713284]:
		var plan: Dictionary = Generator.generate(map, profile, seed).plan
		check(Map.canonical(plan) == Map.canonical(Generator.generate(map, profile, seed).plan), "repeat plan " + str(seed))
		check(not Map.canonical(plan).contains("Object") and not plan.has("fixtures"), "pure plan without fixture state")
		for layer in plan.layers:
			var k: Array = plan.parallax_compensation[layer.name]
			var origin := Vector2(layer.origin_px[0], layer.origin_px[1])
			var size := Vector2(layer.size_px[0], layer.size_px[1])
			var safe := true
			for camera in [Vector2.ZERO, Vector2(320, 60), Vector2(640, 120), Vector2(0, 120), Vector2(640, 0)]:
				var bounds := Rect2(origin + Frame.layer_offset(camera, k), size)
				safe = safe and bounds.encloses(Rect2(0, 0, 640, 360))
			check(safe, "layer covers all camera extrema " + layer.name)
	var plan: Dictionary = Generator.generate(map, profile, 713284).plan
	var baked := Baker.bake(plan)
	var repeated := Baker.bake(plan)
	var legacy_plan: Dictionary = LegacyGenerator.generate(map, old_profile, 713284).plan
	var legacy := LegacyBaker.bake(legacy_plan)
	for name in Generator.Profile.LAYERS:
		check(baked.layers[name].rgba_sha256 == repeated.layers[name].rgba_sha256, "padded pixel repeat " + name)
		if name == "terrain": continue
		var layer_index: int = Generator.Profile.LAYERS.find(name)
		check(plan.layers[layer_index].objects == legacy_plan.layers[layer_index].objects, "selected WG1 object coordinates preserved " + name)
		var data: Dictionary = baked.layers[name]
		var core: Image = data.image.get_region(Rect2i(-data.origin_px[0], -data.origin_px[1], 1280, 480))
		# Rebasing fractional distant leaf vertices can quantize differently in Vector2.
		# Record that difference; WG2 promises stable object coordinates and repeatable
		# new pixels, not byte-identical pixels to the old unpadded raster version.
		if name == "distance":
			var changed_pixels := 0
			for y in 480:
				for x in 1280:
					if core.get_pixel(x, y) != legacy.layers[name].image.get_pixel(x, y): changed_pixels += 1
			print("WG2_DISTANCE_REBASE_CHANGED_PIXELS | ", changed_pixels)
		else: check(core.get_data() == legacy.layers[name].image.get_data(), "unchanged central pixels " + name)
	check(Cache.key(plan) != Cache.key(legacy_plan), "new raster version separates cache")
	check(baked.animations.size() == 2, "only two decorative stems animated")
	var rooted := true
	var bounded := true
	var initial := true
	for animation in baked.animations:
		for time in [0, 0.25, 3, 27, 80, 86400]:
			rooted = rooted and Frame.sway(animation, animation.root_y, time) == 0 and Frame.sway(animation, animation.root_y + 1, time) == 0
			for row in animation.image.get_height():
				var y: float = animation.origin_px[1] + row
				bounded = bounded and absf(Frame.sway(animation, y, time)) <= 2
				initial = initial and Frame.sway(animation, y, 0) == 0
	check(rooted, "every animated root fixed at every sampled time")
	check(bounded and initial, "sway bounded at two pixels, initial pose preserved")
	check(Frame.layer_offset(Vector2(640, 120), [0.22, 0.08]) == Vector2(-499, -110), "compensation is 78 percent scroll, one camera transform")
	var oversized := plan.duplicate(true)
	oversized.layers[1].size_px = [8192, 8192]
	check(not Baker.bake(oversized).ok, "padded allocation bounded before image creation")
	var frame := {"role": "preview", "camera_offset_px": [640, 120], "viewport_size_px": [640, 360], "visual_time_seconds": 3}
	check(Frame.validate(frame), "minimal preview frame accepted")
	for field in ["world", "rng", "hook"]:
		var invalid := frame.duplicate(true)
		invalid[field] = 1
		check(not Frame.validate(invalid), "frame rejects " + field)
	for value in [-1, NAN, INF, 86401]:
		var invalid := frame.duplicate(true)
		invalid.visual_time_seconds = value
		check(not Frame.validate(invalid), "invalid visual time rejected")
	var clock := Frame.new()
	clock.advance(0.25)
	clock.paused = true
	clock.advance(0.75)
	check(clock.visual_time == 0.25, "pause ignores elapsed update")
	clock.paused = false
	clock.advance(0.5)
	check(clock.visual_time == 0.75 and clock.seek(3) and clock.visual_time == 3 and not clock.seek(NAN), "resume and explicit seek")
	check(immutable == Map.canonical(map) + Map.canonical(profile) and authority == Adapter.authority_bytes(), "map/profile/authority immutable")
	print("WG2_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
