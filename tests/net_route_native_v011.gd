extends SceneTree
var failures := 0

const Main=preload("res://scenes/main.tscn")
var game: Node2D
var checks:=0
var original_mouse:=Vector2i.ZERO
var output:="res://artifacts"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func require(ok: bool, message: String) -> bool:
	if ok: checks+=1; print("ROUTE_NATIVE_PASS | ",message)
	else:
		push_error("ROUTE_NATIVE_FAIL | "+message)
		DisplayServer.warp_mouse(original_mouse)
		failures += 1
		quit(1)
	return ok

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(point: Vector2) -> void:
	if game.player_role=="angler": point=game.view.Shore.to_screen(point)
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	Input.parse_input_event(event)

func mouse(pressed: bool, point: Vector2) -> void:
	if game.player_role=="angler": point=game.view.Shore.to_screen(point)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output+"/"+which+"-v011.png")==OK,"capture "+which)

func flush_command(point: Vector2) -> void:
	game.advance_tick({},game.local_input.angler_command(game,point))

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	original_mouse=DisplayServer.mouse_get_position()
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="native-route"
	game.save_path="user://net-route-native-v011.cfg"
	game.set_process(false)
	game.reset(true,"angler")
	game.water_strength=0
	game.fish=Vector2(60,275)
	key(KEY_E,true)
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	if not require(game.angler.net_held and not Input.use_accumulated_input,"actual E input arms net with unmerged mouse events"): return
	var route:=PackedVector2Array([Vector2(425,110),Vector2(540,110),Vector2(540,200),Vector2(425,200),Vector2(425,110)])
	motion(route[0]); mouse(true,route[0])
	if not require(not game.manual_net and not game.local_input.net_events.is_empty(),"native mouse input queues commands without writing world state"): return
	for index in range(1,route.size()): motion(route[index])
	Input.flush_buffered_events()
	flush_command(route[-1])
	if not require(game.manual_net and game.net_from.distance_to(route[0])<0.01,"authority tick creates net at viewport-correct first click position"): return
	var same_route: bool=game.net_route.size()==route.size()
	if same_route:
		for index in route.size(): same_route=same_route and game.net_route[index].distance_to(route[index])<0.01
	if not require(same_route,"multiple mouse turns in a single frame retain their original order and coordinates"): return
	if not require(game.net_state=="prepare" and game.net_pos.distance_to(route[0])<0.01,"drawing during entry does not move the net prematurely"): return
	await capture("queued-loop")
	for frame in 180:
		if game.net_state=="sweep": break
		game._step_net(1.0/120)
	for frame in 105: game._step_net(1.0/120)
	if not require(game.net_pos.distance_to(Vector2(540,135))<0.05,"real input loop plays back through the first corner before the next leg"): return
	await capture("following-loop")
	var before: Vector2=game.net_pos
	key(KEY_E,false)
	if not require(game.net_state=="sweep" and game.net_pos==before,"release event leaves world unchanged until authority tick"): return
	flush_command(route[-1])
	if not require(game.net_state=="withdraw" and game.net_catches==0,"next authority tick cancels before any further sweep or capture"): return
	var pending: PackedVector2Array=game.net_route.duplicate()
	motion(Vector2(580,260)); Input.flush_buffered_events()
	if not require(game.net_route==pending,"motion after E release does not extend the route"): return
	mouse(false,Vector2(580,260))
	game.reset(true,"angler")
	game.fish=Vector2(60,275)
	game.fish_before=game.fish
	key(KEY_E,true)
	motion(route[0]); mouse(true,route[0])
	motion(route[1]); Input.flush_buffered_events()
	mouse(false,route[1])
	flush_command(route[1])
	if not require(game.net_state=="withdraw" and game.net_catches==0,"same-frame click, turns and release cancel in their original order"): return
	key(KEY_E,false)
	game.reset(true,"angler")
	game.fish=Vector2(60,275)
	game.fish_before=game.fish
	key(KEY_E,true); motion(route[0]); mouse(true,route[0]); motion(route[1]); Input.flush_buffered_events()
	flush_command(route[1])
	game.menu.open("pause")
	var saved: PackedVector2Array=game.net_route.duplicate()
	motion(route[2]); Input.flush_buffered_events()
	if not require(game.net_route==saved and game.local_input.needs_neutral,"paused mouse motion cannot alter a pending route"): return
	game.menu.close()
	motion(route[3]); Input.flush_buffered_events()
	flush_command(route[3])
	if not require(game.net_route==saved,"resuming with held controls cannot restart or extend the cancelled gesture"): return
	key(KEY_E,false); mouse(false,route[3])
	print("NET_ROUTE_NATIVE_V011_TESTS | passed=",checks)
	game.queue_free()
	await process_frame
	DisplayServer.warp_mouse(original_mouse)
	quit(1 if failures else 0)

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
