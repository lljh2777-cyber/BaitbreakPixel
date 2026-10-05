extends Node2D
## Read-only rendering slice of current generated ponds; no simulated world.
const Appearance = preload("res://scripts/watergen/generated_water_appearance.gd")
const Ecology = preload("res://scripts/watergen/water_ecology_renderer.gd")
const Presentation = preload("res://scripts/maps/map_presentation.gd")
const Art = preload("res://scripts/pixel_art.gd")
const Plant = preload("res://scripts/pond_plant_art.gd")
const Scenery = preload("res://scripts/pond_scenery.gd")
var generated_water := Appearance.new()
var ecology := Ecology.new()
var map_presentation: RefCounted
var public_map: Dictionary = {}
var camera_offset := Vector2(320, 120)
var water_layers: Dictionary = {}
var props: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var mode := "full"
var visual_time := 0.0
var guides := false
var cover_opacity := 1.0
var last_draw_us := 0
var prepared_context: RefCounted

func prepare(context: RefCounted, visual_seed: int, density: String) -> bool:
	if not generated_water.prepare(context, visual_seed): return false
	var next := Appearance.Adapter.build(context)
	if not ecology.prepare(next, visual_seed, density): return false
	public_map = next
	if prepared_context != context:
		prepared_context = context
		map_presentation = Presentation.for_context(context)
		props = Art.scene_props(map_presentation)
		plants.clear()
		for plant: Dictionary in map_presentation.plants:
			var image := Image.create(1280, 132, false, Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			Plant.paint(image, plant, 0.0)
			var region := Rect2i(int(plant.x - plant.width * 0.5 - 14), int(129 - plant.height - 8), int(plant.width + 29), int(plant.height + 12)).intersection(Rect2i(0, 0, 1280, 132))
			plants.append({"texture": ImageTexture.create_from_image(image.get_region(region)), "position": Vector2(region.position) + Vector2(0, plant.y - 129), "back": plant.back})
	queue_redraw()
	return true

func _plants(back: bool) -> void:
	for plant: Dictionary in plants:
		if plant.back == back: draw_texture(plant.texture, plant.position, Color(1, 1, 1, cover_opacity))

func _draw() -> void:
	if not generated_water.enabled or ecology.bundle.is_empty(): return
	var started := Time.get_ticks_usec()
	var complete := mode in ["full", "before"]
	ecology.enabled = mode in ["full", "plants"]
	generated_water.draw_slot(self, "water", camera_offset, visual_time)
	if complete:
		generated_water.draw_slot(self, "distance", camera_offset, visual_time)
		generated_water.draw_relief(self, camera_offset, true)
		generated_water.draw_slot(self, "surface", camera_offset, visual_time)
		generated_water.draw_slot(self, "floor", camera_offset, visual_time)
		generated_water.draw_relief(self, camera_offset, false)
		generated_water.draw_slot(self, "terrain", camera_offset, visual_time)
	ecology.draw_layer(self, "plants", camera_offset, visual_time)
	draw_set_transform(-camera_offset)
	_plants(true)
	Scenery.floor_layer(self)
	ecology.draw_layer(self, "bed", camera_offset, visual_time)
	for prop: Dictionary in props:
		draw_texture(prop.texture, prop.position, Color(1, 1, 1, cover_opacity))
		# Exactly the same opacity as the whole connected wood/stone reference.
		ecology.draw_attached(self, prop.targets, camera_offset, visual_time, cover_opacity)
	_plants(false)
	if complete: generated_water.draw_slot(self, "foreground", camera_offset, visual_time)
	if guides:
		for patch: Dictionary in ecology.bundle.plan.patches:
			var p := Vector2(patch.root_px[0], patch.root_px[1])
			draw_circle(p, 2, Color("b6d7b2"))
		for rect in Ecology.Plan.quiet_regions(public_map): draw_rect(rect, Color(0.5, 0.7, 0.7, 0.4), false)
	draw_set_transform(Vector2.ZERO)
	last_draw_us = Time.get_ticks_usec() - started
