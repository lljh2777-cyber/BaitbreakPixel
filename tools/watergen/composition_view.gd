extends "res://scripts/pond_view.gd"
## Frozen composition board. Its authored floor is NOT playable map geometry.
const StudyAppearance=preload("res://tools/watergen/composition_appearance.gd")
var choice:="A"
var overview:=false
var show_baseline:=false

func _init() -> void:
	generated_water=StudyAppearance.new()

func prepare_map(context: RefCounted) -> void:
	generated_water.variant=choice
	# Production scenery remains available only for the explicit baseline toggle.
	super.prepare_map(context)
	generated_water.show_baseline=show_baseline
	if generated_water.prepare(context,visual_seed) and not generated_water.study.is_empty():
		bed_texture=generated_water.original_bed

func _world(t: float) -> void:
	if show_baseline: super._world(t); return
	generated_water.draw_blockout(self,camera_offset,t)
	# Existing public gameplay overlays supply scale/readability checks, while
	# the paused board does not suggest that these concept slopes are collidable.
	_winding_fish(t,false)
	_baits(t,true)
	_line_back()

func _navigation() -> void:
	if show_baseline: super._navigation()

func _draw() -> void:
	if not overview: super._draw(); return
	if not is_instance_valid(game): return
	world=game
	prepare_map(world.map_context)
	var t: float=world.elapsed
	line_frame=line_motion.sample(world); net_frame=net_motion.sample(world)
	fish_observation=FishObservation.build(world)
	camera_offset=Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	_world(t)
	_baits(t); _angler(t); _line(); _net_back(t); _player(t); _net(t)
	draw_set_transform(Vector2.ZERO)
