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

func malformed_checks() -> void:
	var source:=World.new(); source.reset_world({"seed":2311,"npc_count":3})
	for tick in 13: source.advance_tick({}, {})
	baseline=source.capture_snapshot()
	check(receiver.restore_snapshot(baseline),"malformed tests start from a valid live baseline")
	var changed: Dictionary=baseline.duplicate(true); changed.schema=14; reject(changed,"prior schema14")
	for field: String in ["next_fish_id","npc_fishes","hook_target_fish_id"]:
		changed=baseline.duplicate(true); changed.state.erase(field); reject(changed,"missing state field "+field)
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
	for field: String in ["aim","wander_heading"]:
		for value in [Vector2.ZERO,Vector2(2,0),Vector2(NAN,0),0]: bad_npc(field,value)
	for value in [Vector2(2,0),Vector2(NAN,0),{}]: bad_npc("steering",value)
	for field: String in ["behavior_age","respawn_age","decision_age","turn_age"]:
		for value in [-0.01,INF,NAN,"0"]: bad_npc(field,value)
	bad_npc("decision_age",State.DECISION_SECONDS+0.01); bad_npc("turn_age",4.01)
	for value in ["SEEK_FOOD","INSPECT","NIBBLE","HOOKED","FLEE","RETURN_HOME",0]: bad_npc("behavior_state",value)
	for field: String in ["target_bait_id","focus_bait_id"]:
		for value in [0,1,-2,-1.0]: bad_npc(field,value)
	for value in [0.0,99.0,101.0,100,"100"]: bad_npc("satiety",value)
	for value in [0.1,-0.1,0]: bad_npc("risk_tolerance",value)
	for field: String in ["suspicion_by_bait","caution_by_bait"]:
		for value in [{1:0.5},{"secret":{"truth":true}},[]]: bad_npc(field,value)
	for value in ["UNEASY","ALARMED",0]: bad_npc("caution_state",value)
	for value in [0.01,1.0]: bad_npc("respawn_age",value)
	for value in [-1,0.5,"100",null]: bad_npc("brain_seed",value)
	for value in [0.5,"100",null]: bad_npc("brain_rng_state",value)
	for value in [0,"true",null]: bad_npc("active",value)
	bad_npc("future_gameplay",{"attack":true})
	check(receiver.restore_snapshot(baseline),"all rejected snapshots leave receiver able to accept valid state")
	var before: Dictionary=receiver.capture_snapshot()
	receiver.npc_fishes[0].position+=Vector2(1,0)
	check(before.state.npc_fishes[0].position!=receiver.npc_fishes[0].position,"captured nested NPC state is detached from live world")
	source.free()

func _initialize() -> void:
	receiver=World.new(); receiver.reset_world({"seed":9,"npc_count":0})
	replay_checks(); malformed_checks()
	receiver.free()
	print("PHASE03_NPC_SNAPSHOT_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
