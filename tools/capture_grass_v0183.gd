extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game:Node2D
func _initialize() -> void: call_deferred("run")
func prepare(target:int,y:float) -> void:
	game.reset(false,"angler"); game.player_role="fish"
	game.reset_world({"ruleset":"duel","challenge":false,"seed":2649,"water_strength":0.5,"line_force":0})
	game.angler.x=210; game.fish=Vector2(game.targets[target].bounds.get_center().x,y); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	game._update_contacts(0); game.contact_target=target; game._begin_wrap(); game._commit_wrap()
	game.qte_result_age=0; game.result_flash=0; game.wraps[0].progress=1
	game.fish+=Vector2(-4,20); game.aim=Vector2(0.5,-0.85).normalized(); game.tension=0.41
	game.elapsed=4; game.fish_line_length=game.mouth().distance_to(game.wraps[0].entry)+2
	game.baits[0].pos=game.mouth()-Vector2(2,1).rotated(game.baits[0].angle); game._rebuild_rope()
func capture(label:String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	var prefix:="before" if OS.get_cmdline_user_args().has("--baseline") else "after"
	root.get_texture().get_image().save_png("res://artifacts/grass-"+prefix+"-"+label+"-v0183.png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game=Main.instantiate(); root.add_child(game); game.capture_mode="grass-style"; game.save_path="user://grass-style-v0183.cfg"
	game.set_process(false); game.set_physics_process(false)
	for item in [[14,250],[16,280],[17,270],[29,304],[14,224],[14,305]]:
		prepare(item[0],item[1]); await capture("%d-%d" % [item[0],item[1]])
	game.player_role="angler"; await capture("angler")
	game.queue_free(); await process_frame; quit()
