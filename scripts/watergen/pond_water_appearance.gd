extends RefCounted
## Presentation-only adapter. No world, commands, save data or network input.
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Cache = preload("res://scripts/watergen/water_dynamic_cache.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const PROFILE_PATH := "res://data/watergen/forest_pond_atmosphere.json"
const SOURCE_COMMIT := "c1e3946f0b8cf1afa7becf2b238c8297efda5dc8"
const VISUAL_SEED := 713284
var cache := Cache.new()
var bundle: Dictionary = {}
var enabled := false
var last_code := "LEGACY"
var preparation: Dictionary = {}

static func eligible(role: String, shared: bool, connected: bool) -> bool:
	return role == "fish" and not shared and not connected

func fail(code: String) -> bool:
	enabled = false
	bundle = {}
	last_code = code
	print("WATERGEN_FALLBACK | ", code)
	return false

static func complete(value: Dictionary) -> bool:
	if not value.has_all(["layers", "animations", "parallax_compensation"]): return false
	for name in Cache.Profile.LAYERS:
		if not value.layers.has(name) or not value.parallax_compensation.has(name): return false
		var data: Dictionary = value.layers[name]
		if not data.has_all(["texture", "origin_px"]) or not data.texture is Texture2D: return false
		if data.texture.get_width() <= 0 or data.texture.get_height() <= 0: return false
	for animation in value.animations:
		if not animation.has_all(["texture", "region_px", "origin_px"]) or not animation.texture is Texture2D: return false
	return true

func select(value: bool, profile_override: Variant = null) -> bool:
	if not value:
		enabled = false
		last_code = "LEGACY"
		return true
	# Reopening settings, restarting and changing roles keep the same GPU bundle.
	if profile_override == null and complete(bundle):
		enabled = true
		last_code = "OK"
		return true
	var profile: Variant = profile_override
	if profile == null:
		if not FileAccess.file_exists(PROFILE_PATH): return fail("PROFILE_MISSING")
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(PROFILE_PATH)) != OK: return fail("PROFILE_JSON")
		profile = parser.data
	if not profile is Dictionary: return fail("PROFILE_TYPE")
	var result := cache.prepare(Adapter.build(SOURCE_COMMIT), profile, VISUAL_SEED)
	if not result.ok: return fail(result.code)
	if not complete(result.bundle): return fail("BUNDLE_INCOMPLETE")
	# Activate atomically; discard CPU images/plan with the local result.
	bundle = result.bundle
	preparation = result.timing_us.duplicate()
	enabled = true
	last_code = "OK"
	print("WATERGEN_READY | wg-2.1 | seed=", VISUAL_SEED, " | cache=", bundle.cache_key)
	return true

func draw_slot(view: Node2D, name: String, camera: Vector2, time: float, clip := Rect2()) -> void:
	var data: Dictionary = bundle.layers[name]
	var origin := Vector2(data.origin_px[0], data.origin_px[1])
	var offset := Frame.layer_offset(camera, bundle.parallax_compensation[name])
	view.draw_set_transform(offset)
	if clip.has_area(): view.draw_texture_rect_region(data.texture, clip, Rect2(clip.position - origin, clip.size))
	else: view.draw_texture(data.texture, origin)
	for animation in bundle.animations:
		if animation.layer != name: continue
		var region: Array = animation.region_px
		var at := Vector2(animation.origin_px[0], animation.origin_px[1])
		if not Rect2(at + offset, Vector2(region[2], region[3])).grow(animation.amplitude + 1).intersects(view.get_viewport_rect()): continue
		for band in Frame.bands(animation, region[3], time):
			view.draw_texture_rect_region(animation.texture, Rect2(at + Vector2(band.shift, band.row), Vector2(region[2], band.height)), Rect2(region[0], region[1] + band.row, region[2], band.height))
	# The existing scenery/actors continue in world coordinates, exactly once.
	view.draw_set_transform(-camera)
