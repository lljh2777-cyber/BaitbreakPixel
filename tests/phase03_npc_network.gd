extends SceneTree

const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
const AnglerPublic=preload("res://scripts/angler_network_observation.gd")
const NPCState=preload("res://scripts/npc_fish_state.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
const NPC_STAT_FIELDS: Array[String]=["npc_food_consumed","npc_food_by_type","npc_feeding_events","player_npc_food_contests","npc_target_switches","npc_hook_count","npc_escapes","npc_breaks","wrong_catches","npc_hooked_seconds"]
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
			if key in NPCState.SOCIAL_MEMORY_FIELDS: return false
			if key in ["brain_seed","brain_rng_state","target_bait_id","suspicion_by_bait","caution_by_bait","focus_bait_id","risk_tolerance","behavior_state","behavior_age","respawn_age","hook_immunity","decision_age","wander_heading","steering","turn_age","decision_weights","future_secret","feeding","power","bite_cooldown","intent_aim","satiety"]: return false
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
	check(saved.schema==16 and saved.state.npc_fishes.size()==3,"schema16 authority has three ambient NPC records")
	check(projection.npc_profile_version==2 and projection.state.npc_fishes.size()==3 and Public.valid(receiver,projection),"fish projection has guarded three-NPC public extension")
	check(shore.format==AnglerPublic.FORMAT and shore.npc_profile_version==4 and AnglerPublic.valid(receiver,shore),"angler projection validates its independent NPC privacy guard")
	check(NPCPublic.valid(projection.state.npc_fishes,world.fish_id,world.map_context.water) and private_free(projection.state.npc_fishes) and private_free(shore.state.npc_fishes),"both roles carry only six allowlisted NPC presentation facts")
	for key: String in ["npc_foraging_enabled","npc_social_enabled","public_hook_cue","npc_hook_enabled"]:
		check(not projection.state.has(key) and not shore.state.has(key),"private NPC world configuration/cue never crosses either role wire: "+key)
	for key: String in NPC_STAT_FIELDS:
		check(not projection.state.round_stats.has(key) and not shore.state.round_stats.has(key),"both roles omit private NPC aggregate: "+key)
	check(not projection.state.has("next_fish_id") and not shore.state.has("next_fish_id") and projection.state.hook_target_fish_id==-1 and shore.state.hook_target_fish_id==-1,"private allocator is omitted and inactive line target is explicitly public")
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
		for key: String in NPCState.SOCIAL_MEMORY_FIELDS: npc[key]={"private_canary":0.99}
	world.npc_foraging_enabled=not world.npc_foraging_enabled
	world.npc_social_enabled=not world.npc_social_enabled
	world.npc_hook_enabled=not world.npc_hook_enabled
	world.npc_hook.struggle_phase=1.4; world.npc_hook.age=7.0
	world.npc_hook.future_secret={"hidden_roll":0.9}
	world.public_hook_cue={"tick":int(world.simulation_tick),"position":Vector2(600,200)}
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
		for key: String in ["brain_seed","brain_rng_state","target_bait_id","suspicion_by_bait","risk_tolerance","decision_weights","future_secret","active","behavior_state","feeding","power","bite_cooldown","intent_aim","satiety","hook_immunity"]+NPCState.SOCIAL_MEMORY_FIELDS:
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
		for invalid in ["HESITATE","FLEE","COMPETE","WANDER","",&"swim",0,null]:
			var bad:=source.duplicate(true); bad.state.npc_fishes[0].animation_state=invalid
			reject(receiver,bad,role,"non-public animation state "+str(invalid))
		for invalid in [0,1,3,2 if role=="angler" else 4,1.0,2.0,3.0,4.0,"1",null]:
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
		for key: String in ["next_fish_id","brain_rng_state","npc_foraging_enabled","npc_social_enabled","public_hook_cue","npc_hook_enabled"]:
			bad=source.duplicate(true); bad.state[key]=7
			reject(receiver,bad,role,"extra top-level NPC authority key "+key)
		for key: String in NPC_STAT_FIELDS:
			bad=source.duplicate(true); bad.state.round_stats[key]=World.Stats.fresh()[key]
			reject(receiver,bad,role,"private NPC statistics smuggled into role payload: "+key)
		bad=source.duplicate(true); bad.state.npc_fishes=[]
		check(Public.apply(receiver,bad) if role=="fish" else AnglerPublic.apply(receiver,bad),role+" supports zero NPCs")
		check(receiver.npc_fishes.is_empty(),role+" zero-NPC snapshot removes prior records")
	hook_projection_checks(world,receiver)
	interpolation_checks(world)
	world.free(); receiver.free()

func hook_projection_checks(world: Node2D, receiver: Node2D) -> void:
	for role: String in ["fish","angler"]:
		var source: Dictionary=Public.capture(world) if role=="fish" else AnglerPublic.capture(world)
		var target: int=source.state.npc_fishes[0].fish_id
		source.state.hook_target_fish_id=target
		source.state.npc_hook={"phase":"hooked"}
		source.state.bound_bait=0
		source.state.npc_fishes[0].animation_state="hooked"
		source.state.npc_fishes[0].position=Vector2(650,200)
		source.state.npc_fishes[0].velocity=Vector2(120,0)
		source.state.npc_fishes[0].aim=Vector2.RIGHT
		source.state.public_npc_hook_result={"tick":source.state.simulation_tick,"fish_id":target,"result":"hooked","position":Vector2(650,200)}
		source.state.rope_path=PackedVector2Array([Vector2(650,53),Vector2(662,200)])
		check(Public.apply(receiver,source) if role=="fish" else AnglerPublic.apply(receiver,source),role+" accepts an observed NPC hook with player still free")
		check(receiver.hook_target_fish_id==target and receiver.hooked==0 and receiver.npc_hook=={"phase":"hooked"},role+" applies target and only public hook phase")
		check(receiver.npc_fishes[0].animation_state=="hooked" and receiver.public_npc_hook_result.result=="hooked",role+" preserves contact-derived animation and outcome")
		check(NPCPublic.capture(receiver.npc_fishes)==source.state.npc_fishes,role+" reprojecting public records preserves hooked animation")
		for field: String in ["age","low_age","high_age","landing_age","landing_from","struggle_phase","brain_rng_state","future_secret"]:
			var bad:=source.duplicate(true); bad.state.npc_hook[field]=0.0
			reject(receiver,bad,role,"private NPC hook field "+field)
		for field: String in ["hook_target_fish_id","npc_hook","public_npc_hook_result"]:
			var bad:=source.duplicate(true); bad.state.erase(field)
			reject(receiver,bad,role,"missing P3.4 field "+field)
		for invalid in [-1,0,1,999,2.0,"2",null]:
			var bad:=source.duplicate(true); bad.state.hook_target_fish_id=invalid
			reject(receiver,bad,role,"inconsistent or malformed target "+str(invalid))
		for invalid in [{},{"phase":"HOOKED"},{"phase":1},{"phase":""},null]:
			var bad:=source.duplicate(true); bad.state.npc_hook=invalid
			reject(receiver,bad,role,"invalid public NPC hook shape "+str(invalid))
		for invalid in [{},{"tick":0,"fish_id":target,"result":"captured","position":Vector2.ZERO},{"tick":-1,"fish_id":target,"result":"hooked","position":Vector2(650,200)},{"tick":999999,"fish_id":target,"result":"hooked","position":Vector2(650,200)},{"tick":0,"fish_id":target,"result":"safe","position":Vector2(650,200)},{"tick":0,"fish_id":target,"result":"hooked","position":Vector2(650,200),"has_hook":true}]:
			var bad:=source.duplicate(true); bad.state.public_npc_hook_result=invalid
			reject(receiver,bad,role,"invalid public NPC result "+str(invalid))
		var bad:=source.duplicate(true); bad.state.npc_fishes[0].animation_state="swim"
		reject(receiver,bad,role,"target geometry without hook animation")
		bad=source.duplicate(true); bad.state.npc_fishes[1].animation_state="hooked"
		reject(receiver,bad,role,"multiple simultaneous hook targets")
		bad=source.duplicate(true); bad.state.npc_fishes=[]
		reject(receiver,bad,role,"target absent from public fish")
		bad=source.duplicate(true); bad.state.npc_fishes[0].velocity=Vector2(150.01,0)
		reject(receiver,bad,role,"hooked velocity exceeds public motion envelope")
		var landing:=source.duplicate(true)
		landing.state.npc_hook.phase="landing"; landing.state.npc_fishes[0].animation_state="landing"
		landing.state.npc_fishes[0].position=Vector2(650,45)
		landing.state.npc_fishes[0].velocity=Vector2(0,-100)
		check(Public.apply(receiver,landing) if role=="fish" else AnglerPublic.apply(receiver,landing),role+" accepts visible NPC landing above water while player remains free")
		var view:=Presentation.new()
		check(view.accept(source,1.0,role) and view.accept(landing,1.1,role),role+" presentation accepts NPC hook-to-landing transition")
		check(find_fish(view.sample(1.1).npc_fishes,target).position==Vector2(650,45),role+" discrete NPC landing transition snaps without a ghost path")
		check(view.world.hook_target_fish_id==target and view.world.npc_hook=={"phase":"landing"},role+" render history keeps target and strips private hook timers")
		var result:=landing.duplicate(true)
		result.state.hook_target_fish_id=-1; result.state.npc_hook.phase=""; result.state.bound_bait=-1
		result.state.rope_path=PackedVector2Array(); result.state.tension=0.0
		result.state.npc_fishes.remove_at(0)
		result.state.public_npc_hook_result.result="captured"; result.state.public_npc_hook_result.position=Vector2(650,39)
		check(Public.apply(receiver,result) if role=="fish" else AnglerPublic.apply(receiver,result),role+" capture removes NPC and synchronizes non-winning outcome")
		check(not receiver.match_over and receiver.winner_role=="" and find_fish(receiver.npc_fishes,target).is_empty(),role+" wrong capture cannot fabricate a match result")
		check(view.accept(result,1.2,role) and find_fish(view.sample(1.2).npc_fishes,target).is_empty(),role+" removed hooked NPC disappears immediately from presentation")
		for outcome: String in ["escaped","broken"]:
			result=source.duplicate(true)
			result.state.hook_target_fish_id=-1; result.state.npc_hook.phase=""; result.state.bound_bait=-1
			result.state.npc_fishes[0].animation_state="swim"; result.state.npc_fishes[0].velocity=Vector2.ZERO
			result.state.public_npc_hook_result.result=outcome
			check(Public.apply(receiver,result) if role=="fish" else AnglerPublic.apply(receiver,result),role+" syncs realized NPC "+outcome+" without removing the swimmer")
		view.dispose()

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
	check(view.current.is_empty() and view.previous.is_empty() and view.world.npc_fishes.is_empty() and view.world.hook_target_fish_id==-1 and view.world.npc_hook.phase=="" and view.world.public_npc_hook_result.result=="","disconnect clears both NPC histories, displayed list and hook result")
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
	var positions:=NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook)
	for tick in 18: await frame()
	host.match_paused=true; host.network._send_state(true)
	for tick in 6: await frame()
	check(NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook)!=positions and client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook),"real ENet "+role+" receives actual authority NPC movement")
	var transported:=Protocol.unpack_state(host.network._state_packet("state").snapshot)
	check(transported.format==(Public.FORMAT if role=="fish" else AnglerPublic.FORMAT) and private_free(transported.state.npc_fishes),"real ENet "+role+" wire uses role projection with no NPC AI internals")
	check(private_free(client.npc_fishes) and private_free(client.network.presentation.current.state.npc_fishes) and private_free(client.network.display_world().npc_fishes),"real ENet "+role+" client and render history contain no private NPC state")
	await live_foraging_checks(role)
	await live_social_checks(role)
	await live_hook_checks(role)
	var old_id: int=host.npc_fishes[0].fish_id
	host.npc_fishes.remove_at(0)
	var replacement_id: int=host.spawn_npc()
	host.npc_fishes.reverse(); host.network._send_state(true)
	for tick in 6: await frame()
	check(replacement_id>old_id and find_fish(client.npc_fishes,old_id).is_empty() and not find_fish(client.npc_fishes,replacement_id).is_empty(),"real ENet "+role+" replaces stable NPC ID without reusing its slot")
	check(client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook),"real ENet "+role+" canonical records survive authority reorder")
	host.npc_fishes[0].active=false; host.network._send_state(true)
	for tick in 6: await frame()
	check(client.npc_fishes.size()==2 and client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook),"real ENet "+role+" hides inactive NPC without sending private respawn timers")
	var prior_session: String=host.network.session_id
	host.network.close(); client.network.close()
	check(client.network.presentation.current.is_empty() and client.network.presentation.world.npc_fishes.is_empty(),"real ENet "+role+" disconnect removes stale NPC render state")
	check(host.network.host_game(host_role,port,config)==OK and client.network.join_game("127.0.0.1",port)==OK,"real ENet "+role+" reconnects to fresh session")
	if not await phase("waiting"): check(false,role+" rejoin handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,role+" rejoin countdown completes"); return
	host.match_paused=true; host.network._send_state(true)
	for tick in 6: await frame()
	check(host.network.session_id!=prior_session and client.npc_fishes.size()==3 and client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook) and private_free(client.npc_fishes),"real ENet "+role+" fresh round resets IDs and receives only new public fish")

