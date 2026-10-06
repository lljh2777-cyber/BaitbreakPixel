extends RefCounted
## Native production scenery for one authored map. Only immutable public map
## presentation, public host opacity and local visual time enter this renderer.
const Map=preload("res://scripts/maps/woodland_pond_map.gd")
const Geometry=preload("res://scripts/maps/map_geometry.gd")
const Fauna=preload("res://scripts/watergen/woodland_fauna.gd")
static var cached: Dictionary={}
var active:=false
var bundle: Dictionary={}
var fauna: RefCounted
var visual_time:=0.0

func prepare(context: RefCounted, presentation: RefCounted) -> void:
	active=context.id==Map.ID and presentation.visual_profile_id==Map.PROFILE
	if not active: bundle={}; return
	if cached.is_empty(): cached=_prepare(context,presentation)
	bundle=cached
	if fauna==null: fauna=Fauna.new()

static func _image(path: String) -> Image:
	var texture: Texture2D=load(path)
	var image:=texture.get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(1280,480,Image.INTERPOLATE_NEAREST)
	return image

static func _prepare(context: RefCounted, presentation: RefCounted) -> Dictionary:
	var original:=_image("res://assets/woodland_pond/scene.png")
	var behind:=_image("res://assets/woodland_pond/cleanplate.png")
	var base:=original.duplicate()
	var groups: Array[Dictionary]=[]
	var indexes: Dictionary={}
	for i in presentation.solids.size():
		var solid: Dictionary=presentation.solids[i]
		var group: String=presentation.solid_fade_group(i)
		if not indexes.has(group):
			indexes[group]=groups.size(); groups.append({"id":group,"targets":[],"masks":[],"plant":-1})
		var entry: Dictionary=groups[indexes[group]]
		entry.targets.append(solid.target_index)
		if not solid.skin_polygon.is_empty(): entry.masks.append(solid.skin_polygon)
	for i in presentation.plants.size():
		var plant: Dictionary=presentation.plants[i]
		groups.append({"id":plant.feature_id,"targets":[plant.target_index],"masks":[plant.skin_polygon],"plant":i})
	# Disjoint ownership prevents overlapping host crops from leaving a duplicate
	# stone/leaf behind when either host fades. This is runtime texture assembly.
	var owners:=PackedInt32Array(); owners.resize(1280*480); owners.fill(-1)
	for i in groups.size():
		for polygon: PackedVector2Array in groups[i].masks:
			var bounds:=Geometry.polygon_bounds(polygon)
			for y in range(maxi(0,floori(bounds.position.y)),mini(480,ceili(bounds.end.y))):
				for x in range(maxi(0,floori(bounds.position.x)),mini(1280,ceili(bounds.end.x))):
					if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),polygon): owners[y*1280+x]=i
	var images: Array[Image]=[]
	for i in groups.size():
		var image:=Image.create(1280,480,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT); images.append(image)
	for y in 480:
		for x in 1280:
			var owner:=owners[y*1280+x]
			if owner<0: continue
			images[owner].set_pixel(x,y,original.get_pixel(x,y))
			base.set_pixel(x,y,behind.get_pixel(x,y))
	var props: Array[Dictionary]=[]; var plants: Array=[]; var host_indexes: Dictionary={}
	plants.resize(presentation.plants.size())
	for i in groups.size():
		var region:=images[i].get_used_rect()
		var entry: Dictionary={"texture":ImageTexture.create_from_image(images[i].get_region(region)),"position":Vector2(region.position),"targets":groups[i].targets}
		host_indexes[groups[i].id]=groups[i].targets
		if groups[i].plant>=0:
			var frames: Array[Dictionary]=[]
			for frame in 8: frames.append(entry)
			plants[groups[i].plant]=frames
		else: props.append(entry)
	var bed:=Image.create(1280,480,false,Image.FORMAT_RGBA8); bed.fill(Color.TRANSPARENT)
	for x in 1280:
		for y in range(ceili(context.floor_at(x)),480): bed.set_pixel(x,y,base.get_pixel(x,y))
	return {"background":ImageTexture.create_from_image(base),"bed":ImageTexture.create_from_image(bed),"props":props,"plants":plants,"host_indexes":host_indexes,"owners":owners}

func draw_background(view: Node2D) -> void:
	view.draw_texture(bundle.background,Vector2.ZERO)
	fauna.draw(view,visual_time,"background")

func draw_attached(view: Node2D, opacities: Array) -> void:
	var hosts: Dictionary={}
	for identity: String in bundle.host_indexes:
		var opacity:=1.0
		for index: int in bundle.host_indexes[identity]: opacity=minf(opacity,opacities[index])
		hosts[identity]=opacity
	fauna.draw(view,visual_time,"attached",hosts)

func draw_foreground(view: Node2D) -> void:
	fauna.draw(view,visual_time,"foreground")
