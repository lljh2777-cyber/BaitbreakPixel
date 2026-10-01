extends SceneTree
const Water=preload("res://scripts/pond_water_art.gd")
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("WATER_ART_PASS | ",title)
	else: failed+=1; push_error("WATER_ART_FAIL | "+title)
func run() -> void:
	var world:=World.new(); world.reset_world({"seed":42})
	var state: Dictionary=world.capture_snapshot(); var targets: PackedByteArray=var_to_bytes(world.targets)
	var start:=Time.get_ticks_msec()
	var water:=Water.water_image(); var distance:=Water.distant_image()
	check(water.get_size()==Vector2i(1280,480) and distance.get_size()==water.get_size(),"layers cover the entire scrolling pond at native pixel resolution")
	check(water.get_data()==Water.water_image().get_data(),"water gradients, feathered shafts and grain are deterministic")
	check(distance.get_data()==Water.distant_image().get_data(),"distant shelves, plants and branches are deterministic")
	var terrain:=Water.Depth.middle_image(); var bed:=Water.Depth.floor_image()
	var surface:=Water.Depth.surface_image(); var foreground:=Water.Depth.foreground_image()
	check(terrain.get_size()==water.get_size() and bed.get_size()==water.get_size() and surface.get_size()==water.get_size() and foreground.get_size()==water.get_size(),"all depth planes cover the scrolling pond without cropped edges")
	check(terrain.get_data()==Water.Depth.middle_image().get_data() and bed.get_data()==Water.Depth.floor_image().get_data() and surface.get_data()==Water.Depth.surface_image().get_data() and foreground.get_data()==Water.Depth.foreground_image().get_data(),"new depth planes are deterministic and independent of simulation RNG")
	var bed_opaque:=true; var bed_seam:=0.0; var clear_foreground:=true
	for x in bed.get_width():
		for y in range(433,480): bed_opaque=bed_opaque and bed.get_pixel(x,y).a==1
		var above:=bed.get_pixel(x,432); var below:=bed.get_pixel(x,433)
		bed_seam+=absf(above.r-below.r)+absf(above.g-below.g)+absf(above.b-below.b)
		for y in range(68,300): clear_foreground=clear_foreground and foreground.get_pixel(x,y).a==0
	check(bed_opaque and bed_seam/bed.get_width()<0.05,"near bed stays opaque with no straight alpha/color seam at the gameplay floor")
	check(clear_foreground,"near-edge decoration leaves the upper and central swimming area uncovered")
	var largest_step:=0.0; var opaque:=true; var palette: Dictionary={}
	for y in range(80,420):
		var row_step:=0.0
		for x in water.get_width():
			var pixel:=water.get_pixel(x,y); var above:=water.get_pixel(x,y-1)
			row_step+=absf(pixel.r-above.r)+absf(pixel.g-above.g)+absf(pixel.b-above.b)
			opaque=opaque and pixel.a==1
			palette[pixel.to_rgba32()]=true
		largest_step=maxf(largest_step,row_step/water.get_width())
	check(opaque,"water has no transparent holes exposing seams while the camera scrolls")
	check(largest_step<0.018,"no hard full-width color-band steps remain (largest %.5f)" % largest_step)
	check(palette.size()>100,"water keeps fine native-pixel tonal variation")
	var clear:=0; var occupied:=0; var contrast:=0.0
	for y in range(70,300):
		for x in distance.get_width():
			var pixel:=distance.get_pixel(x,y)
			if pixel.a==0: clear+=1
			else:
				occupied+=1
				var base:=water.get_pixel(x,y); var visible:=base.lerp(pixel,pixel.a)
				contrast=maxf(contrast,absf(base.r-visible.r)+absf(base.g-visible.g)+absf(base.b-visible.b))
	check(occupied>100 and float(clear)/(clear+occupied)>0.90,"upper and middle water retain more than 90 percent clear space")
	check(contrast<0.22,"far silhouettes remain subdued behind fish, food and actual obstacles")
	var motes: Dictionary={}; var valid:=true
	for index in 82:
		var point:=Water.mote(index); motes[point]=true
		valid=valid and world.Layout.WATER.has_point(point)
	check(valid and motes.size()>70,"suspended motes stay in water without repeating a dense tile grid")
	check(world.capture_snapshot()==state and var_to_bytes(world.targets)==targets,"art preparation cannot change RNG, targets, physics or network state")
	world.free()
	print("WATER_ART | passed=",passed," | failed=",failed," | preparation_checks_ms=",Time.get_ticks_msec()-start)
	quit(1 if failed else 0)
