extends RefCounted

const Wood=preload("res://scripts/pond_wood_art.gd")

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

# Materials are painted inside the authoritative silhouette. The net, fading and
# line-coil targets still use PondLayout; decorative pixels never enlarge cover.
static func prop(obstacle: Dictionary) -> Dictionary:
	var bounds := prop_bounds(obstacle)
	return {"texture":ImageTexture.create_from_image(prop_image(obstacle)),"position":bounds.position}

static func prop_bounds(obstacle: Dictionary) -> Rect2:
	var polygon := PackedVector2Array(obstacle.points)
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds=bounds.expand(point)
	return bounds.grow(1)

static func prop_image(obstacle: Dictionary) -> Image:
	var polygon := PackedVector2Array(obstacle.points)
	var bounds := prop_bounds(obstacle)
	var canvas := Image.create(int(bounds.size.x)+1,int(bounds.size.y)+1,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var wood: bool=obstacle.kind=="wood"
	var grain := Wood.context(obstacle) if wood else {}
	for y in canvas.get_height():
		for x in canvas.get_width():
			var point := bounds.position+Vector2(x+0.5,y+0.5)
			if not Geometry2D.is_point_in_polygon(point,polygon): continue
			if wood:
				canvas.set_pixel(x,y,Wood.color_at(point,grain))
				continue
			var color := _stone_color(Vector2(x,y),bounds.size,int(obstacle.seed))
			var top_edge := not Geometry2D.is_point_in_polygon(point-Vector2(0,2),polygon)
			var lower_edge := not Geometry2D.is_point_in_polygon(point+Vector2(1,1),polygon)
			# Broken, quiet algae patches settle on upper-facing ledges, rather
			# than outlining every object with a continuous bright green border.
			var algae := sin(point.x*0.19+obstacle.seed*1.7)+sin(point.x*0.071-point.y*0.08)
			if top_edge and algae>0.9 and y>5:
				color=Color("748769") if algae>1.55 else Color("526d58")
			elif lower_edge:
				color=Color("36545a")
			canvas.set_pixel(x,y,color)
	return canvas

static func _stone_color(point: Vector2, size: Vector2, seed: int) -> Color:
	var u:=point.x/size.x
	var v:=point.y/size.y
	var palette: Array[Color]=[Color("36535a"),Color("4d6d70"),Color("69857f"),Color("879b8c"),Color("a4af97")]
	# Broad uneven masses describe rounded weathered stone. Each rock gets a
	# different ridge instead of the same diagonal division and tiled speckles.
	var ridge:=0.27+sin(u*6.5+seed)*0.07+sin(u*16+seed)*0.024
	var light:=0.94-v*0.43-u*0.20+sin(u*8+v*5+seed)*0.055
	var tone:=1 if light<0.44 else (2 if light<0.66 else 3)
	if v<ridge and u<0.78: tone=4 if u<0.52 else 3
	if v>0.83-sin(u*4+seed)*0.055 or u>0.90-v*0.13: tone=maxi(0,tone-1)
	var color: Color=palette[tone]
	var mineral:=sin(point.x*0.19+point.y*0.087+seed)*sin(point.y*0.22-seed*0.7)
	var fleck:=posmod(int(point.x)*17+int(point.y)*29+seed*31,53)
	if mineral>0.52 and fleck<6: color=palette[maxi(1,tone-1)]
	elif mineral< -0.63 and fleck>48: color=palette[mini(4,tone+1)]
	# Sparse short hairline fractures follow the weathered faces; small pebbles
	# stay simple. Break the line and vary its route to avoid a repeated icon.
	if size.y>35:
		var crack_x:=size.x*(0.29+posmod(seed,4)*0.09)+point.y*(0.15 if seed%2 else -0.17)+sin(point.y*0.18+seed)*1.6
		if v>ridge+0.08 and v<0.71 and absf(point.x-crack_x)<0.6 and posmod(int(point.y)+seed,19)<16:
			color=palette[maxi(0,tone-1)]
		if v>0.45 and v<0.66 and absf(point.x-crack_x-(point.y-size.y*0.45)*0.8)<0.55:
			color=palette[maxi(1,tone-1)]
	if v>0.89+sin(u*14+seed)*0.026: color=color.lerp(Color("526f65"),0.40)
	return color
