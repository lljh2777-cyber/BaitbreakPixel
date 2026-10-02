extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var passed := 0
var failed := 0
var output := "res://artifacts/phase15-native"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PHASE15_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("PHASE15_NATIVE_FAIL | " + title)

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

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="phase15"
	game.reset(false,"angler"); game.menu.close(); freeze(game)
	game.reset_world({"ruleset":"duel","seed":2649,"rules":{"water_strength":0,"hunger_enabled":false}})
	game.fish=Vector2(900,300); game.fish_before=game.fish
	game.notice_age=0
	var initial:=await render("angler-undeployed")
	check(game.view.Shore.rig_index(game)==-1,"initial ambient hooks have no owned float/line")
	game.advance_tick({}, {"deploy":true})
	for n in 60: game.advance_tick({}, {})
	var idle:=await render("angler-idle")
	check(game.view.Shore.rig_index(game)==0 and initial.get_data()!=idle.get_data(),"Q visibly deploys actual rig")
	var reel_images: Array[Image]=[]
	for key in 2:
		for n in 15: game.advance_tick({}, {"reel":true})
		reel_images.append(await render("angler-reel-%d" % key))
	check(game.angler.reel_hand_mode==-1 and game.angler.free_reel_speed<0,"reel keyframes driven by actual motion")
	var release_images: Array[Image]=[]
	for key in 2:
		for n in 25: game.advance_tick({}, {"release":true})
		release_images.append(await render("angler-release-%d" % key))
	check(game.angler.reel_hand_mode==1 and game.angler.free_reel_speed>0,"release keyframes driven by actual motion")
	var hand_rect:=Rect2i(170,215,350,112)
	check(idle.get_region(hand_rect).get_data()!=reel_images[0].get_region(hand_rect).get_data(),"idle/reel hand keyframes differ")
	check(reel_images[0].get_region(hand_rect).get_data()!=reel_images[1].get_region(hand_rect).get_data(),"reel periodic keyframes differ")
	check(release_images[0].get_region(hand_rect).get_data()!=release_images[1].get_region(hand_rect).get_data(),"release periodic keyframes differ")
	check(reel_images[1].get_region(hand_rect).get_data()!=release_images[1].get_region(hand_rect).get_data(),"reel/release poses differ")
	for n in 90: game.advance_tick({}, {})
	check(game.angler.reel_hand_amount==0 and game.angler.feedback_reel_speed(game)==0,"neutral stops reel action")
	await render("angler-stopped")
	game.reset(false,"angler"); game.notice_age=0
	check(game.view.Shore.rig_index(game)==-1,"actual application restart undeployed")
	await render("angler-restart")
	game.reset(false,"fish"); game.notice_age=0
	game.elapsed=2; game.instinct_drive=0
	var prior_width:=-1
	for value in [0.0,5.0,20.0,50.0,100.0]:
		game.satiety=value; game.caution_state="CALM"
		var picture:=await render("fish-satiety-%d" % int(value))
		var pixels:=0
		for x in range(446,516):
			if picture.get_pixel(x,23)!=Color("335762"): pixels+=1
		check(pixels>=prior_width and pixels>=0 and pixels<=70,"satiety actual pixel width bounded/monotonic %d: %d" % [int(value),pixels])
		check(absf(pixels-game.view.satiety_bar_width(value))<=1,"satiety rendered width follows self value %d" % int(value))
		prior_width=pixels
	game.satiety=50
	var caution_images:Array[Image]=[]
	for caution in ["CALM","UNEASY","ALARMED"]:
		game.caution_state=caution
		caution_images.append(await render("fish-caution-"+caution.to_lower()))
	check(caution_images[0].get_region(Rect2i(366,31,100,17)).get_data()!=caution_images[1].get_region(Rect2i(366,31,100,17)).get_data(),"caution own readable row")
	check(caution_images[1].get_region(Rect2i(366,31,100,17)).get_data()!=caution_images[2].get_region(Rect2i(366,31,100,17)).get_data(),"uneasy/alarmed text differs")
	game.satiety=5; game.instinct_drive=0.8
	await render("fish-low-satiety-instinct")
	var font:Font=game.view.font
	check(366+font.get_string_size("警惕 · 警觉",HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<470,"full-size caution label clears instinct column")
	check(43-font.get_ascent(11)>25 and 43+font.get_descent(11)<49,"caution row clears bars and top panel bottom")
	check(532+font.get_string_size("不限时",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<640,"right clock label within viewport")
	print("PHASE15_NATIVE | passed=",passed," | failed=",failed)
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
