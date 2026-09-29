extends RefCounted

const Art = preload("res://scripts/pixel_art.gd")
const CENTER := Vector2(86,108)
const START := -PI/9.0
const SWEEP := PI*318.0/180.0

# The float travels from the barb around the hook body to the eye.
static func point(progress: float, radius: float = 49.0) -> Vector2:
	return CENTER+Vector2.from_angle(START+clampf(progress,0,1)*SWEEP)*radius

static func section(start: float, finish: float, radius: float = 49.0) -> PackedVector2Array:
	var path := PackedVector2Array()
	var count := maxi(2,ceili(absf(finish-start)*180))
	for index in range(count+1): path.append(point(lerpf(start,finish,index/float(count)),radius).round())
	return path

static func metal_texture() -> Texture2D:
	var canvas := Image.create(176,177,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	# Rasterized metal bands keep the stepped silhouette crisp at integer zoom.
	for y in range(45,172):
		for x in range(18,153):
			var local := Vector2(x,y)-CENTER
			var angle := fposmod(local.angle()-START,TAU)
			var band := local.length()-54.0
			if angle>SWEEP or absf(band)>8: continue
			var color := Color("07131e")
			if absf(band)<6:
				color=Color("354652")
				if band>2: color=Color("a3adb0")
				elif band>-1: color=Color("63717d")
				elif band>-4: color=Color("414f5e")
				if band>3 and band<5: color=Color("e5e3d8")
				if band < -4.5: color=Color("99a3a9")
				if local.x>30 and local.y<10: color=color.darkened(0.18)
			canvas.set_pixel(x,y,color)
	# Shank and eye sit above the open end, with a broad bevel joining the body.
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(106,42),Vector2(118,42),Vector2(118,83),Vector2(107,77),Vector2(96,64),Vector2(107,54)]),Color("07131e"))
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(109,43),Vector2(115,43),Vector2(115,78),Vector2(107,72),Vector2(100,63),Vector2(110,57)]),Color("72818a"))
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(109,44),Vector2(112,44),Vector2(112,70),Vector2(103,63),Vector2(109,59)]),Color("d6d7ce"))
	for y in range(26,51):
		for x in range(101,125):
			var radius := (Vector2(x-113,y-38)/Vector2(9,11)).length()
			if radius>1.13 or radius<0.46: continue
			var color := Color("09151f")
			if radius<0.96 and radius>0.56: color=Color("c9ced0") if x<114 else Color("6a7782")
			if y<32 and radius<0.93: color=Color("f3f0df")
			canvas.set_pixel(x,y,color)
	# Sharp point and inward-facing barb at the other end of the hook.
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(127,70),Vector2(147,94),Vector2(143,109),Vector2(123,116),Vector2(133,99)]),Color("07131e"))
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(130,76),Vector2(143,95),Vector2(140,105),Vector2(128,111),Vector2(137,98)]),Color("939b9e"))
	Art.paint_polygon(canvas,PackedVector2Array([Vector2(130,76),Vector2(139,94),Vector2(138,101),Vector2(134,104),Vector2(136,95)]),Color("f4e8cc"))
	return ImageTexture.create_from_image(canvas)

static func bobber_texture() -> Texture2D:
	return Art.sprite([
		"........dd.......",
		"........dsd......",
		".......dwsd......",
		".....ddddddd.....",
		"....drrrrrrrd....",
		"...drhwwrrrrrd...",
		"..drrhwwrrrrrrd..",
		"..drrrrrrrrrrrd..",
		"..drrrrrrrrrrrd..",
		"..drrrrrrrrrrsd..",
		"..dwwwrrrrrsssd..",
		"..dwwwwwwssssd..",
		"...dwwwwwbbbdd...",
		"....dwwbbbbdd....",
		".....ddddddd.....",
		".......ddd......."],
		{"d":"081521","r":"e74035","h":"ff8263","w":"fff9e7","s":"a22b32","b":"91c3d9"})
