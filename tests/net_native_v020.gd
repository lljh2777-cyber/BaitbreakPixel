extends SceneTree
var output := "res://artifacts"
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed+=1; print("NET_NATIVE_PASS | ",text)
	else: failed+=1; push_error("NET_NATIVE_FAIL | "+text)
func frames() -> void:
	for i in 3: await process_frame
func capture(label: String) -> void:
	game.view.queue_redraw(); await frames(); await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join("net-"+label+"-v020.png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [label, output])
func flush() -> void:
	game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(game.get_global_mouse_position())))
func key_e() -> void:
	var event:=InputEventKey.new(); event.physical_keycode=KEY_E; event.pressed=true
	Input.parse_input_event(event); await process_frame; flush()
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await frames(); flush()
func click(point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point*Vector2(root.size)/Vector2(640,360); event.pressed=true
	Input.parse_input_event(event); await process_frame; flush()
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await frames(); flush()
func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="net-native"; game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.set_physics_process(false); game.menu.close(); game.fish=Vector2(280,170); game.baits[0].active=true
	await frames()
	await capture("shore")
	await key_e()
	check(game.net_action.observing,"real E press opens water view and release leaves it open")
	check(game.screen_to_game(Vector2(250,170))==Vector2(250,170),"observation coordinates exactly match fish space")
	await click(Vector2(70,85))
	check(not game.net_action.has_a,"clicks on tension HUD do not select a hidden start point")
	await click(Vector2(220,170))
	check(game.net_action.has_a and game.net_action.a.distance_to(Vector2(220,170))<0.1,"first native click selects A in world coordinates")
	Input.warp_mouse(Vector2(385,230)*Vector2(root.size)/Vector2(640,360)); await frames()
	await capture("observe-blocked")
	await click(Vector2(390,170))
	check(not game.net_action.observing and game.net_state=="warning","second native click commits and restores shore view")
	check(game.net_blocked and game.net_to.x<320,"wood clips the same preview and actual path")
	await capture("committed-shore")
	for i in 36: game.advance_tick({},{"reel":true})
	check(game.net_state=="sweep" and game.angler.spool==0,"net sweeps autonomously while hand is occupied")
	await capture("sweep-shore")
	game.player_role="fish"; await capture("sweep-fish")
	game.player_role="angler"
	for i in 300: game.advance_tick({},{})
	game.reset(false,"angler"); game.set_physics_process(false); game.menu.close(); game.fish=Vector2(280,170); game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	await key_e(); game.effort_checks.angler.wait=0
	for i in 5: game.advance_tick({},{"reel":true})
	await capture("observe-hooked")
	check(game.net_action.observing and game.angler.spool<0,"W works before commitment while hooked in observation")
	game.menu.open("rules"); await frames()
	var editor: Control=game.menu.rules_editor
	for index in editor.category_picker.item_count:
		if editor.category_picker.get_item_text(index)=="抄网": editor.category_picker.select(index); editor.category_picker.item_selected.emit(index)
	await capture("settings")
	check(editor.controls.has("net_observe_time") and not editor.controls.has("net_capture_base"),"settings show new rules without retired capture timer")
	print("NET_NATIVE_V020 | passed=",passed," | failed=",failed)
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
