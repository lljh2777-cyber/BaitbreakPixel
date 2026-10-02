extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var passed := 0
var failed := 0
var output := "res://artifacts/phase02-bite-native"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("BITE_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("BITE_NATIVE_FAIL | " + title)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(name: String = "") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if not name.is_empty() and picture.save_png(output.path_join(name + ".png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [name, output])
	return picture

func setup_fixture() -> void:
	game.reset(false,"fish"); game.menu.close()
	game.reset_world({"ruleset":"survival","seed":8231,"rules":{"water_strength":0,"timer_enabled":false,"satiety_decay":0,"instinct_max_strength":0}})
	freeze(game)
	game.fish=Vector2(700,210); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.velocity=Vector2.ZERO
	game.elapsed=2.0; game.power=0.35; game.feeding=false; game.notice_age=0; game.hook_cooldown=1000
	game.satiety=50; game.instinct_drive=0; game.caution_state="CALM"
	for bait in game.baits:
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true

func put_food(offset: Vector2, count: int=1) -> void:
	var bait: Dictionary=game.baits[0]
	bait.active=true; bait.pos=game.mouth()+Vector2(42,0); bait.home=bait.pos; bait.angle=0
	for index in count:
		var grain: Dictionary=bait.grains[index]
		grain.eaten=false; grain.free=true; grain.pos=game.mouth()+offset+Vector2(index,0); grain.points=1.0

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="phase02_bite"
	setup_fixture()
	var ready:=await render("bite-ready")
	check(ready.get_size()==Vector2i(640,360),"native capture preserves 640x360 pixel canvas")
	var initial: Dictionary=game.capture_snapshot()
	var repeated:=await render()
	check(ready.get_data()==repeated.get_data() and game.capture_snapshot()==initial,"ready render is deterministic and simulation-neutral")
	game._attempt_bite(); game.bite_feedback_age=game.BITE_FEEDBACK_SECONDS*0.6
	var empty:=await render("bite-empty-snap")
	check(game.score==0 and game.satiety==50 and game.bite_cooldown==0,"empty snap gives no food, satiety or accepted cooldown")
	check(empty.get_region(Rect2i(272,31,80,17)).get_data()==ready.get_region(Rect2i(272,31,80,17)).get_data(),"empty snap keeps HUD ready, never advertises successful intake")
	check(empty.get_region(Rect2i(285,160,75,65)).get_data()!=ready.get_region(Rect2i(285,160,75,65)).get_data(),"empty press still has local neutral jaw response")
	setup_fixture(); put_food(Vector2(24,0))
	var far_ready:=await render("bite-far-ready")
	check(far_ready.get_region(Rect2i(350,188,12,12)).get_data()!=ready.get_region(Rect2i(350,188,12,12)).get_data(),"far fixture has a visible food grain beyond mouth range")
	game._attempt_bite(); game.bite_feedback_age=game.BITE_FEEDBACK_SECONDS*0.6
	var far:=await render("bite-far-snap")
	check(far.get_region(Rect2i(350,188,12,12)).get_data()==far_ready.get_region(Rect2i(350,188,12,12)).get_data(),"far snap does not visually remove unreachable food")
	check(not game.baits[0].grains[0].eaten and game.score==0 and game.bite_cooldown==0,"far food is not collected and incurs no accepted cooldown")
	check(far.get_region(Rect2i(272,31,80,17)).get_data()==far_ready.get_region(Rect2i(272,31,80,17)).get_data(),"far snap leaves ready hint unchanged")
	setup_fixture(); put_food(Vector2(7,0),4)
	var offered:=await render("bite-food-ready")
	game._attempt_bite(); game.bite_feedback_age=game.BITE_FEEDBACK_SECONDS*0.6
	var active:=await render("bite-active")
	check(game.score==4 and game.satiety>50 and game.bite_cooldown>0,"accepted Bite shows actual four-grain food reward and cooldown")
	check(offered.get_region(Rect2i(272,31,80,17)).get_data()!=active.get_region(Rect2i(272,31,80,17)).get_data(),"ready and cooldown HUD are visually distinct")
	game.bite_feedback_age=0
	var cooling:=await render("bite-cooldown")
	check(active.get_region(Rect2i(285,160,75,65)).get_data()!=cooling.get_region(Rect2i(285,160,75,65)).get_data(),"active jaw and cooldown-resting pose visibly differ")
	game.bite_cooldown=0
	var recovered:=await render("bite-recovered")
	check(recovered.get_region(Rect2i(272,31,80,17)).get_data()==ready.get_region(Rect2i(272,31,80,17)).get_data(),"cooldown recovery restores F ready hint")
	check(active.get_region(Rect2i(366,0,274,49)).get_data()==cooling.get_region(Rect2i(366,0,274,49)).get_data(),"jaw animation does not disturb neighboring HUD")
	check(active.get_region(Rect2i(272,0,80,30)).get_data()==recovered.get_region(Rect2i(272,0,80,30)).get_data(),"Bite hint stays clear of suction label and power bar")
	for state in ["ready","active","cooldown"]:
		setup_fixture(); put_food(Vector2(7,0),4)
		if state!="ready": game._attempt_bite()
		game.bite_feedback_age=game.BITE_FEEDBACK_SECONDS*0.6 if state=="active" else 0.0
		var safe:=await render("hidden-safe-"+state)
		for bait in game.baits: bait.hook=true; bait.hook_id=int(bait.bait_id)+1000
		var hidden:=await render("hidden-hook-"+state)
		check(safe.get_data()==hidden.get_data(),state+": hidden hook flags and IDs never alter pre-contact pixels")
	print("BITE_NATIVE | passed=",passed," | failed=",failed)
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
