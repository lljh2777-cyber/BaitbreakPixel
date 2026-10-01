extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Shore=preload("res://scripts/shore_view.gd")
var game:Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("UNTANGLE_NATIVE_PASS | ",label)
	else: failed+=1; push_error("UNTANGLE_NATIVE_FAIL | "+label)
func key(code:Key,pressed:bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func setup(role:String) -> void:
	game.reset(false,"angler"); game.player_role=role
	game.reset_world({"ruleset":"duel","challenge":false,"water_strength":0.35,"seed":2649})
	game.fish=Vector2(332,245); game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	game._update_contacts(0); game._begin_wrap(); game._commit_wrap()
	game.wraps[0].progress=1.0; game.untangle_cooldown=0.0
	game.fish=Vector2(382,245); game.fish_before=game.fish; game.velocity=Vector2.ZERO; game.qte=""
	game.fish_line_length=game.mouth().distance_to(game.wraps[0].entry)-(0.4-0.18)*32
	game.tension=0.4; game.angler.x=310; game._rebuild_rope()
	game.effort_checks.angler.wait=12.0
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game=Main.instantiate(); root.add_child(game); game.capture_mode="untangle-native"
	game.save_path="user://untangle-native-v018.cfg"; game.set_process(false); game.set_physics_process(false)
	for role in ["angler","fish"]:
		setup(role)
		var pressed:=false; var captured:=false; var unwind_seen:=false; var first:Dictionary={}
		for frame in 260:
			key(KEY_W,game.tension<0.39); key(KEY_S,game.tension>0.51)
			if frame==35: key(KEY_F,true)
			if frame==36: key(KEY_F,false)
			var state:Dictionary=game.effort_checks.angler
			if not pressed and state.active and game.Effort.progress(state)>=state.zone+state.width*0.35:
				key(KEY_SPACE,true); pressed=true
			else: key(KEY_SPACE,false)
			game.advance_tick({"move":Vector2.RIGHT*0.05},game.local_input.angler_command(game,Vector2.ZERO))
			if frame==35: check(game.untangle_phase=="check","physical F opens the counter in "+role+" recording")
			if game.untangle_phase=="unwind":
				unwind_seen=true
				var pose:Dictionary=Shore.tackle_pose(game,game.elapsed)
				if first.is_empty(): first=pose
			game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			if state.active and state.age>0.75 and not captured:
				root.get_texture().get_image().save_png("res://artifacts/untangle-"+role+"-check-v018.png"); captured=true
			if game.untangle_phase=="unwind" and game.untangle_age>0.30 and game.untangle_age<0.32:
				root.get_texture().get_image().save_png("res://artifacts/untangle-"+role+"-unwind-v018.png")
		check(pressed and unwind_seen and game.round_stats.unwrap_good==1,"actual W/S and Space complete one animated counter in "+role+" view")
		check(not game.movement_locked(),"fish remains mobile after the counter in "+role+" view")
		key(KEY_W,false); key(KEY_S,false); key(KEY_F,false); key(KEY_SPACE,false)
	game.queue_free(); await process_frame
	print("UNTANGLE_NATIVE_V018 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
