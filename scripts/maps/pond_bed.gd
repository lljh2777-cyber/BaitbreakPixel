extends RefCounted
## Shared Authority/presentation heightfield. Screen Y increases downward.
## The bed is solid below an ordered polyline; there are no caves or overhangs.

static func segment(points: PackedVector2Array, x: float) -> int:
	var lo := 0
	var hi := points.size()-2
	while lo < hi:
		var mid := (lo+hi+1)/2
		if points[mid].x <= x: lo=mid
		else: hi=mid-1
	return lo

static func height(points: PackedVector2Array, x: float, flat: float=433.0) -> float:
	if points.is_empty(): return flat
	var i := segment(points,x)
	var a := points[i]
	var b := points[i+1]
	return lerpf(a.y,b.y,clampf((x-a.x)/(b.x-a.x),0,1))

static func limit(points: PackedVector2Array, x: float, radius: float) -> float:
	# Exact top envelope of a circle against each nearby line segment, including
	# shared vertices. Merely subtracting radius at the centre cuts into slopes.
	var ceiling := INF
	var first := segment(points,x-radius)
	var last := segment(points,x+radius)
	for i in range(first,last+1):
		var a := points[i]
		var b := points[i+1]
		var slope := (b.y-a.y)/(b.x-a.x)
		var left := maxf(a.x,x-radius)
		var right := minf(b.x,x+radius)
		if left>right: continue
		var sample_x := clampf(x-slope*radius/sqrt(1+slope*slope),left,right)
		var y := a.y+(sample_x-a.x)*slope-sqrt(maxf(0,radius*radius-pow(sample_x-x,2)))
		ceiling=minf(ceiling,y)
	return ceiling

static func polygon(points: PackedVector2Array, size: Vector2) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(Vector2(size.x,size.y))
	result.append(Vector2(0,size.y))
	return result
