extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: checks+=1; print("REEL_NATIVE_PASS | ",description)
	else: failures+=1; push_error("REEL_NATIVE_FAIL | "+description)
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
	await physics_frame
func capture(label: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("E:/Fish_catches_people/BaitbreakPixel/artifacts/reeling-"+label+"-v0122.png")==OK,"capture "+label)
func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="reeling-test"; game.set_process(false)
	game.save_path="user://reeling-native-v0122.cfg"
	game.reset(true,"angler"); game.set_physics_process(false)
	game.fish_brain.reset(2719); game.water_strength=0
	game.set_escape_timing(0.5,0.4,3)
	game.fish=Vector2(240,205); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	await capture("start")
	game.set_physics_process(true)
	await key(KEY_W,true)
	for frame in 118: await physics_frame
	game.set_physics_process(false)
	check(game.hooked==game.HookState.HOOKED and game.fish.y<170,"physical W draws the resisting AI fish toward shore")
	check(game.angler.spool<0 and game.tension>=0.9,"W command and real tension reach the live world")
	await capture("w-tight")
	await key(KEY_W,false); await key(KEY_S,true)
	game.set_physics_process(true)
	for frame in 60: await physics_frame
	game.set_physics_process(false)
	check(game.hooked==game.HookState.HOOKED and game.tension<0.89 and game.high_age==0,"physical S relieves high tension within one second against AI")
	check(game.angler.spool>0 and game.reel_speed>0,"S reverses the actual spool direction")
	await capture("s-release")
	game.set_physics_process(true)
	for frame in 38: await physics_frame
	game.set_physics_process(false)
	check(game.hooked==game.HookState.HOOKED and game.rope_length>game.line_anchor(0).distance_to(game.mouth())+10,"continued S creates visible slack before the fish's QTE resolves")
	await capture("s-slack")
	await key(KEY_S,false)
	game.set_physics_process(true)
	for frame in 10: await physics_frame
	check(is_zero_approx(game.reel_speed),"letting go brakes the spool promptly")
	print("REEL_NATIVE_V0122_TESTS | passed=",checks," | failed=",failures)
	game.queue_free(); await process_frame; quit(1 if failures else 0)
