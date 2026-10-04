extends SceneTree

# P3.5 integration invariants, not a win-rate or human-playtest claim. Counts
# 2/3/4 are controlled normal-density coverage, not a new player-facing setting.
# Production defaults and all food/decay/attention tuning remain unchanged.
const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Hook=preload("res://scripts/npc_hook.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
const Public=preload("res://scripts/npc_fish_public_state.gd")
const RUN_TICKS:=1200
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("ECOLOGY_BALANCE_PASS | ",label)
	else: failed+=1; push_error("ECOLOGY_BALANCE_FAIL | "+label)

func angler_command(tick: int, mode: String) -> Dictionary:
	# Fixed public schedule through the ordinary command surface. Rejected Q
	# requests stay rejected by production authority; this never edits a line.
	return {"auto_reel":true,"auto_net":false,"deploy":mode=="duel" and tick%120==0}

func identity_and_record_valid(world: Node2D, count: int) -> bool:
	if world.npc_fishes.size()!=count: return false
	var ids: Dictionary={}
	for npc: Dictionary in world.npc_fishes:
		if ids.has(npc.fish_id) or not State.valid(npc,world.next_fish_id,world.map_context.water): return false
		ids[npc.fish_id]=true
	return true

func default_contract() -> void:
	var world:=World.new(); world.reset_world({"seed":75100})
	check(State.DEFAULT_COUNT==3 and world.npc_fishes.size()==3,"production default remains three; 2/4 exist only as test fixtures")
	check(world.npc_foraging_enabled and world.npc_social_enabled and world.npc_hook_enabled,"default ecology enables feeding, social cues and physical NPC hooks")
	check(world.rule("bite_range")==10.0 and is_equal_approx(world.rule("bite_cooldown"),0.8),"shared Bite contract remains 10 px / 0.8 s")
	check(is_equal_approx(Hook.RETRIEVAL_GAIN,1.8),"0.25.4 NPC retrieval gain remains unchanged")
	var fresh:=true
	for npc: Dictionary in world.npc_fishes: fresh=fresh and npc.satiety==70.0
	check(fresh and Public.FIELDS==["fish_id","position","velocity","aim","visual_variant","animation_state"],"fresh appetite and six-field public NPC contract stay unchanged")
	world.free()

func integrated_case(count: int, mode: String, challenge: bool, hunger: bool, seed_value: int) -> void:
	var config: Dictionary={"seed":seed_value,"ruleset":mode,"challenge":challenge,"npc_count":count,"rules":{"hunger_enabled":hunger}}
	var source:=World.new(); source.reset_world(config)
	var verifier:=World.new(); verifier.reset_world(config)
	var replay:=World.new(); replay.reset_world(config)
	# Deliberately diverse private starting appetites stress the existing rules.
	# This is not the default-start population used by the statistical study.
	for index in count: source.npc_fishes[index].satiety=[5.0,35.0,70.0,100.0][index]
	var goal: float=source.food_target()
	var initial_player_satiety: float=source.satiety
	var shape_ok:=true; var snapshots_ok:=true; var wires_ok:=true; var replay_ok:=true
	var checks:=0; var observed_states: Dictionary={}; var replay_started:=false
	var label:="count=%d mode=%s challenge=%s hunger=%s seed=%d" % [count,mode,str(challenge),str(hunger),seed_value]
	for tick in RUN_TICKS:
		if tick==300:
			source.match_paused=true
			var frozen:=var_to_bytes(source.capture_snapshot())
			for ignored in 30: source.advance_tick({"suck":true},{"deploy":true,"reel":true})
			check(frozen==var_to_bytes(source.capture_snapshot()),"pause freezes full ecology and supply: "+label)
			source.match_paused=false
		if tick==RUN_TICKS-120:
			replay_started=replay.restore_snapshot(source.capture_snapshot())
			replay_ok=replay_started
		var command:=angler_command(tick,mode)
		source.advance_tick({},command)
		if replay_started:
			replay.advance_tick({},command)
			replay_ok=replay_ok and var_to_bytes(source.capture_snapshot())==var_to_bytes(replay.capture_snapshot())
		for npc: Dictionary in source.npc_fishes:
			observed_states[npc.behavior_state]=int(observed_states.get(npc.behavior_state,0))+1
		if tick%60==0 or tick==RUN_TICKS-1:
			shape_ok=shape_ok and identity_and_record_valid(source,count)
			var checkpoint:=source.capture_snapshot()
			var accepted: bool=verifier.restore_snapshot(checkpoint)
			snapshots_ok=snapshots_ok and accepted and var_to_bytes(checkpoint)==var_to_bytes(verifier.capture_snapshot())
			wires_ok=wires_ok and FishWire.valid(verifier,FishWire.capture(source)) and AnglerWire.valid(verifier,AnglerWire.capture(source))
			checks+=1
	check(shape_ok,"normal-density records/identities remain legal: "+label)
	check(snapshots_ok and checks==21,"21 live authority checkpoints restore byte-exactly: "+label)
	check(wires_ok,"both role allowlists accept every observed ecology checkpoint: "+label)
	check(replay_ok and replay_started,"last 120 production ticks replay byte-for-byte: "+label)
	check(not source.match_over and source.food_target()==goal and source.score==0.0 and source.round_stats.food_consumed==0.0,"idle home player keeps original goal/ownership; NPCs cannot force a winner: "+label)
	check(source.satiety<initial_player_satiety if hunger else source.satiety==initial_player_satiety,"player hunger toggle keeps its own established physiology: "+label)
	check(source.Stats.valid(source.round_stats),"integrated intake and hook statistics reconcile: "+label)
	print("ECOLOGY_BALANCE_CASE | ",JSON.stringify({"count":count,"mode":mode,"challenge":challenge,"hunger":hunger,"seed":seed_value,"ticks":source.simulation_tick,"npc_food":source.round_stats.npc_food_consumed,"npc_hooks":source.round_stats.npc_hook_count,"wrong_catches":source.round_stats.wrong_catches,"states":observed_states}))
	source.free(); verifier.free(); replay.free()

func capture_with_peers(count: int, mode: String) -> void:
	var source:=World.new()
	source.reset_world({"seed":75300+count,"ruleset":mode,"challenge":false,"npc_count":count,
		"rules":{"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
	# Only the initial physical contact is controlled. All retrieval, capture,
	# respawn, independent fish activity and supply then run at ordinary 60 Hz.
	source.angler.x=614.0; source.angler.previous_anchor=source.angler.anchor()
	var target: Dictionary=source.npc_fishes[0]
	target.position=Vector2(640,220); target.velocity=Vector2.ZERO; target.aim=Vector2.RIGHT
	target.intent_aim=Vector2.RIGHT; target.steering=Vector2.ZERO
	var identity: int=target.fish_id
	var bait: Dictionary=source.baits[1]
	bait.active=true; bait.removed=false; bait.hook=true; bait.tackle=false
	bait.angle=0.0; bait.suction_offset=Vector2.ZERO
	var point: Vector2=source.FishFeeding.mouth(target.position,target.aim)+Vector2(3,0)
	bait.pos=point-Vector2(2,1); bait.home=bait.pos; bait.tip_before=point
	source._step_bait(1,0.0,false,source.mouth())
	var label:="capture count=%d mode=%s" % [count,mode]
	check(source.hook_target_fish_id==identity and source.hooked==World.HookState.FREE,"real swept mouth contact chooses only NPC: "+label)
	var peer_id: int=source.npc_fishes[1].fish_id
	var peer_before: Dictionary=source.npc_fishes[1].duplicate(true)
	var verifier:=World.new(); verifier.reset_world({"seed":1})
	var legal:=true; var replay_ok:=true; var peer_progress:=false; var checks:=0; var capture_tick:=-1; var replacement_tick:=-1
	var replay:=World.new(); replay.reset_world({"seed":2})
	var restored: bool=replay.restore_snapshot(source.capture_snapshot())
	for tick in 1200:
		var command: Dictionary={"reel":true,"auto_net":false}
		source.advance_tick({},command)
		if source.hook_target_fish_id==identity:
			peer_progress=peer_progress or source.npc_by_id(peer_id)!=peer_before
		if restored:
			replay.advance_tick({},command)
			if tick%30==0: replay_ok=replay_ok and var_to_bytes(source.capture_snapshot())==var_to_bytes(replay.capture_snapshot())
		if capture_tick<0 and not target.active: capture_tick=tick
		if replacement_tick<0 and source.npc_by_id(identity).is_empty(): replacement_tick=tick
		if tick%30==0:
			legal=legal and identity_and_record_valid(source,count) and verifier.restore_snapshot(source.capture_snapshot())
			legal=legal and FishWire.valid(verifier,FishWire.capture(source)) and AnglerWire.valid(verifier,AnglerWire.capture(source))
			checks+=1
	check(legal and checks==40,"40 lifecycle checkpoints stay legal on authority and both roles: "+label)
	check(restored and replay_ok,"real capture and replacement replay with live peers: "+label)
	check(capture_tick>=0 and replacement_tick-capture_tick>=479 and replacement_tick-capture_tick<=482,"capture spends the existing eight-second replacement delay: "+label)
	check(source.npc_by_id(identity).is_empty() and source.npc_fishes.size()==count and source.next_fish_id>count+2,"population recovers with a fresh stable identity: "+label)
	check(peer_progress,"other ecology continues while the original NPC occupies the line: "+label)
	check(not source.match_over and source.winner_role.is_empty() and source.hook_count==0 and source.score==0 and source.round_stats.wrong_catches>=1,"wrong catch keeps player awards and victory separate: "+label)
	print("ECOLOGY_BALANCE_CAPTURE | ",JSON.stringify({"count":count,"mode":mode,"capture_tick":capture_tick,"replacement_tick":replacement_tick,"npc_food":source.round_stats.npc_food_consumed,"npc_hooks":source.round_stats.npc_hook_count,"wrong_catches":source.round_stats.wrong_catches}))
	source.free(); verifier.free(); replay.free()

func no_npc_net_target() -> void:
	# Same committed, collision-cleared route: an NPC crossing has no capture
	# authority, while a player crossing still uses the existing net outcome.
	for player_in_lane: bool in [false,true]:
		var world:=World.new()
		world.reset_world({"seed":75401,"ruleset":"duel","challenge":true,"npc_count":3,
			"rules":{"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
		world.angler.x=234.0; world.angler.previous_anchor=world.angler.anchor()
		world.fish=Vector2(260,140) if player_in_lane else Vector2(1000,320)
		world.fish_before=world.fish
		var npc: Dictionary=world.npc_fishes[0]
		npc.position=Vector2(260,140); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
		npc.intent_aim=Vector2.RIGHT; npc.wander_heading=Vector2.RIGHT; npc.steering=Vector2.ZERO
		for bait: Dictionary in world.baits: bait.active=false
		world.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}]})
		check(world.net_state=="warning","ordinary net command commits the paired lane; player in lane="+str(player_in_lane))
		var nearest:=INF
		for tick in 90:
			world.advance_tick({},{})
			if world.net_state=="sweep": nearest=minf(nearest,world.net_pos.distance_to(npc.position))
		if player_in_lane:
			check(world.net_catches==1 and world.net_state=="caught","positive control retains normal player net capture")
		else:
			check(nearest<20.0,"negative control genuinely sweeps across the NPC body")
			check(world.net_catches==0 and npc.active and npc.behavior_state!="CAPTURED" and world.round_stats.wrong_catches==0 and not world.match_over,"NPC overlap grants neither net capture, wrong catch nor player loss")
		world.free()

func _initialize() -> void:
	default_contract()
	var serial:=0
	for count: int in [2,3,4]:
		for mode: String in ["survival","duel"]:
			for challenge: bool in [false,true]:
				for hunger: bool in [false,true]:
					integrated_case(count,mode,challenge,hunger,75101+serial)
					serial+=1
			capture_with_peers(count,mode)
	no_npc_net_target()
	print("PHASE03_ECOLOGY_BALANCE_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
