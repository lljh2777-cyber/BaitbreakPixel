extends RefCounted

# Map-independent geometry. Construction helpers run only when a round context is
# built; contact and coil helpers retain the legacy operation/tie-break order.
static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty(): return Rect2()
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	return bounds

static func nearest_boundary(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty(): return point
	var nearest := polygon[0]
	var distance := INF
	for index in polygon.size():
		var candidate := Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])
		var separation := candidate.distance_squared_to(point)
		if separation < distance:
			nearest = candidate
			distance = separation
	return nearest

static func touches(point: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if polygon.is_empty(): return false
	return Geometry2D.is_point_in_polygon(point,polygon) or nearest_boundary(point,polygon).distance_squared_to(point) < radius*radius

# Input must already pass MapValidator. Visual lookup is by presentation identity,
# never by visual-array order; visual metadata cannot replace Authority geometry.
static func interaction_targets(definition: Dictionary) -> Array[Dictionary]:
	var indexes: Dictionary = {}
	var visuals: Dictionary = {}
	for feature: Dictionary in definition.interaction_features:
		indexes[feature.id] = feature.compatibility_index
	for visual: Dictionary in definition.visual_features:
		visuals[visual.id] = visual.legacy
	var result: Array[Dictionary] = []
	for feature: Dictionary in definition.interaction_features:
		var polygon: PackedVector2Array = feature.shape.points.duplicate()
		var legacy: Dictionary = visuals[feature.presentation_ref]
		var target := {
			"name":"水草" if feature.kind == "grass" else legacy.get("name","石头" if feature.kind == "stone" else "木枝"),
			"kind":feature.kind,"polygon":polygon,"bounds":polygon_bounds(polygon),
		}
		# Preserve old fields/insertion order; self-grouped grass had no fade_group.
		# A different authored representative is still meaningful for any kind.
		if feature.kind != "grass" or feature.fade_group_id != feature.id:
			target["fade_group"] = indexes[feature.fade_group_id]
		target.id = feature.id
		target.compatibility_index = feature.compatibility_index
		target.capabilities = feature.capabilities.duplicate(true)
		target.fade_group_id = feature.fade_group_id
		target.presentation_ref = feature.presentation_ref
		result.append(target)
	return result

# The Array points adapter keeps Rope's existing value contract. Cache it once;
# callers doing polygon collision should use polygon, not reconstruct it per tick.
static func capability_targets(targets: Array[Dictionary], capability: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target: Dictionary in targets:
		if not target.capabilities.get(capability,false): continue
		var entry: Dictionary = target.duplicate(true)
		entry.points = Array(entry.polygon)
		result.append(entry)
	return result

static func coil_at(target: Dictionary, contact: Vector2) -> Dictionary:
	var bounds: Rect2 = target.bounds
	var y := clampf(contact.y,bounds.position.y+4,bounds.end.y-4)
	var polygon: PackedVector2Array = target.polygon
	var crossings: Array[float] = []
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index+1)%polygon.size()]
		if absf(b.y-a.y)<0.001: continue
		if y>=minf(a.y,b.y) and y<maxf(a.y,b.y): crossings.append(a.x+(y-a.y)*(b.x-a.x)/(b.y-a.y))
	crossings.sort()
	var left := bounds.position.x if crossings.is_empty() else crossings[0]
	var right := bounds.end.x if crossings.is_empty() else crossings[-1]
	var center := Vector2((left+right)*0.5,y)
	var radii := Vector2(maxf(7,(right-left)*0.5+4),6 if target.kind=="wood" else 7)
	var loop := PackedVector2Array()
	for index in range(65): loop.append(center+Vector2(cos(-PI/2+TAU*index/64.0),sin(-PI/2+TAU*index/64.0))*radii)
	return {"center":center,"radii":radii,"loop":loop,"entry":loop[0],"progress":0.0}
