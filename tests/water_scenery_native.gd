extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/water-depth"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("WATER_NATIVE_PASS | ",title)
	else: failed+=1; push_error("WATER_NATIVE_FAIL | "+title)
func render(label: String="") -> Image:
	game.view.queue_redraw()
	for tick in 3: await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not label.is_empty(): picture.save_png(output.path_join(label+".png"))
	return picture
func fixture(point: Vector2) -> void:
	game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
	game.reset_world({"ruleset":"survival","seed":42})
	game.fish=point; game.fish_before=point; game.aim=Vector2.RIGHT
	game.elapsed=2; game.notice_age=0
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output-directory="): output=arg.trim_prefix("--capture-output-directory=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.capture_mode="water-depth"
	game.set_process(false); game.set_physics_process(false)
	var cache: Dictionary=game.view.water_layers.duplicate()
	for sample: Array in [["nest",Vector2(66,385)],["left",Vector2(280,310)],["middle",Vector2(670,310)],["right",Vector2(1080,330)],["shallow",Vector2(670,130)],["upper-right",Vector2(1080,170)]]:
		fixture(sample[1]); var state: PackedByteArray=var_to_bytes(game.capture_snapshot())
		var first:=await render(sample[0]); var repeat:=await render()
		check(first.get_data()==repeat.get_data(),sample[0]+": frozen scenery renders identically")
		check(var_to_bytes(game.capture_snapshot())==state,sample[0]+": scenery cannot change the authoritative world")
	fixture(Vector2(320,260))
	for tick in 20: game.advance_tick({"move":Vector2.RIGHT,"aim":Vector2.RIGHT},{})
	await render("contact")
	check(game.target_opacity[0]<1 and game.fish.x>320,"foreground contact fade and actual swimming still work over the distant layers")
	fixture(Vector2(670,310)); game._enter_hook(0); game._attach_hook()
	await render("hooked")
	check(game.view.line_frame.path.size()>1,"hooked line and interaction feedback remain visible")
	fixture(Vector2(970,270))
	var hidden:=await render("hidden-hook")
	game.baits[0].hook=not game.baits[0].hook; game.baits[1].hook=not game.baits[1].hook
	check(hidden.get_data()==(await render()).get_data(),"new background never reveals hidden hook identity")
	check(game.view.water_layers==cache,"resets and camera movement reuse the two prepared textures")
	var point:=Vector2(414,192); var world_point: Vector2=game.screen_to_game(point)
	check(game.view.Camera.to_screen(world_point,game,"fish")==point,"far-layer parallax never changes gameplay pointer coordinates")
	fixture(game.HOME); game.score=game.food_target()-1
	var waiting:=await render("nest-waiting"); game.score=game.food_target()
	var ready:=await render("nest-ready")
	check(waiting.get_region(Rect2i(22,258,77,64)).get_data()!=ready.get_region(Rect2i(22,258,77,64)).get_data(),"natural nest still lights its entrance and destination arrow when food is sufficient")
	check(game.can_home() and game.HOME==Vector2(60,401),"natural nest preserves the original return-home destination")
	print("WATER_NATIVE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
