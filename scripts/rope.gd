extends RefCounted

# The pillars meet the pond floor. A route may go around their upper corners,
# but never shortcut underneath the floor or through a visible solid.
static func blocked(a: Vector2, b: Vector2, obstacle: Rect2) -> bool:
	var rect := obstacle.grow(-0.05)
	var delta := b - a
	var low := 0.0
	var high := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if a[axis] <= rect.position[axis] or a[axis] >= rect.end[axis]: return false
		else:
			var first := (rect.position[axis] - a[axis]) / delta[axis]
			var last := (rect.end[axis] - a[axis]) / delta[axis]
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if high <= low: return false
	return high > low

static func clear(a: Vector2, b: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect in obstacles:
		if blocked(a, b, rect): return false
	return true

static func solve(anchor: Vector2, end: Vector2, obstacles: Array[Rect2]) -> PackedVector2Array:
	if clear(anchor, end, obstacles): return PackedVector2Array([anchor, end])
	var nodes: Array[Vector2] = [anchor, end]
	for solid in obstacles:
		var rect := solid.grow(2.0)
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			if point.y <= 307.0 and point.x >= 10 and point.x <= 630: nodes.append(point)
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
		if best == 1: break
		visited[best] = true
		for next in nodes.size():
			if visited[next] or next == best or not clear(nodes[best], nodes[next], obstacles): continue
			var candidate := distance[best] + nodes[best].distance_to(nodes[next])
			if candidate < distance[next]:
				distance[next] = candidate
				previous[next] = best
	if previous[1] == -1: return PackedVector2Array()
	var points: Array[Vector2] = []
	var index := 1
	while index >= 0:
		points.push_front(nodes[index])
		index = previous[index]
	return PackedVector2Array(points)

static func length_of(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()): total += points[index - 1].distance_to(points[index])
	return total
