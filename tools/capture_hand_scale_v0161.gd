extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game:Node2D
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This capture needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func capture(label:String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/hand-scale-"+label+"-v0161.png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="hand-scale"; game.save_path="user://hand-scale-v0161.cfg"
	game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0
	game.baits[0].active=true; game.fish=Vector2(310,235); game._enter_hook(0); game._attach_hook()
	game.angler.reel_hand_amount=1
	for at in [18,280,588]:
		game.angler.x=at
		for mode in [-1,1]:
			game.angler.reel_hand_mode=mode; game.reel_speed=-36 if mode<0 else 90
			game.angler.reel_phase=PI/2; game.angler.release_phase=PI/2
			await capture("%s-%s" % [at,mode])
	game.angler.x=280; game.angler.reel_hand_mode=-1; game.reel_speed=-36
	game.view.scale=Vector2(2,2); game.view.position=Vector2(-540,-294)
	await capture("closeup")
	game.queue_free(); await process_frame; quit()
