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
	if ok: checks+=1; print("DUAL_NATIVE_PASS | ",message)
	else: failures += 1; push_error("DUAL_NATIVE_FAIL | "+message); DisplayServer.warp_mouse(original_mouse); quit(1)
	return ok

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func mouse(button: MouseButton, pressed: bool, point: Vector2) -> void:
	root.warp_mouse(point)
	await process_frame
	var motion:=InputEventMouseMotion.new()
	motion.position=root.get_final_transform()*point
	motion.global_position=motion.position
	Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new()
	event.button_index=button
	event.pressed=pressed
	event.position=motion.position
	event.global_position=event.position
	Input.parse_input_event(event)
	await physics_frame
	await process_frame

func capture(which: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output+"/"+which+"-v09.png")==OK,"capture "+which)

func click_button(prefix: String) -> bool:
	for child in game.menu.content.find_children("*","Button",true,false):
		if child.text.begins_with(prefix):
			var point: Vector2=child.get_global_rect().get_center()
			await mouse(MOUSE_BUTTON_LEFT,true,point)
			await mouse(MOUSE_BUTTON_LEFT,false,point)
			return true
	return require(false,"missing button: "+prefix)

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	original_mouse=DisplayServer.mouse_get_position()
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="dual-native"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("dual-title")
	if not await click_button("钓鱼人挑战"): return
	if not require(game.player_role=="angler" and not game.paused,"title button enters human challenge"): return
	game.set_physics_process(true)
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(180,110))
	var clicked: Vector2=game.get_global_mouse_position()
	await mouse(MOUSE_BUTTON_LEFT,false,Vector2(180,110))
	if not require(game.angler.casting,"physical left click casts bait"): return
	game.set_physics_process(false)
	for frame in 18: game.controlled_step(1.0/60,{})
	await capture("angler-cast")
	game.set_physics_process(true)
	for frame in 40: await physics_frame
	if not require(game.baits[0].active and game.baits[0].home.distance_to(clicked)<2,"cast lands at mouse position sampled on press"): return
	var start: float=game.angler.x
	var fish_start: Vector2=game.fish
	await key(KEY_D,true)
	for frame in 20: await physics_frame
	await key(KEY_D,false)
	if not require(game.angler.x>start+15 and game.fish.distance_to(fish_start)>10,"D walks angler while fish AI continues moving"): return
	await key(KEY_E,true)
	await key(KEY_E,false)
	if not require(not game.baits[0].active,"physical E retrieves bait"): return
	await key(KEY_H,true)
	await key(KEY_H,false)
	if not require(game.menu.screen=="help" and game.paused,"H opens role-specific help"): return
	await capture("angler-help")
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	game.menu.close()
	game.set_physics_process(false)
	game.reset(true,"angler")
	game.fish=Vector2(230,170)
	game.baits[0].active=true
	game._enter_hook(0)
	game._attach_hook()
	game.set_physics_process(true)
	await mouse(MOUSE_BUTTON_RIGHT,true,Vector2(240,150))
	for frame in 12: await physics_frame
	if not require(game.reel_speed<0,"physical right hold reels attached fish"): return
	await mouse(MOUSE_BUTTON_RIGHT,false,Vector2(240,150))
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(240,150))
	for frame in 24: await physics_frame
	if not require(game.reel_speed>0 and not game.angler.casting,"physical left hold releases line instead of recasting"): return
	await mouse(MOUSE_BUTTON_LEFT,false,Vector2(240,150))
	game.set_physics_process(false)
	game.tension=0.71
	await capture("angler-fight")
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.net_state=="prepare","physical Space deploys aimed net during fight"): return
	game.set_physics_process(false)
	for frame in 72: game.controlled_step(1.0/60,{})
	await capture("angler-net")
	game.menu.open("pause")
	var time_before: float=game.clock
	game.set_physics_process(true)
	for frame in 5: await physics_frame
	if not require(game.clock==time_before,"pause stops live human and AI inputs"): return
	game.menu.close()
	await key(KEY_R,true)
	await key(KEY_R,false)
	if not require(game.player_role=="angler" and not game.baits[0].active and game.net_state=="wait","R restarts current role and clears net/cast state"): return
	game.set_physics_process(false)
	game.finish(false,"net")
	await capture("angler-victory")
	if not await click_button("再来一局"): return
	if not require(game.player_role=="angler" and not game.won,"result retry preserves selected role"): return
	game.finish(true,"home")
	await capture("angler-defeat")
	if not await click_button("返回标题"): return
	if not await click_button("小鱼挑战"): return
	if not require(game.player_role=="fish" and game.challenge,"fish challenge remains available from same title"): return
	game.fish=Vector2(192,160)
	game._enter_hook(0)
	game.qte_age=1.3
	await capture("fish-qte")
	game.set_physics_process(true)
	game.qte_age=0.4+(game.qte_zone+0.05)*2
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.hooked==game.HookState.FREE and game.net_state=="wait","fish Space still judges QTE instead of deploying angler net"): return
	print("DUAL_NATIVE_TESTS | passed=",checks)
	game.queue_free()
	await process_frame
	DisplayServer.warp_mouse(original_mouse)
	quit(1 if failures else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-output="):
			output = argument.trim_prefix("--visual-output=")
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
