extends SceneTree

const Art = preload("res://scripts/pond_plant_art.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const View = preload("res://scripts/pond_view.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("PLANT_ART_FAIL | "+label)

func _initialize() -> void:
	var view := View.new()
	view.prepare_map(View.Presentation.default_map().context) # Explicit golden-map setup before private raster helper.
	var frames := 0
	var preview := ""
	var capture_directory := ""
	var capture_requested := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="): preview=arg.trim_prefix("--preview=")
		if arg.begins_with("--capture-output-directory="):
			capture_directory=arg.trim_prefix("--capture-output-directory=")
			capture_requested=true
	# Preserve the explicit --preview filename and the default no-image mode.
	if capture_requested and preview.is_empty():
		if capture_directory.strip_edges().is_empty():
			push_error("CAPTURE_OUTPUT_FAIL | --capture-output-directory must not be empty")
			view.free(); quit(2); return
		var error := DirAccess.make_dir_recursive_absolute(capture_directory)
		if error!=OK:
			push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s" % [capture_directory,error_string(error)])
			view.free(); quit(2); return
		preview=capture_directory.path_join("plant-art-preview.png")
	var sheet := Image.create(660,156,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("174654"))
	var samples := [0,1,2,5,6,13,14,18]
	# Raster generation must not advance the simulation's global RNG.
	seed(18032026)
	var next_random := randf()
	seed(18032026)
	for index in Layout.PLANTS.size():
		var plant: Dictionary = Layout.PLANTS[index]
		var crop := Rect2i(int(plant.x-plant.width*0.5-14),int(129-plant.height-8),int(plant.width+29),int(plant.height+12))
		crop=crop.intersection(Rect2i(0,0,int(Layout.SIZE.x),132))
		for frame in 8:
			var t := frame*TAU/12.0
			var first: Dictionary = view._make_plant_layer(t,index)
			var second: Dictionary = view._make_plant_layer(t,index)
			var img: Image = first.texture.get_image()
			var data := img.get_data()
			var label := "plant %d frame %d" % [index,frame]
			check(data==second.texture.get_image().get_data(),"deterministic raster: "+label)
			check(img.get_size()==crop.size,"unchanged crop size: "+label)
			check(first.position==Vector2(crop.position)+Vector2(0,plant.y-129),"unchanged crop position: "+label)
			var opaque_pixels := true
			for byte in range(3,data.size(),4):
				if data[byte]!=0 and data[byte]!=255: opaque_pixels=false; break
			check(opaque_pixels,"hard-edged native pixels: "+label)
			var full := Image.create(int(Layout.SIZE.x),132,false,Image.FORMAT_RGBA8)
			full.fill(Color.TRANSPARENT)
			Art.paint(full,plant,t)
			check(crop.encloses(full.get_used_rect()),"no leaves clipped by original crop: "+label)
			for stem in int(plant.stems):
				var fraction := float(stem)/maxi(1,int(plant.stems)-1)
				var height: float = plant.height*(0.67+0.33*sin(stem*2.37+1.2))
				if stem==int(plant.stems)/2: height=plant.height
				# This is the original cached-stalk formula used by grass_binding.
				# Changing a silhouette must never move its mechanical centerline.
				for step in 17:
					var growth := step/16.0
					var old := Vector2(plant.x+(fraction-0.5)*plant.width,129)
					old+=Vector2((fraction-0.5)*plant.width*0.38*growth+sin(t*1.5+plant.x*0.13+stem*0.7+growth*2.1)*growth*2,-height*growth)
					check(old.distance_to(Art._spine(plant,stem,growth,t))<0.0003,"original binding spine: "+label+" stem %d step %d" % [stem,step])
				var root := Vector2i(Art._spine(plant,stem,0,t).round())
				check(full.get_pixelv(root).a==1.0,"visible anchored root: "+label+" stem %d" % stem)
			frames+=1
			if frame==3 and index in samples:
				var col: int = samples.find(index)
				sheet.blend_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i(col*82+8,142-img.get_height()))
	check(randf()==next_random,"raster generation preserves the simulation RNG")
	check(frames==Layout.PLANTS.size()*8,"all cached frames checked")
	if not preview.is_empty():
		sheet.resize(1320,312,Image.INTERPOLATE_NEAREST)
		check(sheet.save_png(preview)==OK,"optional detail preview saved")
	view.free()
	print("PLANT_ART | frames=",frames," | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
