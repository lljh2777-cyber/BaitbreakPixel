extends "res://scripts/watergen/water_dynamic_cache.gd"
## Preview-only composition. No production adapter references this cache.
const Terrain = preload("res://scripts/watergen/water_visual_terrain.gd")
const TerrainBaker = preload("res://scripts/watergen/water_terrain_baker.gd")
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Foliage = preload("res://scripts/watergen/water_foliage.gd")
var terrain_profile: Dictionary = {}
var mode := "full"

func generate(map: Dictionary, profile: Dictionary, visual_seed: int) -> Dictionary:
	if not mode in ["full", "terrain", "before"]: return {"ok": false, "code": "PREVIEW_MODE"}
	var terrain := Terrain.generate(map, terrain_profile, visual_seed)
	if not terrain.ok: return terrain
	var result := super.generate(map, profile, visual_seed)
	if not result.ok: return result
	result.plan["visual_terrain"] = terrain.plan
	result.plan["preview_mode"] = mode
	result.plan.profile_digest = (result.plan.profile_digest + Map.canonical(terrain.plan) + mode).sha256_text()
	return result

func bake(plan: Dictionary) -> Dictionary:
	var source := plan.duplicate(true)
	if plan.preview_mode == "terrain":
		for layer in source.layers:
			if layer.name != "water": layer.objects.clear()
	var result := super.bake(source)
	if not result.ok or plan.preview_mode == "before": return result
	var terrain := TerrainBaker.bake(plan.visual_terrain, plan.palette, plan.parallax_compensation.distance)
	if not terrain.ok: return terrain
	# Ground behind far foliage; existing six-layer rendering and atlas are reused.
	var distance: Image = result.layers.distance.image
	terrain.far.blend_rect(distance, Rect2i(Vector2i.ZERO, distance.get_size()), Vector2i.ZERO)
	result.layers.distance.image = terrain.far
	result.layers.floor.image = terrain.bed
	if plan.preview_mode == "full":
		for layer in source.layers:
			if layer.name != "floor": continue
			for object in layer.objects:
				match object.kind:
					"gravel": DynamicBaker.Base._gravel(terrain.bed, object, plan.palette)
					"shadow": DynamicBaker.Base._shadow(terrain.bed, object, plan.palette)
					"leaf_litter": Foliage.litter(terrain.bed, object, plan.palette)
	for name in ["distance", "floor"]: result.layers[name].rgba_sha256 = Raster.digest(result.layers[name].image)
	return result
