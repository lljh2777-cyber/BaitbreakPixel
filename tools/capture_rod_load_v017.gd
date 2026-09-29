extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game:Node2D
func _initialize() -> void: call_deferred("run")
func capture(label:String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/Fish_catches_people/BaitbreakPixel/artifacts/rod-load-"+label+"-v017.png")
func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="rod-load"; game.save_path="user://rod-load-v017.cfg"
	game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0
	game.baits[0].active=true; game.fish=Vector2(280,235); game._enter_hook(0); game._attach_hook()
	game.angler.reel_hand_mode=-1; game.angler.reel_hand_amount=1; game.reel_speed=-36
	for at in [18,280,588]:
		game.angler.x=at; game.fish=Vector2(at,235)
		for load in [0.0,0.5,1.0]:
			game.tension=load; game.angler.rod_load=load; game.angler.rod_lift=load
			await capture("%s-%s" % [at,load])
	game.queue_free(); await process_frame; quit()
