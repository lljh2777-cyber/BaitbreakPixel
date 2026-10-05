extends RefCounted
# Only immutable public MapContext geometry and presentation metadata enter here.
# This adapter never receives a World, actor, observation, hook or gameplay RNG.
const Contract=preload("res://scripts/watergen/public_map_context.gd")
const Presentation=preload("res://scripts/maps/map_presentation.gd")
const PORT_SOURCE:="63112b1a161975e466639525dff5deb1fd252b80"
static func point(v:Vector2)->Array: return [v.x,v.y]
static func rectangle(v:Rect2)->Array: return point(v.position)+point(v.size)
static func build(context:RefCounted)->Dictionary:
	var presentation:=Presentation.for_context(context)
	var covers:Array=[]; var sites:Array=[]; var grasses:Array=[]
	var protected:Array=[{"purpose":"home","rect_px":rectangle(Rect2(context.home-Vector2(32,32),Vector2(64,64)))},
		{"purpose":"spawn","rect_px":rectangle(Rect2(context.player_spawn-Vector2(24,24),Vector2(48,48)))}]
	var visuals:Dictionary={}
	for visual:Dictionary in context.visual_features: visuals[visual.id]=visual.legacy
	for target:Dictionary in context.interaction_targets:
		var polygon:Array=[]
		for v:Vector2 in target.polygon: polygon.append(point(v))
		var source:Dictionary={}
		var legacy:Dictionary=visuals[target.presentation_ref]
		if target.kind=="grass":
			var plant:Dictionary=presentation.plant_for_target(target.compatibility_index)
			for key:String in ["x","y","height","width","kind","stems","back"]: source[key]=plant[key]
		else: source={"seed":int(legacy.get("seed",1)),"name":String(legacy.get("name",""))}
		covers.append({"legacy_target_index":target.compatibility_index,"kind":target.kind,"polygon_px":polygon,"bounds_px":rectangle(target.bounds),
			"fade_group":int(target.get("fade_group",target.compatibility_index)),"source":source})
	for site:Vector2 in context.bait_sites:
		sites.append(point(site)); protected.append({"purpose":"candidate_bait","rect_px":rectangle(Rect2(site-Vector2(24,24),Vector2(48,48)))})
	for region:Rect2 in context.vegetation_drag_zones: grasses.append(rectangle(region))
	var result:Dictionary={"format":"baitbreak-public-map-context","schema_version":2,"map_id":context.id,"source_commit":PORT_SOURCE,
		"world_size_px":[int(context.size.x),int(context.size.y)],"viewport_size_px":[640,360],"water_rect_px":rectangle(context.water),
		"floor_y_px":context.floor_y,"visual_surface_y_px":presentation.surface_y,"home_px":point(context.home),"spawn_px":point(context.player_spawn),
		"net_area_px":rectangle(context.net_area),"bait_sites_px":sites,"legacy_grass_rects_px":grasses,"wood_groups":presentation.wood_groups.duplicate(true),
		"static_cover_records":covers,"protected_regions":protected}
	if context.has_relief:
		result.schema_version=3
		result["floor_profile_px"]=[]
		for vertex:Vector2 in context.floor_profile: result.floor_profile_px.append(point(vertex))
	result["map_public_digest"]=Contract.digest(result)
	return result
