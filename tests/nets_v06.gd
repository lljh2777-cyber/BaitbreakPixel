extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var output := "E:/Fish_catches_people/BaitbreakPixel/artifacts"

func _initialize() -> void:
	call_deferred("run")

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/"+which+"-v06.png")
	print("VISUAL | ",which," | error=",error)

func tick(seconds: float, movement: Vector2=Vector2.ZERO) -> void:
	for frame in ceili(seconds*60): game.step(1.0/60,movement,false,false)

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

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func fresh(point: Vector2, count: int=0) -> void:
	game.reset(false)
	game.water_strength=1
	game.fish=point
	game.aim=Vector2.RIGHT
	game.net_count=count

func run() -> void:
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="net-visual"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("title")
	fresh(Vector2(66,265))
	await press(KEY_N)
	tick(1)
	await capture("net-starting-area")
	if not require(not game._net_contact(game.net_from) and game.net_to.distance_to(game.net_from)>30,"Starting-area practice net must enter clear of the bank rocks"): return
	fresh(Vector2(490,150))
	game.menu.open("pause")
	await capture("pause-net-button")
	var net_button: Button
	for candidate in game.menu.content.find_children("*","Button",true,false):
		if candidate.text.begins_with("抄网练习"): net_button=candidate
	if not require(is_instance_valid(net_button),"Practice pause must expose a net training button"): return
	await click_at(net_button.get_global_rect().get_center())
	if not require(not game.paused and game.net_queued,"Native net button must resume and queue an attack"): return
	tick(0.2)
	await capture("net-prepare")
	tick(0.8)
	if not require(game.net_state=="warning","Queued net must enter warning"): return
	await capture("net-sweep-warning")
	tick(1,Vector2.UP)
	tick(1.55)
	if not require(game.net_state=="sweep","Horizontal net should be visibly sweeping"): return
	await capture("net-sweep")
	tick(1.3)
	await capture("net-withdraw")
	tick(1)
	if not require(game.net_dodges==1 and game.net_catches==0,"Swimming up must evade the sweep"): return
	fresh(Vector2(490,150),1)
	await press(KEY_N)
	if not require(game.net_queued,"Physical N must queue a repeatable training attack"): return
	tick(1.1)
	await capture("net-drop-warning")
	tick(0.8,Vector2.RIGHT)
	tick(1.6)
	await capture("net-drop")
	tick(3)
	if not require(game.net_kind=="drop" and game.net_dodges==1 and game.net_catches==0,"Swimming sideways must evade the descending net"): return
	fresh(Vector2(490,150))
	game.score=12
	await press(KEY_N)
	for frame in range(360):
		tick(1.0/60)
		if game.net_state=="caught": break
	if not require(game.net_state=="caught","Remaining in the warned path should begin capture"): return
	tick(0.3)
	await capture("net-caught")
	game.menu.open("pause")
	var pos: Vector2=game.fish
	var age: float=game.net_age
	tick(1)
	if not require(game.fish==pos and game.net_age==age,"Pause must freeze net lift"): return
	game.menu.close()
	tick(1)
	await capture("net-practice-return")
	if not require(not game.lost and game.score==12 and game.fish.distance_to(game.HOME)<23,"Practice returns with food intact"): return
	fresh(Vector2(490,245))
	await press(KEY_N)
	tick(3.9)
	await capture("net-cover")
	if not require(game.net_blocked and game.net_catches==0,"Wood must stop the physical rim before it reaches the fish"): return
	fresh(Vector2(490,150))
	game.challenge=true
	game.request_net()
	tick(6)
	await capture("net-challenge-result")
	if not require(game.lost and game.reason=="net","Challenge still ends after capture"): return
	fresh(Vector2(490,100))
	game.net_kind="drop"
	game.net_from=Vector2(418,67)
	game.net_to=Vector2(490,200)
	game.net_state="sweep"
	var started := Time.get_ticks_msec()
	for frame in range(120):
		game.elapsed+=1.0/60
		game.net_age=fmod(frame/60.0,game.NET_SWEEP)
		game.net_pos=game.net_from.lerp(game.net_to,game.net_age/game.NET_SWEEP)
		game.view.queue_redraw()
		await process_frame
	print("RENDER_SAMPLE | net mesh and water | elapsed_ms=",Time.get_ticks_msec()-started," | fps=",Engine.get_frames_per_second())
	print("NATIVE_NET_V06_PASS | pause button, N, sweep, descent, warning, dodge, capture, cover and practice recovery")
	game.queue_free()
	await create_timer(0.1).timeout
	quit()
