extends RefCounted
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const Seed = preload("res://scripts/watergen/water_visual_seed.gd")

static func generate(map: Variant, profile: Variant, visual_seed: Variant) -> Dictionary:
	var validation := Map.validate(map)
	if not validation.ok: return validation
	validation = Profile.validate(profile)
	if not validation.ok: return validation
	if not Seed.valid(visual_seed): return Profile.fail("VISUAL_SEED")
	if map.world_size_px != [1280, 480]: return Profile.fail("WG1_RASTER_BUDGET")
	var layers: Dictionary = {}
	for key in Profile.LAYERS: layers[key] = {"name": key, "origin_px": [0, 0], "objects": []}
	var size: Array = map.world_size_px
	var composition: Dictionary = profile.composition
	var water_rng := Seed.stream(visual_seed, "water", "field")
	layers.water["phase"] = water_rng.randf_range(0, TAU)
	var beams: Dictionary = profile.beams
	for index in _count(visual_seed, "water", beams.count_range):
		var rng := Seed.stream(visual_seed, "water", "beam", index)
		layers.water.objects.append({"id": "water/beam/" + str(index), "kind": "beam", "x": rng.randf_range(-40, size[0] - 100), "width": _sample(rng, beams.width_px_range), "depth": _sample(rng, beams.depth_px_range), "lean": _sample(rng, beams.lean_px_range), "intensity": _sample(rng, beams.intensity_range), "phase": rng.randf_range(0, TAU)})
	for entry in [["distance", "far_clump_count_range"], ["terrain", "middle_clump_count_range"], ["foreground", "foreground_clump_count_range"]]:
		var layer: String = entry[0]
		for index in _count(visual_seed, layer, composition[entry[1]]):
			layers[layer].objects.append(_clump(visual_seed, layer, index, map, composition))
	for index in _count(visual_seed, "surface", composition.surface_pad_count_range):
		var rng := Seed.stream(visual_seed, "surface", "pad", index)
		var x := _edge_x(index, rng, size[0], composition.open_center_x_fraction)
		layers.surface.objects.append({"id": "surface/pad/" + str(index), "kind": "pad", "x": x, "y": map.visual_surface_y_px + rng.randf_range(-4, 2), "width": rng.randf_range(25, 49), "depth": rng.randf_range(4, 8), "stem_length": rng.randf_range(180, 375), "lean": rng.randf_range(-25, 25), "phase": rng.randf_range(0, TAU)})
	for index in 3:
		var rng := Seed.stream(visual_seed, "surface", "root", index)
		layers.surface.objects.append({"id": "surface/root/" + str(index), "kind": "root", "x": rng.randf_range(6, 85), "y": map.visual_surface_y_px, "length": rng.randf_range(65, 150), "width": rng.randf_range(16, 28), "phase": rng.randf_range(0, TAU)})
	var bed_rng := Seed.stream(visual_seed, "floor", "bed")
	layers.floor["phase"] = bed_rng.randf_range(0, TAU)
	for record in map.static_cover_records:
		var bounds: Array = record.bounds_px
		if record.kind != "grass" and bounds[1] + bounds[3] >= map.floor_y_px - 3:
			layers.floor.objects.append({"id": "floor/shadow/" + str(record.legacy_target_index), "kind": "shadow", "x": bounds[0] + bounds[2] * 0.5, "y": map.floor_y_px + 2, "radius": bounds[2] * 0.44})
	for index in int(composition.gravel_count):
		var rng := Seed.stream(visual_seed, "floor", "gravel", index)
		var patch := Seed.stream(visual_seed, "floor", "patch", index % 12)
		var x := clampf(patch.randf_range(0, size[0]) + rng.randf_range(-75, 75), 2, size[0] - 8)
		var y := clampf(patch.randf_range(map.floor_y_px - 12, size[1] - 3) + rng.randf_range(-14, 14), map.floor_y_px - 22, size[1] - 2)
		layers.floor.objects.append({"id": "floor/gravel/" + str(index), "kind": "gravel", "x": x, "y": y, "width": rng.randi_range(2, 7), "height": rng.randi_range(1, 3), "shade": rng.randi_range(0, 3)})
	for index in int(composition.mote_count):
		var rng := Seed.stream(visual_seed, "distance", "mote", index)
		layers.distance.objects.append({"id": "distance/mote/" + str(index), "kind": "mote", "x": rng.randi_range(8, size[0] - 9), "y": rng.randi_range(map.visual_surface_y_px + 25, map.floor_y_px - 18), "alpha": rng.randf_range(0.07, 0.15)})
	var ordered: Array = []
	var counts: Dictionary = {}
	for key in Profile.LAYERS:
		ordered.append(layers[key])
		counts[key] = layers[key].objects.size()
	var plan := {"format": "baitbreak-water-scene-plan", "schema_version": 1, "generator_version": Profile.VERSION, "profile_id": profile.profile_id, "profile_digest": Profile.digest(profile), "map_public_digest": map.map_public_digest, "visual_seed": visual_seed, "world_size_px": size.duplicate(), "surface_y": map.visual_surface_y_px, "floor_y": map.floor_y_px, "palette": profile.palette.duplicate(true), "parallax_compensation": profile.parallax_compensation.duplicate(true), "layers": ordered, "statistics": counts}
	return {"ok": true, "code": "OK", "plan": plan}

