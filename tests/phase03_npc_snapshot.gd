extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
var passed:=0
var failed:=0
var receiver: Node2D
var baseline: Dictionary

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_SNAPSHOT_FAIL | "+label)

func reject(snapshot: Dictionary, label: String) -> void:
	var before: PackedByteArray=var_to_bytes(receiver.capture_snapshot())
	check(not receiver.restore_snapshot(snapshot),"reject "+label)
	check(before==var_to_bytes(receiver.capture_snapshot()),"rejection is atomic for all authority, IDs and RNG: "+label)

func bad_npc(field: String, value: Variant) -> void:
	var changed: Dictionary=baseline.duplicate(true)
	changed.state.npc_fishes[0][field]=value
	reject(changed,"NPC "+field+"="+str(value))

func replay_checks() -> void:
	var source:=World.new()
	for count: int in [0,3,6]:
		source.reset_world({"seed":4408,"npc_count":count,"ruleset":"duel","rules":{"hunger_enabled":false,"timer_enabled":false}})
		for tick in 137: source.advance_tick({"move":Vector2.RIGHT,"suck":tick%40<10},{})
		if count>0:
			source.npc_fishes.remove_at(0)
			var replacement: int=source.spawn_npc()
			check(replacement==count+2,"saved allocator includes a removed identity")
		var snapshot: Dictionary=source.capture_snapshot()
		check(snapshot.schema==15 and snapshot.state.has("npc_fishes") and snapshot.state.hook_target_fish_id==-1,"schema15 explicitly contains separate NPC authority and inactive hook target")
		check(receiver.restore_snapshot(snapshot),"restore legal running NPC snapshot count="+str(count))
		check(var_to_bytes(snapshot)==var_to_bytes(receiver.capture_snapshot()),"restore reproduces exact byte-serialized authority including local RNG and steering")
		if count>0:
			var restored_position: Vector2=receiver.npc_fishes[0].position
			snapshot.state.npc_fishes[0].position+=Vector2(80,0)
			check(receiver.npc_fishes[0].position==restored_position,"restored nested NPC records do not alias the exact input snapshot")
			snapshot.state.npc_fishes[0].position=restored_position
		for tick in 720:
			var fish: Dictionary={"move":Vector2.RIGHT.rotated(tick*0.011),"aim":Vector2.RIGHT.rotated(tick*0.031),"suck":tick%60<25}
			var angler: Dictionary={"walk":sin(tick*0.013),"reel":tick%210<70,"release":tick%210>=140}
			if tick in [100,400]:
				source.refill_hook_bait(0); receiver.refill_hook_bait(0)
			source.advance_tick(fish,angler); receiver.advance_tick(fish,angler)
			check(source.capture_snapshot()==receiver.capture_snapshot(),"snapshot continuation stays exact past brain turns/refill count=%d tick=%d" % [count,tick])
		source.reset_world({"seed":991,"npc_count":6})
		check(receiver.restore_snapshot(source.capture_snapshot()),"six fish can replace prior zero/three/six fish world")
	source.free()

func live_foraging_replay_checks() -> void:
	var source:=World.new()
	source.reset_world({"seed":61003,"npc_count":1,"ruleset":"duel","rules":{"hunger_enabled":false,"timer_enabled":false,"water_strength":0.0}})
	source.fish=Vector2(940,310); source.fish_before=source.fish
	var npc: Dictionary=source.npc_fishes[0]
	npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0
	for bait: Dictionary in source.baits:
		bait.active=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	for index in 12:
		var grain: Dictionary=source.baits[0].grains[index]
		grain.eaten=false; grain.free=true; grain.pos=npc.position+Vector2(12+index,0); grain.points=1.0
	for tick in 120:
		source.advance_tick({}, {})
		if source.round_stats.npc_food_consumed>0: break
	check(source.npc_foraging_enabled and source.round_stats.npc_food_consumed>0,"default foraging replay fixture consumes actual loose food")
	check(npc.behavior_state=="FEED" and npc.bite_cooldown>0,"checkpoint captures live feeding behavior and pending bite cooldown")
	var checkpoint: Dictionary=source.capture_snapshot()
	check(receiver.restore_snapshot(checkpoint),"restore live feeding checkpoint with consumption, memory, cooldown and local RNG")
	check(var_to_bytes(checkpoint)==var_to_bytes(receiver.capture_snapshot()),"live feeding checkpoint restores byte-for-byte")
	var prior_food: float=source.round_stats.npc_food_consumed
	for tick in 360:
		source.advance_tick({}, {}); receiver.advance_tick({}, {})
		check(source.capture_snapshot()==receiver.capture_snapshot(),"live foraging continuation remains exact after intake tick="+str(tick))
	check(source.round_stats.npc_food_consumed>prior_food and source.Stats.valid(source.round_stats),"restored feeding cooldown expires into further real food intake")
	check(source.score==0 and source.round_stats.food_consumed==0 and source.hook_count==0,"NPC replay intake leaves player awards and hook counters unchanged")
	source.reset_world({"seed":61003,"npc_count":1,"npc_foraging_enabled":false})
	check(receiver.restore_snapshot(source.capture_snapshot()) and not receiver.npc_foraging_enabled,"private passive-mode switch restores exactly")
	source.free()

