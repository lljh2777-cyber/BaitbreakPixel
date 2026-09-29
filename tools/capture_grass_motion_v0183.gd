extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game:Node2D
func _initialize() -> void: call_deferred("run")
func prepare(role:String,target:int=18) -> void:
	game.reset(false,"angler"); game.player_role=role
	game.reset_world({"ruleset":"duel","challenge":false,"water_strength":0.0,"line_force":0,"seed":2649})
	game.angler.x=310
	game.fish=Vector2(game.targets[target].bounds.get_center().x,250 if target==18 else minf(285,game.targets[target].bounds.get_center().y)); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	game._update_contacts(0); game.contact_target=target; game._begin_wrap()
	game.qte_age=0.4+(game.qte_zone+game.qte_width*0.5)*2-game.TICK_SECONDS
	game.effort_checks.angler.wait=12.0
func capture(label:String) -> void:
	root.get_texture().get_image().save_png("E:/Fish_catches_people/BaitbreakPixel/artifacts/line-"+label+"-v0183.png")
func run() -> void:
	game=Main.instantiate(); root.add_child(game); game.capture_mode="grass-binding"
	game.save_path="user://grass-binding-v0183.cfg"; game.set_process(false); game.set_physics_process(false)
	for role in ["fish","angler"]:
		prepare(role)
		var judged:=false
		for frame in 290:
			var fish:Dictionary={"move":Vector2.RIGHT*0.18 if frame>22 and frame<100 else Vector2.ZERO}
			if frame==20: fish.qte=true
			# Pause a green test fixture until the wrap cue; all animation frames
			# thereafter are driven by the actual simulation and action timings.
			if frame<20: game.qte_age-=game.TICK_SECONDS
			if frame==104:
				game.fish_line_length=game.mouth().distance_to(game.wraps[-1].entry)-(0.4-0.18)*32
				game.tension=0.4; game.qte=""; game.low_age=0
			var human:Dictionary={"untangle":frame==110}
			var s:Dictionary=game.effort_checks.angler
			if s.active and not judged and game.Effort.progress(s)>=s.zone+s.width*0.30: human.qte=true; judged=true
			game.advance_tick(fish,human)
			game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			if frame in [24,35,48,60,74,94]: capture(role+"-wind-%03d" % frame)
			if game.untangle_phase=="unwind" and game.untangle_age>0.31 and game.untangle_age<0.34: capture(role+"-unwind")
		print("LINE_CAPTURE | role=",role," | wraps=",game.wraps.size()," | released=",game.round_stats.unwrap_good)
		if game.round_stats.unwrap_good!=1: push_error("animation fixture did not complete its real QTE"); quit(1); return
	for target in [16,17,29,12]:
		prepare("fish",target); game._commit_wrap()
		for frame in 76:
			game.advance_tick({"move":Vector2.RIGHT*0.12},{})
			game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			if frame in [8,18,29,39,52]: capture("target-%d-%03d" % [target,frame])
	game.queue_free(); await process_frame; quit()