static func _sample(rng: RandomNumberGenerator, interval: Array) -> float:
	# RNG real_t precision can round a singleton range just outside its endpoints.
	return clampf(rng.randf_range(interval[0], interval[1]), interval[0], interval[1])

static func _count(visual_seed: int, layer: String, interval: Array) -> int:
	return Seed.stream(visual_seed, layer, "count").randi_range(int(interval[0]), int(interval[1]))

static func _edge_x(index: int, rng: RandomNumberGenerator, width: float, center: Array) -> float:
	# Stable, stratified edge placement: adding a named object never shifts earlier ones.
	var fraction := fposmod(index * 0.61803398875 + rng.randf_range(0.05, 0.26), 1.0)
	if index % 2 == 0: return lerpf(18, maxf(18, width * center[0] - 18), fraction)
	return lerpf(minf(width - 18, width * center[1] + 18), width - 18, fraction)

static func _clump(visual_seed: int, layer: String, index: int, map: Dictionary, composition: Dictionary) -> Dictionary:
	var rng := Seed.stream(visual_seed, layer, "clump", index)
	var size: Array = map.world_size_px
	var x := _edge_x(index, rng, size[0], composition.open_center_x_fraction)
	var root: float = map.floor_y_px + rng.randf_range(-27, 5)
	var height := rng.randf_range(110, 260)
	var width := rng.randf_range(40, 80)
	var contrast := 1.0
	if layer == "terrain": height = rng.randf_range(30, 76); root = map.floor_y_px + rng.randf_range(-10, 4)
	if layer == "foreground": height = rng.randf_range(25, 63); root = size[1] + 4; width = rng.randf_range(28, 62)
	for region in map.protected_regions:
		var r: Array = region.rect_px
		var rect := Rect2(r[0], r[1], r[2], r[3]).grow(24)
		if rect.has_point(Vector2(x, root - height * 0.5)): contrast = 0.5
	var stems: Array = []
	for stem_index in rng.randi_range(5, 9):
		var stem_rng := Seed.stream(visual_seed, layer, "clump-%d-stem" % index, stem_index)
		stems.append({"x": x + stem_rng.randf_range(-width * 0.5, width * 0.5), "y": root + stem_rng.randf_range(-2, 2), "height": height * stem_rng.randf_range(0.55, 1), "lean": stem_rng.randf_range(-16, 16), "phase": stem_rng.randf_range(0, TAU), "kind": "ribbon" if stem_index % 3 == 0 else "fern"})
	return {"id": layer + "/clump/" + str(index), "kind": "clump", "contrast": contrast, "stems": stems}
