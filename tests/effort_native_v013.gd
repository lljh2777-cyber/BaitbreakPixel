extends SceneTree
var output := "res://artifacts"
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var seen: Array[String]=[]
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("EFFORT_NATIVE_PASS | ",description)
	else: failed+=1; push_error("EFFORT_NATIVE_FAIL | "+description)
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func tick(frames: int, role: String) -> void:
	for frame in frames:
		var fish_input: Dictionary=game.local_input.fish_command(game,Vector2(440,235)) if role=="fish" else {"move":Vector2.DOWN}
		var angler_input: Dictionary=game.local_input.angler_command(game,Vector2(440,120)) if role=="angler" else {"reel":true}
		game.advance_tick(fish_input,angler_input)
func capture(name: String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/effort-"+name+"-v013.png")==OK,"capture "+name)
func fresh(role: String) -> void:
	game.reset(true,"angler"); game.player_role=role
	game.menu.close(); game.set_process(false); game.set_physics_process(false)
	game.fish=Vector2(260,205); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game.water_strength=0
	game._enter_hook(0); game._attach_hook(); seen.clear()
func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="effort-test"; game.save_path="user://effort-native-v013.cfg"
	game.feedback_requested.connect(func(cue: String): seen.append(cue))
	for role in ["angler","fish"]:
		fresh(role)
		await key(KEY_W if role=="angler" else KEY_S,true)
		game.effort_checks[role].wait=0.0
		await tick(1,role)
		check(game.effort_checks[role].active and seen.has("qte_"+role),role+" keyboard effort starts with its own cue")
		check(game.sound.cues.qte.get_length()<0.4,"warning sound finishes before the ring sweep starts")
		await capture(role+"-warning")
		var state: Dictionary=game.effort_checks[role]
		state.age=0.4+(state.zone+state.width*0.5)*2-1.0/60
		await capture(role+"-ring")
		await key(KEY_SPACE,true)
		await tick(1,role)
		check(state.good and not state.active and state.effect_age>1.9,role+" physical Space judges its own random green zone")
		await key(KEY_SPACE,false)
		await capture(role+"-success")
		await key(KEY_W if role=="angler" else KEY_S,false)
		state.result_age=0; await capture(role+"-boost")
		game.Effort.reset(state); game.Effort.open(state,game.rng)
		state.age=0.1; await key(KEY_SPACE,true); await tick(1,role); await key(KEY_SPACE,false)
		check(state.active and state.result_age==0 and state.multiplier==1.0,role+" warning-period Space leaves the hidden timing check active")
		await process_frame
		state.age=state.lead+0.02; await key(KEY_SPACE,true); await tick(1,role); await key(KEY_SPACE,false)
		check(not state.good and state.multiplier==0.6,role+" visible off-zone Space briefly weakens the correct side")
		await capture(role+"-failure")
	fresh("fish"); game._open_qte("wrap"); game.qte_age=0.6
	await capture("wrap-random")
	game._open_qte("entry"); await capture("entry-warning")
	game.qte_age=0.8; await capture("entry-random")
	# Role routing must not make an AI/opponent warning sound like a local check.
	game.player_role="angler"
	var voice: int=game.sound.next_voice
	game.play_feedback("qte_fish")
	check(game.sound.next_voice==voice,"opponent cue is not played as the local player's check")
	game.play_feedback("qte_angler")
	check(game.sound.next_voice!=voice,"local cue reaches an actual audio player")
	print("EFFORT_NATIVE_V013_TESTS | passed=",passed," | failed=",failed)
	game.queue_free(); await process_frame; quit(1 if failed else 0)

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
