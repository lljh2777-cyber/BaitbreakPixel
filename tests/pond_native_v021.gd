extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/pond-v021"
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("POND_NATIVE_PASS | ",title)
	else: failed+=1; push_error("POND_NATIVE_FAIL | "+title)
func render(name: String="") -> Image:
	game.view.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	if not name.is_empty() and result.save_png(output.path_join(name+".png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [name, output])
	return result
func click(point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	event.position=point*Vector2(root.size)/Vector2(640,360)
	Input.parse_input_event(event); await process_frame
	game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(point)))
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await process_frame
func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="pond21"
	game.set_process(false); game.set_physics_process(false); game.reset(false,"fish"); game.menu.close()
	game.set_physics_process(false); game.elapsed=2; game.notice_age=0
	for region in [Vector2(280,310),Vector2(670,310),Vector2(1080,330)]:
		game.fish=region; game.aim=Vector2.RIGHT
		await render("fish-"+str(int(region.x)))
	game.fish=Vector2(970,270); game.aim=Vector2.RIGHT
	for i in game.baits.size():
		var bait: Dictionary=game.baits[i]; bait.active=i!=2
		bait.pos=Vector2(895+i*45,230); bait.home=bait.pos
		for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
	var before: Dictionary=game.capture_snapshot()
	var visible:=await render("hidden-hook")
	game.baits[0].hook=false; game.baits[1].hook=true; game.rules.hook_scale=1.1
	var swapped:=await render()
	check(visible.get_data()==swapped.get_data(),"fish pixels contain no pre-bite hook, filament, glint or identity label")
	game.restore_snapshot(before)
	var stable:=await render()
	check(var_to_bytes(game.capture_snapshot())==var_to_bytes(before),"native drawing leaves the authoritative world unchanged")
	check(stable.get_data()==visible.get_data(),"fixed simulation tick renders identically")
	var screen:=Vector2(430,190); var point: Vector2=game.screen_to_game(screen)
	var motion:=InputEventMouseMotion.new()
	motion.position=screen*Vector2(root.size)/Vector2(640,360)
	motion.global_position=motion.position
	Input.parse_input_event(motion)
	await process_frame
	# Windows may deliver its current cursor after a synthetic motion in a hidden window.
	# Check the actual pointer consumed by production input against the camera transform.
	point=game.screen_to_game(game.get_global_mouse_position())
	var expected: Vector2=(point-game.fish).normalized()
	game._physics_process(1.0/60)
	check(game.aim.distance_to(expected)<0.001,"native mouse aiming uses the scrolled fish camera")
	game.set_physics_process(false)
	game._enter_hook(0); game._attach_hook()
	await render("hooked-fish")
	check(game.view.line_frame.path.size()>1,"line and escape feedback reappear once hooked")
	game.reset(false,"angler"); game.set_physics_process(false); game.menu.close(); game.notice_age=0
	game.angler.x=1054; game.fish=Vector2(1120,180); game.fish_before=game.fish
	await render("shore-far-bank")
	game.advance_tick({}, {"net_events":[{"kind":"toggle"}]})
	await render("observe-far-bank")
	var a:=Vector2(1070,180); var b:=Vector2(1170,180)
	var screen_a: Vector2=game.View.Camera.to_screen(a,game,"angler")
	await click(Vector2(70,85))
	check(not game.net_action.has_a,"observation HUD clicks remain blocked after camera scrolling")
	await click(screen_a)
	check(game.net_action.has_a and game.net_action.a.distance_to(a)<0.01,"native far-bank A click reaches exact world coordinates")
	var screen_b: Vector2=game.View.Camera.to_screen(b,game,"angler")
	await click(screen_b)
	check(game.net_state=="warning" and game.net_to.distance_to(b)<0.01,"native B click commits and restores the shore view")
	for i in 37: game.advance_tick({},{})
	await render("net-far-bank")
	check(game.net_state in ["sweep","caught"],"far-bank net animates in the first-person view")
	game.player_role="fish"; await render("net-fish-far-bank")
	print("POND_NATIVE_V021 | passed=",passed," | failed=",failed)
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
