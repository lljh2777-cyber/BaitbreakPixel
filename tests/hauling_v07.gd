extends SceneTree

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
		push_error("NATIVE_V07_FAIL | "+message)
		quit(1)
	else:
		checks+=1
		print("NATIVE_PASS | ",message)
	return ok

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/"+which+"-v07.png")
	require(error==OK,"capture "+which)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func tick(seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	for frame in ceili(seconds*60): game.step(1.0/60,movement,false,false)

func hook(point: Vector2, challenge: bool = false) -> void:
	game.reset(challenge)
	game.water_strength=1
	game.fish=point
	game.aim=Vector2.RIGHT
	game._enter_hook(0)
	game._attach_hook()
	game._update_contacts(1)

func hold_input(place: Vector2) -> Vector2:
	return ((place-game.fish)*5-game.line_pull_velocity()-game.water_velocity(game.fish))/70/game.vegetation_drag(game.fish)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-output="): output=argument.trim_prefix("--visual-output=")
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="visual-test"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("title")
	hook(Vector2(338,239))
	# Exercise the real registered input actions, including movement during Space's QTE.
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.qte=="wrap","physical Space starts wrap"): return
	var before: Vector2=game.fish
	await key(KEY_S,true)
	for frame in range(8): await physics_frame
	await key(KEY_S,false)
	game.set_physics_process(false)
	if not require(game.fish.y>before.y and game.qte=="wrap","physical S moves fish against pull during QTE"): return
	var point: Vector2=game.fish
	for frame in range(160):
		if game.qte_progress()>=game.qte_zone+0.05 or game.qte!="wrap": break
		game.step(1.0/60,hold_input(point),false,false)
	if not require(game.qte=="wrap" and game.resisting,"contact held by swimming through the full countdown"): return
	await capture("moving-wrap")
	# Press the physical judgment key with movement still held.
	game.set_physics_process(true)
	await key(KEY_S,true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	await key(KEY_S,false)
	game.set_physics_process(false)
	if not require(game.winding() and game.wraps.size()==1,"physical Space wins moving wrap"): return
	tick(0.4,Vector2.LEFT)
	await capture("moving-winding")
	for frame in range(260):
		if game.hooked!=game.HookState.HOOKED: break
		var movement: Vector2=hold_input(Vector2(game.wraps[-1].entry)-game.aim*10)
		if game.qte=="slack" and game.qte_progress()>=game.qte_zone+0.05: break
		game.step(1.0/60,movement,false,false)
	if not require(game.qte=="slack" and game.tension<0.25,"moving back to coil creates playable E opportunity"): return
	await capture("moving-slack")
	game.set_physics_process(true)
	await key(KEY_E,true)
	await key(KEY_E,false)
	game.set_physics_process(false)
	if not require(game.hooked==game.HookState.FREE,"physical E ejects after moving wrap"): return
	hook(Vector2(280,220),true)
	tick(2)
	await capture("hauling")
	for frame in range(1200):
		game.step(1.0/60,Vector2.ZERO,false,false)
		if game.landing: break
	if not require(game.landing,"idle fish reaches landing threshold"): return
	tick(0.65)
	await capture("lift")
	game.set_physics_process(true)
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	game.set_physics_process(false)
	before=game.fish
	tick(1)
	if not require(game.menu.visible and game.fish==before,"physical Esc pauses lift"): return
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	tick(1)
	if not require(game.lost and game.reason=="landed","challenge shows caught result"): return
	await capture("landed-result")
	game.reset(false)
	await key(KEY_F2,true)
	await key(KEY_F2,false)
	if not require(game.menu.screen=="practice" and game.paused,"physical F2 opens hauling controls"): return
	await capture("practice-settings")
	game.menu.close()
	await key(KEY_H,true)
	await key(KEY_H,false)
	if not require(game.menu.screen=="help" and game.paused,"physical H opens current rules"): return
	await capture("help")
	game.menu.close()
	hook(Vector2(350,210))
	game.stamina=12
	tick(0.7,Vector2.DOWN)
	await capture("exhausted")
	print("NATIVE_HAUL_V07_PASS | checks=",checks)
	quit(0)
