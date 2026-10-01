extends SceneTree
# Render-only tree assemblies must agree across overlapping physics targets.
const Art=preload("res://scripts/pixel_art.gd")
const Wood=preload("res://scripts/pond_wood_art.gd")
const Layout=preload("res://scripts/pond_layout.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("WOOD_JUNCTION_PASS | ",title)
	else: failed+=1; push_error("WOOD_JUNCTION_FAIL | "+title)
func run() -> void:
	var original:=var_to_bytes(Layout.SOLIDS)
	for group: Array in Wood.GROUPS:
		var layers: Array[Dictionary]=[]
		var forward:=Image.create(1280,480,false,Image.FORMAT_RGBA8)
		var reverse:=Image.create(1280,480,false,Image.FORMAT_RGBA8)
		forward.fill(Color.TRANSPARENT); reverse.fill(Color.TRANSPARENT)
		for seed_value: int in group:
			for solid: Dictionary in Layout.SOLIDS:
				if solid.seed!=seed_value: continue
				layers.append({"seed":seed_value,"image":Art.prop_image(solid),"at":Vector2i(Art.prop_bounds(solid).position)})
		var shared:=0
		var identical:=true
		for layer: Dictionary in layers:
			var overlap:=0
			for y in layer.image.get_height():
				for x in layer.image.get_width():
					var color: Color=layer.image.get_pixel(x,y)
					if color.a==0: continue
					var previous:=forward.get_pixelv(layer.at+Vector2i(x,y))
					if previous.a>0:
						overlap+=1
						if previous!=color: identical=false
			shared+=overlap
			if layer.seed!=group[0]: check(overlap>0,"branch %d shares actual opaque pixels with its parent" % layer.seed)
			forward.blend_rect(layer.image,Rect2i(Vector2i.ZERO,layer.image.get_size()),layer.at)
		layers.reverse()
		for layer: Dictionary in layers:
			reverse.blend_rect(layer.image,Rect2i(Vector2i.ZERO,layer.image.get_size()),layer.at)
		check(shared>0 and identical,"tree %d has identical bark and lighting in all %d overlap pixels" % [group[0],shared])
		check(forward.get_data()==reverse.get_data(),"tree %d stays seamless when trunk/branch drawing order reverses" % group[0])
		# Shared material never fills open water at a fork or expands a target.
		var mask_matches:=true
		var tree:=Wood.context(Layout.SOLIDS[group[0]-1])
		for y in forward.get_height():
			for x in forward.get_width():
				if (forward.get_pixel(x,y).a>0)!=Wood.contains(Vector2(x+0.5,y+0.5),tree): mask_matches=false
		check(mask_matches,"tree %d composite covers exactly the union of existing target polygons" % group[0])
	check(var_to_bytes(Layout.SOLIDS)==original,"shared tree materials leave obstacle geometry unchanged")
	print("WOOD_JUNCTIONS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
