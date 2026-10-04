extends RefCounted

# Raster-only water and distant scenery. No world state or gameplay targets.
const Presentation=preload("res://scripts/maps/map_presentation.gd")
const Art=preload("res://scripts/pixel_art.gd")
const Depth=preload("res://scripts/pond_depth_art.gd")
const BEAMS: Array = [
	{"x":82,"width":34,"depth":306,"lean":105},
	{"x":398,"width":56,"depth":239,"lean":69},
	{"x":796,"width":43,"depth":349,"lean":122},
	{"x":1129,"width":39,"depth":267,"lean":84}
]

static func layers(presentation: RefCounted=null) -> Dictionary:
	if presentation == null: presentation=Presentation.default_map()
	return {"water":ImageTexture.create_from_image(water_image(presentation)),"distance":ImageTexture.create_from_image(distant_image(presentation)),
		"terrain":ImageTexture.create_from_image(Depth.middle_image(presentation)),"floor":ImageTexture.create_from_image(Depth.floor_image(presentation)),
		"surface":ImageTexture.create_from_image(Depth.surface_image(presentation)),"foreground":ImageTexture.create_from_image(Depth.foreground_image(presentation))}

static func _noise(x: int, y: int) -> float:
	var value:=posmod(x*374761+y*668265+1729,104729)
	return float(value)/104729.0-0.5

static func water_image(presentation: RefCounted=null) -> Image:
	if presentation == null: presentation=Presentation.default_map()
	var image:=Image.create(int(presentation.size.x),int(presentation.size.y),false,Image.FORMAT_RGBA8)
	var shallow:=Color("30777c"); var deep:=Color("123e50")
	for y in image.get_height():
		var depth:=clampf((y-presentation.surface_y)/maxf(1,presentation.floor_y-presentation.surface_y),0,1)
		var base:=shallow.lerp(deep,pow(depth,0.82))
		for x in image.get_width():
			var haze: float=(sin(x*0.009+y*0.006)+sin(x*0.021-y*0.004))*0.003
			var grain:=_noise(x,y)*0.004
			image.set_pixel(x,y,Color(base.r+haze+grain,base.g+haze+grain,base.b+haze+grain,1))
	# Feather the shafts into the existing pixels, including irregular edges.
	# Their ends fade into water; no stacked rectangular cells or full-width bands.
	for beam: Dictionary in BEAMS if presentation.visual_profile_id=="legacy_pond" else []:
		for y in range(maxi(0,int(presentation.surface_y)),mini(image.get_height(),int(presentation.surface_y)+int(beam.depth))):
			var progress: float=(y-presentation.surface_y)/beam.depth
			var center: float=beam.x+beam.lean*progress+sin(progress*5.7+beam.x)*3
			var width: float=beam.width*(0.70+progress*0.65)
			var fade:=pow(1-progress,1.8)*0.085
			for x in range(maxi(0,floori(center-width)),mini(image.get_width(),ceili(center+width))):
				var edge:=maxf(0,1-absf(x-center)/width)
				var strength:=edge*edge*fade*(0.88+sin(y*0.063+beam.x)*0.12)
				image.set_pixel(x,y,image.get_pixel(x,y).lerp(Color("a4ceb4"),strength))
	return image

static func distant_image(presentation: RefCounted=null) -> Image:
	if presentation == null: presentation=Presentation.default_map()
	return Depth.distant_image(presentation)

static func mote(index: int, presentation: RefCounted=null) -> Vector2:
	if presentation == null: presentation=Presentation.default_map()
	return Vector2(minf(10,presentation.size.x*0.5)+posmod(index*197+index*index*13,maxi(1,int(presentation.size.x)-20)),
		presentation.water.position.y+8+posmod(index*97+index*index*7,maxi(1,int(presentation.water.size.y)-30)))
