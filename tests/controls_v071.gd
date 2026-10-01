extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var checks := 0
var output := "res://artifacts"

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error("NATIVE_CONTROLS_FAIL | "+message)
		quit(1)
	else:
		checks+=1
		print("NATIVE_PASS | ",message)
	return ok

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=button
	event.pressed=pressed
	event.position=root.get_final_transform()*Vector2(500,200)
	event.global_position=event.position
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output+"/"+which+"-v071.png")==OK,"capture "+which)

func fresh(point: Vector2) -> void:
	game.reset(false)
	game.fish=point
	game.aim=Vector2.RIGHT
	game.water_strength=0
	game.set_physics_process(true)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-output="): output=argument.trim_prefix("--visual-output=")
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="native-controls"
	game.set_process(false)
	fresh(Vector2(150,170))
	game._enter_hook(0)
	game.qte_age=0.4+(game.qte_zone+0.03)*2
	await key(KEY_E,true)
	await key(KEY_E,false)
	if not require(game.qte=="entry","physical E does not judge entry"): return
	game.set_physics_process(false)
	await capture("entry-space")
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	if not require(game.hooked==game.HookState.FREE,"physical Space ejects entry hook"): return
	game._enter_hook(0)
	game.qte_age=0.4+(game.qte_zone+0.03)*2
	for frame in range(4): await physics_frame
	if not require(game.qte=="entry","holding Space does not auto-judge a new QTE"): return
	await key(KEY_SPACE,false)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.hooked==game.HookState.FREE,"releasing and pressing Space judges the next QTE"): return
	fresh(Vector2(338,239))
	game._enter_hook(0)
	game._attach_hook()
	game.rope_length+=80
	for frame in range(40): await physics_frame
	if not require(game.qte=="slack" and game.contact_target>=0,"slack check appears while touching a wrappable object"): return
	game.qte_age=0.4+(game.qte_zone+0.02)*2
	await key(KEY_E,true)
	await key(KEY_E,false)
	if not require(game.qte=="slack","physical E does not judge slack"): return
	game.set_physics_process(false)
	await capture("slack-space")
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.hooked==game.HookState.FREE and game.wraps.is_empty(),"physical Space judges slack without accidentally starting wrap"): return
	fresh(Vector2(338,239))
	game._enter_hook(0)
	game._attach_hook()
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.qte=="wrap" and game.wraps.is_empty(),"first Space starts but does not consume wrap check"): return
	await mouse(MOUSE_BUTTON_RIGHT,true)
	await key(KEY_S,true)
	for frame in range(5): await physics_frame
	if not require(game.sprinting and game.qte=="wrap","right mouse sprint works during moving wrap QTE"): return
	game.qte_age=0.4+(game.qte_zone+0.03)*2
	game.set_physics_process(false)
	await capture("wrap-space")
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	await key(KEY_S,false)
	await mouse(MOUSE_BUTTON_RIGHT,false)
	if not require(game.wraps.size()==1 and game.winding(),"second physical Space completes wrap while sprinting"): return
	fresh(Vector2(100,120))
	await key(KEY_D,true)
	await key(KEY_SHIFT,true)
	for frame in range(18): await physics_frame
	if not require(not game.sprinting and game.stamina==100 and game.velocity.length()<=70.1,"Shift no longer activates sprint"): return
	await key(KEY_SHIFT,false)
	await mouse(MOUSE_BUTTON_RIGHT,true)
	for frame in range(45): await physics_frame
	if not require(game.sprinting and game.velocity.length()>135 and game.stamina<85,"holding right mouse keeps sprinting and drains stamina"): return
	await mouse(MOUSE_BUTTON_LEFT,true)
	for frame in range(4): await physics_frame
	if not require(game.sprinting and game.feeding,"left suction and right sprint work simultaneously"): return
	game.set_physics_process(false)
	await capture("right-sprint")
	game.set_physics_process(true)
	await mouse(MOUSE_BUTTON_RIGHT,false)
	for frame in range(17): await physics_frame
	if not require(not game.sprinting and game.feeding and game.velocity.length()<=70.1,"releasing right mouse ends sprint without stopping left suction"): return
	await mouse(MOUSE_BUTTON_LEFT,false)
	await key(KEY_D,false)
	for frame in range(20): await physics_frame
	var stamina: float=game.stamina
	await mouse(MOUSE_BUTTON_RIGHT,true)
	for frame in range(12): await physics_frame
	if not require(not game.sprinting and game.stamina>=stamina,"right mouse alone does not spend sprint stamina"): return
	await mouse(MOUSE_BUTTON_RIGHT,false)
	fresh(game.HOME)
	game.score=18
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(not game.returning,"Space does not return home"): return
	await key(KEY_E,true)
	await key(KEY_E,false)
	if not require(game.returning,"E still returns home"): return
	await key(KEY_H,true)
	await key(KEY_H,false)
	await capture("help-controls")
	print("NATIVE_CONTROLS_V071_PASS | checks=",checks)
	quit(0)
