extends SceneTree
var failures := 0

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var output := "res://artifacts"
var checks := 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("NET_V08_FAIL | "+message)
		failures += 1
		quit(1)
	else:
		checks+=1
		print("NET_PASS | ",message)
	return ok

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output+"/"+which+"-v08.png")==OK,"capture "+which)

func tick(seconds: float, movement: Vector2=Vector2.ZERO) -> void:
	for frame in ceili(seconds*60): game.step(1.0/60,movement,false,false)

func until_state(state: String) -> bool:
	for frame in range(720):
		if game.net_state==state: return true
		game.step(1.0/60,Vector2.ZERO,false,false)
	return require(false,"state "+state+" was never reached")

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await physics_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func fresh(point: Vector2, count: int=0) -> void:
	game.reset(false)
	game.water_strength=1
	game.fish=point
	game.aim=Vector2.RIGHT
	game.net_count=count

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="net-v08-test"
	game.set_process(false)
	game.set_physics_process(false)
	fresh(Vector2(490,150))
	game.menu.open("pause")
	var button: Button
	for candidate in game.menu.content.find_children("*","Button",true,false):
		if candidate.text.begins_with("抄网练习"): button=candidate
	if not require(is_instance_valid(button),"net practice remains available from pause"): return
	await click_at(button.get_global_rect().get_center())
	if not require(not game.paused and game.net_queued,"native menu button queues net and resumes"): return
	tick(0.34)
	await capture("net-entry")
	if not until_state("warning"): return
	tick(0.6)
	await capture("net-sweep-warning")
	tick(0.9,Vector2.UP)
	if not until_state("sweep"): return
	tick(0.65)
	await capture("net-sweep")
	if not until_state("miss"): return
	await capture("net-miss")
	if not until_state("withdraw"): return
	tick(0.6)
	await capture("net-withdraw")
	if not until_state("rest"): return
	if not require(game.net_catches==0 and game.net_dodges==1,"moving vertically evades lateral sweep"): return
	fresh(Vector2(490,150),1)
	await press(KEY_N)
	if not require(game.net_queued,"native N queues descending attack"): return
	if not until_state("warning"): return
	tick(0.6)
	await capture("net-drop-warning")
	tick(0.9,Vector2.RIGHT)
	if not until_state("sweep"): return
	tick(0.75)
	await capture("net-drop")
	if not until_state("rest"): return
	if not require(game.net_catches==0 and game.net_dodges==1,"moving sideways evades rotated descending hoop"): return
	fresh(Vector2(490,150))
	game.score=12.75
	await press(KEY_N)
	if not until_state("caught"): return
	tick(0.12)
	await capture("net-contact")
	tick(0.22)
	await capture("net-bag")
	if not require(game.fish.distance_to(game.net_pos+game.net_bag_offset())<1,"fish settles behind mesh at the bag center"): return
	await press(KEY_ESCAPE)
	var position_before: Vector2=game.fish
	tick(0.5)
	if not require(game.fish==position_before and game.paused,"native pause freezes net and fish"): return
	await press(KEY_ESCAPE)
	for frame in range(240):
		if game.net_pos.y<80: break
		tick(1.0/60)
	await capture("net-lift")
	if not until_state("rest"): return
	if not require(game.score==12.75 and not game.lost and game.fish.distance_to(game.HOME)<23,"practice capture preserves food and restores control at nest"): return
	fresh(Vector2(490,245))
	await press(KEY_N)
	if not until_state("miss"): return
	tick(0.08)
	await capture("net-blocked")
	if not require(game.net_blocked and game.net_catches==0,"wood stops the rim and causes a visible blocked reaction"): return
	fresh(Vector2(490,150),1)
	game.challenge=true
	game.request_net()
	tick(8)
	if not require(game.lost and game.reason=="net" and game.fish.y<53,"challenge ends only after the complete lift"): return
	await capture("net-result")
	fresh(Vector2(490,90),1)
	game.request_net()
	if not until_state("warning"): return
	var started := Time.get_ticks_msec()
	for frame in range(120):
		game.elapsed+=1.0/60
		game.view.queue_redraw()
		await process_frame
	print("NET_RENDER | 120 frames | elapsed_ms=",Time.get_ticks_msec()-started," | fps=",Engine.get_frames_per_second())
	print("NATIVE_NET_V08_PASS | checks=",checks)
	quit(1 if failures else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-output="):
			output = argument.trim_prefix("--visual-output=")
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
