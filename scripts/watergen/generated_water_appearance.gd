extends RefCounted
# Presentation settings and GPU cache belong to the view, never to a snapshot.
const Adapter=preload("res://scripts/watergen/watergen_public_adapter.gd")
const Cache=preload("res://scripts/watergen/water_dynamic_cache.gd")
const Terrain=preload("res://scripts/watergen/water_visual_terrain.gd")
const TerrainBaker=preload("res://scripts/watergen/water_terrain_baker.gd")
const Frame=preload("res://scripts/watergen/water_visual_frame.gd")
const Seed=preload("res://scripts/watergen/water_visual_seed.gd")
var cache:=Cache.new()
var bundle:Dictionary={}
var enabled:=false
var last_error:=""
var prepared_context:WeakRef
var prepared_seed:=-1
var profile:Dictionary={}
var terrain_profile:Dictionary={}

func prepare(context:RefCounted,visual_seed:int)->bool:
	if prepared_context!=null and prepared_context.get_ref()==context and prepared_seed==visual_seed: return enabled
	prepared_context=weakref(context); prepared_seed=visual_seed; enabled=false; bundle={}
	if context.map_source.kind!="generated": return true
	if not Seed.valid(visual_seed): last_error="VISUAL_SEED"; return false
	if profile.is_empty():
		profile=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
		terrain_profile=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/terrain_profiles.json")).fern
	var map:=Adapter.build(context)
	var result:=cache.prepare(map,profile,visual_seed)
	if not result.ok: last_error=result.code; return false
	var next:Dictionary=result.bundle
	if not next.has("terrain_far"):
		var relief:=Terrain.generate(map,terrain_profile,visual_seed)
		if not relief.ok: last_error=relief.code; return false
		var baked:=TerrainBaker.bake(relief.plan,profile.palette,next.parallax_compensation.distance)
		if not baked.ok: last_error=baked.code; return false
		next["terrain_far"]=ImageTexture.create_from_image(baked.far)
		next["terrain_bed"]=ImageTexture.create_from_image(baked.bed)
	bundle=next; enabled=true; last_error=""
	return true

func draw_slot(view:Node2D,name:String,camera:Vector2,time:float,clip:=Rect2())->void:
	var data:Dictionary=bundle.layers[name]
	var origin:=Vector2(data.origin_px[0],data.origin_px[1])
	var offset:=Frame.layer_offset(camera,bundle.parallax_compensation[name])
	view.draw_set_transform(offset)
	if clip.has_area(): view.draw_texture_rect_region(data.texture,clip,Rect2(clip.position-origin,clip.size))
	else: view.draw_texture(data.texture,origin)
	for animation:Dictionary in bundle.animations:
		if animation.layer!=name: continue
		var region:Array=animation.region_px
		var at:=Vector2(animation.origin_px[0],animation.origin_px[1])
		if not Rect2(at+offset,Vector2(region[2],region[3])).grow(animation.amplitude+1).intersects(view.get_viewport_rect()): continue
		for band:Dictionary in Frame.bands(animation,region[3],time):
			view.draw_texture_rect_region(animation.texture,Rect2(at+Vector2(band.shift,band.row),Vector2(region[2],band.height)),Rect2(region[0],region[1]+band.row,region[2],band.height))
	view.draw_set_transform(-camera)

func draw_relief(view:Node2D,camera:Vector2,far:bool)->void:
	if far:
		var k:Array=bundle.parallax_compensation.distance
		view.draw_set_transform(Frame.layer_offset(camera,k))
		view.draw_texture(bundle.terrain_far,-Vector2(Frame.padding(k)),Color(1,1,1,0.64))
	else:
		view.draw_set_transform(-camera)
		view.draw_texture(bundle.terrain_bed,Vector2.ZERO,Color(1,1,1,0.42))
	view.draw_set_transform(-camera)
