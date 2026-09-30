extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/feeding-feel-v022"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("FEEDING_NATIVE_PASS | ",title)
	else: failed+=1; push_error("FEEDING_NATIVE_FAIL | "+title)
func render(name: String="") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not name.is_empty(): picture.save_png(output.path_join(name+".png"))
	return picture
func fixture(power_value: float, has_hook: bool) -> void:
	game.reset_world({"ruleset":"survival","seed":42,"rules":{"water_strength":0,"timer_enabled":false}})
	game.fish=Vector2(700,210); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.power=power_value
	game.hook_cooldown=1000; game.notice_age=0; game.feeding=true
	for bait in game.baits: bait.active=false
	var bait: Dictionary=game.baits[0]
	bait.active=true; bait.hook=has_hook; bait.pos=game.mouth()+Vector2(26,0); bait.home=bait.pos; bait.angle=0.0
	for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output-directory="): output=arg.trim_prefix("--capture-output-directory=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.capture_mode="feeding22"
	game.set_process(false); game.set_physics_process(false); game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
	for power_value in [0.35,1.0]:
		var prefix:="gentle" if power_value<1 else "strong"
		var frames: Array[PackedByteArray]=[]
		for has_hook in [true,false]:
			fixture(power_value,has_hook)
			var peak:=0.0; var elapsed_ticks:=0
			for stage in [9,18,36,60]:
				for tick in stage-elapsed_ticks:
					game.elapsed+=1.0/60; game._step_bait(0,1.0/60,true,game.mouth())
				elapsed_ticks=stage
				peak=maxf(peak,Vector2(game.baits[0].suction_offset).length())
				var picture:=await render(prefix+("-hook-" if has_hook else "-plain-")+str(stage))
				if has_hook: frames.append(picture.get_data())
				else: check(picture.get_data()==frames[[9,18,36,60].find(stage)],prefix+": bait shape, trails and intake feedback never reveal hook identity at frame "+str(stage))
			check(peak>2,prefix+": whole cluster actually moves, hook=%s" % has_hook)
			var before: Dictionary=game.capture_snapshot(); var first:=await render(); var second:=await render()
			check(game.capture_snapshot()==before,prefix+": visual feedback cannot alter simulation")
			check(first.get_data()==second.get_data(),prefix+": a fixed simulation tick renders identically")
		fixture(power_value,false)
		for tick in 36: game.elapsed+=1.0/60; game._step_bait(0,1.0/60,true,game.mouth())
		var deformed:=await render(prefix+"-deformed")
		var saved: Vector2=game.baits[0].suction_offset; game.baits[0].suction_offset=Vector2.ZERO
		var round_shape:=await render()
		check(deformed.get_region(Rect2i(320,180,45,28)).get_data()!=round_shape.get_region(Rect2i(320,180,45,28)).get_data(),"the rendered cluster stretches along its actual pull, "+prefix)
		game.baits[0].suction_offset=saved; game.last_eat_at=game.elapsed-0.3
		var quiet:=await render(); game.last_eat_at=game.elapsed-0.02
		var intake:=await render(prefix+"-intake")
		check(quiet.get_region(Rect2i(328,187,12,14)).get_data()!=intake.get_region(Rect2i(328,187,12,14)).get_data(),"a real intake timestamp lights the mouth, "+prefix)
	print("FEEDING_FEEL_NATIVE_V022 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
