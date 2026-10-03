extends SceneTree

const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
const AnglerPublic=preload("res://scripts/angler_network_observation.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
const NPC_STAT_FIELDS: Array[String]=["npc_food_consumed","npc_food_by_type","npc_feeding_events","player_npc_food_contests","npc_target_switches"]
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("NPC_NETWORK_PASS | ",label)
	else: failed+=1; push_error("NPC_NETWORK_FAIL | "+label)

func private_free(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["brain_seed","brain_rng_state","target_bait_id","suspicion_by_bait","caution_by_bait","focus_bait_id","risk_tolerance","behavior_state","behavior_age","respawn_age","decision_age","wander_heading","steering","turn_age","decision_weights","future_secret","feeding","power","bite_cooldown","intent_aim","satiety"]: return false
			if not private_free(value[key]): return false
	elif value is Array:
		for item in value:
			if not private_free(item): return false
	return true

func reject(world: Node2D, value: Dictionary, role: String, label: String) -> void:
	var before: PackedByteArray=var_to_bytes(world.capture_snapshot())
	var accepted: bool=Public.apply(world,value) if role=="fish" else AnglerPublic.apply(world,value)
	check(not accepted and before==var_to_bytes(world.capture_snapshot()),role+" atomically rejects "+label)

func find_fish(states: Array, identity: int) -> Dictionary:
	for state: Dictionary in states:
		if state.fish_id==identity: return state
	return {}

func _initialize() -> void: call_deferred("run")

func pure_checks() -> void:
	var world:=World.new(); world.reset_world({"seed":3303,"ruleset":"duel"})
	var receiver:=World.new(); receiver.reset_world({"seed":18})
	var saved: Dictionary=world.capture_snapshot()
	var projection:=Public.capture(world)
	var shore:=AnglerPublic.capture(world)
	check(saved.schema==15 and saved.state.npc_fishes.size()==3,"schema15 authority has three ambient NPC records")
	check(projection.npc_profile_version==1 and projection.state.npc_fishes.size()==3 and Public.valid(receiver,projection),"fish projection has guarded three-NPC public extension")
	check(shore.format==AnglerPublic.FORMAT and shore.npc_profile_version==2 and AnglerPublic.valid(receiver,shore),"angler projection validates its independent NPC privacy guard")
	check(NPCPublic.valid(projection.state.npc_fishes) and private_free(projection.state.npc_fishes) and private_free(shore.state.npc_fishes),"both roles carry only six allowlisted NPC presentation facts")
	check(not projection.state.has("npc_foraging_enabled") and not shore.state.has("npc_foraging_enabled"),"private foraging configuration never crosses either role wire")
	for key: String in NPC_STAT_FIELDS:
		check(not projection.state.round_stats.has(key) and not shore.state.round_stats.has(key),"both roles omit private NPC aggregate: "+key)
	check(not projection.state.has("next_fish_id") and not projection.state.has("hook_target_fish_id") and not shore.state.has("next_fish_id") and not shore.state.has("hook_target_fish_id"),"NPC allocators and reserved hook target never cross either wire")
	for wire: Dictionary in [projection,shore]:
		check(Protocol.unpack_state(Protocol.pack_state(wire))==wire,"compressed protocol preserves role-projected NPC records")
	var held:=projection.duplicate(true)
	projection.state.npc_fishes[0].position+=Vector2(7,2)
	check(world.capture_snapshot()==saved and held.state.npc_fishes[0].position!=projection.state.npc_fishes[0].position,"NPC projection is detached from authority and earlier payloads")
	projection=held
	world.npc_fishes.reverse()
	check(Public.capture(world)==projection and AnglerPublic.capture(world)==shore,"authority array reorder preserves canonical public ordering")
	for npc: Dictionary in world.npc_fishes:
		npc.brain_seed+=123; npc.brain_rng_state+=456; npc.target_bait_id=17
		npc.suspicion_by_bait={17:0.9}; npc.caution_by_bait={17:"ALARMED"}; npc.risk_tolerance=0.8
		npc.behavior_state="FEED"; npc.behavior_age=993.0; npc.future_secret={"brain_rng_state":12}
		npc.feeding=true; npc.power=0.93; npc.bite_cooldown=0.1; npc.intent_aim=-npc.aim; npc.satiety=3.0
	world.npc_foraging_enabled=not world.npc_foraging_enabled
	world.round_stats.npc_food_consumed=7.0; world.round_stats.npc_food_by_type.cluster=7.0
	world.round_stats.npc_feeding_events=3; world.round_stats.player_npc_food_contests=2; world.round_stats.npc_target_switches=5
	check(Public.capture(world)==projection and AnglerPublic.capture(world)==shore,"neither role exposes NPC hidden decisions, RNG or future nested private fields")
	check(world.restore_snapshot(saved),"reset private-contamination fixture to exact authority")
	check(Public.apply(receiver,projection) and receiver.npc_fishes==projection.state.npc_fishes and private_free(receiver.npc_fishes),"fish application removes previously generated offline NPC secrets")
	check(AnglerPublic.apply(receiver,shore) and receiver.npc_fishes==shore.state.npc_fishes and private_free(receiver.npc_fishes),"angler application removes previously generated offline NPC secrets")
	for role: String in ["fish","angler"]:
		var source: Dictionary=projection if role=="fish" else shore
		for invalid in [null,1,{},"fish",PackedVector2Array()]:
			var bad:=source.duplicate(true); bad.state.npc_fishes=invalid
			reject(receiver,bad,role,"non-array NPC list "+str(invalid))
		for invalid in [null,1,[],"fish"]:
			var bad:=source.duplicate(true); bad.state.npc_fishes=[invalid]
			reject(receiver,bad,role,"non-record NPC "+str(invalid))
		for key: String in NPCPublic.FIELDS:
			var missing:=source.duplicate(true); missing.state.npc_fishes[0].erase(key)
			reject(receiver,missing,role,"missing NPC "+key)
			var nested:=source.duplicate(true); nested.state.npc_fishes[0][key]={"brain_seed":17}
			reject(receiver,nested,role,"private dictionary nested inside "+key)
		for key: String in ["brain_seed","brain_rng_state","target_bait_id","suspicion_by_bait","risk_tolerance","decision_weights","future_secret","active","behavior_state","feeding","power","bite_cooldown","intent_aim","satiety"]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0][key]={"value":0}
			reject(receiver,bad,role,"extra NPC key "+key)
		for invalid in [0,1,-1,2.0,"2",null]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0].fish_id=invalid
			reject(receiver,bad,role,"invalid NPC identity "+str(invalid))
		for key: String in ["position","velocity","aim"]:
			for invalid in [Vector2(NAN,1),Vector2(INF,2),Vector2(100001,0),[1,2],null]:
				var bad:=source.duplicate(true); bad.state.npc_fishes[0][key]=invalid
				reject(receiver,bad,role,"invalid NPC "+key+" "+str(invalid))
		for invalid in [Vector2.ZERO,Vector2(2,0)]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0].aim=invalid
			reject(receiver,bad,role,"non-unit NPC aim")
		for invalid in [-1,3,0.0,"0",null]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0].visual_variant=invalid
			reject(receiver,bad,role,"invalid visual variant "+str(invalid))
		for invalid in ["FLEE","WANDER","",&"swim",0,null]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0].animation_state=invalid
			reject(receiver,bad,role,"non-public animation state "+str(invalid))
		for invalid in [0,3,1 if role=="angler" else 2,1.0,2.0,"1",null]:
			var bad:=source.duplicate(true); bad.npc_profile_version=invalid
			reject(receiver,bad,role,"incompatible NPC extension guard "+str(invalid))
		var bad:=source.duplicate(true); bad.erase("npc_profile_version")
		reject(receiver,bad,role,"missing NPC extension guard")
		bad=source.duplicate(true); bad.state.npc_fishes[1].fish_id=bad.state.npc_fishes[0].fish_id
		reject(receiver,bad,role,"duplicate stable NPC identity")
		bad=source.duplicate(true); bad.state.npc_fishes[0].position=Vector2(5,5)
		reject(receiver,bad,role,"NPC outside legal water")
		bad=source.duplicate(true); bad.state.npc_fishes[0].velocity=Vector2(NPCPublic.MAX_SPEED+0.1,0)
		reject(receiver,bad,role,"unbounded NPC velocity")
		bad=source.duplicate(true)
		for index in 4:
			var extra: Dictionary=bad.state.npc_fishes[0].duplicate(true); extra.fish_id=100+index; bad.state.npc_fishes.append(extra)
		reject(receiver,bad,role,"more than six NPCs")
		for key: String in ["next_fish_id","hook_target_fish_id","brain_rng_state","npc_foraging_enabled"]:
			bad=source.duplicate(true); bad.state[key]=7
			reject(receiver,bad,role,"extra top-level NPC authority key "+key)
		for key: String in NPC_STAT_FIELDS:
			bad=source.duplicate(true); bad.state.round_stats[key]=World.Stats.fresh()[key]
			reject(receiver,bad,role,"private NPC statistics smuggled into role payload: "+key)
		bad=source.duplicate(true); bad.state.npc_fishes=[]
		check(Public.apply(receiver,bad) if role=="fish" else AnglerPublic.apply(receiver,bad),role+" supports zero NPCs")
		check(receiver.npc_fishes.is_empty(),role+" zero-NPC snapshot removes prior records")
	interpolation_checks(world)
	world.free(); receiver.free()

