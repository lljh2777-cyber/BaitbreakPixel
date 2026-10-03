extends Node2D
## Preview-only static slice of pond_scenery.background and pond_view._world.
## Original painters/crops/order are retained. No authority or fake world object.
const Water = preload("res://scripts/pond_water_art.gd")
const Scenery = preload("res://scripts/pond_scenery.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Plant = preload("res://scripts/pond_plant_art.gd")
var camera_offset := Vector2.ZERO
var water_layers: Dictionary = {}
var context: Dictionary = {}
var props: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var show_geometry := true
var show_guides := false
var preparation_us := 0

func prepare(public_context: Dictionary) -> void:
	context = public_context.duplicate(true)
	var started := Time.get_ticks_usec()
	# Preserve the legacy initialization call. Its CPU bake + upload is indivisible.
	water_layers = Water.layers()
	preparation_us = Time.get_ticks_usec() - started
	prepare_geometry(public_context)
	queue_redraw()

func prepare_geometry(public_context: Dictionary) -> void:
	context = public_context.duplicate(true)
	props = Art.scene_props()
	plants.clear()
	# Original pond_view._make_plant_layer crop, at fixed visual time zero.
	for record in context.static_cover_records:
		if record.kind != "grass": continue
		var plant: Dictionary = record.source
		var canvas := Image.create(1280, 132, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		Plant.paint(canvas, plant, 0.0)
		var region := Rect2i(int(plant.x - plant.width * 0.5 - 14), int(129 - plant.height - 8), int(plant.width + 29), int(plant.height + 12))
		region = region.intersection(Rect2i(0, 0, 1280, 132))
		plants.append({"texture": ImageTexture.create_from_image(canvas.get_region(region)), "position": Vector2(region.position) + Vector2(0, plant.y - 129), "back": plant.back})

func _draw() -> void:
	if water_layers.is_empty(): return
	draw_set_transform(-camera_offset)
	draw_texture(water_layers.water, Vector2.ZERO)
	# Static far bank copied from pond_scenery.gd at the recorded source commit.
	draw_rect(Rect2(0, 0, 1280, 55), Color("a9b8a3"))
	var bank := PackedVector2Array([Vector2(0, 55)])
	for x in range(0, 1288, 8):
		var height: float = 9 + sin(x * 0.010) * 4 + sin(x * 0.031 + 1.2) * 2 + sin(x * 0.067) * 0.8
		bank.append(Vector2(x, 53 - roundf(height)))
	bank.append(Vector2(1280, 55))
	draw_colored_polygon(bank, Color("6c9287"))
	draw_rect(Rect2(0, 53, 1280, 2), Color("6faaa0"))
	draw_texture(water_layers.distance, (camera_offset * Vector2(0.22, 0.08)).round())
	draw_texture(water_layers.surface, (camera_offset * Vector2(0.13, 0.03)).round())
	draw_texture(water_layers.floor, Vector2.ZERO)
	draw_texture(water_layers.terrain, (camera_offset * Vector2(0.06, 0.02)).round())
	if show_geometry: _draw_plants(true)
	Scenery.floor_layer(self)
	if show_geometry:
		for prop in props: draw_texture(prop.texture, prop.position)
		_draw_plants(false)
	Scenery.foreground(self)
	if show_guides:
		for region in context.protected_regions:
			var rect: Array = region.rect_px
			draw_rect(Rect2(rect[0], rect[1], rect[2], rect[3]), Color(0.8, 0.8, 0.3, 0.6), false)
		for record in context.static_cover_records:
			var points := PackedVector2Array()
			for vertex in record.polygon_px: points.append(Vector2(vertex[0], vertex[1]))
			points.append(points[0])
			draw_polyline(points, Color(0.4, 0.9, 0.8, 0.6))
	draw_set_transform(Vector2.ZERO)

func _draw_plants(back: bool) -> void:
	for plant in plants:
		if plant.back == back: draw_texture(plant.texture, plant.position)
