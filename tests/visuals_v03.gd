extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var output := "E:/Fish_catches_people/BaitbreakPixel/artifacts"

func _initialize() -> void:
	call_deferred("run")

func capture(which: String) -> void:
	game._update_contacts(1)
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/"+which+"-v03.png")
	print("VISUAL | ",which," | error=",error)

func key_press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	game.capture_mode = "visual-test"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("title")
	game.menu.open("help")
	await capture("help")
	game.reset(false)
	game.fish = Vector2(338,239)
	game.aim = Vector2.RIGHT
	game._enter_hook(0)
	game._attach_hook()
	await capture("contact")
	var old: Vector2 = game.fish
	game.set_physics_process(true)
	await key_press(KEY_SPACE)
	game.set_physics_process(false)
	if not require(game.qte=="wrap" and game.fish==old,"Physical Space failed to open wrap QTE without moving fish"): return
	game.qte_age = 1.25
	await capture("wrap-qte")
	game.qte_age = 0.4+(game.qte_zone+0.07)*2
	game.set_physics_process(true)
	await key_press(KEY_SPACE)
	game.set_physics_process(false)
	if not require(game.wraps.size()==1 and game.winding(),"Physical Space white-zone hit failed to wind"): return
	game.step(0.17,Vector2.ZERO,false,false)
	await capture("wind-quarter")
	game.step(0.26,Vector2.ZERO,false,false)
	await capture("wind-half")
	game.step(0.5,Vector2.ZERO,false,false)
	await capture("wind-complete")
	if not require(not game.winding() and game.wraps.size()==1,"Winding animation failed to complete one persistent turn"): return
	game.step(0.55,Vector2.ZERO,false,false)
	await capture("slack-followup")
	if not require(game.qte=="slack","Successful winding did not offer the follow-up E QTE"): return
	game.set_physics_process(true)
	Input.action_press("left")
	old = game.fish
	await create_timer(0.15).timeout
	Input.action_release("left")
	if not require(game.fish.x<old.x,"Movement failed to unlock after winding"): return
	game.set_physics_process(false)
	game.reset(false)
	game.fish = Vector2(300,120)
	game.set_physics_process(true)
	old = game.fish
	await key_press(KEY_CTRL)
	await key_press(KEY_SPACE)
	if not require(game.fish==old,"Space or Ctrl still moves fish vertically"): return
	game.menu.open("pause")
	Input.action_press("right")
	await create_timer(0.15).timeout
	Input.action_release("right")
	if not require(game.fish==old,"Pause did not freeze swimming"): return
	game.menu.close()
	game.set_physics_process(false)
	var started := Time.get_ticks_msec()
	for frame in range(120):
		game.elapsed += 1.0/60
		game.view.queue_redraw()
		await process_frame
	print("RENDER_SAMPLE | 120 frames | elapsed_ms=",Time.get_ticks_msec()-started," | fps=",Engine.get_frames_per_second())
	print("NATIVE_WRAP_PASS | physical Space / Ctrl, winding, transparency, movement unlock, follow-up QTE and pause")
	game.queue_free()
	await create_timer(0.1).timeout
	quit()
