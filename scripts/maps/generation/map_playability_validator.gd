extends RefCounted

# Conservative spatial admission. Expanded boxes prove clear routes; runtime
# tests separately exercise actual polygon detours, net sweeps and match outcomes.
const Validator=preload("res://scripts/maps/map_validator.gd")
const Geometry=preload("res://scripts/maps/map_geometry.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
const NET_CLEARANCE := 26 # Default rim.y (24) + runtime clearance (2).

static func validate(value: Variant) -> Dictionary:
	var structural:=Validator.validate(value)
	if not structural.valid: return {"valid":false,"errors":structural.errors,"metrics":{},"structural_valid":false}
	return _validated(value)

static func _validated(definition: Dictionary) -> Dictionary:
	var errors:Array[String]=[]
	var b:Dictionary=definition.bounds
	if b.size!=Profile.SIZE or b.water!=Profile.WATER or b.floor_y!=Profile.FLOOR or b.net_area!=Profile.NET_AREA:
		errors.append("envelope must match balanced_pond_v1")
	if definition.anchors.home!=Profile.HOME or definition.anchors.player_spawn!=Profile.SPAWN: errors.append("home/spawn must remain fixed in prototype")
	if definition.bait_sites.size()!=Profile.BAIT_COUNT: errors.append("exactly six bait candidates required")
	var spacing:=INF
	var home_distance:=INF
	var spawn_distance:=INF
	for index in definition.bait_sites.size():
		var point:Vector2=definition.bait_sites[index]
		if not b.water.grow(-30).has_point(point): errors.append("bait edge margin")
		home_distance=minf(home_distance,point.distance_to(definition.anchors.home))
		spawn_distance=minf(spawn_distance,point.distance_to(definition.anchors.player_spawn))
		for other in range(index): spacing=minf(spacing,point.distance_to(definition.bait_sites[other]))
	if spacing<Profile.BAIT_SPACING: errors.append("bait spacing below minimum")
	if home_distance<Profile.HOME_CLEARANCE+Profile.BAIT_CLEARANCE: errors.append("bait too close to home")
	if spawn_distance<Profile.SPAWN_CLEARANCE+Profile.BAIT_CLEARANCE: errors.append("bait too close to spawn")
	var protected:=Profile.protected_regions(definition.bait_sites)
	var boxes:Array[Rect2]=[]
	var npc_boxes:Array[Rect2]=[]
	var rope_boxes:Array[Rect2]=[]
	var counts:Dictionary={"wood":0,"stone":0,"grass":0}
	var area:=0.0
	for feature:Dictionary in definition.interaction_features:
		counts[feature.kind]+=1
		var polygon:PackedVector2Array=feature.shape.points
		var bounds:=Geometry.polygon_bounds(polygon)
		for index in protected.size():
			if bounds.intersects(protected[index],true): errors.append("protected region %d overlaps %s" % [index,feature.id])
		var twice_area:=0.0
		for index in polygon.size(): twice_area+=polygon[index].cross(polygon[(index+1)%polygon.size()])
		area+=absf(twice_area)*0.5
		if feature.capabilities.net_blocking: boxes.append(bounds.grow(NET_CLEARANCE))
		if feature.capabilities.npc_spawn_blocking: npc_boxes.append(bounds.grow(12))
		if feature.capabilities.rope_anchor: rope_boxes.append(bounds)
	if counts.wood<4 or counts.wood>6 or counts.stone<3 or counts.stone>5 or counts.grass<5 or counts.grass>8 or definition.interaction_features.size()>Profile.MAX_FEATURES:
		errors.append("feature count outside balanced budget")
	var density:float=area/(b.water.size.x*b.water.size.y)
	if density<0.025 or density>0.22: errors.append("cover density outside balanced budget")
	var rope_span:=0.0
	var min_x:=INF
	var max_x:=-INF
	for bounds:Rect2 in rope_boxes:
		min_x=minf(min_x,bounds.get_center().x); max_x=maxf(max_x,bounds.get_center().x)
	if not rope_boxes.is_empty(): rope_span=max_x-min_x
	if rope_boxes.size()<6 or rope_span<700: errors.append("insufficient rope anchor count/spread")
	var bait_anchor_distance:=0.0
	for point:Vector2 in definition.bait_sites:
		var nearest:=INF
		for feature:Dictionary in definition.interaction_features:
			if feature.capabilities.rope_anchor: nearest=minf(nearest,Geometry.nearest_boundary(point,feature.shape.points).distance_to(point))
		bait_anchor_distance=maxf(bait_anchor_distance,nearest)
	if bait_anchor_distance>270: errors.append("bait activity too far from rope anchor")
	var spawn_free:=0
	var spawn_samples:=0
	for y in range(116,401,56):
		for x in range(64,1241,56):
			spawn_samples+=1
			if not _inside_any(Vector2(x,y),npc_boxes): spawn_free+=1
	if spawn_free<80 or float(spawn_free)/spawn_samples<0.55: errors.append("insufficient NPC spawn area")
	var exits:=0
	for x in [160,360,560,760,960,1140]:
		var corridor:=Rect2(x-1,5,2,171)
		var blocked:=false
		for box:Rect2 in boxes:
			if box.intersects(corridor,true): blocked=true; break
		if not blocked: exits+=1
	if exits<6: errors.append("six distributed clear net lift corridors required")
	var routes:=net_routes(boxes)
	if boxes.is_empty() or routes.open<6 or routes.partial<1: errors.append("net routes require both open routes and meaningful blockers")
	return {"valid":errors.is_empty(),"errors":errors,"structural_valid":true,"metrics":{
		"wood_count":counts.wood,"stone_count":counts.stone,"grass_count":counts.grass,"feature_count":definition.interaction_features.size(),
		"bait_spacing":spacing,"bait_home_distance":home_distance,"bait_spawn_distance":spawn_distance,"cover_density":density,
		"rope_anchor_count":rope_boxes.size(),"rope_anchor_span":rope_span,"bait_anchor_max_distance":bait_anchor_distance,
		"npc_spawn_free":spawn_free,"npc_spawn_samples":spawn_samples,"net_routes":routes,"net_lift_corridors":exits}}

# Conservative expanded AABB routes: no false claim of a narrow polygon gap.
# Lift corridors above prove exits; the runtime solver also supports polygon detours.
static func net_routes(boxes: Array[Rect2]) -> Dictionary:
	var metrics:Dictionary={"open":0,"partial":0,"invalid":0,"total":0}
	for y in [175,245,315,375]:
		for x in [160,320,480,640,800,960]:
			var a:=Vector2(x,y)
			var endpoint:=Vector2(x+180,y)
			metrics.total+=1
			if _inside_any(a,boxes): metrics.invalid+=1; continue
			var hit:=false
			for box:Rect2 in boxes:
				if _segment_hits_rect(a,endpoint,box): hit=true; break
			if hit: metrics.partial+=1
			else: metrics.open+=1
	return metrics

static func _inside_any(point: Vector2, boxes: Array[Rect2]) -> bool:
	for box:Rect2 in boxes:
		if point.x>=box.position.x and point.y>=box.position.y and point.x<=box.end.x and point.y<=box.end.y: return true
	return false

static func _segment_hits_rect(a: Vector2, endpoint: Vector2, box: Rect2) -> bool:
	# Candidate routes are horizontal; all arithmetic and endpoints are integral.
	return a.y>=box.position.y and a.y<=box.end.y and endpoint.x>=box.position.x and a.x<=box.end.x
