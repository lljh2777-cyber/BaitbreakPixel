extends "res://scripts/pond_view.gd"
## Development-only WG62 view. Main still constructs the unmodified PondView.
## Reuse real actor/food/HUD renderers for review, with local flora insertions.
const Ecology = preload("res://scripts/watergen/water_ecology_renderer.gd")
var flora := Ecology.new()
var flora_context: RefCounted
var flora_seed := -1
var flora_visible := true

func prepare_map(context: RefCounted) -> void:
	super.prepare_map(context)
	if flora_context == context and flora_seed == visual_seed: return
	flora_context = context; flora_seed = visual_seed
	flora.enabled = context.map_source.kind == "generated"
	if flora.enabled:
		if not flora.prepare(GeneratedWater.Adapter.build(context), visual_seed):
			flora.enabled = false; push_error("WG62 gameplay review flora preparation failed")

func _world(t: float) -> void:
	var active := flora.enabled and flora_visible
	Scenery.background(self, world, t)
	if active: flora.draw_layer(self, "plants", camera_offset, t)
	_npc_fishes(t)
	_winding_fish(t, false)
	_baits(t, true)
	if not line_frame.grass.is_empty(): _line_back()
	_plants(t, true)
	Scenery.floor_layer(self)
	if active: flora.draw_layer(self, "bed", camera_offset, t)
	if line_frame.grass.is_empty(): _line_back()
	for prop: Dictionary in props:
		var opacity := 1.0
		for index: int in prop.targets: opacity = minf(opacity, world.target_opacity[index])
		draw_texture(prop.texture, prop.position, Color(1, 1, 1, opacity))
		if active: flora.draw_attached(self, prop.targets, camera_offset, t, opacity)
	_plants(t, false)
	Scenery.foreground(self)
	Scenery.nest(self, world, t)
