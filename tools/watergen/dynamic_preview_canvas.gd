extends "res://tools/watergen/legacy_preview_canvas.gd"
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const Fixtures = preload("res://tools/watergen/readability_fixtures.gd")
var bundle: Dictionary = {}
var visual_time := 0.0
var show_fixtures := false
var fixtures: RefCounted
var draw_count := 0
var last_draw_us := 0

func use_bundle(value: Dictionary) -> void:
	bundle = value
	queue_redraw()

func set_frame(frame: Dictionary) -> bool:
	if not Frame.validate(frame): return false
	camera_offset = Vector2(frame.camera_offset_px[0], frame.camera_offset_px[1])
	visual_time = frame.visual_time_seconds
	queue_redraw()
	return true

func _layer(name: String) -> void:
	var data: Dictionary = bundle.layers[name]
	draw_set_transform(Frame.layer_offset(camera_offset, bundle.parallax_compensation[name]))
	draw_texture(data.texture, Vector2(data.origin_px[0], data.origin_px[1]))
	for animation in bundle.animations:
		if animation.layer != name: continue
		var texture: Texture2D = animation.texture
		var origin := Vector2(animation.origin_px[0], animation.origin_px[1])
		var region: Array = animation.get("region_px", [0, 0, texture.get_width(), texture.get_height()])
		var screen_origin := origin + Frame.layer_offset(camera_offset, bundle.parallax_compensation[name])
		if not Rect2(screen_origin, Vector2(region[2], region[3])).grow(animation.get("amplitude", 2.0) + 1).intersects(get_viewport_rect()): continue
		# Merge identically shifted rows, preserving the original nearest-pixel result.
		for band in Frame.bands(animation, region[3], visual_time):
			draw_texture_rect_region(texture, Rect2(origin + Vector2(band.shift, band.row), Vector2(region[2], band.height)), Rect2(region[0], region[1] + band.row, region[2], band.height))

func _draw() -> void:
	if bundle.is_empty(): return
	var started := Time.get_ticks_usec()
	for name in ["water", "distance", "surface", "floor", "terrain"]: _layer(name)
	draw_set_transform(-camera_offset)
	if show_geometry:
		_draw_plants(true)
		for prop in props: draw_texture(prop.texture, prop.position)
		_draw_plants(false)
	_layer("foreground")
	draw_set_transform(-camera_offset)
	if show_guides:
		for region in context.protected_regions:
			var r: Array = region.rect_px
			draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color(0.8, 0.8, 0.3, 0.6), false)
	draw_set_transform(Vector2.ZERO)
	if show_fixtures and fixtures != null: fixtures.draw_samples(self)
	last_draw_us = Time.get_ticks_usec() - started
	draw_count += 1
