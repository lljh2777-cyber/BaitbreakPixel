extends RefCounted
## Grounded cover. Keep V1/V2 recipes reproducible; V3 retains the V2 bed stream.
const Legacy=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Relief=preload("res://scripts/maps/generation/generated_pond_v2.gd")
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Bed=preload("res://scripts/maps/pond_bed.gd")
const Geometry=preload("res://scripts/maps/map_geometry.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")

static func generate(request: Dictionary, attempt: int) -> Dictionary:
	var result:=Legacy.generate(Request.create(request.map_seed,1),attempt)
	if result.is_empty(): return result
	var relief:=Relief.generate(Request.create(request.map_seed,2),attempt)
	var points: PackedVector2Array=relief.bounds.floor_profile
	result.meta.id="generated_pond_v3_%d" % request.map_seed
	result.meta.contract_version=2
	result.bounds["floor_profile"]=points
	result.presentation.visual_profile_id="generated_pond_grounded"
	# Find the original contact edge, not the centre of an asymmetric tree's
	# combined bounds. Both branches and trunk retain one rigid transform.
	var groups: Dictionary={}
	for feature: Dictionary in result.interaction_features:
		var id: String=feature.fade_group_id
		if not groups.has(id): groups[id]={"left":INF,"right":-INF,"top":433.0}
		for p: Vector2 in feature.shape.points:
			groups[id].top=minf(groups[id].top,p.y)
			if p.y!=433: continue
			groups[id].left=minf(groups[id].left,p.x)
			groups[id].right=maxf(groups[id].right,p.x)
	result.bounds.vegetation_drag_zones.clear()
	for i in result.interaction_features.size():
		var feature: Dictionary=result.interaction_features[i]
		var group: Dictionary=groups[feature.fade_group_id]
		var low:=Bed.height(points,group.left)
		var high:=low
		# Include every breakpoint under the foot, including a valley between
		# its ends. Sink the flat foot into the soil, which masks buried pixels.
		for x in range(int(group.left),int(group.right)+1):
			var y:=Bed.height(points,x)
			low=minf(low,y); high=maxf(high,y)
		var base:=ceilf(high)
		var scale_y:=minf(1,(base-270)/maxf(1,433-group.top))
		var shape:=PackedVector2Array()
		if feature.kind=="grass":
			var height:=floorf(minf(433-group.top,low-270))
			var xs: Array[float]=[group.left]
			for p: Vector2 in points:
				if p.x>group.left and p.x<group.right: xs.append(p.x)
			xs.append(group.right)
			for x: float in xs: shape.append(Vector2(x,Bed.height(points,x)-height))
			xs.reverse()
			for x: float in xs: shape.append(Vector2(x,Bed.height(points,x)))
			var style: Dictionary=result.visual_features[i].legacy
			style.y=base; style.height=height
			style["root_y"]=[]
			for stem in int(style.stems):
				var x: float=style.x+(float(stem)/(int(style.stems)-1)-0.5)*style.width
				style.root_y.append(Bed.height(points,x))
			result.bounds.vegetation_drag_zones.append(Geometry.polygon_bounds(shape))
		else:
			for p: Vector2 in feature.shape.points:
				shape.append(Vector2(p.x,roundf(base+(p.y-433)*scale_y)))
		feature.shape.points=shape
	for i in result.bait_sites.size():
		var site: Vector2=result.bait_sites[i]
		site.y=minf(site.y,floorf(Bed.limit(points,site.x,52)))
		for feature: Dictionary in result.interaction_features:
			var box:=Geometry.polygon_bounds(feature.shape.points)
			if site.x+42>=box.position.x and site.x-42<=box.end.x: site.y=minf(site.y,box.position.y-43)
		result.bait_sites[i]=site
	result.meta.content_hash=Definition.content_hash(result)
	return result