func social_fixture(world: Node2D, behavior: String) -> void:
	world.reset_world({"seed":73003,"npc_count":1,"ruleset":"duel","rules":{"hunger_enabled":false,"timer_enabled":false,"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0}})
	world.fish=Vector2(970,310); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0; npc.satiety=25.0
	for bait: Dictionary in world.baits:
		bait.active=false; bait.hook=false; bait.motion_velocity=Vector2.ZERO
		for grain: Dictionary in bait.grains: grain.eaten=true
	var bait: Dictionary=world.baits[0]
	var food:=Vector2(730,200) if behavior=="COMPETE" else Vector2(700,200)
	bait.pos=food; bait.home=food
	var grain: Dictionary=bait.grains[0]
	grain.eaten=false; grain.free=true; grain.pos=food; grain.points=1.0
	bait.motion_velocity=Vector2(6,0) if behavior=="HESITATE" else Vector2(22,0) if behavior=="FLEE" else Vector2.ZERO
	if behavior=="COMPETE":
		world.fish=Vector2(710,200); world.fish_before=world.fish; world.feeding=true
	world._tick_npc_fishes(World.TICK_SECONDS)

func social_replay_checks() -> void:
	var source:=World.new()
	for behavior: String in ["HESITATE","FLEE","COMPETE"]:
		social_fixture(source,behavior)
		check(source.npc_fishes[0].behavior_state==behavior,"public-cue authority fixture reaches "+behavior)
		var checkpoint: Dictionary=source.capture_snapshot()
		check(checkpoint.schema==15 and checkpoint.state.has("npc_social_enabled") and checkpoint.state.has("public_hook_cue"),"social extension retains schema15 with mandatory current authority shape")
		check(receiver.restore_snapshot(checkpoint),"restore actual "+behavior+" checkpoint")
		check(var_to_bytes(checkpoint)==var_to_bytes(receiver.capture_snapshot()),"restore all private social latches/timers byte-for-byte: "+behavior)
		var identity: int=source.npc_fishes[0].fish_id
		for tick in 300:
			var command: Dictionary={"suck":tick<30,"move":Vector2.RIGHT if tick<12 else Vector2.ZERO}
			source.advance_tick(command,{}); receiver.advance_tick(command,{})
			check(source.capture_snapshot()==receiver.capture_snapshot(),"social replay exact across reaction/recovery/competition tick=%d state=%s" % [tick,behavior])
		check(source.npc_fishes.size()==1 and source.npc_fishes[0].active and source.npc_fishes[0].fish_id==identity and source.hook_target_fish_id==-1,"social replay never hooks, captures or replaces NPC: "+behavior)
	source.reset_world({"seed":73003,"npc_social_enabled":false})
	check(receiver.restore_snapshot(source.capture_snapshot()) and not receiver.npc_social_enabled,"strict snapshot retains private legacy-social diagnostic switch")
	source.free()

func social_malformed_checks() -> void:
	check(receiver.restore_snapshot(baseline),"social malformed checks reset valid baseline")
	var changed: Dictionary=baseline.duplicate(true)
	changed=baseline.duplicate(true)
	for npc: Dictionary in changed.state.npc_fishes:
		for field: String in State.SOCIAL_MEMORY_FIELDS: npc.erase(field)
	reject(changed,"P3.2 schema15 NPCs without mandatory social extension")
	for value in [0,1,"true",null]:
		changed=baseline.duplicate(true); changed.state.npc_social_enabled=value; reject(changed,"nonboolean social diagnostic switch")
	for value in [null,[],{}, {"tick":-1}, {"position":Vector2.ZERO}, {"tick":-1,"position":Vector2.ZERO,"hook":true}, {"tick":-2,"position":Vector2.ZERO}, {"tick":-1,"position":Vector2(650,200)}, {"tick":0.0,"position":Vector2.ZERO}, {"tick":"0","position":Vector2.ZERO}, {"tick":0,"position":Vector2(NAN,0)}, {"tick":0,"position":Vector2(90000,1)}, {"tick":999999,"position":Vector2(650,200)}]:
		changed=baseline.duplicate(true); changed.state.public_hook_cue=value; reject(changed,"malformed public hook occurrence "+str(value))
	for field: String in ["social_reaction_left","social_recovery_left","social_compete_left"]:
		for value in [-0.01,INF,NAN,0,"0",100.0]: bad_npc(field,value)
	for pair: Array in [["social_reaction_left",State.FLEE_SECONDS],["social_recovery_left",State.SOCIAL_RECOVERY_SECONDS],["social_compete_left",State.COMPETE_SECONDS]]:
		bad_npc(pair[0],float(pair[1])+0.001)
	for value in [Vector2(1,1),Vector2(NAN,0),Vector2(INF,0),[0,0],null]: bad_npc("social_origin",value)
	for value in [0,-2,1.0,"1",null]: bad_npc("social_bait_id",value)
	for value in [-1,3,0.0,"0",null]: bad_npc("social_motion_level",value)
	for value in [-2,0.0,"0",999999,null]: bad_npc("social_danger_tick",value)
	for behavior: String in ["HESITATE","FLEE","COMPETE"]:
		bad_npc("behavior_state",behavior)
		var source:=World.new(); social_fixture(source,behavior)
		var valid: Dictionary=source.capture_snapshot()
		check(receiver.restore_snapshot(valid),"accept actual bounded social contract "+behavior)
		changed=valid.duplicate(true); changed.state.npc_fishes[0].feeding=true
		reject(changed,"social non-feeding state cannot carry active suction: "+behavior)
		changed=valid.duplicate(true)
		changed.state.npc_fishes[0]["social_compete_left" if behavior=="COMPETE" else "social_reaction_left"]=0.0
		reject(changed,"social behavior without live supporting timer: "+behavior)
		if behavior in ["HESITATE","FLEE"]:
			changed=valid.duplicate(true); changed.state.npc_fishes[0].social_recovery_left=0.0
			reject(changed,"reaction cannot outlive its recovery lock: "+behavior)
			changed=valid.duplicate(true); changed.state.npc_fishes[0].social_compete_left=0.1
			reject(changed,"reaction and competition cannot be simultaneously active: "+behavior)
		if behavior=="HESITATE":
			changed=valid.duplicate(true); changed.state.npc_fishes[0].social_reaction_left=0.85
			reject(changed,"HESITATE cannot adopt the longer FLEE reaction duration")
			changed=valid.duplicate(true); changed.state.npc_fishes[0].social_bait_id=-1
			reject(changed,"HESITATE cannot claim an unidentified cue source")
		if behavior=="FLEE":
			changed=valid.duplicate(true); changed.state.npc_fishes[0].target_bait_id=source.baits[0].bait_id
			reject(changed,"FLEE cannot keep a food pursuit target")
		source.free()
	check(receiver.restore_snapshot(baseline),"all social rejections preserve ability to restore valid authority")

func malformed_checks() -> void:
	var source:=World.new(); source.reset_world({"seed":2311,"npc_count":3})
	for tick in 13: source.advance_tick({}, {})
	baseline=source.capture_snapshot()
	check(receiver.restore_snapshot(baseline),"malformed tests start from a valid live baseline")
	var changed: Dictionary=baseline.duplicate(true); changed.schema=14; reject(changed,"prior schema14")
	for field: String in ["next_fish_id","npc_fishes","hook_target_fish_id","npc_foraging_enabled","npc_social_enabled","public_hook_cue","npc_hook_enabled","npc_hook","public_npc_hook_result"]:
		changed=baseline.duplicate(true); changed.state.erase(field); reject(changed,"missing state field "+field)
	# Schema 15 is intentionally strict: old P3.1 shapes are not silently upgraded.
	changed=baseline.duplicate(true)
	for npc: Dictionary in changed.state.npc_fishes:
		for field: String in ["feeding","power","bite_cooldown","intent_aim"]: npc.erase(field)
	reject(changed,"P3.1 schema15 NPC records missing the foraging extension")
	for value in [0,1,"true",null]:
		changed=baseline.duplicate(true); changed.state.npc_foraging_enabled=value; reject(changed,"non-boolean private foraging switch")
	for value in [-1,0,1,4,5.0,"5",null]:
		changed=baseline.duplicate(true); changed.state.next_fish_id=value; reject(changed,"invalid allocator "+str(value))
	for value in [0,1,2,2.0,"-1"]:
		changed=baseline.duplicate(true); changed.state.hook_target_fish_id=value; reject(changed,"target without matching contact state "+str(value))
	changed=baseline.duplicate(true); changed.state.npc_fishes[1].fish_id=changed.state.npc_fishes[0].fish_id; reject(changed,"duplicate fish ID")
	changed=baseline.duplicate(true); changed.state.npc_fishes=[1]; reject(changed,"non-dictionary NPC")
	changed=baseline.duplicate(true); changed.state.npc_fishes={}; reject(changed,"non-array NPC container")
	changed=baseline.duplicate(true)
	for index in 4: changed.state.npc_fishes.append(changed.state.npc_fishes[0].duplicate(true))
	reject(changed,"above six NPCs")
	for field: String in baseline.state.npc_fishes[0]:
		changed=baseline.duplicate(true); changed.state.npc_fishes[0].erase(field); reject(changed,"missing nested field "+field)
	for value in [0,1,5,-1,2.0,"2"]: bad_npc("fish_id",value)
	for value in [-1,3,0.0,"0"]: bad_npc("visual_variant",value)
	for value in [Vector2(NAN,0),Vector2(INF,0),Vector2(-10,200),Vector2(600,500),Vector2(1262,421),[200,200]]: bad_npc("position",value)
	for value in [Vector2(INF,0),Vector2(39,0),Vector2(30,30),"0"]: bad_npc("velocity",value)
	for field: String in ["aim","wander_heading","intent_aim"]:
		for value in [Vector2.ZERO,Vector2(2,0),Vector2(NAN,0),0]: bad_npc(field,value)
	for value in [Vector2(2,0),Vector2(NAN,0),{}]: bad_npc("steering",value)
	for field: String in ["behavior_age","respawn_age","decision_age","turn_age","bite_cooldown"]:
		for value in [-0.01,INF,NAN,"0"]: bad_npc(field,value)
	bad_npc("decision_age",State.DECISION_SECONDS+0.01); bad_npc("turn_age",4.01)
	for value in ["SEEK_FOOD","INSPECT","NIBBLE","HOOKED","CAPTURED","RETURN_HOME",0]: bad_npc("behavior_state",value)
	for field: String in ["target_bait_id","focus_bait_id"]:
		for value in [0,-2,-1.0,"1"]: bad_npc(field,value)
	for value in [-0.01,101.0,NAN,INF,100,"100"]: bad_npc("satiety",value)
	for value in [0.6001,-0.1,NAN,INF,0]: bad_npc("risk_tolerance",value)
	for value in [{0:0.5},{-1:0.5},{1:-0.1},{1:1.001},{1:NAN},{1:INF},{1:0},{"1":0.5},{"secret":{"truth":true}},[]]: bad_npc("suspicion_by_bait",value)
	for value in [{0:"CALM"},{-1:"CALM"},{1:"SAFE"},{1:0.5},{"1":"CALM"},{"secret":{"truth":true}},[]]: bad_npc("caution_by_bait",value)
	for value in ["SAFE","FLEE",0]: bad_npc("caution_state",value)
	for value in [-0.01,1.001,NAN,INF,0,"0"]: bad_npc("power",value)
	for value in [0,"true",null]: bad_npc("feeding",value)
	bad_npc("bite_cooldown",1000.0)
	for value in [0.01,1.0]: bad_npc("respawn_age",value)
	for value in [-1,0.5,"100",null]: bad_npc("brain_seed",value)
	for value in [0.5,"100",null]: bad_npc("brain_rng_state",value)
	for value in [0,"true",null]: bad_npc("active",value)
	bad_npc("future_gameplay",{"attack":true})
	for behavior: String in ["WANDER","APPROACH_FOOD","FEED"]:
		for satiety: float in [0.0,70.0,100.0]:
			changed=baseline.duplicate(true)
			var npc: Dictionary=changed.state.npc_fishes[0]
			npc.behavior_state=behavior; npc.satiety=satiety
			npc.target_bait_id=-1 if behavior=="WANDER" else 1; npc.focus_bait_id=1
			npc.suspicion_by_bait={1:0.5}; npc.caution_by_bait={1:"UNEASY"}
			npc.risk_tolerance=0.6; npc.caution_state="UNEASY"
			check(receiver.restore_snapshot(changed),"accept bounded foraging state, memory and satiety: "+behavior+" "+str(satiety))
	check(receiver.restore_snapshot(baseline),"all rejected snapshots leave receiver able to accept valid state")
	var before: Dictionary=receiver.capture_snapshot()
	receiver.npc_fishes[0].position+=Vector2(1,0)
	check(before.state.npc_fishes[0].position!=receiver.npc_fishes[0].position,"captured nested NPC state is detached from live world")
	source.free()

func hook_fixture(world: Node2D) -> void:
	world.reset_world({"seed":83003,"npc_count":1,"npc_foraging_enabled":true,"npc_social_enabled":false,"ruleset":"duel","rules":{"hunger_enabled":false,"timer_enabled":false,"water_strength":0.0}})
	world.fish=Vector2(950,310); world.fish_before=world.fish
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT
	var bait: Dictionary=world.baits[0]
	bait.active=true; bait.hook=true; bait.removed=false; bait.tackle=false
	bait.angle=0.0; bait.suction_offset=Vector2.ZERO
	bait.pos=world.FishFeeding.mouth(npc.position,npc.aim)+Vector2(1,-1)
	bait.home=bait.pos; bait.tip_before=world._tip(0)
	world._step_bait(0,0.0,false,world.mouth())

func hook_replay_checks() -> void:
	var source:=World.new()
	hook_fixture(source)
	check(source.hook_target_fish_id==source.npc_fishes[0].fish_id and source.hooked==source.HookState.FREE,"snapshot hook fixture comes from actual NPC mouth contact")
	var checkpoint: Dictionary=source.capture_snapshot()
	check(receiver.restore_snapshot(checkpoint),"restore actual NPC hooked checkpoint")
	check(var_to_bytes(checkpoint)==var_to_bytes(receiver.capture_snapshot()),"NPC hook restores exact private struggle phase and timers")
	for tick in 240:
		var fish: Dictionary={"move":Vector2.LEFT if tick<60 else Vector2.ZERO}
		var angler: Dictionary={"release":tick>80}
		source.advance_tick(fish,angler); receiver.advance_tick(fish,angler)
		check(source.capture_snapshot()==receiver.capture_snapshot(),"NPC hooked/release continuation stays deterministic tick="+str(tick))
	hook_fixture(source)
	var npc: Dictionary=source.npc_fishes[0]
	var captured_id: int=npc.fish_id
	npc.position=Vector2(source.line_anchor(0).x,80); npc.behavior_state="LANDING"
	source.npc_hook.phase="landing"; source.npc_hook.landing_from=npc.position; source.npc_hook.landing_age=0.0
	source._rebuild_rope()
	checkpoint=source.capture_snapshot()
	check(receiver.restore_snapshot(checkpoint),"restore pending NPC landing checkpoint")
	for tick in 600:
		source.advance_tick({},{}); receiver.advance_tick({},{})
		check(source.capture_snapshot()==receiver.capture_snapshot(),"NPC landing/capture/respawn continuation exact tick="+str(tick))
		if source.public_npc_hook_result.result=="captured" and source.npc_fishes[0].fish_id==captured_id:
			check(receiver.restore_snapshot(source.capture_snapshot()),"captured inactive ecology and pending respawn timer restore")
	check(source.npc_fishes.size()==1 and source.npc_fishes[0].active and source.npc_fishes[0].fish_id>captured_id,"replay crosses delayed respawn into new stable identity")
	check(not source.match_over and source.winner_role=="" and source.score==0,"NPC replay capture never claims victory or player food")
	source.free()

func hook_malformed_checks() -> void:
	var source:=World.new(); hook_fixture(source)
	var checkpoint: Dictionary=source.capture_snapshot()
	check(receiver.restore_snapshot(checkpoint),"NPC malformed checks begin from actual hooked state")
	for field: String in checkpoint.state.npc_hook:
		var changed:=checkpoint.duplicate(true); changed.state.npc_hook.erase(field)
		reject(changed,"missing authoritative NPC hook field "+field)
	var changed:=checkpoint.duplicate(true); changed.state.npc_hook.future_secret=1
	reject(changed,"unknown authoritative NPC hook key")
	for field: String in ["age","low_age","high_age","landing_age","struggle_phase"]:
		for value in [-0.01,NAN,INF,0,"0",null]:
			changed=checkpoint.duplicate(true); changed.state.npc_hook[field]=value
			reject(changed,"malformed NPC hook timer "+field+" "+str(value))
	for value in ["","captured","HOOKED",0,null]:
		changed=checkpoint.duplicate(true); changed.state.npc_hook.phase=value
		reject(changed,"inconsistent NPC phase "+str(value))
	for value in [-1,0,1,999,2.0,"2",null]:
		changed=checkpoint.duplicate(true); changed.state.hook_target_fish_id=value
		reject(changed,"orphan or wrong-role NPC target "+str(value))
	changed=checkpoint.duplicate(true); changed.state.npc_fishes[0].active=false
	reject(changed,"inactive NPC cannot own the live line")
	changed=checkpoint.duplicate(true); changed.state.landing=true
	reject(changed,"NPC target cannot claim player landing")
	changed=checkpoint.duplicate(true); changed.state.qte="entry"
	reject(changed,"NPC target cannot claim a player QTE")
	changed=checkpoint.duplicate(true); changed.state.npc_fishes[0].behavior_state="WANDER"
	reject(changed,"NPC target cannot remain a free swimmer")
	for value in [{},{"tick":0,"fish_id":1,"result":"hooked","position":Vector2(650,200)},{"tick":0,"fish_id":999,"result":"hooked","position":Vector2(650,200)},{"tick":999999,"fish_id":2,"result":"hooked","position":Vector2(650,200)},{"tick":0,"fish_id":2,"result":"safe","position":Vector2(650,200)},{"tick":0,"fish_id":2,"result":"hooked","position":Vector2.ZERO}]:
		changed=checkpoint.duplicate(true); changed.state.public_npc_hook_result=value
		reject(changed,"malformed realized NPC result "+str(value))
	changed=checkpoint.duplicate(true); changed.state.npc_hook={"phase":"hooked"}
	reject(changed,"public phase-only dictionary cannot restore authority")
	changed=checkpoint.duplicate(true); changed.state.npc_fishes=source.NPCFishState.fresh(2,1,Vector2(650,200),Vector2.RIGHT,1)
	reject(changed,"malformed hook-target collection remains atomic")
	source.reset_world({"seed":1})
	changed=source.capture_snapshot(); changed.state.bound_bait=0
	reject(changed,"unowned bound bait cannot masquerade as an inactive line")
	check(receiver.restore_snapshot(baseline),"new hook rejection checks leave receiver able to restore valid current schema")
	source.free()

func _initialize() -> void:
	receiver=World.new(); receiver.reset_world({"seed":9,"npc_count":0})
	replay_checks(); live_foraging_replay_checks(); social_replay_checks(); malformed_checks(); social_malformed_checks(); hook_replay_checks(); hook_malformed_checks()
	receiver.free()
	print("PHASE03_NPC_SNAPSHOT_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
