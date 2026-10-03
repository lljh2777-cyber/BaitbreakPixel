extends RefCounted
## Versioned WG-2 preview. Keep 2.0 callable for a same-seed A/B comparison.
const Base = preload("res://scripts/watergen/water_visual_generator.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const Atmosphere = preload("res://scripts/watergen/water_atmosphere.gd")
const VERSION := "wg-2.1"
const LEGACY_VERSION := "wg-2.0"
const RASTER_SPEC := "rgba8-rich-foliage-atlas-v2"
const LEGACY_RASTER_SPEC := "rgba8-padded-stem-strips-v1"

static func validate(profile: Variant) -> Dictionary:
	if not profile is Dictionary or not profile.get("generator_version") in [VERSION, LEGACY_VERSION]: return Profile.fail("VERSION")
	var legacy: Dictionary = profile.duplicate(true)
	legacy.generator_version = Profile.VERSION
	var k: Variant = profile.get("parallax_compensation")
	if not Profile.keys(k, Profile.LAYERS): return Profile.fail("PARALLAX_FIELDS")
	for layer in Profile.LAYERS:
		var v: Variant = k[layer]
		if not v is Array or v.size() != 2 or not Profile.number(v[0], -0.1, 0.3) or not Profile.number(v[1], -0.1, 0.3): return Profile.fail("PARALLAX_RANGE")
		if layer in ["water", "floor"] and (v[0] != 0 or v[1] != 0): return Profile.fail("ANCHORED_BASE")
		legacy.parallax_compensation[layer] = [0, 0]
	return Profile.validate(legacy)

static func generate(map: Variant, profile: Variant, visual_seed: Variant) -> Dictionary:
	var validation := validate(profile)
	if not validation.ok: return validation
	var legacy: Dictionary = profile.duplicate(true)
	legacy.generator_version = Profile.VERSION
	for layer in Profile.LAYERS: legacy.parallax_compensation[layer] = [0, 0]
	var result := Base.generate(map, legacy, visual_seed)
	if not result.ok: return result
	var plan: Dictionary = result.plan
	plan.generator_version = profile.generator_version
	plan.profile_digest = Profile.digest(profile)
	plan.parallax_compensation = profile.parallax_compensation.duplicate(true)
	plan["raster_spec"] = RASTER_SPEC if profile.generator_version == VERSION else LEGACY_RASTER_SPEC
	plan["layout_stream_version"] = Profile.VERSION
	if profile.generator_version == VERSION: Atmosphere.enrich(plan, map, profile.composition)
	for layer in plan.layers:
		var pad := Frame.padding(profile.parallax_compensation[layer.name])
		layer.origin_px = [-pad.x, -pad.y]
		layer["size_px"] = [1280 + pad.x * 2, 480 + pad.y * 2]
		if profile.generator_version == VERSION:
			Atmosphere.animate(layer, visual_seed)
			plan.statistics[layer.name] = layer.objects.size()
			continue
		# Animate two separate decorative stems, never a collision/interactive plant.
		if layer.name != "terrain": continue
		var additions: Array = []
		for object in layer.objects:
			if object.kind != "clump" or additions.size() >= 2: continue
			var stem: Dictionary = object.stems.pop_front()
			additions.append({"id": object.id + "/sway", "kind": "animated_stem", "contrast": object.contrast, "stem": stem, "root_y": stem.y, "height": stem.height, "phase": stem.phase})
		layer.objects.append_array(additions)
		plan.statistics[layer.name] = layer.objects.size()
	return result
