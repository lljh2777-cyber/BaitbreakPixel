extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Shore=preload("res://scripts/shore_view.gd")
var game: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("SHORE_NATIVE_PASS | ",message)
	else: failed+=1; push_error("SHORE_NATIVE_FAIL | "+message)
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func mouse(point: Vector2, pressed: bool=false, motion: bool=false) -> void:
	var event: InputEventMouse=InputEventMouseMotion.new() if motion else InputEventMouseButton.new()
	event.position=root.get_final_transform()*point; event.global_position=event.position
	if not motion: event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func capture(name: String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("E:/Fish_catches_people/BaitbreakPixel/artifacts/shore-"+name+"-v015.png")==OK,"capture "+name)
func tick(command: Dictionary, frames: int) -> void:
	for frame in frames: game.advance_tick({},command)
func run() -> void:
	game=Main.instantiate(); root.add_child(game); game.capture_mode="shore-test"
	game.save_path="user://shore-native-v015.cfg"; game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0
	game.fish=Vector2(390,205); game.fish_before=game.fish
	await capture("ready")
	key(KEY_Q,true); game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(Vector2(400,240)))); key(KEY_Q,false)
	tick({},50); await capture("float")
	check(Shore.rig_index(game)>=0,"physical Q deploys the rig in first-person view")
	var fixed_time:float=game.elapsed
	var background_before:Image=root.get_texture().get_image().get_region(Rect2i(20,238,185,60))
	var start_grip:Vector2=Shore.tackle_pose(game,fixed_time).hand.wrist
	var start: Vector2=game.angler.anchor(); key(KEY_D,true)
	for frame in 60: game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(Vector2(400,240))))
	key(KEY_D,false)
	check(game.angler.anchor().x>start.x+60 and game.angler.anchor().y==start.y,"physical D shifts only the horizontal rod position")
	check(Shore.tackle_pose(game,fixed_time).hand.wrist.x-start_grip.x>20,"physical D visibly carries the foreground hand across the picture")
	var after_time:float=game.elapsed
	game.elapsed=fixed_time
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	var background_after:Image=root.get_texture().get_image().get_region(Rect2i(20,238,185,60))
	check(background_before.get_data()==background_after.get_data(),"actual static underwater pixels do not scroll to fake hand movement")
	game.elapsed=after_time
	await capture("right")
	key(KEY_A,true)
	for frame in 150: game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(Vector2(400,180))))
	key(KEY_A,false); await capture("left")
	game.reset(false,"angler"); game.fish=Vector2(410,200); game.aim=Vector2.RIGHT; game.baits[0].active=true
	game._enter_hook(0); game._attach_hook(); game.tension=0.92; game.high_age=1.3; game.elapsed=2
	game.Effort.open(game.effort_checks.angler,game.rng); game.effort_checks.angler.age=1.1
	await capture("hooked-qte")
	check(game.view.world==game and game.effort_checks.angler.active,"first-person rendering uses live hooked world and its own QTE")
	game._clear_hook(); game.angler.x=450; game.fish=Vector2(70,110); game.fish_before=game.fish
	key(KEY_E,true)
	var route:=PackedVector2Array([Vector2(400,110),Vector2(520,110),Vector2(520,200),Vector2(400,200)])
	mouse(Shore.to_screen(route[0],game),true)
	for index in range(1,route.size()): mouse(Shore.to_screen(route[index],game),false,true)
	var command: Dictionary=game.local_input.angler_command(game,game.screen_to_game(Shore.to_screen(route[-1],game)))
	game.advance_tick({},command)
	var route_matches: bool=game.net_route.size()==route.size()
	if route_matches:
		for index in route.size(): route_matches=route_matches and game.net_route[index].distance_to(route[index])<0.01
	check(game.manual_net and route_matches,"screen-space native mouse turns become the exact original world-space net route")
	await capture("net-route")
	for frame in 300:
		if game.net_state=="sweep": break
		game._step_net(1.0/120)
	game._step_net(0.9); await capture("net-moving")
	check(game.net_pos.distance_to(Vector2(520,134))<0.1,"projected net still traverses its corner before the vertical leg")
	key(KEY_E,false); mouse(Shore.to_screen(route[-1],game),false)
	game.advance_tick({},game.local_input.angler_command(game,game.screen_to_game(Shore.to_screen(route[-1],game))))
	check(game.net_state=="withdraw","releasing E cancels from the new perspective")
	game.reset(false,"angler"); game.baits[0].active=true; game.fish=Vector2(240,40)
	game._enter_hook(0); game._attach_hook(); game.landing=true
	await capture("landing")
	game.reset(true,"fish"); game.fish=Vector2(250,170); game._enter_hook(0); game._attach_hook()
	await capture("fish-view")
	check(game.screen_to_game(Vector2(320,200))==Vector2(320,200),"fish view retains its original input and underwater coordinates")
	print("SHORE_NATIVE_V015_TESTS | passed=",passed," | failed=",failed)
	game.queue_free(); await process_frame; quit(1 if failed else 0)
