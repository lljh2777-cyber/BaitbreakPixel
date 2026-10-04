extends SceneTree

const Context=preload("res://scripts/maps/map_context.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const PondV2=preload("res://scripts/maps/pond_v2_map.gd")
const Legacy=preload("res://scripts/pond_layout.gd")
const Presentation=preload("res://scripts/maps/map_presentation.gd")
const Camera=preload("res://scripts/pond_camera.gd")
const Water=preload("res://scripts/pond_water_art.gd")
const Art=preload("res://scripts/pixel_art.gd")
const View=preload("res://scripts/pond_view.gd")
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("MAP_PRESENTATION_FAIL | "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var context: RefCounted=Context.load_map().context
	var presentation: RefCounted=Presentation.for_context(context)
	check(presentation==Presentation.for_context(context),"same context reuses its prepared adapter")
	check(presentation.size==Legacy.SIZE and presentation.floor_y==Legacy.FLOOR and presentation.home==Legacy.HOME,"public map dimensions and anchors exact")
	check(presentation.solids.size()==Legacy.SOLIDS.size() and presentation.plants.size()==Legacy.PLANTS.size(),"complete legacy render count and ordering")
	check(presentation.wood_groups==Legacy.WOOD_GROUPS,"connected wood metadata exact")
	check(presentation.solids.is_read_only() and presentation.plants.is_read_only() and presentation.wood_groups.is_read_only(),"cached collection views are read-only")
	for index in presentation.solids.size():
		var solid: Dictionary=presentation.solids[index]
		for key in Legacy.SOLIDS[index]: check(solid[key]==Legacy.SOLIDS[index][key],"solid %d field %s unchanged"%[index,key])
		check(solid.is_read_only() and solid.points.is_read_only(),"solid record and point Array cannot mutate shared cache")
		check(solid.target_index==index,"solid explicit opacity index")
	for index in presentation.plants.size():
		var plant: Dictionary=presentation.plants[index]
		for key in Legacy.PLANTS[index]: check(plant[key]==Legacy.PLANTS[index][key],"plant %d field %s unchanged"%[index,key])
		check(presentation.plant_target_index(index)==Legacy.SOLIDS.size()+index,"legacy plant opacity index exact")
		check(presentation.plant_index_for_target(plant.target_index)==index and presentation.plant_for_target(plant.target_index)==plant,"plant target resolves by explicit identity")
	check(presentation.plant_index_for_target(-1)==-1 and presentation.plant_for_target(-1).is_empty(),"unknown plant target fails closed")
	var shuffled:=PondV2.create()
	shuffled.visual_features.reverse()
	var shuffled_context: RefCounted=Context.from_definition(shuffled).context
	check(Presentation.for_context(shuffled_context).matches(presentation),"visual array order cannot replace presentation identities")
	var visual_edit:=PondV2.create()
	visual_edit.visual_features[1].legacy.seed=902
	var edited_context: RefCounted=Context.from_definition(visual_edit).context
	var edited: RefCounted=Presentation.for_context(edited_context)
	check(edited_context.content_hash==context.content_hash and edited!=presentation and not edited.matches(presentation),"same gameplay hash cannot alias distinct visual metadata")
	check(edited.solids[1].seed==902 and presentation.solids[1].seed==2,"visual metadata belongs to its own context")
	var world:=World.new()
	var view:=View.new()
	view.prepare_map(context)
	var water_cache: Dictionary=view.water_layers.duplicate()
	var prop_cache: Array=view.props.duplicate()
	var plant_cache: Array=view.plant_frames.duplicate()
	view.prepare_map(shuffled_context)
	check(view.water_layers==water_cache and view.props==prop_cache and view.plant_frames==plant_cache,"equivalent reset contexts retain existing texture objects")
	var tall:=PondV2.create()
	tall.meta.id="fixture_presentation_tall"
	tall.bounds.size.y=720
	tall.bounds.floor_y=673
	tall.bounds.water.size.y=603
	tall.meta.content_hash=Definition.content_hash(tall)
	check(world.reset_world({"seed":491},tall),"taller map fixture validates")
	world.angler.free_line_length=900
	check(Camera.offset(world,"angler").y==360,"tall-map angler camera travels beyond legacy 120px")
	var small:=small_definition()
	check(world.reset_world({"seed":491},small),"smaller-than-viewport fixture validates and initializes")
	var small_map: RefCounted=Presentation.for_context(world.map_context)
	view.prepare_map(world.map_context)
	check(view.map_presentation==small_map and view.water_layers!=water_cache,"switching context refreshes all view caches")
	check(view.props.size()>0 and view.plant_frames.size()==small_map.plants.size(),"fixture cover and plant frames are built from its context")
	for key in view.water_layers: check(view.water_layers[key].get_size()==small_map.size,"fixture layer extent: "+key)
	for point: Vector2 in [Vector2.ZERO,Vector2(100,100),Vector2(320,240),Vector2(1000,1000)]:
		world.fish=point
		check(Camera.offset(world,"fish")==Vector2.ZERO,"undersized map cannot produce negative camera clamp")
		check(Camera.to_world(Camera.to_screen(point,world,"fish"),world,"fish")==point,"fixture fish camera roundtrip")
	check(Camera.offset(world,"angler")==Vector2.ZERO,"undersized angler camera cannot produce negative clamp")
	var rng_before: int=world.rng.state
	seed(8157); var expected:=randf(); seed(8157)
	for index in 120:
		check(Presentation.for_context(world.map_context)==small_map,"hot-path adapter identity stays cached")
		Water.mote(index,small_map)
		Camera.offset(world,"fish")
	check(world.rng.state==rng_before and randf()==expected,"presentation preparation and sampling consume no gameplay/global RNG")
	world.free(); view.free()
	print("PHASE04_MAP_PRESENTATION | passed=%d | failed=%d"%[passed,failed])
	quit(1 if failed else 0)

# A private size stress fixture, never registered or offered in player UI.
func small_definition() -> Dictionary:
	var result:=PondV2.create()
	var scale:=Vector2(0.25,0.5)
	result.meta.id="fixture_presentation_tiny"
	result.bounds.size*=scale
	result.bounds.floor_y*=scale.y
	for key in ["water","net_area"]:
		var rect: Rect2=result.bounds[key]
		result.bounds[key]=Rect2(rect.position*scale,rect.size*scale)
	for index in result.bounds.vegetation_drag_zones.size():
		var rect: Rect2=result.bounds.vegetation_drag_zones[index]
		result.bounds.vegetation_drag_zones[index]=Rect2(rect.position*scale,rect.size*scale)
	result.anchors.player_spawn*=scale
	result.anchors.home*=scale
	for index in result.bait_sites.size(): result.bait_sites[index]*=scale
	for feature: Dictionary in result.interaction_features:
		for index in feature.shape.points.size(): feature.shape.points[index]*=scale
	for visual: Dictionary in result.visual_features:
		if visual.kind=="solid":
			for index in visual.legacy.points.size(): visual.legacy.points[index]*=scale
		else:
			visual.legacy.x*=scale.x; visual.legacy.y*=scale.y
			visual.legacy.width*=scale.x; visual.legacy.height*=scale.y
	result.presentation.visual_profile_id="fixture_plain"
	result.meta.content_hash=Definition.content_hash(result)
	return result
