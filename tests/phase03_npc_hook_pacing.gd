extends SceneTree

# Full-distance, real-contact NPC retrieval gate. No test moves an attached NPC
# toward shore or changes the line to make a capture succeed.
const World=preload("res://scripts/world_simulation.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")

static func contact_fixture(mode: String, seed_value: int, position: Vector2) -> Node2D:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"ruleset":mode,"challenge":true,"npc_count":1,
		"npc_foraging_enabled":true,"npc_social_enabled":true,"npc_hook_enabled":true,
		"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0}})
	world.fish=Vector2(1100,400); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	world.angler.x=614.0
	world.angler.previous_anchor=world.angler.anchor()
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=position; npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO
	for bait: Dictionary in world.baits:
		bait.active=false; bait.removed=false; bait.hook=false; bait.tackle=false; bait.suction_offset=Vector2.ZERO
		for grain: Dictionary in bait.grains: grain.eaten=true
	var bait: Dictionary=world.baits[1]
	var point:=Feeding.mouth(npc.position,npc.aim)+Vector2(3,0)
	bait.active=true; bait.hook=true; bait.angle=0.0; bait.pos=point-Vector2(2,1)
	bait.home=bait.pos; bait.tip_before=point; bait.attachment_anchor=Vector2(640,53)
	world._step_bait(1,0.0,false,world.mouth())
	return world

static func measure(mode: String, seed_value: int, position: Vector2, control: String, limit_ticks: int=3600) -> Dictionary:
	var world:=contact_fixture(mode,seed_value,position)
	var attached: bool=world.hook_target_fish_id==2 and world.round_stats.npc_hook_count==1
	var npc: Dictionary=world.npc_fishes[0]
	var anchor: Vector2=world.line_anchor(1)
	var initial_distance:=anchor.distance_to(world.hook_target_mouth())
	var landing_tick:=-1
	var terminal_tick:=-1
	var max_step:=0.0
	var max_hooked_step:=0.0
	var high_peak:=0.0
	var low_peak:=0.0
	var reel_ticks:=0
	var release_ticks:=0
	var samples: Array=[]
	for tick in limit_ticks:
		var command: Dictionary={"auto_reel":true} if control=="auto_reel" else {"reel":true}
		if control=="release": command={"release":true}
		# W/S control responds only to the realized public line tension.
		if control=="ws": command={"release":true} if world.tension>=0.84 or (tick>=30 and tick<42) else {"reel":true}
		if command.get("reel",false): reel_ticks+=1
		if command.get("release",false): release_ticks+=1
		var previous_position: Vector2=npc.position
		var previous_phase: String=world.npc_hook.phase
		world.advance_tick({},command)
		var step:=previous_position.distance_to(npc.position)
		max_step=maxf(max_step,step)
		if previous_phase=="hooked": max_hooked_step=maxf(max_hooked_step,step)
		high_peak=maxf(high_peak,world.npc_hook.high_age)
		low_peak=maxf(low_peak,world.npc_hook.low_age)
		if world.npc_hook.phase=="landing" and landing_tick<0: landing_tick=tick+1
		if tick%60==0 or world.hook_target_fish_id<0:
			samples.append({"tick":tick+1,"x":npc.position.x,"y":npc.position.y,"tension":world.tension,"rope_length":world.rope_length,"reel_speed":world.reel_speed,"phase":world.npc_hook.phase})
		if world.hook_target_fish_id<0:
			terminal_tick=tick+1
			break
	var result: Dictionary={"mode":mode,"seed":seed_value,"control":control,"start_x":position.x,"start_y":position.y,
		"horizontal":position.x-anchor.x,"initial_mouth_anchor_distance":initial_distance,"real_contact":attached,
		"landing_tick":landing_tick,"landing_seconds":landing_tick*World.TICK_SECONDS if landing_tick>=0 else -1.0,
		"terminal_tick":terminal_tick,"terminal_seconds":terminal_tick*World.TICK_SECONDS if terminal_tick>=0 else -1.0,
		"outcome":world.public_npc_hook_result.result if terminal_tick>=0 else "unfinished",
		"capture_count":world.round_stats.wrong_catches,"escape_count":world.round_stats.npc_escapes,"break_count":world.round_stats.npc_breaks,
		"player_match_over":world.match_over,"player_hook_events":world.round_stats.hook_events,"player_food":world.score,
		"max_step":max_step,"max_hooked_step":max_hooked_step,"max_high_age":high_peak,"max_low_age":low_peak,
		"reel_ticks":reel_ticks,"release_ticks":release_ticks,"samples":samples}
	world.free()
	return result

