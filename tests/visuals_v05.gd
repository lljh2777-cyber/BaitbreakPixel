extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var output := "res://artifacts"

func _initialize() -> void:
	call_deferred("run")

func capture(which: String) -> void:
	game._update_contacts(1)
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/"+which+"-v05.png")
	print("VISUAL | ",which," | error=",error)

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func press(code: Key) -> void:
	await key_event(code,true)
	await key_event(code,false)

func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	# OS input is in window pixels; the game viewport renders at half this size.
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func prepare_hook() -> void:
	game.reset(false)
	game.water_strength=1
	game.fish=Vector2(338,239)
	game.aim=Vector2.RIGHT
	game._enter_hook(0)
	game._attach_hook()
	game._update_contacts(1)

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
	game.menu.open("help")
	await capture("help")
	game.reset(false)
	await press(KEY_F2)
	if not require(game.menu.screen=="practice" and game.paused,"Physical F2 must open practice adjustment and pause play"): return
	await capture("practice-default")
	var sensitivity: HSlider=game.menu.content.find_child("LineSensitivity",true,false)
	var force: HSlider=game.menu.content.find_child("LineForce",true,false)
	await click_at(sensitivity.global_position+Vector2(sensitivity.size.x*0.75,8))
	await click_at(force.global_position+Vector2(force.size.x*0.2,8))
	print("NATIVE_TUNING | sensitivity=",game.practice_line_sensitivity," | force=",game.practice_line_force)
	if not require(game.practice_line_sensitivity>1.5 and game.practice_line_force<0.8,"Native slider clicks must change sensitivity and force separately"): return
	await capture("practice-adjusted")
	await click_at(game.menu.first_button.get_global_rect().get_center())
	if not require(game.line_tuning()==Vector2.ONE,"Native default button must reset both sliders"): return
	await press(KEY_ESCAPE)
	if not require(game.menu.screen=="pause","Esc from practice adjustment must return safely to pause"): return
	await press(KEY_ESCAPE)
	if not require(not game.paused and not game.menu.visible,"Esc from pause resumes the same practice round"): return
	game.fish=Vector2(200,184)
	game.aim=Vector2.RIGHT
	for frame in range(90): game.step(1.0/60,Vector2.ZERO,false,false)
	await capture("bait-water")
	prepare_hook()
	await capture("contact")
	game.set_physics_process(true)
	await press(KEY_SPACE)
	game.set_physics_process(false)
	if not require(game.qte=="wrap","Physical Space must start the wrap QTE"): return
	game.qte_age=0.18
	await capture("qte-ready")
	game.qte_age=1.2
	await capture("qte-trail")
	game.qte_age=0.4+(game.qte_zone+0.07)*2
	await capture("qte-green-zone")
	game.set_physics_process(true)
	await press(KEY_SPACE)
	game.set_physics_process(false)
	if not require(game.wraps.size()==1 and game.qte_result_good,"Green-zone Space must produce a winding and success response"): return
	game.step(0.15,Vector2.ZERO,false,false)
	await capture("qte-success")
	game.step(0.3,Vector2.ZERO,false,false)
	await capture("wind-half")
	game.step(0.6,Vector2.ZERO,false,false)
	await capture("wind-complete")
	game.step(0.5,Vector2.ZERO,false,false)
	await capture("slack")
	if not require(game.qte=="slack","Faster spool must still leave a playable slack check after winding"): return
	var side: Vector2=game.qte_origin
	game.fish.x=300
	if not require(game.qte_origin==side,"QTE card must not jump sides when the fish crosses the screen center"): return
	prepare_hook()
	game.set_physics_process(true)
	await press(KEY_SPACE)
	await press(KEY_SPACE)
	game.set_physics_process(false)
	if not require(game.qte_result_age>0 and not game.qte_result_good and game.wraps.is_empty(),"Early Space must show a failure response and retain the hook"): return
	game.step(0.15,Vector2.ZERO,false,false)
	await capture("qte-failure")
	game.reset(false)
	game.fish=Vector2(210,157)
	game._enter_hook(0)
	game.qte_age=1.5
	await capture("entry-hook")
	# Real held keys: no repeated press is sent while the simulation keeps running.
	game.reset(false)
	game.fish=Vector2(150,135)
	game.set_physics_process(true)
	await key_event(KEY_D,true)
	await key_event(KEY_SHIFT,true)
	await create_timer(1.3).timeout
	if not require(game.sprinting and game.velocity.x>135 and game.stamina<65,"Holding physical Shift must sustain speed and drain stamina"): return
	game.set_physics_process(false)
	await capture("sprint")
	game.set_physics_process(true)
	await key_event(KEY_SHIFT,false)
	await create_timer(0.35).timeout
	if not require(not game.sprinting and game.velocity.x<71,"Physical Shift release must return to normal speed"): return
	await key_event(KEY_D,false)
	await create_timer(0.3).timeout
	game.menu.open("pause")
	var old: Vector2=game.fish
	var energy: float=game.stamina
	var time: float=game.elapsed
	await key_event(KEY_SHIFT,true)
	await key_event(KEY_D,true)
	await create_timer(0.2).timeout
	if not require(game.fish==old and game.stamina==energy and game.elapsed==time,"Pause must freeze sprint, stamina and water"): return
	await key_event(KEY_SHIFT,false)
	await key_event(KEY_D,false)
	game.menu.close()
	game.set_physics_process(false)
	prepare_hook()
	game._begin_wrap()
	game.qte_age=0.5
	var started := Time.get_ticks_msec()
	for frame in range(120):
		game.elapsed+=1.0/60
		game.qte_age=0.4+fmod(frame/60.0,2)
		game.view.queue_redraw()
		await process_frame
	print("RENDER_SAMPLE | 120 frames with water and QTE | elapsed_ms=",Time.get_ticks_msec()-started," | fps=",Engine.get_frames_per_second())
	print("NATIVE_V05_PASS | F2, both slider clicks, defaults, escape navigation, held Shift, hook gauge success/failure and slack")
	game.queue_free()
	await create_timer(0.1).timeout
	quit()
