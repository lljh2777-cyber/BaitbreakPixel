extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var checks:=0
var original_mouse:=Vector2i.ZERO
var output:="E:/Fish_catches_people/BaitbreakPixel/artifacts"

func _initialize() -> void: call_deferred("run")
func require(ok: bool, message: String) -> bool:
	if ok: checks+=1; print("RIG_NATIVE_PASS | ",message)
	else: push_error("RIG_NATIVE_FAIL | "+message); DisplayServer.warp_mouse(original_mouse); quit(1)
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
	if game.player_role=="angler" and not game.menu.visible: point=game.view.Shore.to_screen(point)
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
	require(root.get_texture().get_image().save_png(output+"/"+which+"-v0101.png")==OK,"capture "+which)

func click_button(prefix: String) -> bool:
	for child in game.menu.content.find_children("*","Button",true,false):
		if child.text.begins_with(prefix):
			var point: Vector2=child.get_global_rect().get_center()
			await mouse(MOUSE_BUTTON_LEFT,true,point)
			await mouse(MOUSE_BUTTON_LEFT,false,point)
			return true
	return require(false,"missing button "+prefix)

func run() -> void:
	original_mouse=DisplayServer.mouse_get_position()
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="native-v010"
	game.save_path="user://angler-native-v010.cfg"
	game.set_process(false)
	game.set_physics_process(false)
	await capture("title")
	if not await click_button("钓鱼人挑战"): return
	game.set_physics_process(true)
	game.fish=Vector2(590,100)
	await key(KEY_Q,true)
	await key(KEY_Q,false)
	if not require(game.angler.casting,"physical Q starts lowering a baited hook"): return
	for frame in 48: await physics_frame
	if not require(game.baits[0].active,"deployed rig reaches water"): return
	var length_before: float=game.angler.free_line_length
	await key(KEY_W,true)
	for frame in 20: await physics_frame
	await key(KEY_W,false)
	if not require(game.angler.free_line_length<length_before-4,"physical W reels free line"): return
	length_before=game.angler.free_line_length
	await key(KEY_S,true)
	for frame in 45: await physics_frame
	await key(KEY_S,false)
	if not require(game.angler.free_line_length>length_before+5,"physical S pays out free line"): return
	await key(KEY_D,true)
	for frame in 35: await physics_frame
	await key(KEY_D,false)
	if not require(game.baits[0].pos.x<game.angler.anchor().x-5 and game.angler.hook_velocity.x>1,"physical bank movement creates trailing inertial rig"): return
	game.set_physics_process(false)
	await capture("inertial-hook")
	game.set_physics_process(true)
	await key(KEY_H,true)
	await key(KEY_H,false)
	await capture("human-help")
	game.menu.close()
	await key(KEY_F3,true)
	await key(KEY_F3,false)
	if not require(game.menu.screen=="timing" and game.paused,"F3 opens timing controls in challenge"): return
	for name in ["SlackHold","MouthWindow","BreakHold"]:
		var slider: HSlider=game.menu.content.find_child(name,true,false)
		if not require(is_instance_valid(slider),"timing slider "+name+" exists"): return
		var old: float=slider.value
		var point: Vector2=slider.global_position+Vector2(slider.size.x*0.74,slider.size.y/2)
		await mouse(MOUSE_BUTTON_LEFT,true,point)
		await mouse(MOUSE_BUTTON_LEFT,false,point)
		if not require(slider.value>old,"native click changes "+name): return
	await capture("timing-panel")
	var configured: float=game.break_hold_seconds
	if not await click_button("保存并返回"): return
	game.set_escape_timing(0.5,0.4,3)
	game._load_profile()
	if not require(is_equal_approx(configured,game.break_hold_seconds),"saved timing settings survive reload"): return
	game.menu.close()
	game.reset(true,"angler")
	game.set_escape_timing(0.5,0.4,3)
	game.fish=Vector2(60,275)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.net_state=="wait","human Space no longer triggers net"): return
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(232,160))
	for frame in 5: await physics_frame
	if not require(game.net_state=="wait" and not game.angler.casting,"left mouse alone no longer throws bait"): return
	await mouse(MOUSE_BUTTON_LEFT,false,Vector2(232,160))
	await key(KEY_E,true)
	if not require(game.angler.net_held and game.net_state=="wait","holding E arms net without a stroke"): return
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(337,260))
	if not require(game.net_state=="wait" and game.angler.net_cooldown==0,"clicking wood neither spawns a net nor spends cooldown"): return
	await mouse(MOUSE_BUTTON_LEFT,false,Vector2(337,260))
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(480,140))
	if not require(game.net_state=="prepare","E and left mouse begin manual net entry"): return
	if not require(game.net_pos.distance_to(game.manual_net_target(game.screen_to_game(game.get_global_mouse_position())))<1 and game.net_pos.distance_to(game.angler.anchor())>230,"native underwater click becomes the actual net start beyond shore reach"): return
	game.set_physics_process(false)
	await capture("underwater-net-entry")
	game.set_physics_process(true)
	for frame in 104: await physics_frame
	if not require(game.net_state=="sweep","holding the gesture reaches sweep"): return
	var net_before: Vector2=game.net_pos
	await mouse(MOUSE_BUTTON_LEFT,true,Vector2(555,145))
	for frame in 20: await physics_frame
	if not require(game.net_pos.x>net_before.x+10,"moving held mouse redirects live net"): return
	game.set_physics_process(false)
	await capture("drag-net")
	game.set_physics_process(true)
	await key(KEY_E,false)
	if not require(game.net_state=="withdraw","releasing E cancels while left mouse remains held"): return
	await mouse(MOUSE_BUTTON_LEFT,false,Vector2(555,145))
	game.set_physics_process(false)
	await capture("cancel-net")
	game.set_physics_process(true)
	await key(KEY_R,true)
	await key(KEY_R,false)
	if not require(game.player_role=="angler" and not game.manual_net and game.angler.hook_velocity==Vector2.ZERO,"R clears manual net and inertia while retaining human role"): return
	game.set_physics_process(false)
	game.fish=Vector2(230,160)
	game.baits[0].active=true
	game._enter_hook(0)
	game._attach_hook()
	game.set_physics_process(true)
	await key(KEY_W,true)
	for frame in 15: await physics_frame
	if not require(game.reel_speed<0,"physical W reels an attached fish"): return
	await key(KEY_W,false)
	await key(KEY_S,true)
	for frame in 30: await physics_frame
	if not require(game.reel_speed>0,"physical S pays out to an attached fish"): return
	await key(KEY_S,false)
	game.menu.open("title")
	game.set_physics_process(false)
	if not await click_button("小鱼挑战"): return
	game.set_escape_timing(0.5,0.8,4)
	game.fish=Vector2(192,160)
	game._enter_hook(0)
	game.qte_age=0.4+(game.qte_zone+0.25)*2
	await capture("wide-mouth-qte")
	game.set_physics_process(true)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	if not require(game.hooked==game.HookState.FREE,"fish Space succeeds within the widened visual QTE window"): return
	print("ANGLER_NATIVE_V010_TESTS | passed=",checks)
	game.queue_free()
	await process_frame
	DisplayServer.warp_mouse(original_mouse)
	quit()
