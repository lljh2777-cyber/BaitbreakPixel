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
	var grain := _wood_shape(int(obstacle.seed),polygon) if wood else {}
	for y in canvas.get_height():
		for x in canvas.get_width():
			var point := bounds.position+Vector2(x+0.5,y+0.5)
			if not Geometry2D.is_point_in_polygon(point,polygon): continue
			var color := _wood_color(point,grain,int(obstacle.seed)) if wood else _stone_color(Vector2(x,y),bounds.size,int(obstacle.seed))
			var top_edge := not Geometry2D.is_point_in_polygon(point-Vector2(0,2),polygon)
			var lower_edge := not Geometry2D.is_point_in_polygon(point+Vector2(1,1),polygon)
			# Broken, quiet algae patches settle on upper-facing ledges, rather
			# than outlining every object with a continuous bright green border.
			var algae := sin(point.x*0.19+obstacle.seed*1.7)+sin(point.x*0.071-point.y*0.08)
			if top_edge and algae>0.9 and y>5:
				color=Color("748769") if algae>1.55 else Color("526d58")
			elif lower_edge and (not wood or int(obstacle.seed) in [1,7] or point.distance_to(grain.path[-1])>float(grain.radii[-1])*1.6):
				color=Color("344b43") if wood else Color("36545a")
			canvas.set_pixel(x,y,color)
	return canvas

static func _wood_shape(seed: int, polygon: PackedVector2Array) -> Dictionary:
	# These are art-only grain spines through the existing bent trunks/roots.
	# Matching their curvature makes a fallen branch read as timber, not a plank.
	var shapes := {
		1:[[Vector2(337,171),Vector2(335,237),Vector2(344,299),Vector2(354,368),Vector2(355,434)],[8.0,14.0,18.0,25.0,25.0]],
		4:[[Vector2(266,246),Vector2(286,260),Vector2(311,284),Vector2(342,309)],[4.0,7.0,8.0,11.0]],
		5:[[Vector2(415,222),Vector2(394,238),Vector2(354,281)],[4.0,7.0,10.0]],
		6:[[Vector2(247,430),Vector2(260,415),Vector2(281,399),Vector2(315,399),Vector2(351,432)],[3.0,6.0,7.0,7.0,12.0]],
		7:[[Vector2(487,422),Vector2(530,411),Vector2(590,390),Vector2(647,374),Vector2(663,374)],[9.0,17.0,17.0,17.0,7.0]],
		11:[[Vector2(303,210),Vector2(333,231)],[3.0,6.0]],
		12:[[Vector2(372,227),Vector2(361,241),Vector2(347,259)],[4.0,5.0,7.0]],
		15:[[Vector2(583,312),Vector2(587,340),Vector2(610,379)],[3.0,5.0,9.0]],
		17:[[Vector2(1224,363),Vector2(1218,399),Vector2(1202,433)],[6.0,8.0,9.0]],
		18:[[Vector2(1172,363),Vector2(1190,385),Vector2(1217,400)],[3.0,6.0,8.0]]
	}
	var shape: Array=shapes.get(seed,[[polygon[0],polygon[polygon.size()/2]],[6.0,6.0]])
	var length:=0.0
	for i in range(1,shape[0].size()): length+=Vector2(shape[0][i]).distance_to(shape[0][i-1])
	return {"path":shape[0],"radii":shape[1],"length":length}

static func _wood_color(point: Vector2, shape: Dictionary, seed: int) -> Color:
	var distance:=INF
	var along:=0.0
	var across:=0.0
	var radius:=1.0
	var normal:=Vector2.RIGHT
	var travelled:=0.0
	for i in range(1,shape.path.size()):
		var a: Vector2=shape.path[i-1]
		var b: Vector2=shape.path[i]
		var edge:=b-a
		var ratio:=clampf((point-a).dot(edge)/edge.length_squared(),0,1)
		var delta:=point-a.lerp(b,ratio)
		if delta.length_squared()<distance:
			distance=delta.length_squared()
			normal=edge.normalized().orthogonal()
			across=delta.dot(normal)
			along=travelled+edge.length()*ratio
			radius=lerpf(shape.radii[i-1],shape.radii[i],ratio)
		travelled+=edge.length()
	var side:=clampf(across/radius,-1,1)
	var light:=0.43+sqrt(maxf(0,1-side*side))*0.34+side*normal.dot(Vector2(-0.8,-0.6))*0.18
	var palette: Array[Color]=[Color("334d46"),Color("50604e"),Color("737b5e"),Color("979779")]
	var tone:=0 if light<0.40 else (1 if light<0.58 else (2 if light<0.75 else 3))
	var color: Color=palette[tone]
	var wave:=across+sin(along*0.047+seed)*1.35+sin(along*0.117+seed*2.3)*0.55
	var groove:=sin(wave*0.87+seed)
	var broken:=sin(along*0.093+wave*0.31)+sin(along*0.037-seed)
	# Interrupted, curving bark furrows and occasional exposed wood fibres.
	if groove>0.83 and broken> -0.25: color=palette[maxi(0,tone-1)]
	elif groove< -0.93 and broken>0.55 and tone>0: color=palette[mini(3,tone+1)]
	var scar:=sin(along*0.031+seed)+sin(across*0.35+along*0.019)
	if scar>1.55 and absf(side)<0.65: color=palette[mini(3,tone+1)]
	# Water-darkened remnants of bark break up the pale exposed heartwood.
	var bark:=sin(along*0.026+seed*2.1)+sin(wave*0.28+seed*0.7)
	if bark>1.17 and absf(side)>0.24:
		color=palette[maxi(0,tone-1)]
		if groove>0.83: color=palette[0]
	# A few end-grain splinters remain pale; most cut faces are water-darkened.
	if along<3.4+sin(across*1.1+seed)*1.4:
		color=Color("a5a080") if posmod(floori(across*1.5)+seed,5)<3 else Color("757858")
	# Only the old trunk and large fallen log carry large knots, not every twig.
	if seed in [1,7]:
		var knot:=Vector2((across-radius*0.13)/4.0,(along-shape.length*(0.39 if seed==1 else 0.65))/7.0)
		var ring:=knot.length()+sin(knot.angle()*3+seed)*0.09
		if ring<0.45: color=Color("3b5149")
		elif ring<0.70 or (ring>0.96 and ring<1.15): color=palette[tone if knot.y<0 else mini(3,tone+1)]
		elif ring<0.94: color=palette[0]
	if seed==7:
		# The snapped end is an irregular, partially hollow cross-section. Its
		# restrained rings differ from the lengthwise grain and do not look sawn.
		var end:=Vector2((point.x-657)/8.0,(point.y-375)/13.0)
		var ring:=end.length()+sin(end.angle()*5)*0.09
		if ring<1:
			color=Color("8c9070") if end.x<0 else Color("67765d")
			if ring>0.65 and ring<0.80: color=Color("586950")
			if ring<0.34: color=Color("304e47")
			if end.y>0.1 and absf(end.x+end.y*0.2)<0.10: color=Color("425b49")
	# Buried timber takes on silt and algae near the bed, with no separate halo.
	if point.y>422+sin(point.x*0.14+seed)*3:
		color=color.lerp(Color("4d685b"),0.45)
	return color

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
