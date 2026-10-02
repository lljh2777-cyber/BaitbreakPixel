extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/bait-suction-v0211"
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("BAIT_NATIVE_PASS | ",title)
	else: failed+=1; push_error("BAIT_NATIVE_FAIL | "+title)
func render(name: String="") -> Image:
	game.view.queue_redraw()
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	if not name.is_empty() and result.save_png(output.path_join(name+".png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [name, output])
	return result
func fixture(has_hook: bool) -> void:
	game.reset_world({"ruleset":"survival","seed":42,"rules":{"water_strength":0,"timer_enabled":false}})
	game.fish=Vector2(700,210); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.power=1.0
	game.hook_cooldown=1000; game.notice_age=0; game.feeding=true
	for bait in game.baits: bait.active=false
	var bait: Dictionary=game.baits[0]
	bait.hook=has_hook; bait.active=true; bait.pos=game.mouth()+Vector2(26,0); bait.home=bait.pos; bait.angle=0.0
	for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="bait21"
	game.set_process(false); game.set_physics_process(false); game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
	var frames: Array[PackedByteArray]=[]
	for has_hook in [true,false]:
		fixture(has_hook)
		for stage in range(6):
			for tick in 12:
				game.elapsed+=1.0/60
				game._step_bait(0,1.0/60,true,game.mouth())
			var picture:=await render(("hook-" if has_hook else "plain-")+str(stage))
			if has_hook: frames.append(picture.get_data())
			else: check(picture.get_data()==frames[stage],"suction frame %d: hook and plain food render identical moving pellets" % stage)
	check(game.score>0,"native suction sequence delivers food to the mouth")
	print("BAIT_SUCTION_NATIVE_V0211 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="):
			output = argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | --capture-output-directory must not be empty")
		return false
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s; choose a writable --capture-output-directory" % [output, error_string(error)])
		return false
	return true
