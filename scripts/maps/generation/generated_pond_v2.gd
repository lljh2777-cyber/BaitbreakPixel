extends RefCounted
## Version 2 adds solid, gently sloping ground. V1 generation stays frozen.
const Legacy=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Seeds=preload("res://scripts/maps/generation/seed_derivation.gd")
const Bed=preload("res://scripts/maps/pond_bed.gd")
const Geometry=preload("res://scripts/maps/map_geometry.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")

static func generate(request: Dictionary, attempt: int) -> Dictionary:
	var result := Legacy.generate(Request.create(request.map_seed,1),attempt)
	if result.is_empty(): return result
	var rng=Seeds.stream(Legacy.attempt_seed(request,attempt),"solid-bed")
	var hills: Array[Vector3]=[]
	for band in 3:
		hills.append(Vector3(320+band*320+rng.between(-32,32),rng.between(190,220),rng.between(60,88)))
	var points := PackedVector2Array()
	for x in range(0,1281,32):
		var rise := 0.0
		for hill: Vector3 in hills:
			var u := clampf(1-absf(x-hill.x)/hill.y,0,1)
			rise=maxf(rise,hill.z*u*u*(3-2*u))
		# Keep the nest and its approach exactly flat; ramp out over 64 px.
		rise*=clampf((x-160)/64.0,0,1)
		points.append(Vector2(x,433-roundf(rise)))
	# Bound grade to 20/32 even at the flattened nest transition.
	for i in range(1,points.size()): points[i].y=maxf(points[i].y,points[i-1].y-20)
	for i in range(points.size()-2,-1,-1): points[i].y=maxf(points[i].y,points[i+1].y-20)
	result.meta.id="generated_pond_v2_%d" % request.map_seed
	result.meta.contract_version=2
	result.bounds["floor_profile"]=points
	result.presentation.visual_profile_id="generated_pond_relief"
	for i in result.bait_sites.size():
		var site: Vector2=result.bait_sites[i]
		site.y=minf(site.y,floorf(Bed.limit(points,site.x,52)))
		result.bait_sites[i]=site
	# Joined wood shares one vertical transform. Roots embed slightly in the
	# actual bed; tops retain the open central swimming/hoisting corridor.
	var groups: Dictionary={}
	for feature: Dictionary in result.interaction_features:
		var box := Geometry.polygon_bounds(feature.shape.points)
		var id: String=feature.fade_group_id
		groups[id]=groups[id].merge(box) if groups.has(id) else box
	result.bounds.vegetation_drag_zones.clear()
	for i in result.interaction_features.size():
		var feature: Dictionary=result.interaction_features[i]
		var box: Rect2=groups[feature.fade_group_id]
		var base := Bed.height(points,box.get_center().x)
		var scale_y := minf(1,(base-270)/maxf(1,433-box.position.y))
		var shape := PackedVector2Array()
		for p: Vector2 in feature.shape.points:
			shape.append(Vector2(p.x,roundf(base+(p.y-433)*scale_y)))
		feature.shape.points=shape
		if feature.kind=="grass":
			var bounds := Geometry.polygon_bounds(shape)
			result.bounds.vegetation_drag_zones.append(bounds)
			var style: Dictionary=result.visual_features[i].legacy
			style.y=bounds.end.y; style.height=bounds.size.y
	# Lift feeding sites only where relocated cover would occupy their clearance.
	# Preserve the six separated X bands and use the normal 42 px safety margin.
	for i in result.bait_sites.size():
		var site: Vector2=result.bait_sites[i]
		for feature: Dictionary in result.interaction_features:
			var box := Geometry.polygon_bounds(feature.shape.points)
			if site.x+42>=box.position.x and site.x-42<=box.end.x: site.y=minf(site.y,box.position.y-43)
		result.bait_sites[i]=site
	result.meta.content_hash=Definition.content_hash(result)
	return result
