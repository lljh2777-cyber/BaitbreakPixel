extends RefCounted
## Local pixel kernel. Bresenham follows pixel_art.paint_line (upstream 0.24.6),
## copied to avoid that module's transitive Layout dependency. No texture APIs.
static func line(canvas: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var start := Vector2i(a.round())
	var end := Vector2i(b.round())
	var dx := absi(end.x - start.x)
	var dy := -absi(end.y - start.y)
	var sx := 1 if start.x < end.x else -1
	var sy := 1 if start.y < end.y else -1
	var error := dx + dy
	while true:
		pixel(canvas, start.x, start.y, color)
		if start == end: break
		var twice := error * 2
		if twice >= dy: error += dy; start.x += sx
		if twice <= dx: error += dx; start.y += sy

static func pixel(canvas: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < canvas.get_width() and y < canvas.get_height(): canvas.set_pixel(x, y, color)

static func polygon(canvas: Image, points: PackedVector2Array, color: Color) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	for y in range(maxi(0, floori(bounds.position.y)), mini(canvas.get_height(), ceili(bounds.end.y) + 1)):
		for x in range(maxi(0, floori(bounds.position.x)), mini(canvas.get_width(), ceili(bounds.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points): canvas.set_pixel(x, y, color)

static func digest(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()
