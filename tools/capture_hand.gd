extends SceneTree

const Main=preload("res://scenes/main.tscn")
var game: Node2D

func _initialize() -> void: call_deferred("run")

func capture(label: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "E:/Fish_catches_people/BaitbreakPixel/artifacts/hand-"+label+"-v0159.png"
	var result := root.get_texture().get_image().save_png(path)
	print("HAND_CAPTURE | ",label," | ",result)
	if result!=OK: quit(1)

func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	game.save_path="user://hand-preview-v0159.cfg"
	game.capture_mode="hand-preview"; game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0
	game.baits[0].active=true; game.baits[0].pos=Vector2(232,180); game.fish=Vector2(380,200)
	await capture("rest")
	var pixels: Image=game.view.shore.hand.pixel_texture.get_image()
	var colors := {}; var fractional_alpha := 0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var color := pixels.get_pixel(x,y)
			if color.a>0: colors[color.to_rgba32()]=true
			if color.a>0 and color.a<1: fractional_alpha+=1
	print("HAND_PIXELS | size=",pixels.get_size()," | colors=",colors.size()," | fractional_alpha=",fractional_alpha)
	game.view.scale=Vector2(2,2); game.view.position=Vector2(-660,-330)
	await capture("closeup")
	game.view.scale=Vector2.ONE; game.view.position=Vector2.ZERO
	game.angler.x=18
	await capture("left-limit")
	game.angler.x=588
	await capture("right-limit")
	game.angler.x=220; game._enter_hook(0); game._attach_hook(); game.tension=0.95; game.reel_speed=-36
	game.elapsed=1.1
	await capture("reeling")
	game.elapsed=1.5
	await capture("reeling-later")
	game.reel_speed=90
	await capture("release")
	game.queue_free(); await process_frame; quit()