func live_hook_checks(role: String) -> void:
	for outcome: String in ["escaped","broken","captured"]:
		var npc: Dictionary=host.npc_fishes[0]
		npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT
		npc.hook_immunity=0.0
		var identity: int=npc.fish_id
		var bait: Dictionary=host.baits[0]
		bait.active=true; bait.hook=true; bait.removed=false; bait.tackle=false
		bait.angle=0.0; bait.suction_offset=Vector2.ZERO
		bait.pos=host.FishFeeding.mouth(npc.position,npc.aim)+Vector2(1,-1)
		bait.home=bait.pos; bait.tip_before=host._tip(0)
		host.fish=Vector2(950,310); host.fish_before=host.fish
		host.match_paused=false
		host._step_bait(0,0.0,false,host.mouth())
		host.match_paused=true
		check(host.hook_target_fish_id==identity and host.hooked==host.HookState.FREE,"real ENet "+role+" hook fixture resolves actual NPC mouth contact")
		host.network._send_state(true)
		for tick in 6: await frame()
		check(client.hook_target_fish_id==identity and client.npc_hook=={"phase":"hooked"} and client.hooked==client.HookState.FREE,"real ENet "+role+" preserves separate NPC line owner and free player")
		check(find_fish(client.npc_fishes,identity).animation_state=="hooked" and client.public_npc_hook_result.result=="hooked","real ENet "+role+" transports observed NPC hook animation and result")
		var display: Node2D=client.network.display_world()
		check(display.hook_target_fish_id==identity and display.rope_path[-1].is_equal_approx(display.hook_target_mouth()),"real ENet "+role+" rendered line follows the target NPC mouth")
		var packet: Dictionary=Protocol.unpack_state(host.network._state_packet("state").snapshot)
		check(packet.state.npc_hook=={"phase":"hooked"} and private_free(packet.state.npc_fishes),"real ENet "+role+" hooked wire contains no struggle timing or brain")
		if outcome=="captured":
			npc.position=Vector2(host.line_anchor(0).x,80)
			npc.behavior_state="LANDING"; host.npc_hook.phase="landing"; host.npc_hook.landing_from=npc.position; host.npc_hook.landing_age=0.0
			host.NPCHook.step(host,host.rule("landing_lift")*0.5)
			host.network._send_state(true)
			for tick in 6: await frame()
			check(client.npc_hook.phase=="landing" and find_fish(client.npc_fishes,identity).animation_state=="landing","real ENet "+role+" synchronizes NPC lift above water")
			host.NPCHook.step(host,host.rule("landing_lift"))
		else: host.NPCHook.release(host,outcome=="broken")
		host.network._send_state(true)
		for tick in 6: await frame()
		check(client.hook_target_fish_id==-1 and client.npc_hook=={"phase":""} and client.public_npc_hook_result.result==outcome,"real ENet "+role+" synchronizes realized NPC "+outcome)
		check(not host.match_over and not client.match_over and client.winner_role=="" and client.hooked==client.HookState.FREE,"real ENet "+role+" NPC "+outcome+" never ends player match")
		if outcome=="captured":
			check(find_fish(client.npc_fishes,identity).is_empty(),"real ENet "+role+" captured NPC leaves active public ecology")
			host.NPCHook.respawn(host,NPCState.RESPAWN_SECONDS)
			host.network._send_state(true)
			for tick in 6: await frame()
			check(client.npc_fishes.size()==3 and find_fish(client.npc_fishes,identity).is_empty() and client.npc_fishes[-1].fish_id>identity,"real ENet "+role+" respawns a new stable identity without captured ghosts")

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
	check(client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook) and private_free(client.network.display_world().npc_fishes),"real ENet "+role+" feeding presentation has current public geometry and no private intent")

