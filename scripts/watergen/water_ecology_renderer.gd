extends RefCounted
## View-owned local flora. Call prepare only on context/settings changes.
const Plan = preload("res://scripts/watergen/water_ecology_plan.gd")
const Baker = preload("res://scripts/watergen/water_ecology_baker.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
var entries: Array[Dictionary] = []
var bundle: Dictionary = {}
var enabled := true
var prepare_count := 0
var bake_count := 0
var upload_count := 0
var last_timing_us: Dictionary = {}

func prepare(map: Dictionary, visual_seed: int, density := "medium") -> bool:
	if not Plan.Seed.valid(visual_seed) or density not in Plan.DENSITIES:
		bundle = {}; return false
	# Compare public values at setup, not broad file hashes or per-frame geometry.
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if entry.map == map and entry.seed == visual_seed and entry.density == density:
			entries.remove_at(index); entries.append(entry)
			bundle = entry.bundle
			last_timing_us = {"cache_hit": true, "plan": 0, "bake": 0, "upload": 0}
			return true
	var started := Time.get_ticks_usec()
	var result := Plan.generate(map, visual_seed, density)
	prepare_count += 1
	if not result.ok: bundle = {}; return false
	var plan_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var baked := Baker.bake(result.plan)
	bake_count += 1
	if not baked.ok: bundle = {}; return false
	var bake_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	bundle = {"texture": ImageTexture.create_from_image(baked.image), "patches": baked.patches, "plan": result.plan}
	upload_count += 1
	last_timing_us = {"cache_hit": false, "plan": plan_us, "bake": bake_us, "upload": Time.get_ticks_usec() - started}
	entries.append({"map": map.duplicate(true), "seed": visual_seed, "density": density, "bundle": bundle})
	while entries.size() > 2: entries.pop_front()
	return true

func draw_layer(view: Node2D, layer: String, camera: Vector2, visual_time: float) -> void:
	if not enabled or bundle.is_empty(): return
	for patch: Dictionary in bundle.patches:
		if patch.anchor_target < 0 and patch.layer == layer: _draw_patch(view, patch, camera, visual_time, 1.0)

func draw_attached(view: Node2D, targets: Array, camera: Vector2, visual_time: float, opacity := 1.0) -> void:
	if not enabled or bundle.is_empty() or opacity <= 0: return
	for patch: Dictionary in bundle.patches:
		if patch.anchor_target in targets: _draw_patch(view, patch, camera, visual_time, opacity)

func _draw_patch(view: Node2D, patch: Dictionary, camera: Vector2, visual_time: float, opacity: float) -> void:
	var r: Array = patch.region_px
	var origin := Vector2(patch.origin_px[0], patch.origin_px[1])
	if not Rect2(origin - camera, Vector2(r[2], r[3])).grow(3).intersects(view.get_viewport_rect()): return
	view.draw_set_transform(-camera)
	if patch.amplitude == 0:
		view.draw_texture_rect_region(bundle.texture, Rect2(origin, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, opacity))
	else:
		for band: Dictionary in Frame.bands(patch, r[3], visual_time):
			view.draw_texture_rect_region(bundle.texture, Rect2(origin + Vector2(band.shift, band.row), Vector2(r[2], band.height)), Rect2(r[0], r[1] + band.row, r[2], band.height), Color(1, 1, 1, opacity))