func interpolation_checks(world: Node2D) -> void:
	var base:=Public.capture(world)
	base.state.simulation_tick=60
	base.state.npc_fishes.resize(2)
	base.state.npc_fishes[0].position=Vector2(210,200); base.state.npc_fishes[0].aim=Vector2.RIGHT; base.state.npc_fishes[0].velocity=Vector2(10,0)
	base.state.npc_fishes[1].position=Vector2(530,200); base.state.npc_fishes[1].aim=Vector2.RIGHT
	var latest:=base.duplicate(true); latest.state.simulation_tick=66
	latest.state.npc_fishes[0].position=Vector2(230,220); latest.state.npc_fishes[0].aim=Vector2.DOWN; latest.state.npc_fishes[0].velocity=Vector2(0,10)
	latest.state.npc_fishes[1].position=Vector2(550,220)
	latest.state.npc_fishes.reverse()
	var first_id: int=base.state.npc_fishes[0].fish_id
	var second_id: int=base.state.npc_fishes[1].fish_id
	var view:=Presentation.new()
	check(view.accept(base,1.0,"fish") and view.accept(latest,1.1,"fish"),"presentation accepts reordered NPC snapshots")
	var immutable:=latest.duplicate(true)
	var midpoint: Node2D=view.sample(1.15)
	var fish:=find_fish(midpoint.npc_fishes,first_id)
	check(fish.position.is_equal_approx(Vector2(220,210)) and fish.velocity.is_equal_approx(Vector2(5,5)) and fish.aim.is_equal_approx(Vector2.ONE.normalized()),"NPC position/velocity/heading interpolate by stable identity")
	check(find_fish(midpoint.npc_fishes,second_id).position.is_equal_approx(Vector2(540,210)),"array reorder cannot swap unrelated NPC trajectories")
	check(latest==immutable and private_free(view.current.state.npc_fishes) and private_free(midpoint.npc_fishes),"interpolation neither mutates received snapshot nor holds private AI state")
	var replacement:=latest.duplicate(true); replacement.state.simulation_tick=72
	for npc: Dictionary in replacement.state.npc_fishes:
		if npc.fish_id==first_id: npc.fish_id=90; npc.position=Vector2(840,200)
	check(view.accept(replacement,1.2,"fish"),"replacement NPC identity accepted")
	check(find_fish(view.sample(1.2).npc_fishes,first_id).is_empty() and find_fish(view.world.npc_fishes,90).position==Vector2(840,200),"removed fish disappears and replacement snaps without inherited interpolation")
	var absent:=replacement.duplicate(true); absent.state.simulation_tick=78; absent.state.npc_fishes=[]
	check(view.accept(absent,1.3,"fish") and view.sample(1.3).npc_fishes.is_empty(),"inactive/absent public NPCs disappear immediately")
	replacement.state.simulation_tick=84
	check(view.accept(replacement,1.4,"fish") and find_fish(view.sample(1.4).npc_fishes,90).position==Vector2(840,200),"reactivated identity after absence has no ghost trajectory")
	var before:=view.current.duplicate(true)
	var bad:=replacement.duplicate(true); bad.state.npc_fishes[0].brain_rng_state=7
	check(not view.accept(bad,1.5,"fish") and view.current==before,"invalid presentation packet cannot replace history")
	view.clear()
	check(view.current.is_empty() and view.previous.is_empty() and view.world.npc_fishes.is_empty(),"disconnect clears both NPC histories and displayed list")
	var authority: Dictionary=world.capture_snapshot()
	check(view.accept(authority,2.0,"angler") and private_free(view.current.state.npc_fishes) and private_free(view.world.npc_fishes),"local authority-preview compatibility strips private NPC state before rendering")
	var shore:=AnglerPublic.capture(world)
	check(view.accept(shore,3.0,"angler") and private_free(view.current.state.npc_fishes) and private_free(view.world.npc_fishes),"angler role preview retains only projected NPC records")
	view.dispose()

