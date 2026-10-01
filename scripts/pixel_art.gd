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
	var palette: Array[Color]=[Color("2c464a"),Color("39565a"),Color("4b6666"),Color("5b7670"),Color("6b8277"),Color("7b8f7f"),Color("8e9c89"),Color("a2ac96")]
	# Curved light rolls around the front face into a broad right-hand shadow.
	var dome:=sqrt(maxf(0,1-pow((u-0.47)/0.55,2)))
	var light:=0.28+dome*0.39-u*0.20-v*0.21
	var crown:=0.27+sin(u*5.4+seed)*0.075+sin(u*13+seed)*0.018
	if v<crown and u<0.72: light+=0.19*(1-u*0.6)
	if u>0.64+sin(v*5+seed)*0.05: light-=0.12
	if v>0.77+sin(u*5+seed)*0.045: light-=0.10
	light+=sin(point.x*0.19+point.y*0.087+seed)*sin(point.y*0.22-seed*0.7)*0.048
	var tone:=clampi(roundi(light*10),0,7)
	var fleck:=posmod(int(point.x)*17+int(point.y)*29+seed*31,53)
	if fleck<5: tone=maxi(0,tone-1)
	elif fleck>48: tone=mini(7,tone+1)
	var color: Color=palette[tone]
	# Hairline cracks and weathered pits sit in the shaded faces, without a
	# diagonal flat fill slicing every rock into the same two triangles.
	if size.y>35:
		var crack_x:=size.x*(0.29+posmod(seed,4)*0.09)+point.y*(0.15 if seed%2 else -0.17)+sin(point.y*0.18+seed)*1.6
		if v>crown+0.08 and v<0.74 and absf(point.x-crack_x)<0.6 and posmod(int(point.y)+seed,19)<16:
			color=palette[maxi(0,tone-2)]
		var pit:=Vector2((u-0.63)/0.12,(v-0.51)/0.10).length()
		if pit<1.0 and sin(point.x*0.9+seed)>0.2: color=palette[maxi(0,tone-1)]
	var moss:=sin(point.x*0.21+seed)+sin(point.y*0.27+point.x*0.047)
	if v<crown+0.09 and moss>1.22: color=color.lerp(Color("78865e"),0.43)
	if v>0.91+sin(u*14+seed)*0.026: color=color.lerp(Color("3b5a50"),0.48)
	return color
