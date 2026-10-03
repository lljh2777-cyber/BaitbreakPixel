extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Feeding=preload("res://scripts/fish_feeding.gd")
var game: Node2D
var output:="res://artifacts/p34-bugfix-native-pacing-r2"
var rows: Array=[]
func _initialize() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	call_deferred("run")
func capture(label: String) -> void:
	game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(label+".png"))!=OK: push_error("CAPTURE_OUTPUT_FAIL"); quit(2)
func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="native-pacing-review"; game.set_process(false); game.set_physics_process(false)
	for control: String in ["reel","auto_reel"]:
		game.reset_world({"seed":64317,"ruleset":"duel" if control=="reel" else "survival","challenge":true,"npc_count":1,
			"npc_foraging_enabled":true,"npc_social_enabled":true,"npc_hook_enabled":true,
			"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0}})
		game.fish=Vector2(1100,400); game.fish_before=game.fish; game.aim=Vector2.RIGHT
		game.angler.x=614.0; game.angler.previous_anchor=game.angler.anchor()
		var target: Dictionary=game.npc_fishes[0]
		target.position=Vector2(960,390); target.velocity=Vector2.ZERO; target.aim=Vector2.RIGHT
		target.intent_aim=Vector2.RIGHT; target.steering=Vector2.ZERO
		for bait: Dictionary in game.baits:
			bait.active=false; bait.removed=false; bait.hook=false; bait.hook_id=0; bait.tackle=false; bait.suction_offset=Vector2.ZERO
			for grain: Dictionary in bait.grains: grain.eaten=true
		var bait: Dictionary=game.baits[1]
		var point:=Feeding.mouth(target.position,target.aim)+Vector2(3,0)
		bait.active=true; bait.hook=true; bait.hook_id=game.next_hook_id; game.next_hook_id+=1
		bait.angle=0.0; bait.pos=point-Vector2(2,1); bait.home=bait.pos; bait.tip_before=point; bait.attachment_anchor=Vector2(640,53)
		game._step_bait(1,0.0,false,game.mouth())
		if game.hook_target_fish_id!=2: push_error("NATIVE_PACING_FAIL real contact"); quit(1); return
		game.menu.close(); game.player_role="angler"; game.net_action.observing=false
		var npc: Dictionary=game.npc_fishes[0]
		await capture(control+"-contact")
		var landing_tick:=-1
		var terminal_tick:=-1
		var max_step:=0.0
		var event:=InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=true
		Input.parse_input_event(event); Input.flush_buffered_events()
		for tick in 1500:
			var before: Vector2=npc.position
			var command: Dictionary=game.local_input.angler_command(game,Vector2.ZERO) if control=="reel" else {"auto_reel":true}
			game.advance_tick({},command)
			if game.npc_hook.phase=="hooked": max_step=maxf(max_step,before.distance_to(npc.position))
			game.view.queue_redraw(); await process_frame
			if tick==119 or tick==299: await capture(control+"-t"+str((tick+1)/60))
			if game.npc_hook.phase=="landing" and landing_tick<0:
				landing_tick=tick+1; game.net_action.observing=false
				await capture(control+"-landing-start")
			if landing_tick>0 and tick+1==landing_tick+30: await capture(control+"-landing-mid")
			if game.hook_target_fish_id<0:
				terminal_tick=tick+1; break
		event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events()
		await capture(control+"-captured")
		var row: Dictionary={"control":control,"landing_seconds":landing_tick/60.0,"terminal_seconds":terminal_tick/60.0,"max_hooked_step":max_step,"outcome":game.public_npc_hook_result.result,"player_match_over":game.match_over,"wrong_catches":game.round_stats.wrong_catches}
		rows.append(row); print("NATIVE_PACING_REVIEW | ",JSON.stringify(row))
		if terminal_tick<0 or row.outcome!="captured" or row.player_match_over: push_error("NATIVE_PACING_FAIL outcome"); quit(1); return
	var file:=FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"rendered":true,"engine":Engine.get_version_info().string,"frame_policy":"one ordinary 60 Hz simulation tick per renderer frame; still captures pause only presentation", "rows":rows},"\t")); file.close()
	print("NATIVE_PACING_REVIEW | passed=2 | failed=0")
	game.queue_free(); await process_frame; quit(0)
