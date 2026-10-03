extends SceneTree

const Brain=preload("res://scripts/npc_fish_brain.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Rules=preload("res://scripts/game_rules.gd")
const Layout=preload("res://scripts/pond_layout.gd")
const Profile=preload("res://scripts/food_profile.gd")
var passed:=0
var failed:=0
var rules: Dictionary=Rules.defaults()

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_FORAGING_BRAIN_FAIL | "+label)

func npc(position: Vector2=Vector2(264,200), satiety: float=70.0) -> Dictionary:
	var result:=State.fresh(2,19,position,Vector2.RIGHT,23)
	result.satiety=satiety
	return result

func bait(position: Vector2=Vector2(300,200), kind: String="cluster", id: int=3) -> Dictionary:
	var profile:=Profile.get_profile(kind)
	return {"bait_id":id,"band":"near","distance":36.0,"food_position":position,"has_attached_food":true,
		"hints":{"approx_position":position.snapped(Vector2.ONE*16),"shape":"grain_cluster","smell":"food",
		"shape_hint":profile.shape_hint,"smell_hint":profile.smell_hint,
		"motion":{"velocity":Vector2.ZERO,"water_drift":Vector2.ZERO,"suction_displacement":Vector2.ZERO},
		"disturbances":{"recent_motion":false,"loose_grains":0}}}

func observation(record: Dictionary, foods: Array, tick: int=0) -> Dictionary:
	var entries: Array=[]
	for food: Dictionary in foods:
		var copy:=food.duplicate(true)
		copy.distance=Vector2(record.position).distance_to(copy.food_position)
		entries.append(copy)
	return {"tick":tick,"self":State.observer(record,rules),"perceived_baits":entries}

func environment(enabled: bool=true) -> Dictionary:
	return {"bounds":Layout.fish_bounds(State.RADIUS),"neighbors":[],"foraging_enabled":enabled}

func decide(record: Dictionary, foods: Array, tick: int=0, enabled: bool=true) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=98
	return Brain.decide(observation(record,foods,tick),record.duplicate(true),environment(enabled),rules,State.DECISION_SECONDS,rng)

# Independent P3.1 cruise fixture, intentionally not calling any Brain helper.
func legacy_wander(view: Dictionary, memory: Dictionary, env: Dictionary, delta: float, rng: RandomNumberGenerator) -> Dictionary:
	var self_state: Dictionary=view.self
	var heading: Vector2=memory.wander_heading
	var turn_age:=maxf(0.0,float(memory.turn_age)-delta)
	if turn_age<=0:
		heading=heading.rotated(rng.randf_range(-0.85,0.85)).normalized()
		turn_age=rng.randf_range(1.6,3.8)
	var position: Vector2=self_state.position
	var bounds: Rect2=env.bounds
	var projected:=position+Vector2(self_state.velocity)*0.9
	var avoidance:=Vector2.ZERO
	var margin:=65.0
	avoidance.x=clampf((bounds.position.x+margin-projected.x)/margin,0,1)-clampf((projected.x-bounds.end.x+margin)/margin,0,1)
	avoidance.y=clampf((bounds.position.y+margin-projected.y)/margin,0,1)-clampf((projected.y-bounds.end.y+margin)/margin,0,1)
	if avoidance.length()>0.05: heading=heading.lerp(avoidance.normalized(),0.28).normalized()
	var separation:=Vector2.ZERO
	for neighbor: Dictionary in env.neighbors:
		if int(neighbor.fish_id)==int(self_state.fish_id): continue
		var offset:=position-Vector2(neighbor.position)
		var distance:=offset.length()
		var radius:=55.0 if int(neighbor.fish_id)==1 else 38.0
		if distance<radius:
			var direction:=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(float(self_state.fish_id)*2.399963)
			separation+=direction*(1.0-distance/radius)
	var steer: Vector2=(heading+avoidance*2.6+separation*1.4).normalized()
	return {"move":steer,"aim":steer,"suck":false,"state":"WANDER","target_bait_id":-1,
		"wander_heading":heading,"turn_age":turn_age}

func passive_checks() -> void:
	var a:=RandomNumberGenerator.new(); a.seed=151
	var b:=RandomNumberGenerator.new(); b.seed=151
	var record:=npc(Vector2(40,95),100.0)
	var env:=environment(false)
	env.neighbors=[{"fish_id":1,"position":Vector2(45,98)},{"fish_id":2,"position":record.position},{"fish_id":3,"position":record.position}]
	for tick in 160:
		record.velocity=Vector2.LEFT.rotated(float(tick)*0.02)*State.SPEED
		var view:=observation(record,[bait()],tick)
		var previous:=var_to_bytes(record)
		var expected:=legacy_wander(view,record,env,State.DECISION_SECONDS,a)
		var actual:=Brain.decide(view,record,env,rules,State.DECISION_SECONDS,b)
		check(var_to_bytes(actual)==var_to_bytes(expected) and a.state==b.state,"disabled foraging preserves P3.1 movement and local RNG exactly")
		check(previous==var_to_bytes(record),"passive brain never changes own physiology/memory")
		record.wander_heading=actual.wander_heading; record.turn_age=actual.turn_age
	# Enabling a decision uses no extra RNG and cannot alter a caller's values.
	var view:=observation(record,[bait()])
	var before:=var_to_bytes([view,record,env,rules])
	Brain.decide(view,record,environment(true),rules,State.DECISION_SECONDS,a)
	Brain.decide(view,record,environment(false),rules,State.DECISION_SECONDS,b)
	check(a.state==b.state,"foraging does not add random draws")
	check(before==var_to_bytes([view,record,env,rules]),"decision inputs remain detached and unchanged")

func intent_checks() -> void:
	var record:=npc()
	check(record.satiety==70.0 and not record.feeding and record.power==0.0 and record.bite_cooldown==0.0,"fresh fish starts ready for P3.2 with independent physiology")
	var result:=decide(record,[bait()],0)
	check(result.state in ["APPROACH_FOOD","FEED"] and result.target_bait_id==3,"ordinary fish acquires a nearby public food target")
	check(result.values.has(3) and result.bands.has(3) and result.focus_bait_id==3,"brain returns own per-food interpretation")
	check(decide(npc(Vector2(200,200),100.0),[bait()]).state=="WANDER","full fish does not commit to food")
	check(decide(record,[]).state=="WANDER" and decide(record,[]).target_bait_id==-1,"disappearing target returns to wandering")
	var distant:=bait(Vector2(650,200))
	check(decide(npc(Vector2(264,200),70.0),[distant]).state=="WANDER","ordinary appetite has bounded seek range")
	check(decide(npc(Vector2(264,200),20.0),[distant]).state=="APPROACH_FOOD","hungry fish seeks farther food")
	var uneasy:=npc()
	uneasy.suspicion_by_bait={3:0.60}; uneasy.caution_by_bait={3:"ALARMED"}
	check(decide(uneasy,[bait()]).state=="WANDER","own suspicion can outweigh normal appetite")
	uneasy.satiety=5.0
	check(decide(uneasy,[bait()]).state!="WANDER","starving fish accepts more perceived risk without gaining true knowledge")
	var mild_count:=0; var hungry_count:=0
	for tick in 96:
		var mild:=npc(Vector2(264,200),70.0); mild.behavior_state="APPROACH_FOOD"
		var hungry:=npc(Vector2(264,200),10.0); hungry.behavior_state="APPROACH_FOOD"
		if decide(mild,[bait()],tick).state=="FEED": mild_count+=1
		if decide(hungry,[bait()],tick).state=="FEED": hungry_count+=1
	check(mild_count>0 and mild_count<hungry_count and hungry_count<96,"appetite increases feed duty while preserving rest windows")
	for kind: String in Profile.TYPES:
		check(Brain.observed_kind(bait(Vector2(300,200),kind))==kind,"food type derives from public profile cues: "+kind)
	var far:=bait(); far.hints={"approx_position":Vector2(304,208),"approx_size":12.0}
	check(Brain.observed_kind(far)=="unknown","far observation cannot fill in an unseen type")
	var saw_suction:=false; var saw_bite:=false
	for tick in 96:
		result=decide(record,[bait()],tick)
		if result.state=="FEED": saw_suction=saw_suction or bool(result.suck)
		result=decide(npc(Vector2(285,200)),[bait(Vector2(300,200),"chunk")],tick)
		if result.state=="FEED": saw_bite=saw_bite or not bool(result.suck)
	check(saw_suction and saw_bite,"cluster and chunk cues produce suction and close-bite intents")
	var moving:=npc(Vector2(265,200)); moving.velocity=Vector2(30,0)
	check(Vector2(decide(moving,[bait()]).move).x<0,"arrival actively damps forward drift instead of snapping")
	var choice_a:=decide(record,[bait(Vector2(300,200),"cluster",5),bait(Vector2(300,200),"cluster",4)])
	var choice_b:=decide(record,[bait(Vector2(300,200),"cluster",4),bait(Vector2(300,200),"cluster",5)])
	check(choice_a==choice_b and choice_a.target_bait_id==4,"equal food choices resolve by stable public identity")
	var source:=FileAccess.get_file_as_string("res://scripts/npc_fish_brain.gd")
	for forbidden: String in ["world.",".hook","truth_events","_enter_hook","_attach_hook","refill_hook_bait","HOOKED","CAPTURED","respawn"]:
		check(not source.contains(forbidden),"brain avoids authority/future-capture dependency: "+forbidden)

func state_checks() -> void:
	var record:=npc()
	check(State.valid(record,3),"new record passes strict guard")
	record.satiety=100.0
	check(State.valid(record,3),"explicit current-shape WANDER/100 record remains valid")
	for value: float in [100.0,60.0,25.0,10.0,0.0]:
		record.satiety=value
		var observer:=State.observer(record,rules)
		var expected: String="STARVING" if value<=10 else ("CRITICAL" if value<=25 else ("HUNGRY" if value<=60 else "NORMAL"))
		check(observer.satiety_band==expected,"observer satiety band matches shared player thresholds")
	record.feeding=true; record.power=0.4
	var observed:=State.observer(record,rules)
	check(observed.mouth==record.position+record.aim*10.0 and observed.feeding and observed.power==0.4,"public self uses the player's mouth geometry and own feeding/power")
	var no_hunger:=rules.duplicate(true); no_hunger.hunger_enabled=false
	check(State.observer(record,no_hunger).satiety_band=="NORMAL","disabled hunger reports NORMAL like player")
	record=npc(); record.behavior_state="FEED"; record.target_bait_id=3; record.focus_bait_id=3
	record.suspicion_by_bait={3:0.2}; record.caution_by_bait={3:"CALM"}; record.feeding=true; record.power=0.35; record.bite_cooldown=0.8
	check(State.valid(record,3),"legal food intent and shared cooldown restore")
	for field: String in ["satiety","power","bite_cooldown","risk_tolerance"]:
		for value in [NAN,INF,-0.01,"0",0]:
			var bad:=record.duplicate(true); bad[field]=value
			check(not State.valid(bad,3),"reject malformed finite scalar "+field+"="+str(value))
	for pair: Array in [["satiety",100.01],["power",1.01],["bite_cooldown",0.81],["risk_tolerance",0.61],["feeding",1],["intent_aim",Vector2.ZERO],["intent_aim",Vector2(NAN,0)],["behavior_state","HOOKED"],["suspicion_by_bait",{3:NAN}],["suspicion_by_bait",{"3":0.2}],["suspicion_by_bait",{3:1}],["caution_by_bait",{3:"SECRET"}],["caution_by_bait",{}],["focus_bait_id",8],["target_bait_id",8]]:
		var bad:=record.duplicate(true); bad[pair[0]]=pair[1]
		check(not State.valid(bad,3),"reject illegal NPC shape or range: "+str(pair))
	for key: String in ["feeding","power","bite_cooldown","intent_aim"]:
		var bad:=record.duplicate(true); bad.erase(key)
		check(not State.valid(bad,3),"missing new fields never silently migrate: "+key)

func _initialize() -> void:
	passive_checks(); intent_checks(); state_checks()
	print("PHASE03_NPC_FORAGING_BRAIN_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