func frame(command: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	client.network.tick(1.0/60,command); host.network.tick(1.0/60,{})
	await create_timer(0.017).timeout

func phase(wanted: String) -> bool:
	for tick in 350:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false

func live_checks(host_role: String, port: int) -> void:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game: Node2D in [host,client]:
		game.capture_mode="phase03-npc-network"; game.set_process(false); game.set_physics_process(false)
		game.save_path="user://phase03-npc-network-"+str(game.get_instance_id())+".cfg"
	var role: String="fish" if host_role=="angler" else "angler"
	var config: Dictionary={"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}}
	check(host.network.host_game(host_role,port,config)==OK and client.network.join_game("127.0.0.1",port)==OK,"real ENet "+role+" client connects")
	if not await phase("waiting"): check(false,role+" handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,role+" countdown reaches playing"); return
	check(client.network.local_role==role and host.npc_fishes.size()==3 and client.npc_fishes.size()==3,"real ENet "+role+" receives three ambient fish")
	var positions:=NPCPublic.capture(host.npc_fishes)
	for tick in 18: await frame()
	host.match_paused=true; host.network._send_state(true)
	for tick in 6: await frame()
	check(NPCPublic.capture(host.npc_fishes)!=positions and client.npc_fishes==NPCPublic.capture(host.npc_fishes),"real ENet "+role+" receives actual authority NPC movement")
	var transported:=Protocol.unpack_state(host.network._state_packet("state").snapshot)
	check(transported.format==(Public.FORMAT if role=="fish" else AnglerPublic.FORMAT) and private_free(transported.state.npc_fishes),"real ENet "+role+" wire uses role projection with no NPC AI internals")
	check(private_free(client.npc_fishes) and private_free(client.network.presentation.current.state.npc_fishes) and private_free(client.network.display_world().npc_fishes),"real ENet "+role+" client and render history contain no private NPC state")
	await live_foraging_checks(role)
	var old_id: int=host.npc_fishes[0].fish_id
	host.npc_fishes.remove_at(0)
	var replacement_id: int=host.spawn_npc()
	host.npc_fishes.reverse(); host.network._send_state(true)
	for tick in 6: await frame()
	check(replacement_id>old_id and find_fish(client.npc_fishes,old_id).is_empty() and not find_fish(client.npc_fishes,replacement_id).is_empty(),"real ENet "+role+" replaces stable NPC ID without reusing its slot")
	check(client.npc_fishes==NPCPublic.capture(host.npc_fishes),"real ENet "+role+" canonical records survive authority reorder")
	host.npc_fishes[0].active=false; host.network._send_state(true)
	for tick in 6: await frame()
	check(client.npc_fishes.size()==2 and client.npc_fishes==NPCPublic.capture(host.npc_fishes),"real ENet "+role+" hides inactive NPC without sending private respawn timers")
	var prior_session: String=host.network.session_id
	host.network.close(); client.network.close()
	check(client.network.presentation.current.is_empty() and client.network.presentation.world.npc_fishes.is_empty(),"real ENet "+role+" disconnect removes stale NPC render state")
	check(host.network.host_game(host_role,port,config)==OK and client.network.join_game("127.0.0.1",port)==OK,"real ENet "+role+" reconnects to fresh session")
	if not await phase("waiting"): check(false,role+" rejoin handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,role+" rejoin countdown completes"); return
	host.match_paused=true; host.network._send_state(true)
	for tick in 6: await frame()
	check(host.network.session_id!=prior_session and client.npc_fishes.size()==3 and client.npc_fishes==NPCPublic.capture(host.npc_fishes) and private_free(client.npc_fishes),"real ENet "+role+" fresh round resets IDs and receives only new public fish")

func public_edible_count(baits: Array) -> int:
	var count:=0
	for bait: Dictionary in baits:
		for grain: Dictionary in bait.grains:
			if not grain.eaten and (bait.active or grain.free): count+=1
	return count

func live_foraging_checks(role: String) -> void:
	# Publish a real edible fixture before allowing the authority to resolve intake.
	host.fish=Vector2(930,300); host.fish_before=host.fish
	for index in host.npc_fishes.size():
		var npc: Dictionary=host.npc_fishes[index]
		npc.position=Vector2(650,200) if index==0 else Vector2(300+index*250,120)
		npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT
		npc.steering=Vector2.ZERO; npc.decision_age=0.0; npc.bite_cooldown=0.0
		npc.target_bait_id=-1; npc.focus_bait_id=-1; npc.behavior_state="WANDER"
		npc.suspicion_by_bait={}; npc.caution_by_bait={}; npc.satiety=70.0
	for bait: Dictionary in host.baits:
		bait.active=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	var grain: Dictionary=host.baits[0].grains[0]
	grain.eaten=false; grain.free=true; grain.pos=Vector2(662,200); grain.points=1.0
	var previous_food: float=host.round_stats.npc_food_consumed
	var previous_score: float=host.score
	host.network._send_state(true)
	for tick in 6: await frame()
	check(public_edible_count(client.baits)==1,"real ENet "+role+" receives visible food before NPC consumption")
	host.match_paused=false
	for tick in 120:
		await frame()
		if grain.eaten: break
	host.match_paused=true; host.network._send_state(true)
	for tick in 6: await frame()
	check(grain.eaten and host.round_stats.npc_food_consumed==previous_food+1.0,"real ENet "+role+" authority NPC consumes actual food")
	check(public_edible_count(client.baits)==0 and client.score==previous_score and host.score==previous_score,"real ENet "+role+" replicates food depletion without a player award")
	var packet: Dictionary=Protocol.unpack_state(host.network._state_packet("state").snapshot)
	check(private_free(packet.state.npc_fishes) and not packet.state.has("npc_foraging_enabled"),"real ENet "+role+" feeding wire retains only public swimming records")
	for key: String in NPC_STAT_FIELDS:
		check(not packet.state.round_stats.has(key) and not client.network.presentation.current.state.round_stats.has(key),"real ENet "+role+" omits populated private aggregate "+key)
	check(client.npc_fishes==NPCPublic.capture(host.npc_fishes) and private_free(client.network.display_world().npc_fishes),"real ENet "+role+" feeding presentation has current public geometry and no private intent")

func cleanup_peers() -> void:
	if is_instance_valid(host): host.network.close(); host.queue_free()
	if is_instance_valid(client): client.network.close(); client.queue_free()
	await process_frame

func run() -> void:
	pure_checks()
	await live_checks("angler",24790)
	await cleanup_peers()
	await live_checks("fish",24791)
	await cleanup_peers()
	print("PHASE03_NPC_NETWORK_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
