extends RefCounted

# Raster-only water and distant scenery. No world state or gameplay targets.
const Layout=preload("res://scripts/pond_layout.gd")
const Art=preload("res://scripts/pixel_art.gd")
const BEAMS: Array = [
	{"x":82,"width":34,"depth":306,"lean":105},
	{"x":398,"width":56,"depth":239,"lean":69},
	{"x":796,"width":43,"depth":349,"lean":122},
	{"x":1129,"width":39,"depth":267,"lean":84}
]

static func layers() -> Dictionary:
	return {"water":ImageTexture.create_from_image(water_image()),"distance":ImageTexture.create_from_image(distant_image())}

static func _noise(x: int, y: int) -> float:
	var value:=posmod(x*374761+y*668265+1729,104729)
	return float(value)/104729.0-0.5

static func water_image() -> Image:
	var image:=Image.create(int(Layout.SIZE.x),int(Layout.SIZE.y),false,Image.FORMAT_RGBA8)
	var shallow:=Color("30777c"); var deep:=Color("123e50")
	for y in image.get_height():
		var depth:=clampf((y-55.0)/378.0,0,1)
		var base:=shallow.lerp(deep,pow(depth,0.82))
		for x in image.get_width():
			var haze: float=(sin(x*0.009+y*0.006)+sin(x*0.021-y*0.004))*0.003
			var grain:=_noise(x,y)*0.004
			image.set_pixel(x,y,Color(base.r+haze+grain,base.g+haze+grain,base.b+haze+grain,1))
	# Feather the shafts into the existing pixels, including irregular edges.
	# Their ends fade into water; no stacked rectangular cells or full-width bands.
	for beam: Dictionary in BEAMS:
		for y in range(55,55+int(beam.depth)):
			var progress: float=(y-55.0)/beam.depth
			var center: float=beam.x+beam.lean*progress+sin(progress*5.7+beam.x)*3
			var width: float=beam.width*(0.70+progress*0.65)
			var fade:=pow(1-progress,1.8)*0.085
			for x in range(maxi(0,floori(center-width)),mini(image.get_width(),ceili(center+width))):
				var edge:=maxf(0,1-absf(x-center)/width)
				var strength:=edge*edge*fade*(0.88+sin(y*0.063+beam.x)*0.12)
				image.set_pixel(x,y,image.get_pixel(x,y).lerp(Color("a4ceb4"),strength))
	return image

static func distant_image() -> Image:
	var image:=Image.create(int(Layout.SIZE.x),int(Layout.SIZE.y),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Soft silt shelves give the far plants a place to grow above the near floor.
	for shelf: Array in [[-30,387,242,25],[363,382,282,31],[828,390,241,34],[1115,377,238,37]]:
		var x: float=shelf[0]; var y: float=shelf[1]; var width: float=shelf[2]; var height: float=shelf[3]
		Art.paint_polygon(image,PackedVector2Array([Vector2(x,y+50),Vector2(x,y),Vector2(x+width*0.22,y-height*0.48),Vector2(x+width*0.53,y-height),Vector2(x+width*0.81,y-height*0.36),Vector2(x+width,y+4),Vector2(x+width,y+50)]),Color(0.13,0.28,0.33,0.42))
	# Uneven groups, with broad clear water between. All are decorative silhouettes.
	for clump: Array in [[70,373,144,7],[180,375,78,4],[459,369,116,6],[572,373,66,4],[925,365,147,7],[1034,379,107,5],[1205,365,181,8]]:
		_reeds(image,float(clump[0]),float(clump[1]),float(clump[2]),int(clump[3]))
	# Two distant fallen branches use subdued, unoutlined shapes.
	_branch(image,Vector2(214,367),Vector2(271,316),31)
	_branch(image,Vector2(718,397),Vector2(797,366),67)
	return image

static func _reeds(image: Image, x: float, root_y: float, height: float, stems: int) -> void:
	for stem in stems:
		var root:=Vector2(x+(stem-float(stems-1)*0.5)*9,root_y+sin(stem*2.7+x)*5)
		var rise:=height*(0.55+0.45*(0.5+sin(stem*2.31+x)*0.5))
		var bend:=sin(stem*1.73+x)*9
		var points:=PackedVector2Array()
		for segment in 9:
			var growth:=segment/8.0
			points.append((root+Vector2(bend*growth*growth+sin(growth*3.4+stem)*growth*2,-rise*growth)).round())
		var tint:=Color(0.10,0.25,0.29,0.49) if stem%2 else Color(0.18,0.34,0.35,0.40)
		for segment in range(8):
			Art.paint_line(image,points[segment],points[segment+1],tint)
			if segment in [2,4,6]:
				var side:=1 if (stem+segment/2)%2 else -1
				Art.paint_line(image,points[segment],points[segment]+Vector2(side*(5+segment),-5-segment),tint)
		# A few tapered ribbon silhouettes break up the fine branching plants.
		if stem%3==0:
			Art.paint_polygon(image,PackedVector2Array([root-Vector2(2,0),points[3]-Vector2(2,0),points[8],points[4]+Vector2(2,0),root+Vector2(2,0)]),tint)

static func _branch(image: Image, base: Vector2, tip: Vector2, seed_value: int) -> void:
	var side: Vector2=(tip-base).normalized().orthogonal()
	var middle:=base.lerp(tip,0.55)+Vector2(0,-4)
	var tint:=Color(0.10,0.24,0.28,0.42)
	Art.paint_polygon(image,PackedVector2Array([base-side*6,middle-side*4,tip-side*1,tip+side*2,middle+side*3,base+side*5]),tint)
	var start:=base.lerp(tip,0.45)
	var end:=start+Vector2(8,-24) if seed_value==31 else start+Vector2(-16,-22)
	Art.paint_polygon(image,PackedVector2Array([start-side*3,end,start+side*2]),tint)

static func mote(index: int) -> Vector2:
	return Vector2(10+posmod(index*197+index*index*13,1260),76+posmod(index*97+index*index*7,333))
