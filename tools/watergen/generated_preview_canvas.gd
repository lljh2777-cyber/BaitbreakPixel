extends "res://tools/watergen/legacy_preview_canvas.gd"
## Static WG-1 viewer. Every accepted parallax vector is zero until WG-2.
func use_bundle(bundle: Dictionary) -> void:
	water_layers = {}
	for key in bundle.layers: water_layers[key] = bundle.layers[key].texture
	queue_redraw()

func _draw() -> void:
	if water_layers.is_empty(): return
	draw_set_transform(-camera_offset)
	for key in ["water", "distance", "surface", "floor", "terrain"]: draw_texture(water_layers[key], Vector2.ZERO)
	if show_geometry:
		_draw_plants(true)
		for prop in props: draw_texture(prop.texture, prop.position)
		_draw_plants(false)
	draw_texture(water_layers.foreground, Vector2.ZERO)
	if show_guides:
		for region in context.protected_regions:
			var r: Array = region.rect_px
			draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color(0.8, 0.8, 0.3, 0.6), false)
	draw_set_transform(Vector2.ZERO)
