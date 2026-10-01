extends SceneTree

# Reproducible visual fixtures; these do not modify the player's save or rules.
const Main = preload("res://scenes/main.tscn")
var game: Node2D
const OUTPUT := "res://artifacts/"

func _initialize() -> void: call_deferred("run")

func capture(tag: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT+"angler-"+tag+"-v0121.png")
	if error!=OK: push_error("Capture failed: "+tag); quit(1)
	print("ANGLER_VISUAL | ",tag)

func fresh() -> void:
	game.reset(true,"angler")
	game.set_process(false)
	game.set_physics_process(false)
	game.menu.hide()
	game.angler.x=320
	game.angler.previous_anchor=game.angler.anchor()
	game.elapsed=2
	game.fish=Vector2(363,170)
	game.baits[0].active=true
	game.baits[0].pos=Vector2(346,185)
	for grain in game.baits[0].grains: grain.pos=game.baits[0].pos+grain.offset

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="visual-angler"
	game.save_path="user://visual-angler-v0121.cfg"
	fresh()
	await capture("idle")
	for step in 8:
		game.angler.x+=1.2; game.elapsed+=1.0/60
		game.view.queue_redraw(); await process_frame
	await capture("walk")
	fresh()
	game._enter_hook(0); game._attach_hook(); game._step_line(0.01,false)
	game.tension=0.98; game.reel_speed=-30; game.angler.spool=-1
	await capture("loaded")
	game.player_role="fish"; game.shared_session=true
	await capture("fish-view")
	game.player_role="angler"; game.shared_session=false
	game.angler.net_held=true; game.angler.cursor=Vector2(440,120)
	game.begin_manual_net(Vector2(440,120)); game.net_age=0.6
	await capture("net")
	fresh()
	game.baits[0].active=false
	game.angler.casting=true; game.angler.cast_age=0.3
	game.angler.cast_from=game.angler.anchor(); game.angler.cast_to=Vector2(346,185)
	await capture("cast")
	for edge in [18,588]:
		fresh(); game.angler.x=edge
		await capture("edge-"+str(edge))
	game.queue_free()
	await process_frame
	quit()
