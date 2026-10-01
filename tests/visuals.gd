extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var output := "res://artifacts"

func _initialize() -> void:
	call_deferred("run")

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/"+which+".png")
	print("VISUAL | ",which," | error=",error)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game = Main.instantiate()
	root.add_child(game)
	game.capture_mode = "visual-test"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("title-final")
	var click := InputEventMouseButton.new()
	click.position = game.menu.first_button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	await process_frame
	if game.menu.visible or not game.challenge:
		push_error("Native title mouse click failed")
		quit(1)
		return
	print("NATIVE_UI_PASS | mouse click starts challenge")
	game.menu.open("title")
	game.menu.open("help")
	await capture("help")
	game.menu.open("settings")
	await capture("settings")
	game.reset(true)
	game.fish = Vector2(380,274)
	game.aim = Vector2.RIGHT
	game._enter_hook(0)
	game._attach_hook()
	game._step_line(0.01,false)
	await capture("root-line")
	game.fish = Vector2(380,250)
	game.rope_length += 15
	game._step_line(0.6,false)
	game.qte_age = 1.3
	await capture("slack-ring")
	game.reset(true)
	game.score = 60
	game.elapsed = 143
	game.reason = "home"
	game.won = true
	game.menu.open("result")
	await capture("win")
	game.won = false
	game.lost = true
	game.reason = "landed"
	game.menu.open("result")
	await capture("loss")
	game.reset(true)
	var old: Vector2 = game.fish
	game.set_physics_process(true)
	Input.action_press("right")
	await create_timer(0.35).timeout
	Input.action_release("right")
	if game.fish.x <= old.x:
		push_error("Native scheduled physics input failed")
		quit(1)
		return
	game.menu.open("pause")
	old = game.fish
	Input.action_press("right")
	await create_timer(0.15).timeout
	Input.action_release("right")
	if game.fish != old:
		push_error("Native pause failed")
		quit(1)
		return
	game.menu.close()
	game.sound.play("win")
	await create_timer(0.7).timeout
	var render_start := Time.get_ticks_msec()
	for frame in range(120):
		game.elapsed += 1.0/60
		game.view.queue_redraw()
		await process_frame
	print("RENDER_SAMPLE | 120 animated frames | elapsed_ms=",Time.get_ticks_msec()-render_start," | reported_fps=",Engine.get_frames_per_second())
	print("NATIVE_PASS | scheduled movement, pause, menus, graphics and audio cue completed")
	game.queue_free()
	await create_timer(0.1).timeout
	quit()
