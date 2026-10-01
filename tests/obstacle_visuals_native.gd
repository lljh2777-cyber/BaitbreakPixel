extends SceneTree
# Run with a native renderer and an isolated profile:
# godot --path . --script tests/obstacle_visuals_native.gd -- --test-profile
# Optional: --capture-output-directory=res://artifacts/obstacle-visuals
const Main=preload("res://scenes/main.tscn")
const Layout=preload("res://scripts/pond_layout.gd")
const Grass=preload("res://scripts/grass_binding.gd")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/obstacle-visuals"
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Obstacle visual checks require a native renderer.")
		quit(2)
		return
	if not "--test-profile" in OS.get_cmdline_user_args():
		push_error("Use --test-profile to keep native checks isolated from player saves.")
		quit(2)
		return
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("OBSTACLE_VISUAL_PASS | ",label)
	else: failed+=1; push_error("OBSTACLE_VISUAL_FAIL | "+label)
func render(name:String="") -> Image:
	game.view.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	if not name.is_empty(): result.save_png(output.path_join(name+".png"))
	return result
func difference(a:Image,b:Image) -> float:
	var sum:=0.0
	for y in a.get_height():
		for x in a.get_width():
			var one:=a.get_pixel(x,y); var two:=b.get_pixel(x,y)
			sum+=absf(one.r-two.r)+absf(one.g-two.g)+absf(one.b-two.b)
	return sum
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output-directory="): output=arg.trim_prefix("--capture-output-directory=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.capture_mode="obstacle-visual-check"
	game.set_process(false); game.set_physics_process(false)
	for plant_index in [1,14,18]:
		game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
		game.reset_world({"ruleset":"duel","challenge":false,"water_strength":0,"seed":2649})
		var plant:Dictionary=Layout.PLANTS[plant_index]
		var target:int=Layout.SOLIDS.size()+plant_index
		game.fish=Vector2(plant.x+48,plant.y-42); game.fish_before=game.fish
		game.aim=Vector2.LEFT; game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
		game.elapsed=4; game.notice_age=0; game.tension=0.4; game.qte=""
		var coil:Dictionary=Layout.coil_at(game.targets[target],Vector2(plant.x,plant.y-plant.height*0.48))
		coil.target=target; game.wraps.assign([coil])
		for progress in [0.0,0.5,1.0]:
			game.wraps[0].progress=progress
			await render("grass-%d-bound-%03d" % [plant_index,roundi(progress*100)])
		var profile:=Grass.profile(game,game.wraps[0],1.0)
		check(not game.view.line_frame.grass.is_empty(),"native bound-grass draw path is active for plant %d" % plant_index)
		var roots_anchored:=true
		for offset in [-16,-8,0,8,16]:
			var root_point:=Vector2(plant.x+offset,plant.y)
			roots_anchored=roots_anchored and Grass.deform(root_point,profile)==root_point
		check(roots_anchored,"grass root remains fixed for plant %d" % plant_index)
		game.target_opacity[target]=1.0
		var before:PackedByteArray=var_to_bytes(game.capture_snapshot())
		var opaque:=await render("grass-%d-opacity-100" % plant_index)
		var repeat:=await render()
		check(opaque.get_data()==repeat.get_data(),"bound grass renders deterministically at frozen tick for plant %d" % plant_index)
		check(before==var_to_bytes(game.capture_snapshot()),"bound grass drawing leaves world unchanged for plant %d" % plant_index)
		game.target_opacity[target]=0.25
		var faded:=await render("grass-%d-opacity-025" % plant_index)
		game.target_opacity[target]=0.0
		var hidden:=await render("grass-%d-opacity-000" % plant_index)
		var full_delta:=difference(opaque,hidden)
		var faded_delta:=difference(faded,hidden)
		check(full_delta>1.0 and faded_delta>0.01 and faded_delta<full_delta*0.6,"bound grass honors intermediate/zero target opacity for plant %d (full %.2f, faded %.2f)" % [plant_index,full_delta,faded_delta])
		game.target_opacity[target]=1.0
	# Solid tinting should still fade whole render-only material sprites.
	game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
	game.fish=Vector2(670,310); game.elapsed=2; game.notice_age=0
	var solid:=6
	game.target_opacity[solid]=1.0
	var log_opaque:=await render("log-opacity-100")
	game.target_opacity[solid]=0.25
	var log_faded:=await render("log-opacity-025")
	game.target_opacity[solid]=0.0
	var log_hidden:=await render("log-opacity-000")
	var log_full_delta:=difference(log_opaque,log_hidden)
	var log_faded_delta:=difference(log_faded,log_hidden)
	check(log_full_delta>1.0 and log_faded_delta>0.01 and log_faded_delta<log_full_delta*0.6,"fallen log material respects whole-target fading (full %.2f, faded %.2f)" % [log_full_delta,log_faded_delta])
	print("OBSTACLE_VISUAL_CHECK | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
