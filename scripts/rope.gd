extends RefCounted

# Clip against the actual clockwise convex silhouette, not an enclosing rectangle.
static var _cache_key := 0
static var _cache_anchor := Vector2(INF,INF)
static var _cache_limits := Vector3(INF,INF,INF)
static var _fixed_nodes: Array[Vector2] = []
static var _fixed_links: Array = []

static func blocked(a: Vector2, b: Vector2, obstacle: Dictionary) -> bool:
	var polygon: Array = obstacle.points
	var delta := b - a
	var low := 0.0
	var high := 1.0
	for index in polygon.size():
		var start: Vector2 = polygon[index]
		var edge: Vector2 = polygon[(index+1)%polygon.size()] - start
		var side := edge.cross(a-start) - edge.length()*0.035
		var direction := edge.cross(delta)
		if absf(direction) < 0.00001:
			if side <= 0: return false
		else:
			var crossing := -side/direction
			if direction > 0: low = maxf(low,crossing)
			else: high = minf(high,crossing)
			if high <= low: return false
	return high > low

static func clear(a: Vector2, b: Vector2, obstacles: Array) -> bool:
	for solid in obstacles:
		if blocked(a, b, solid): return false
	return true

# Compatibility policy, not arbitrary-map reachability: the old net detour
# solver only admitted vertices in its western/shallow window (9..631, y<=309).
# Preserve that exact pond window as water-relative tuning. Do not silently
# expand it while abstracting maps; a future routing redesign needs its own gate.
# No lower Y filter is intentional: net exits can rise above the water surface.
static func routing_limits(context: RefCounted) -> Vector3:
	var water: Rect2=context.water
	if context.routing_profile=="generated_pond_v1":
		return Vector3(water.position.x+1.0,water.end.x-1.0,water.end.y-1.0)
	return Vector3(water.position.x+1.0,
		water.position.x+float(water.size.x)*623.0/1264.0,
		water.position.y+float(water.size.y)*241.0/363.0)

static func _prepare(anchor: Vector2, obstacles: Array, limits: Vector3) -> void:
	var key := hash(obstacles)
	if key == _cache_key and anchor == _cache_anchor and limits == _cache_limits: return
	_cache_key = key
	_cache_anchor = anchor
	_cache_limits = limits
	_fixed_nodes.assign([anchor])
	_fixed_links.clear()
	for solid in obstacles:
		var polygon := PackedVector2Array(solid.points)
		for index in polygon.size():
			var vertex := polygon[index]
			var incoming := (vertex - polygon[posmod(index-1,polygon.size())]).normalized()
			var outgoing := (polygon[(index+1)%polygon.size()] - vertex).normalized()
			var first := Vector2(incoming.y,-incoming.x)
			var second := Vector2(outgoing.y,-outgoing.x)
			var bisector := (first+second).normalized()
			var point := vertex + bisector*(1.5/maxf(0.16,bisector.dot(first)))
			if point.y > limits.z or point.x < limits.x or point.x > limits.y: continue
			var buried := false
			for other in obstacles:
				if Geometry2D.is_point_in_polygon(point,PackedVector2Array(other.points)): buried = true; break
			if not buried: _fixed_nodes.append(point)
	for index in _fixed_nodes.size(): _fixed_links.append([])
	for first in _fixed_nodes.size():
		for second in range(first+1,_fixed_nodes.size()):
			if clear(_fixed_nodes[first],_fixed_nodes[second],obstacles):
				var length := _fixed_nodes[first].distance_to(_fixed_nodes[second])
				_fixed_links[first].append(Vector2(second,length))
				_fixed_links[second].append(Vector2(first,length))

static func solve(anchor: Vector2, end: Vector2, obstacles: Array, limits: Vector3) -> PackedVector2Array:
	if clear(anchor, end, obstacles): return PackedVector2Array([anchor, end])
	_prepare(anchor,obstacles,limits)
	var nodes: Array[Vector2] = _fixed_nodes.duplicate()
	var links: Array = _fixed_links.duplicate(true)
	var end_index := nodes.size()
	nodes.append(end)
	links.append([])
	for index in end_index:
		if clear(nodes[index],end,obstacles):
			var length := nodes[index].distance_to(end)
			links[index].append(Vector2(end_index,length))
			links[end_index].append(Vector2(index,length))
	var distance: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for index in nodes.size():
		distance.append(INF)
		previous.append(-1)
		visited.append(false)
	distance[0] = 0
	for iteration in nodes.size():
		var best := -1
		for index in nodes.size():
			if not visited[index] and (best < 0 or distance[index] < distance[best]): best = index
		if best < 0 or distance[best] == INF: break
		if best == end_index: break
		visited[best] = true
		for link in links[best]:
			var next := int(link.x)
			if visited[next]: continue
			var candidate: float = distance[best] + link.y
			if candidate < distance[next]:
				distance[next] = candidate
				previous[next] = best
	if previous[end_index] == -1: return PackedVector2Array()
	var points: Array[Vector2] = []
	var index := end_index
	while index >= 0:
		points.push_front(nodes[index])
		index = previous[index]
	return PackedVector2Array(points)

static func length_of(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()): total += points[index - 1].distance_to(points[index])
	return total
