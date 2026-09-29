extends RefCounted

static func paint_line(canvas: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var start := Vector2i(a.round())
	var end := Vector2i(b.round())
	var dx := absi(end.x-start.x)
	var dy := -absi(end.y-start.y)
	var sx := 1 if start.x<end.x else -1
	var sy := 1 if start.y<end.y else -1
	var error := dx+dy
	while true:
		if start.x>=0 and start.x<canvas.get_width() and start.y>=0 and start.y<canvas.get_height(): canvas.set_pixelv(start,color)
		if start==end: break
		var twice := error*2
		if twice>=dy: error+=dy; start.x+=sx
		if twice<=dx: error+=dx; start.y+=sy

static func paint_polygon(canvas: Image, points: PackedVector2Array, color: Color) -> void:
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	for y in range(maxi(0,int(bounds.position.y)),mini(canvas.get_height(),ceili(bounds.end.y)+1)):
		for x in range(maxi(0,int(bounds.position.x)),mini(canvas.get_width(),ceili(bounds.end.x)+1)):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),points): canvas.set_pixel(x,y,color)

static func sprite(rows: Array[String], palette: Dictionary) -> Texture2D:
	var width := 0
	for row in rows: width = maxi(width, row.length())
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var token := rows[y][x]
			if palette.has(token): image.set_pixel(x, y, Color(palette[token]))
	return ImageTexture.create_from_image(image)

static func fish() -> Texture2D:
	return sprite([
		".............dd.........",
		"............dffd........",
		"..dd.....ddddfffdddd....",
		"..dfd..ddfffffffffffdd..",
		"...dfddffffffffhhfffffd.",
		"...dfffffffffhhhhhwwfffd",
		"....dffffffffhhhhhwbwffd",
		"...dffffffffffffhhwwwffd",
		"...dfddffffllffffffffdd",
		"..dfd..ddlllpllllllddd..",
		"..dd.....ddllpllldd.....",
		"...........dddddd......."],
		{"d":"985436", "f":"e6a448", "h":"ffd879", "l":"f3c780", "p":"fff0b5", "w":"fff6d3", "b":"132a38"})

static func reed() -> Texture2D:
	return sprite([
		"....tt..........", "....tt.......t..", "....tt......tt..", "....ss......tt..",
		".....s......ss..", "..l..s.....s....", "..ll.s.....s....", "...lls..l..s....",
		"....ss..ll.s....", ".....s...lls....", ".....s....ss....", ".....s....s.....",
		".....s....s.....", ".....s....s.....", ".....s....s.....", "....sss..sss...."],
		{"t":"c59d63", "s":"437d6d", "l":"67ac85"})

static func prop(obstacle: Dictionary) -> Dictionary:
	var polygon := PackedVector2Array(obstacle.points)
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	bounds = bounds.grow(1)
	var canvas := Image.create(int(bounds.size.x)+1,int(bounds.size.y)+1,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var seed: int = obstacle.seed
	var wood: bool = obstacle.kind == "wood"
	var colors := [Color("485f62"),Color("637b79"),Color("80928a"),Color("acb29a")]
	if wood: colors = [Color("44514a"),Color("786949"),Color("a48a59"),Color("cbb37c")]
	for y in canvas.get_height():
		for x in canvas.get_width():
			var point := bounds.position + Vector2(x+0.5,y+0.5)
			if not Geometry2D.is_point_in_polygon(point,polygon): continue
			var u := x/bounds.size.x
			var v := y/bounds.size.y
			var noise := posmod(x*31+y*17+seed*43,97)
			var tone := 1
			if wood:
				var grain := posmod(x+int(y*(0.13 if seed%2 else -0.14))+seed,9)
				if seed == 7: grain = posmod(y+int(x*0.43),8)
				tone = 2 if grain < 2 or u < 0.20 else 1
				if grain == 5 and noise < 75: tone = 0
				if v < 0.035: tone = 3 if noise>28 else 2
				var knot := Vector2((u-0.53)*bounds.size.x/3.0,(v-0.42)*bounds.size.y/5.0).length()
				if knot > 0.7 and knot < 1.05: tone = 0
			else:
				tone = 2 if v < 0.45-u*0.22 else 1
				if v > 0.9-u*0.3 or u > 0.88: tone = 0
				if v < 0.19 and u < 0.6: tone = 3
				if absf(u-0.35-v*0.24) < 0.027 and v>0.27: tone = 0
				if noise < 5: tone = maxi(0,tone-1)
			var color: Color = colors[tone]
			var top_edge := not Geometry2D.is_point_in_polygon(point-Vector2(0,2),polygon)
			if top_edge and noise%5 != 0 and (not wood or v>0.05): color = Color("8da879") if noise%3 else Color("577d64")
			if not Geometry2D.is_point_in_polygon(point+Vector2(1,1),polygon): color = colors[0]
			canvas.set_pixel(x,y,color)
	return {"texture":ImageTexture.create_from_image(canvas),"position":bounds.position}