func live_social_checks(role: String) -> void:
	for behavior: String in ["HESITATE","FLEE","COMPETE"]:
		host.fish=Vector2(970,310); host.fish_before=host.fish; host.aim=Vector2.RIGHT; host.feeding=false
		for index in host.npc_fishes.size():
			var npc: Dictionary=host.npc_fishes[index]
			var defaults:=NPCState.fresh(int(npc.fish_id),int(npc.brain_seed),Vector2(650,200),Vector2.RIGHT,int(npc.brain_rng_state))
			for key: String in NPCState.SOCIAL_MEMORY_FIELDS: npc[key]=defaults[key]
			npc.position=Vector2(650,200) if index==0 else Vector2(280+index*320,120)
			npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO
			npc.decision_age=0.0; npc.feeding=false; npc.power=0.0; npc.target_bait_id=-1; npc.focus_bait_id=-1
			npc.suspicion_by_bait={}; npc.caution_by_bait={}; npc.caution_state="CALM"; npc.behavior_state="WANDER"; npc.satiety=25.0
		for bait: Dictionary in host.baits:
			bait.active=false; bait.hook=false; bait.motion_velocity=Vector2.ZERO
			for grain: Dictionary in bait.grains: grain.eaten=true
		var bait: Dictionary=host.baits[0]
		var food:=Vector2(730,200) if behavior=="COMPETE" else Vector2(700,200)
		bait.pos=food; bait.home=food
		var grain: Dictionary=bait.grains[0]
		grain.eaten=false; grain.free=true; grain.pos=food; grain.points=1.0
		bait.motion_velocity=Vector2(6,0) if behavior=="HESITATE" else Vector2(22,0) if behavior=="FLEE" else Vector2.ZERO
		if behavior=="COMPETE":
			host.fish=Vector2(710,200); host.fish_before=host.fish; host.feeding=true
		var before:=NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook)
		for tick in 6: host._tick_npc_fishes(World.TICK_SECONDS)
		check(host.npc_fishes[0].behavior_state==behavior,"real ENet "+role+" fixture enters actual public-cue "+behavior)
		host.network._send_state(true)
		for tick in 6: await frame()
		var packet: Dictionary=Protocol.unpack_state(host.network._state_packet("state").snapshot)
		check(client.npc_fishes==NPCPublic.capture(host.npc_fishes,host.hook_target_fish_id,host.npc_hook) and before!=client.npc_fishes,"real ENet "+role+" carries actual "+behavior+" motion as public geometry")
		check(NPCPublic.valid(packet.state.npc_fishes,host.fish_id,host.map_context.water) and private_free(packet.state.npc_fishes),"real ENet "+role+" "+behavior+" carries only six swim fields")
		check(private_free(client.npc_fishes) and private_free(client.network.presentation.current.state.npc_fishes) and private_free(client.network.display_world().npc_fishes),"real ENet "+role+" "+behavior+" client/history/display hold no social private state")
		for key: String in ["npc_social_enabled","public_hook_cue"]:
			check(not packet.state.has(key) and not client.network.presentation.current.state.has(key),"real ENet "+role+" "+behavior+" excludes private authority "+key)
		check(host.hook_target_fish_id==-1 and host.npc_fishes.size()==3,"real ENet "+role+" "+behavior+" adds no NPC hook/capture outcome")

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
