extends SceneTree

const Brain=preload("res://scripts/npc_fish_brain.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Rules=preload("res://scripts/game_rules.gd")
const Layout=preload("res://scripts/pond_layout.gd")
const Profile=preload("res://scripts/food_profile.gd")
var rules: Dictionary=Rules.defaults()
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_SOCIAL_BRAIN_FAIL | "+label)

func npc(position: Vector2=Vector2(200,200), satiety: float=70.0) -> Dictionary:
	var record:=State.fresh(2,19,position,Vector2.RIGHT,23)
	record.satiety=satiety
	return record

func bait(position: Vector2=Vector2(300,200), speed: float=0.0, id: int=3) -> Dictionary:
	var profile:=Profile.get_profile("cluster")
	return {"bait_id":id,"band":"medium","distance":100.0,"food_position":position,"has_attached_food":true,
		"hints":{"approx_position":position.snapped(Vector2.ONE*16),"shape":"grain_cluster","smell":"food",
		"shape_hint":profile.shape_hint,"smell_hint":profile.smell_hint,
		"motion":{"velocity":Vector2(speed,0),"water_drift":Vector2.ZERO,"suction_displacement":Vector2.ZERO},
		"disturbances":{"recent_motion":false,"loose_grains":0}}}

func cue(feeding: bool=true, position: Vector2=Vector2(320,200), mouth: Vector2=Vector2(310,200), id: int=1) -> Dictionary:
	return {"feeding_fish":[{"fish_id":id,"position":position,"mouth":mouth,"feeding":feeding}],"danger_events":[]}

func observation(record: Dictionary, foods: Array, social: Dictionary={}, tick: int=60) -> Dictionary:
	var entries: Array=[]
	for food: Dictionary in foods:
		var copy:=food.duplicate(true)
		if copy.food_position is Vector2: copy.distance=Vector2(record.position).distance_to(copy.food_position)
		entries.append(copy)
	return {"tick":tick,"self":State.observer(record,rules),"perceived_baits":entries,"social_cues":social.duplicate(true)}

func environment(social: bool=true, foraging: bool=true) -> Dictionary:
	return {"bounds":Layout.fish_bounds(State.RADIUS),"neighbors":[],"foraging_enabled":foraging,"social_enabled":social}

func decide(record: Dictionary, foods: Array, social: Dictionary={}, tick: int=60, enabled: bool=true) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=98
	return Brain.decide(observation(record,foods,social,tick),record.duplicate(true),environment(enabled),rules,State.DECISION_SECONDS,rng)

func apply(record: Dictionary, intent: Dictionary) -> void:
	record.behavior_state=String(intent.state)
	record.target_bait_id=int(intent.target_bait_id)
	record.steering=Vector2(intent.move)
	record.intent_aim=Vector2(intent.aim).normalized()
	record.wander_heading=Vector2(intent.wander_heading)
	record.turn_age=float(intent.turn_age)
	record.feeding=bool(intent.suck)
	record.power=float(intent.power) if record.feeding else 0.0
	record.suspicion_by_bait=intent.values
	record.caution_by_bait=intent.bands
	record.focus_bait_id=int(intent.focus_bait_id)
	record.risk_tolerance=float(intent.risk_tolerance)
	record.caution_state=String(intent.caution_state)
	for key: String in State.SOCIAL_MEMORY_FIELDS: record[key]=intent[key]

func observation_checks() -> void:
	var record:=npc()
	var still:=decide(record,[bait()])
	check(still.state=="APPROACH_FOOD","quiet ordinary food keeps existing approach")
	var mild:=decide(record,[bait(Vector2(300,200),6.0)])
	check(mild.state=="HESITATE" and mild.target_bait_id==3 and not mild.suck,"observed mild motion produces nonfeeding investigation")
	check(Vector2(mild.move).length()<=0.320001 and Vector2(mild.aim).dot(Vector2.RIGHT)>0.99,"hesitation slows/circles while looking at the observed source")
	var severe:=decide(record,[bait(Vector2(300,200),22.0)])
	check(severe.state=="FLEE" and severe.target_bait_id==-1 and not severe.suck,"strong observed motion produces bounded fleeing, not intake")
	check(Vector2(severe.move).dot(Vector2.LEFT)>0.99 and is_equal_approx(Vector2(severe.move).length(),1.0),"flee intent moves away at existing maximum swim speed")
	var full:=npc(Vector2(200,200),100.0)
	check(decide(full,[bait(Vector2(300,200),22.0)]).state=="FLEE","public danger remains observable when appetite is full")
	var quiet_water:=bait(); quiet_water.hints.motion.velocity=Vector2(40,0); quiet_water.hints.motion.water_drift=Vector2(40,0)
	check(decide(record,[quiet_water])==still,"matching water drift is not abnormal motion")
	var suction_only:=bait(); suction_only.hints.motion.suction_displacement=Vector2(50,0); suction_only.hints.disturbances.loose_grains=8
	check(decide(record,[suction_only])==still,"suction displacement and loose grains alone do not mean danger")
	var disturbed:=bait(); disturbed.hints.disturbances.recent_motion=true
	check(decide(record,[disturbed]).state=="HESITATE","recent observed disturbance warrants a brief look")
	check(decide(record,[bait(Vector2(361,200),22.0)]).state not in ["HESITATE","FLEE"],"reaction is bounded to nearby evidence even when a distant food is visible")
	var unknown:=bait(); unknown.hints={"approx_position":Vector2(304,208),"approx_size":12.0}
	check(decide(record,[unknown]).state=="APPROACH_FOOD","missing motion detail is not filled in as danger or certainty")
	var hidden:=bait(); hidden.hook=true; hidden.truth="dangerous"; hidden.hints.private_caution="ALARMED"
	check(decide(record,[hidden])==still,"unrecognized hidden fields have no behavioral influence")
	var public_danger: Dictionary={"danger_events":[{"tick":60,"position":Vector2(230,200)}]}
	var reaction:=decide(record,[],public_danger)
	check(reaction.state=="FLEE" and reaction.social_danger_tick==60 and reaction.social_bait_id==-1,"actual public danger can cause flight without a known food identity")
	for event: Dictionary in [{"tick":14,"position":Vector2(230,200)},{"tick":61,"position":Vector2(230,200)},{"tick":60,"position":Vector2(351,200)},{"tick":-1,"position":Vector2(230,200)},{"tick":60,"position":Vector2(NAN,200)}]:
		check(decide(record,[],{"danger_events":[event]}).state=="WANDER","old, future, distant, absent and nonfinite danger events are ignored")
	check(decide(record,[],{"danger_events":[{"tick":15,"position":Vector2(350,200)}]}).state=="FLEE","freshness and distance boundaries accept a valid observable event")
	var stale:=record.duplicate(true); stale.social_danger_tick=60
	check(decide(stale,[],public_danger).state=="WANDER","same public outcome is never repeatedly consumed")
	var bank:=npc(Layout.fish_bounds(State.RADIUS).position+Vector2(1,40))
	var escape:=decide(bank,[],{"danger_events":[{"tick":60,"position":bank.position+Vector2(10,0)}]})
	check(Vector2(escape.move).length()>0.99 and absf(Vector2(escape.move).y)>0.99,"flight at a bank chooses an available tangent instead of persisting out of bounds")

func competition_checks() -> void:
	var record:=npc(Vector2(200,200),25.0)
	var result:=decide(record,[bait()],cue())
	check(result.state=="COMPETE" and result.target_bait_id==3 and not result.suck,"hungry fish approaches food another fish visibly feeds near")
	check(Vector2(result.move).dot(Vector2.RIGHT)>0.9 and result.social_compete_left==State.COMPETE_SECONDS,"competition remains purposeful approach with bounded public-cue memory")
	for social: Dictionary in [cue(false),cue(true,Vector2(361,200)),cue(true,Vector2(320,200),Vector2(500,200)),cue(true,Vector2(320,200),Vector2(310,200),2),{}]:
		check(decide(record,[bait()],social).state=="APPROACH_FOOD","false, remote, noncontesting, own and missing feeding cues do not create competition")
	check(decide(npc(),[bait()],cue()).state=="APPROACH_FOOD","ordinary appetite is not driven into competition")
	check(decide(record,[],cue()).state=="WANDER","a visible feeder cannot reveal unobserved food")
	var lying:=cue(); lying.feeding_fish[0].target_bait_id=999; lying.feeding_fish[0].caution_state="ALARMED"; lying.feeding_fish[0].satiety=0
	check(decide(record,[bait()],lying)==result,"another fish's private state and intended target are ignored")
	apply(record,result)
	check(State.valid(record,3),"competition private memory is valid")
	for tick in 4:
		result=decide(record,[bait()],{},60+tick*8); apply(record,result)
		check(result.state=="COMPETE" and State.valid(record,3),"short feeder action/rest gaps keep the same contested target")
	for tick in 3:
		result=decide(record,[bait()],{},100+tick*8); apply(record,result)
	check(result.state=="APPROACH_FOOD" and record.social_compete_left==0.0,"expired social memory returns to ordinary approach")
	record=npc(Vector2(264,200),25.0)
	var competing_feed:=0; var baseline_feed:=0
	for tick in 96:
		var actual:=decide(record,[bait()],cue(),tick)
		var baseline:=decide(record,[bait()],cue(),tick,false)
		if actual.state=="FEED": competing_feed+=1
		if baseline.state=="FEED": baseline_feed+=1
		check(actual.move==baseline.move and actual.aim==baseline.aim and actual.suck==baseline.suck,"competition preserves arrival geometry, physical intent and feeding duty")
	check(competing_feed==baseline_feed and competing_feed>0 and competing_feed<96,"competition reaches exactly the accepted appetite feeding windows")
	record=npc(Vector2(200,200),25.0)
	var left:=bait(Vector2(299,200),0.0,3); var right:=bait(Vector2(301,200),0.0,4)
	result=decide(record,[right,left],cue()); apply(record,result)
	var target:=int(record.target_bait_id)
	for tick in 100:
		left.food_position.x=300.0+sin(tick)*2.0; right.food_position.x=300.0-sin(tick)*2.0
		result=decide(record,[right,left] if tick%2==0 else [left,right],cue(),tick); apply(record,result)
		check(record.target_bait_id==target,"small public distance/action variation does not thrash a contested target")
	result=decide(record,[right] if target==3 else [left],cue()); apply(record,result)
	check(record.target_bait_id!=target and State.valid(record,3),"disappearing contested food promptly releases its stale target")
	result=decide(record,[],{}); apply(record,result)
	check(record.behavior_state=="WANDER" and record.target_bait_id==-1 and record.social_compete_left==0.0 and State.valid(record,3),"missing perception safely clears competition without phantom feeding")

func recovery_checks() -> void:
	for speed: float in [6.0,22.0]:
		var record:=npc()
		var starts:=0; var reacting_ticks:=0
		for tick in 160:
			var result:=decide(record,[bait(Vector2(300,200),speed)],{},tick*8)
			if result.state in ["HESITATE","FLEE"]:
				reacting_ticks+=1
				if record.behavior_state not in ["HESITATE","FLEE"]: starts+=1
			apply(record,result)
			check(State.valid(record,3),"continuous cue sequence always satisfies private-state guard")
		check(starts==1 and reacting_ticks<=11,"a continuous motion cue cannot renew hesitation/flight forever")
		for tick in 160:
			var result:=decide(record,[bait()],{},1300+tick*8); apply(record,result)
		check(record.behavior_state in ["APPROACH_FOOD","FEED"] and record.social_reaction_left==0.0 and record.social_recovery_left==0.0,"quiet evidence decays and ordinary foraging recovers")
		var result:=decide(record,[bait(Vector2(300,200),speed)],{},2700)
		check(result.state==("FLEE" if speed>=18 else "HESITATE"),"new motion after quiet recovery can elicit a new bounded response")
	var record:=npc()
	apply(record,decide(record,[bait(Vector2(300,200),6.0)]))
	var result:=decide(record,[bait(Vector2(300,200),22.0)])
	check(result.state=="FLEE","a stronger observed cue can interrupt mild investigation")
	apply(record,result)
	for tick in 14:
		result=decide(record,[],{},68+tick*8); apply(record,result)
		check(State.valid(record,3) and record.target_bait_id==-1,"missing perception during a reaction expires without stale target references")
	check(record.behavior_state=="WANDER" and record.social_origin==Vector2.ZERO and record.social_bait_id==-1,"flight completely releases short-lived source geometry")
	result=decide(record,[bait(Vector2(300,200),22.0)],{},200)
	check(result.state!="FLEE","brief quiet/reappearance during recovery cannot start another flight")
	apply(record,result)
	result=decide(record,[],{"danger_events":[{"tick":201,"position":Vector2(210,200)}]},201)
	check(result.state=="FLEE" and result.social_danger_tick==201,"a genuinely new public outcome can interrupt recovery")
	apply(record,result)
	for tick in 120:
		result=decide(record,[],{"danger_events":[{"tick":201,"position":Vector2(210,200)}]},209+tick*8); apply(record,result)
		check(State.valid(record,3),"expired public outcome leaves only valid decaying private memory")
	check(record.behavior_state=="WANDER" and record.social_recovery_left==0.0,"repeated delivery of the same outcome does not prevent recovery")

func isolation_checks() -> void:
	var record:=npc(Vector2(200,200),25.0)
	var view:=observation(record,[bait(Vector2(300,200),22.0)],cue())
	var env:=environment()
	var before:=var_to_bytes([view,record,env,rules])
	var a:=RandomNumberGenerator.new(); a.seed=151
	var b:=RandomNumberGenerator.new(); b.seed=151
	for tick in 180:
		var actual:=Brain.decide(view,record,env,rules,State.DECISION_SECONDS,a)
		var baseline:=Brain.decide(view,record,environment(false),rules,State.DECISION_SECONDS,b)
		check(a.state==b.state and actual.wander_heading==baseline.wander_heading and actual.turn_age==baseline.turn_age,"social decisions preserve the exact cruise random stream")
	check(before==var_to_bytes([view,record,env,rules]),"social interpretation cannot mutate inputs or physiology")
	var absent:=observation(record,[bait()]); absent.erase("social_cues")
	var disabled:=Brain.decide(absent,record,environment(false),rules,State.DECISION_SECONDS,a)
	check(disabled.state=="APPROACH_FOOD" and disabled.social_reaction_left==0.0 and disabled.social_compete_left==0.0,"diagnostic social switch leaves plain P3.2 feeding available")
	for key: String in State.SOCIAL_MEMORY_FIELDS:
		check(not State.observer(record,rules).has(key),"private social memory is absent from public self: "+key)
	var passive_a:=RandomNumberGenerator.new(); passive_a.seed=151
	var passive_b:=RandomNumberGenerator.new(); passive_b.seed=151
	var on:=Brain.decide(view,record,environment(true,false),rules,State.DECISION_SECONDS,passive_a)
	var off:=Brain.decide(view,record,environment(false,false),rules,State.DECISION_SECONDS,passive_b)
	check(var_to_bytes(on)==var_to_bytes(off) and passive_a.state==passive_b.state,"disabled foraging ignores social cues byte-for-byte, including random state")

func guard_checks() -> void:
	var record:=npc()
	for state: String in ["HESITATE","FLEE","COMPETE"]:
		var fixture:=npc(Vector2(200,200),25.0)
		var result:=decide(fixture,[bait(Vector2(300,200),6.0 if state=="HESITATE" else (22.0 if state=="FLEE" else 0.0))],cue() if state=="COMPETE" else {})
		apply(fixture,result)
		check(fixture.behavior_state==state and State.valid(fixture,3),"valid intent creates a strict current-shape "+state+" record")
		for field: String in State.SOCIAL_MEMORY_FIELDS:
			var bad:=fixture.duplicate(true); bad.erase(field)
			check(not State.valid(bad,3),"social records never silently migrate a missing private field: "+field)
		var copied: Dictionary=bytes_to_var(var_to_bytes(fixture))
		check(State.valid(copied,3) and copied==fixture,"social memory round-trips byte serialization")
	for field: String in ["social_reaction_left","social_recovery_left","social_compete_left"]:
		for value in [NAN,INF,-0.01,4.0,0,"0"]:
			var bad:=record.duplicate(true); bad[field]=value
			check(not State.valid(bad,3),"strict timer scalar rejects malformed "+field)
	for pair: Array in [["social_origin",Vector2(NAN,0)],["social_origin",Vector2(INF,0)],["social_origin",Vector2(1,0)],["social_origin",0],["social_bait_id",0],["social_bait_id",-2],["social_bait_id",3],["social_bait_id",-1.0],["social_motion_level",-1],["social_motion_level",3],["social_motion_level",1.0],["social_danger_tick",-2],["social_danger_tick",0.0],["social_reaction_left",0.1],["social_compete_left",0.1],["behavior_state","HESITATE"],["behavior_state","FLEE"],["behavior_state","COMPETE"],["behavior_state","WRAPPED"],["behavior_state","CAPTURED"]]:
		var bad:=record.duplicate(true); bad[pair[0]]=pair[1]
		check(not State.valid(bad,3),"strict semantic/type guard rejects inconsistent social record: "+str(pair))
	# P3.4 admits the local Hook state; world_snapshot separately requires the
	# matching single-line target/phase and rejects orphan HOOKED records.
	var hooked_record:=record.duplicate(true); hooked_record.behavior_state="HOOKED"
	check(State.valid(hooked_record,3),"P3.4 Hook record shape is valid; target association belongs to the world guard")
	apply(record,decide(record,[bait(Vector2(300,200),6.0)]))
	for pair: Array in [["feeding",true],["target_bait_id",4],["social_bait_id",-1],["social_reaction_left",1.0],["social_recovery_left",0.0],["social_compete_left",0.1]]:
		var bad:=record.duplicate(true); bad[pair[0]]=pair[1]
		check(not State.valid(bad,3),"hesitation rejects impossible food/action/recovery relations")

func _initialize() -> void:
	observation_checks(); competition_checks(); recovery_checks(); isolation_checks(); guard_checks()
	print("PHASE03_NPC_SOCIAL_BRAIN_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
