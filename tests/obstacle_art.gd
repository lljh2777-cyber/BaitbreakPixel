extends SceneTree

const Art=preload("res://scripts/pixel_art.gd")
const Layout=preload("res://scripts/pond_layout.gd")
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("OBSTACLE_ART_PASS | ",title)
	else: failed+=1; push_error("OBSTACLE_ART_FAIL | "+title)

func run() -> void:
	var original:=var_to_bytes(Layout.SOLIDS)
	var wood_colors: Dictionary={}
	var stone_colors: Dictionary={}
	for obstacle in Layout.SOLIDS:
		var title: String=obstacle.kind+" "+str(obstacle.seed)
		var polygon:=PackedVector2Array(obstacle.points)
		var bounds:=Art.prop_bounds(obstacle)
		var first:=Art.prop_image(obstacle)
		var second:=Art.prop_image(obstacle)
		check(first.get_data()==second.get_data(),title+": identical input produces identical pixel bytes")
		var sprite:=Art.prop(obstacle)
		check(sprite.position==bounds.position and sprite.texture.get_image().get_data()==first.get_data(),title+": cached texture preserves exact pixel placement")
		var mask_matches:=true
		var crisp:=true
		var colors: Dictionary={}
		for y in first.get_height():
			for x in first.get_width():
				var color:=first.get_pixel(x,y)
				var inside:=Geometry2D.is_point_in_polygon(bounds.position+Vector2(x+0.5,y+0.5),polygon)
				if (color.a>0)!=inside: mask_matches=false
				if color.a!=0 and color.a!=1: crisp=false
				if color.a>0: colors[color.to_rgba32()]=true
		check(mask_matches,title+": artwork occupies exactly the existing collision/coil silhouette")
		check(crisp,title+": edges remain opaque pixel art without antialiased halos")
		check(colors.size()>=4,title+": natural material retains light, midtone and shadow detail")
		if obstacle.kind=="wood": wood_colors.merge(colors)
		else: stone_colors.merge(colors)
	check(var_to_bytes(Layout.SOLIDS)==original,"art generation never mutates authoritative obstacle geometry")
	check(wood_colors!=stone_colors,"wood and stone keep distinct material palettes")
	print("OBSTACLE_ART | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
