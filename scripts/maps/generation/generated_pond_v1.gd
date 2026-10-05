extends RefCounted

# Pure candidate generator. No registration, World construction or resource IO.
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Seeds=preload("res://scripts/maps/generation/seed_derivation.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const Geometry=preload("res://scripts/maps/map_geometry.gd")
const ROOT=[Vector2i(-12,0),Vector2i(-16,-88),Vector2i(-8,-120),Vector2i(8,-128),Vector2i(16,-116),Vector2i(20,0)]
const ROOT_BRANCH=[Vector2i(-4,-40),Vector2i(-80,-80),Vector2i(-84,-92),Vector2i(-72,-96),Vector2i(12,-64)]
const LOG=[Vector2i(-76,0),Vector2i(-64,-20),Vector2i(60,-68),Vector2i(80,-56),Vector2i(68,-32),Vector2i(-44,0)]
const LOG_BRANCH=[Vector2i(24,-36),Vector2i(8,-96),Vector2i(16,-104),Vector2i(28,-92),Vector2i(40,-40)]
const STONES=[
	[Vector2i(-44,0),Vector2i(-40,-20),Vector2i(-20,-44),Vector2i(4,-48),Vector2i(28,-36),Vector2i(44,0)],
	[Vector2i(-36,0),Vector2i(-32,-36),Vector2i(-12,-72),Vector2i(8,-76),Vector2i(32,-44),Vector2i(40,0)],
	[Vector2i(-48,0),Vector2i(-36,-16),Vector2i(-12,-24),Vector2i(28,-20),Vector2i(48,0)],
]

static func attempt_seed(request: Dictionary, attempt: int) -> int:
	return Seeds.derive(request.map_seed,"%s:%d:attempt:%d" % [request.generator_id,request.generator_version,attempt])

static func generate(request: Variant, attempt: int=0) -> Dictionary:
	if not Request.validate(request).valid or attempt<0 or attempt>=Profile.MAX_ATTEMPTS: return {}
	var rng=Seeds.stream(attempt_seed(request,attempt),"layout")
	var result: Dictionary={
		"meta":{"id":"generated_pond_v1_%d" % request.map_seed,"revision":1,"contract_version":1,"content_hash":""},
		"bounds":{"size":Profile.SIZE,"water":Profile.WATER,"floor_y":Profile.FLOOR,"net_area":Profile.NET_AREA,"vegetation_drag_zones":[]},
		"anchors":{"player_spawn":Profile.SPAWN,"home":Profile.HOME},"bait_sites":[],
		"interaction_features":[],"visual_features":[],"presentation":{"visual_profile_id":"generated_pond_prototype","wood_groups":[]},
	}
	# Ordered west-to-east candidate bands leave >=128px horizontal separation.
	# Actual food type, selected sites and hook assignment remain simulation work.
	for slot in Profile.BAIT_COUNT: result.bait_sites.append(Vector2(180+slot*192+rng.between(0,64),rng.between(145,355)))
	var protected:=Profile.protected_regions(result.bait_sites)
	var occupied: Array[Rect2]=[]
	var zones: Array[int]=[0,1,2,3,4]
	for index in range(zones.size()-1,0,-1):
		var other:int=rng.between(0,index)
		var swap:int=zones[index]; zones[index]=zones[other]; zones[other]=swap
	var wood_groups:int=rng.between(Profile.WOOD_GROUP_RANGE.x,Profile.WOOD_GROUP_RANGE.y)
	for slot in wood_groups:
		var zone:Rect2i=Profile.ZONES[zones[slot]]
		var template:int=rng.between(0,1)
		var placed:=false
		for trial in 32:
			var origin:=Vector2i(zone.get_center().x+rng.between(-32,32),Profile.FLOOR)
			var scale_bucket:int=rng.between(3,5)
			var mirror:int=1 if rng.between(0,1)==0 else -1
			var trunk:=_transform(ROOT if template==0 else LOG,origin,scale_bucket,mirror)
			var branch:=_transform(ROOT_BRANCH if template==0 else LOG_BRANCH,origin,scale_bucket,mirror)
			var bounds:=Geometry.polygon_bounds(trunk).merge(Geometry.polygon_bounds(branch))
			if not _fits(bounds,protected,occupied): continue
			var group_id:="wood_%03d" % (slot*2)
			var first:int=result.interaction_features.size()+1
			_add(result,group_id,"wood",trunk,group_id)
			_add(result,"wood_%03d" % (slot*2+1),"wood",branch,group_id)
			result.presentation.wood_groups.append([first,first+1])
			occupied.append(bounds.grow(6)); placed=true; break
		if not placed: return {}
	var stones:int=rng.between(Profile.STONE_RANGE.x,Profile.STONE_RANGE.y)
	for slot in stones:
		var placed:=false
		for trial in 64:
			var zone:Rect2i=Profile.ZONES[rng.between(0,Profile.ZONES.size()-1)]
			var origin:=Vector2i(zone.get_center().x+rng.between(-72,72),Profile.FLOOR)
			var polygon:=_transform(STONES[rng.between(0,STONES.size()-1)],origin,rng.between(2,4),1)
			var bounds:=Geometry.polygon_bounds(polygon)
			if not _fits(bounds,protected,occupied): continue
			var identity:="stone_%03d" % slot
			_add(result,identity,"stone",polygon,identity)
			occupied.append(bounds.grow(4)); placed=true; break
		if not placed: return {}
	# Grass may grow around the foot of wood/stone, but not over protected areas.
	var grass_occupied: Array[Rect2]=[]
	var grasses:int=rng.between(Profile.GRASS_RANGE.x,Profile.GRASS_RANGE.y)
	for slot in grasses:
		var placed:=false
		for trial in 64:
			var zone:Rect2i=Profile.ZONES[(slot+zones[0])%Profile.ZONES.size()]
			var width:int=rng.between(16,30)*2
			var height:int=rng.between(40,116)
			var x:int=zone.get_center().x+rng.between(-68,68)
			var bounds:=Rect2(x-width/2,Profile.FLOOR-height,width,height)
			if not _fits(bounds,protected,grass_occupied): continue
			var polygon:=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
			var identity:="grass_%03d" % slot
			_add(result,identity,"grass",polygon,identity)
			result.bounds.vegetation_drag_zones.append(bounds)
			grass_occupied.append(bounds.grow(4)); placed=true; break
		if not placed: return {}
	result.meta.content_hash=Definition.content_hash(result)
	return result

static func _fits(bounds: Rect2, protected: Array[Rect2], occupied: Array[Rect2]) -> bool:
	if bounds.position.x<Profile.WATER.position.x+12 or bounds.end.x>Profile.WATER.end.x-12 or bounds.position.y<Profile.WATER.position.y or bounds.end.y>Profile.FLOOR: return false
	for region: Rect2 in protected:
		if bounds.intersects(region,true): return false
	for region: Rect2 in occupied:
		if bounds.intersects(region,true): return false
	return true

static func _transform(template: Array, origin: Vector2i, scale_bucket: int, mirror: int) -> PackedVector2Array:
	var points:=PackedVector2Array()
	# Templates use multiples of four: all scale buckets keep integer coordinates.
	for vertex:Vector2i in template: points.append(Vector2(origin+Vector2i(vertex.x*scale_bucket/4*mirror,vertex.y*scale_bucket/4)))
	if mirror<0: points.reverse()
	return points

static func _add(result: Dictionary, identity: String, kind: String, polygon: PackedVector2Array, group: String) -> void:
	var solid:=kind!="grass"
	var index:int=result.interaction_features.size()
	result.interaction_features.append({"id":identity,"kind":kind,"compatibility_index":index,
		"shape":{"type":"polygon","points":polygon},"fade_group_id":group,"presentation_ref":identity,
		"capabilities":{"fish_passable":true,"net_blocking":solid,"rope_anchor":true,"contact_fade":true,
			"grass_binding":not solid,"shore_visible":true,"npc_spawn_blocking":solid,"fish_occluding":solid}})
	var bounds:=Geometry.polygon_bounds(polygon)
	var style:Dictionary={"seed":index+1,"kind":kind,"name":"木枝" if kind=="wood" else "石头"}
	if not solid: style={"x":bounds.get_center().x,"y":bounds.end.y,"width":bounds.size.x-6,"height":bounds.size.y,"kind":"fern" if index%2 else "ribbon","stems":5,"back":false}
	result.visual_features.append({"id":identity,"kind":"solid" if solid else "plant","legacy":style})
