extends RefCounted
## CPU plans/images are returned to callers; only two GPU bundles are retained.
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const Generator = preload("res://scripts/watergen/water_visual_generator.gd")
const Baker = preload("res://scripts/watergen/water_visual_baker.gd")
var bundles: Dictionary = {}
var order: Array[String] = []
var bake_count := 0
var plan_count := 0
var upload_count := 0
var texture_count := 0

func generate(map: Dictionary, profile: Dictionary, visual_seed: int) -> Dictionary:
	return Generator.generate(map, profile, visual_seed)

func bake(plan: Dictionary) -> Dictionary:
	return Baker.bake(plan)

static func key(plan: Dictionary) -> String:
	return (plan.generator_version + "|" + plan.profile_digest + "|" + plan.map_public_digest + "|" + str(plan.visual_seed) + "|" + plan.get("raster_spec", "rgba8-native-zero-parallax") + "|" + str(Engine.get_version_info().hash)).sha256_text()

func prepare(map: Dictionary, profile: Dictionary, visual_seed: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	plan_count += 1
	var result := generate(map, profile, visual_seed)
	if not result.ok: return result
	var plan: Dictionary = result.plan
	var cache_key := key(plan)
	var plan_us := Time.get_ticks_usec() - started
	if bundles.has(cache_key):
		order.erase(cache_key)
		order.append(cache_key)
		return {"ok": true, "cache_hit": true, "bundle": bundles[cache_key], "plan": plan, "images": {}, "timing_us": {"plan": plan_us, "bake": 0, "upload_api": 0}}
	bake_count += 1
	started = Time.get_ticks_usec()
	var baked := bake(plan)
	var bake_us := Time.get_ticks_usec() - started
	if not baked.ok: return baked
	started = Time.get_ticks_usec()
	var layers: Dictionary = {}
	for layer in Profile.LAYERS:
		var data: Dictionary = baked.layers[layer]
		layers[layer] = {"texture": ImageTexture.create_from_image(data.image), "origin_px": data.origin_px, "rgba_sha256": data.rgba_sha256}
		texture_count += 1
	var animations: Array = []
	var atlas: ImageTexture
	if baked.has("animation_atlas"):
		atlas = ImageTexture.create_from_image(baked.animation_atlas)
		texture_count += 1
	for data in baked.get("animations", []):
		var animation: Dictionary = data.duplicate()
		animation.erase("image")
		if atlas != null: animation["texture"] = atlas
		else:
			animation["texture"] = ImageTexture.create_from_image(data.image)
			texture_count += 1
		animations.append(animation)
	upload_count += 1
	var bundle := {"cache_key": cache_key, "layers": layers, "animations": animations, "parallax_compensation": plan.parallax_compensation.duplicate(true)}
	bundles[cache_key] = bundle
	order.append(cache_key)
	while order.size() > 2:
		bundles.erase(order.pop_front())
	return {"ok": true, "cache_hit": false, "bundle": bundle, "plan": plan, "images": baked.layers, "timing_us": {"plan": plan_us, "bake": bake_us, "upload_api": Time.get_ticks_usec() - started}}
