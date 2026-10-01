extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("BALANCE_NATIVE_PASS | ",message)
	else: failed+=1; push_error("BALANCE_NATIVE_FAIL | "+message)
func capture(name: String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/balance-"+name+"-v014.png")==OK,"capture "+name)
func press_button(prefix: String) -> void:
	await process_frame
	for button in game.menu.content.find_children("*","Button",true,false):
		if button.text.begins_with(prefix):
			var point: Vector2=button.get_global_rect().get_center()
			for pressed in [true,false]:
				var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=root.get_final_transform()*point; event.global_position=event.position
				Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
			return
	check(false,"button found: "+prefix)
func attach() -> void:
	game.fish=Vector2(260,170); game.fish_before=game.fish; game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game=Main.instantiate(); root.add_child(game)
	game.save_path="user://balance-native-v014.cfg"; game.capture_mode="balance-test"
	game.set_process(false); game.set_physics_process(false)
	game.reset(false); game.menu.open("practice")
	await press_button("改练钓鱼人")
	check(game.player_role=="angler" and not game.challenge and game.menu.screen=="practice","practice role button starts an actual human practice round")
	await capture("practice")
	await press_button("发力 QTE")
	check(game.menu.screen=="effort","practice opens the four effort controls")
	if game.menu.screen!="effort": game.queue_free(); quit(1); return
	var tuning := {"EffortFrequency":1.5,"EffortWindow":0.4,"EffortBoost":1.65,"EffortWeak":0.45}
	for name in tuning: game.menu.content.find_child(name,true,false).value=tuning[name]
	await capture("settings")
	await press_button("保存并返回")
	game.set_practice_effort_tuning(1,0.2,1.35,0.6); game._load_profile()
	check(game.save_error==OK and is_equal_approx(game.practice_effort_window,0.4) and is_equal_approx(game.practice_effort_boost,1.65),"saved practice settings reload from the isolated profile")
	game.menu.close(); attach(); game.Effort.open(game.effort_checks.angler,game.rng,game.effort_tuning())
	var state: Dictionary=game.effort_checks.angler
	state.age=0.4+(state.zone+state.width*0.5)*2
	await capture("wide-ring")
	game.Effort.finish(state,true,state.age,game.rng); game.elapsed=1.2
	await capture("human-force")
	game.player_role="fish"; game.Effort.open(game.effort_checks.fish,game.rng,game.effort_tuning())
	game.Effort.finish(game.effort_checks.fish,false,0,game.rng); game.effort_checks.fish.result_age=0
	await capture("fish-weakness")
	game.reset(false,"angler"); game.menu.close()
	game.fish=Vector2(460,160); game.fish_before=game.fish; game.stamina=100
	game.begin_manual_net(game.fish); game.net_state="sweep"; game.net_age=0; game._step_net(0.3)
	check(game.net_capture>0.4 and game.net_state=="sweep" and not game.movement_locked(),"partially closing net leaves fish movement available")
	await capture("net-closing")
	game._step_net(0.4); game._step_net(0.18)
	await capture("net-caught")
	for frame in 600:
		if game.net_state=="rest": break
		game._step_net(1.0/60)
	check(not game.match_over and game.hooked==game.HookState.FREE and game.net_state=="rest","human practice capture resets to a playable pond")
	game.reset(true,"angler"); game.menu.close()
	check(game.effort_tuning().boost==1.35 and game.practice_effort_boost>1.6,"challenge uses default rules without erasing the saved practice preset")
	game.round_stats={"fish_good":3,"fish_total":8,"angler_good":4,"angler_total":6,"wrap_good":2,"breaks":1,"slips":2,"danger_seconds":9.4,"hooked_seconds":36.2}
	game.hook_count=4; game.net_count=3; game.net_catches=1; game.elapsed=125.4; game.score=23.5
	game.finish(false,"net")
	await capture("result-human")
	check(game.menu.screen=="result" and game.Stats.rate(game.round_stats,"fish").begins_with("38%"),"result screen shows role-specific rates and reason")
	game.player_role="fish"; game.menu.open("result"); await capture("result-fish")
	# Client restore presents the same stats; it must never increment them a second time.
	var before: Dictionary=game.round_stats.duplicate(true)
	game.restore_snapshot(game.capture_snapshot()); game.menu.open("result")
	check(game.round_stats==before,"opening and restoring a result does not count it again")
	print("BALANCE_NATIVE_V014_TESTS | passed=",passed," | failed=",failed)
	game.queue_free(); await process_frame; quit(1 if failed else 0)