var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("NPC_PACING_PASS | ",label)
	else: failed+=1; push_error("NPC_PACING_FAIL | "+label)

func _initialize() -> void:
	# Values are the immutable b739fda 60 Hz contact-to-capture baseline.
	# Budget requires a visible retrieval improvement, with the shore hold/lift
	# retained; it is deliberately looser than the intended ~2x NPC-only pace.
	var old_reel: Array=[3.10,6.0334,10.20,6.1667,7.5834,11.2334,10.2834,11.2334,13.55]
	var old_auto: Array=[4.2334,9.4167,16.20,9.75,12.15,17.8834,16.2834,17.6834,21.3667]
	for mode: String in ["duel","survival"]:
		var index:=0
		for depth: float in [130.0,240.0,390.0]:
			for horizontal: float in [0.0,160.0,320.0]:
				for control: String in ["reel","auto_reel"]:
					var row:=measure(mode,64317,Vector2(640+horizontal,depth),control)
					var label:="%s y=%.0f dx=%.0f %s" % [mode,depth,horizontal,control]
					var baseline: float=old_reel[index] if control=="reel" else old_auto[index]
					check(row.real_contact,"real mouth contact: "+label)
					check(row.outcome=="captured" and row.capture_count==1 and row.escape_count==0 and row.break_count==0,"continuous ordinary capture: "+label)
					check(row.terminal_seconds>0 and row.terminal_seconds<=baseline*0.8+0.1+World.TICK_SECONDS,"faster full-distance capture budget: "+label)
					check(row.landing_tick>0 and row.terminal_tick-row.landing_tick==63,"retains full 1.05 s shore lift: "+label)
					check(row.max_hooked_step<=2.5,"no post-contact jump toward shore: "+label)
					check(not row.player_match_over and row.player_hook_events==0 and row.player_food==0,"no player match/food/Hook side effect: "+label)
				index+=1
	for seed_value: int in [64317,64404,64423]:
		for mode: String in ["duel","survival"]:
			var row:=measure(mode,seed_value,Vector2(960,390),"ws")
			check(row.outcome=="captured" and row.reel_ticks>0 and row.release_ticks>=12,"W/S reversal returns to capture through normal controls: %s seed=%d" % [mode,seed_value])
			check(row.terminal_seconds<=12.0 and row.max_hooked_step<=2.5,"deep offset W/S stays bounded without jumps: %s seed=%d" % [mode,seed_value])
			var release_row:=measure(mode,seed_value,Vector2(800,240),"release",600)
			check(release_row.outcome=="escaped" and release_row.escape_count==1 and release_row.capture_count==0,"held S still yields true slack escape: %s seed=%d" % [mode,seed_value])
	# A valid low-force practice configuration gives held W a sustained-high
	# witness. Default 3 s break threshold stays untouched; no rope/position edit.
	for mode: String in ["duel","survival"]:
		var world:=contact_fixture(mode,64317,Vector2(960,390))
		world.set_practice_line_tuning(1.0,0.1)
		var longest_high:=0.0
		for tick in 360:
			world.advance_tick({},{"reel":true})
			longest_high=maxf(longest_high,world.npc_hook.high_age)
			if world.hook_target_fish_id<0: break
		check(world.public_npc_hook_result.result=="broken" and world.round_stats.npc_breaks==1 and world.round_stats.wrong_catches==0,"sustained high tension still breaks: "+mode)
		check(longest_high>=world.break_hold_seconds-World.TICK_SECONDS and is_equal_approx(world.break_hold_seconds,3.0),"observed full default high-tension hold: "+mode)
		check(not world.match_over and world.round_stats.breaks==0,"NPC break stays separate from player: "+mode)
		world.free()
	# Real default-rules mistake: continuing W while walking away can still
	# sustain excessive tension long enough to break the NPC line.
	var walking:=contact_fixture("duel",64317,Vector2(960,390))
	var observed_high:=0.0
	for tick in 600:
		walking.advance_tick({},{"reel":true,"walk":-1.0})
		observed_high=maxf(observed_high,walking.npc_hook.high_age)
		if walking.hook_target_fish_id<0: break
	check(walking.public_npc_hook_result.result=="broken" and walking.round_stats.npc_breaks==1,"default W plus walking away still breaks without any state edits")
	check(observed_high>=walking.break_hold_seconds-World.TICK_SECONDS and is_equal_approx(walking.break_hold_seconds,3.0),"default practical break retains full sustained-high duration")
	check(not walking.match_over and walking.round_stats.breaks==0 and walking.round_stats.wrong_catches==0,"default practical NPC break does not end player match")
	walking.free()
	print("PHASE03_NPC_HOOK_PACING_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
