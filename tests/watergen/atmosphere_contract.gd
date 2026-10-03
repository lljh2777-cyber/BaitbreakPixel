extends SceneTree
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Generator = preload("res://scripts/watergen/water_dynamic_generator.gd")
const Baker = preload("res://scripts/watergen/water_dynamic_baker.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG21_CONTRACT_PASS | ", title)
	else:
		failed += 1
		push_error("WG21_CONTRACT_FAIL | " + title)

func without_motes(layer: Dictionary) -> Array:
	return layer.objects.filter(func(o): return o.kind != "mote")

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	var map := Adapter.build(source.source_commit)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	var before := Map.canonical(map) + Map.canonical(profile)
	var authority := Adapter.authority_bytes()
	check(Generator.validate(profile).ok, "atmosphere profile valid")
	if not Generator.validate(profile).ok: quit(1); return
	for seed in [-1, "713284", 713284.0, null]: check(not Generator.generate(map, profile, seed).ok, "invalid seed rejected")
	var bad := profile.duplicate(true)
	bad.generator_version = "wg-2.9"
	check(not Generator.validate(bad).ok, "unknown version rejected")
	bad = profile.duplicate(true)
	bad["weather"] = "dark"
	check(not Generator.validate(bad).ok, "unknown field rejected")
	var recipes: Array = []
	for seed in [42, 731, 2649, 713284]:
		var plan: Dictionary = Generator.generate(map, profile, seed).plan
		recipes.append(plan.atmosphere.recipe)
		check(Map.canonical(plan) == Map.canonical(Generator.generate(map, profile, seed).plan), "repeat layout " + str(seed))
		var baked := Baker.bake(plan)
		check(baked.ok and baked.animations.size() == 18, "18 bounded decorative patches " + str(seed))
		var canopy_layers: Dictionary = {}
		var crop_exact := true
		var tall_groves := 0
		for layer in plan.layers:
			for object in layer.objects:
				if object.kind == "clump" and object.get("midwater", false):
					for stem in object.stems:
						if stem.y - stem.height < 150: tall_groves += 1
				if object.kind not in ["canopy", "animated_canopy"]: continue
				canopy_layers[layer.name] = true
				if object.kind != "animated_canopy": continue
				# Compare the cropped atlas patch to an uncropped raster, including
				# leaves outside the crop. This catches truncated tips and bad origins.
				var whole := Image.create(1280, 480, false, Image.FORMAT_RGBA8)
				whole.fill(Color.TRANSPARENT)
				Baker.Foliage.canopy(whole, object, layer.name, plan.palette)
				for animation in baked.animations:
					if animation.id != object.id: continue
					var restored := Image.create(1280, 480, false, Image.FORMAT_RGBA8)
					restored.fill(Color.TRANSPARENT)
					restored.blit_rect(animation.image, Rect2i(Vector2i.ZERO, animation.image.get_size()), Vector2i(animation.origin_px[0], animation.origin_px[1]))
					crop_exact = crop_exact and whole.get_data() == restored.get_data()
		check(canopy_layers.has("distance") and canopy_layers.has("foreground") and tall_groves >= 2, "upper center has both depth planes and tall groves " + str(seed))
		check(crop_exact, "canopy animation crops preserve complete leaves " + str(seed))
		var atlas_exact := true
		for animation in baked.animations:
			var r: Array = animation.region_px
			atlas_exact = atlas_exact and baked.animation_atlas.get_region(Rect2i(r[0], r[1], r[2], r[3])).get_data() == animation.image.get_data()
		check(atlas_exact, "atlas preserves every patch pixel")
		var anchored := true
		var bounded := true
		var equivalent := true
		var compact := true
		for animation in baked.animations:
			for time in [0.0, 0.75, 3.0, 8.0, 27.0, 60.0]:
				anchored = anchored and Frame.sway(animation, animation.root_y, time) == 0
				var covered := 0
				var bands := Frame.bands(animation, animation.image.get_height(), time)
				compact = compact and bands.size() <= 5
				for band in bands:
					covered += band.height
					for row in range(band.row, band.row + band.height):
						var shift := Frame.sway(animation, animation.origin_px[1] + row, time)
						equivalent = equivalent and shift == band.shift
						bounded = bounded and absf(shift) <= animation.amplitude
				equivalent = equivalent and covered == animation.image.get_height()
		check(anchored and bounded, "top roots and bottom roots pinned, motion bounded")
		check(equivalent and compact, "merged bands equal every original pixel row with <=5 draws per patch")
		var safe := true
		for layer in plan.layers:
			for camera in [Vector2.ZERO, Vector2(320, 60), Vector2(640, 120), Vector2(0, 120), Vector2(640, 0)]:
				safe = safe and Rect2(Vector2(layer.origin_px[0], layer.origin_px[1]) + Frame.layer_offset(camera, plan.parallax_compensation[layer.name]), Vector2(layer.size_px[0], layer.size_px[1])).encloses(Rect2(0, 0, 640, 360))
		check(safe, "padded layers cover camera bounds")
	check(recipes.size() == 4 and recipes[0] != recipes[1] and recipes[0] != recipes[2] and recipes[0] != recipes[3] and recipes[1] != recipes[2] and recipes[1] != recipes[3] and recipes[2] != recipes[3], "four seeds have distinct composition families")
	var plan: Dictionary = Generator.generate(map, profile, 713284).plan
	var baked := Baker.bake(plan)
	var repeat := Baker.bake(plan)
	for layer in Generator.Profile.LAYERS: check(baked.layers[layer].rgba_sha256 == repeat.layers[layer].rgba_sha256, "static pixel repeat " + layer)
	var same := true
	for index in baked.animations.size(): same = same and baked.animations[index].rgba_sha256 == repeat.animations[index].rgba_sha256
	check(same, "all animation patch pixels repeat")
	var more := profile.duplicate(true)
	more.composition.mote_count += 1
	var more_plan: Dictionary = Generator.generate(map, more, 713284).plan
	check(plan.atmosphere == more_plan.atmosphere and plan.palette == more_plan.palette, "extra mote never changes atmosphere/palette")
	for index in plan.layers.size():
		check(without_motes(plan.layers[index]) == without_motes(more_plan.layers[index]), "motes leave vegetation/roots/light unchanged " + str(index))
	more = profile.duplicate(true)
	more.composition.open_center_x_fraction = [0.18, 0.82]
	check(Generator.generate(map, more, 713284).plan.layers[1].objects != plan.layers[1].objects, "open center profile still controls distribution")
	var empty := profile.duplicate(true)
	for key in Generator.Profile.CLUMP_LIMITS: empty.composition[key] = [0, 0]
	var empty_plan: Dictionary = Generator.generate(map, empty, 713284).plan
	check(empty_plan.layers[1].objects.filter(func(o): return o.kind in ["clump", "animated_stem", "canopy", "animated_canopy"]).is_empty() and empty_plan.layers[5].objects.is_empty(), "zero foliage budget respected in both depth planes")
	check(Map.canonical(map) + Map.canonical(profile) == before and authority == Adapter.authority_bytes(), "map/profile/targets unchanged")
	print("WG21_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
