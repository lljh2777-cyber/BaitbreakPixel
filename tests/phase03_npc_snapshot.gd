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
		check(snapshot.schema==15 and snapshot.state.has("npc_fishes") and snapshot.state.hook_target_fish_id==-1,"schema15 explicitly contains separate NPC authority and inert hook placeholder")
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

func malformed_checks() -> void:
	var source:=World.new(); source.reset_world({"seed":2311,"npc_count":3})
	for tick in 13: source.advance_tick({}, {})
	baseline=source.capture_snapshot()
	check(receiver.restore_snapshot(baseline),"malformed tests start from a valid live baseline")
	var changed: Dictionary=baseline.duplicate(true); changed.schema=14; reject(changed,"prior schema14")
	for field: String in ["next_fish_id","npc_fishes","hook_target_fish_id","npc_foraging_enabled"]:
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
		changed=baseline.duplicate(true); changed.state.hook_target_fish_id=value; reject(changed,"premature hook target "+str(value))
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
	for value in ["SEEK_FOOD","INSPECT","NIBBLE","HOOKED","FLEE","RETURN_HOME",0]: bad_npc("behavior_state",value)
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

func _initialize() -> void:
	receiver=World.new(); receiver.reset_world({"seed":9,"npc_count":0})
	replay_checks(); live_foraging_replay_checks(); malformed_checks()
	receiver.free()
	print("PHASE03_NPC_SNAPSHOT_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
