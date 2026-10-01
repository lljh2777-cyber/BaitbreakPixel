extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var frame := 0
var done := false

func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="hand-motion"; game.save_path="user://hand-motion-v0159.cfg"
	game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0
	game.angler.x=18; game.fish=Vector2(440,240)
	game.break_hold_seconds=10; game.slack_hold_seconds=3

func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or done: return false
	var command := {"walk":0.0}
	var fish_command := {}
	if frame==30: command.deploy=true
	if frame>=60 and frame<540: command.walk=1.0
	elif frame>=600 and frame<1080: command.walk=-1.0
	elif frame>=1080 and frame<1236: command.walk=1.0
	if frame==1296:
		game.fish=Vector2(320,220); game._enter_hook(0); game._attach_hook()
	if frame>=1296:
		command.reel=frame<1416; command.release=frame>=1416
		fish_command={"move":Vector2.DOWN,"dash":true}
	game.advance_tick(fish_command,command)
	game.view.queue_redraw()
	if frame in [60,220,380,535,700,860,1075,1236,1390,1490]: snapshot(frame)
	frame+=1
	if frame>=1536:
		done=true; finish()
	return false

func snapshot(index: int) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/hand-motion-%04d-v0159.png" % index
	print("MOTION_FRAME | ",index," | ",root.get_texture().get_image().save_png(path))

func finish() -> void:
	await RenderingServer.frame_post_draw
	print("HAND_MOTION_CAPTURE | frames=",frame," | fixed_fps=60")
	game.queue_free(); await process_frame; quit()
