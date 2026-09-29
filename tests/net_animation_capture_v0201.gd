extends SceneTree

const Main=preload("res://scenes/main.tscn")
var game: Node2D
const DIRECTORY="res://artifacts/net-animation-v0201"

func _initialize() -> void: call_deferred("run")

func frame(path: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var ignore:=FileAccess.open(DIRECTORY.path_join(".gdignore"),FileAccess.WRITE)
	ignore.close()
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="net-animation"; game.set_process(false); game.set_physics_process(false)
	for i in 4: await process_frame
	for scenario in ["empty","catch","blocked"]:
		game.reset(false,"angler"); game.set_physics_process(false); game.menu.close()
		game.rules.water_strength=0; game.rules.net_reach=620; game.rules.net_sight=680
		game.fish=Vector2(260,140) if scenario=="catch" else Vector2(480,130)
		game.fish_before=game.fish
		var a:=Vector2(230,210) if scenario=="blocked" else Vector2(210,140)
		var b:=Vector2(420,210) if scenario=="blocked" else Vector2(310,140)
		game.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":a},{"kind":"point","point":b}]})
		var index:=0
		while game.net_active() and index<240:
			game.advance_tick({},{})
			if index%2==0:
				for role in ["angler","fish"]:
					game.player_role=role
					await frame(DIRECTORY.path_join("%s-%s-%03d.png" % [scenario,role,index/2]))
			index+=1
		print("NET_ANIMATION_CAPTURE | ",scenario," | ticks=",index," | state=",game.net_state)
	print("NET_ANIMATION_CAPTURE_COMPLETE")
	quit()
