extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
var passed:=0
var failed:=0
var game:Node2D
var output:="res://artifacts/p5-gameplay-native"
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATED_NATIVE_FAIL | "+label)
func _initialize()->void: call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func render(name:String)->Image:
	var before:PackedByteArray=var_to_bytes(game.capture_snapshot())
	game.view.queue_redraw()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(640,360),"game logical viewport")
	check(image.save_png(output.path_join(name+".png"))==OK,"native capture")
	check(before==var_to_bytes(game.capture_snapshot()),"render never changes world")
	return image
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("renderer required"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.capture_mode="p5-native"
	game.menu.close(); freeze(game)
	for seed:int in [42,2166,1346,296,123456789]:
		check(game.reset_world({"map_source":Resolver.generated(seed),"seed":64317,"challenge":false}),"native generated reset")
		game.player_role="fish"; game.fish=Vector2(600,300); game.fish_before=game.fish; game.elapsed=2.0
		await render("seed-%d-fish"%seed)
		check(game.view.generated_water.enabled,"Watergen active and validated")
		check(game.view.props.size()==game.map_context.presentation.wood_groups.size()+game.map_net_blockers.size()-game.map_context.presentation.wood_groups.size()*2,"connected tree parts share one sprite")
		game.player_role="angler"
		await render("seed-%d-shore"%seed)
	game.player_role="fish"
	var first:=await render("visual-a")
	var snapshot:Dictionary=game.capture_snapshot()
	game.view.visual_seed=42
	var second:=await render("visual-b")
	check(first.get_data()!=second.get_data() and game.capture_snapshot()==snapshot,"visual seed changes pixels only")
	var bakes:int=game.view.generated_water.cache.bake_count
	await render("visual-b-repeat")
	check(game.view.generated_water.cache.bake_count==bakes,"unchanged map/visual seed reuses GPU bundle")
	check(game.reset_world(),"classic reset")
	await render("classic")
	check(not game.view.generated_water.enabled,"classic rendering retained")
	game.free()
	print("PHASE05_GAMEPLAY_NATIVE | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
