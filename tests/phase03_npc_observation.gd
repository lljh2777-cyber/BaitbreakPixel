extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("NPC_OBSERVATION_PASS | ",label)
	else: failed+=1; push_error("NPC_OBSERVATION_FAIL | "+label)

# Frozen 0.24.6 builder: explicitly checks field/value/insertion-order compatibility,
# rather than merely comparing two wrappers around the new implementation.
func legacy_build(world: Node2D, include_visuals: bool = true) -> Dictionary:
	var observed: Array[Dictionary]=[]
	var fish_position: Vector2=world.fish
	for bait: Dictionary in world.baits:
		var facts:=Observation._facts(bait,fish_position,world.map_context.water)
		if facts.visible_count==0: continue
		var food: Variant=facts.food_position
		var distance: float=fish_position.distance_to(Vector2(food) if food is Vector2 else Vector2(facts.pos))
		var band:=Observation.distance_band(distance)
		var hints:=Observation._hints(facts,band,world.water_velocity(facts.pos))
		if hints.has("motion"): hints.motion.velocity=Vector2(bait.get("motion_velocity",Vector2.ZERO))
		if hints.has("disturbances"): hints.disturbances.recent_motion=int(world.simulation_tick)-int(bait.get("last_disturbance_tick",-1000))<=60
		var entry: Dictionary={"bait_id":int(bait.bait_id),"band":band,"distance":distance,
			"hints":hints,"has_attached_food":facts.attached,"food_position":food}
		if include_visuals: entry.visual=Observation._visual(bait,facts)
		observed.append(entry)
	return {"tick":int(world.simulation_tick),
		"self":{"fish_id":int(world.fish_id),"position":fish_position,"mouth":world.mouth(),
			"aim":Vector2(world.aim),"velocity":Vector2(world.velocity),"stamina":float(world.stamina),"stamina_ratio":world.stamina_ratio(),"caution_state":world.caution_state,"satiety":float(world.satiety),"satiety_band":world.satiety_band(),"instinct_drive":float(world.instinct_drive),
			"score":float(world.score),"power":float(world.power),"feeding":bool(world.feeding)},
		"perceived_baits":observed}


func private_free(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["hook","hook_id","rng_seed","rng_state","brain_seed","brain_rng_state","target_bait_id","focus_bait_id","suspicion_by_bait","caution_by_bait","risk_tolerance","decision_weights","future_secret","behavior_state","behavior_age"]: return false
			if not private_free(value[key]): return false
	elif value is Array:
		for item in value:
			if not private_free(item): return false
	return true

func place(world: Node2D, index: int, position: Vector2) -> void:
	var bait: Dictionary=world.baits[index]
	bait.active=true; bait.pos=position; bait.angle=0.0; bait.suction_offset=Vector2.ZERO
	for grain: Dictionary in bait.grains:
		grain.eaten=false; grain.free=false; grain.pos=position+Vector2(grain.offset)

func _initialize() -> void:
	for seed_value: int in [1,93,731,3184]:
		var world:=World.new(); world.reset_world({"seed":seed_value})
		for hunger: bool in [true,false]:
			world.rules.hunger_enabled=hunger
			for satiety: float in [0.0,10.0,30.0,80.0,100.0]:
				world.satiety=satiety
				world.fish=Vector2(250,200); world.fish_before=world.fish
				world.aim=Vector2.RIGHT.rotated(satiety/100.0)
				world.velocity=Vector2(25,-7); world.stamina=world.rule("stamina_max")*0.37
				world.score=6.5; world.feeding=true; world.power=0.73
				place(world,0,world.fish+Vector2(30,0)); place(world,1,world.fish+Vector2(100,0)); place(world,2,world.fish+Vector2(200,0))
				world.baits[3].active=false
				world.baits[3].grains[0].free=true; world.baits[3].grains[0].pos=Vector2(275,225)
				var before: PackedByteArray=var_to_bytes(world.capture_snapshot())
				for visuals: bool in [true,false]:
					var legacy:=legacy_build(world,visuals)
					var current:=Observation.build(world,visuals)
					check(var_to_bytes(legacy)==var_to_bytes(current),"legacy_player_observation_equivalence seed=%d hunger=%s satiety=%s visuals=%s" % [seed_value,hunger,satiety,visuals])
					check(Protocol.safe_values(current) and private_free(current),"player observation remains serializable and private")
				check(before==var_to_bytes(world.capture_snapshot()),"player observation never mutates world/RNG/allocators")
		world.free()
	observer_checks()
	print("PHASE03_NPC_OBSERVATION_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)

func observer_checks() -> void:
	var world:=World.new(); world.reset_world({"seed":905})
	world.fish=Vector2(700,300)
	for bait: Dictionary in world.baits: bait.active=false
	place(world,0,Vector2(290,200)); place(world,1,Vector2(380,200)); place(world,2,Vector2(520,200))
	var observer: Dictionary={"fish_id":27,"position":Vector2(270,200),"mouth":Vector2(280,200),"aim":Vector2.RIGHT,
		"velocity":Vector2(8,1),"stamina":87.0,"stamina_ratio":0.87,"caution_state":"CALM","satiety":45.0,
		"satiety_band":"NORMAL","instinct_drive":0.0,"score":0.0,"power":0.0,"feeding":false,
		"brain_seed":813,"brain_rng_state":441,"risk_tolerance":0.8,"future_secret":{"hook":true}}
	var before: PackedByteArray=var_to_bytes(world.capture_snapshot())
	var input_before:=observer.duplicate(true)
	var observed:=Observation.build_for(world,observer)
	check(observed["self"].keys()==Observation.SELF_FIELDS and observed["self"].fish_id==27 and observed["self"].position==observer.position,"explicit NPC observer retains its own identity and public self")
	check(private_free(observed) and before==var_to_bytes(world.capture_snapshot()) and observer==input_before,"build_for has no private/nested observer leakage or side effects")
	check(observed.perceived_baits[0].band=="near" and observed.perceived_baits[1].band=="medium" and observed.perceived_baits[2].band=="far","NPC distance bands originate at observer rather than player position")
	check(observed.perceived_baits[0].distance==20.0,"NPC measures exact public food distance")
	var hints:=Observation.build_for(world,observer,false)
	var stripped:=observed.duplicate(true)
	for bait: Dictionary in stripped.perceived_baits: bait.erase("visual")
	check(var_to_bytes(hints)==var_to_bytes(stripped),"NPC hint-only mode preserves decision fields and order")
	# Alter every player-private value, hidden hook truth and NPC-local randomness.
	world.suspicion_by_bait={1:1.0}; world.caution_by_bait={1:"ALARMED"}; world.risk_tolerance=0.01
	world.fish=Vector2(1000,370); world.satiety=0.0; world.stamina=0.0; world.aim=Vector2.DOWN
	world.rng.seed=9017; world.rng.state=9018
	for bait: Dictionary in world.baits:
		bait.hook=not bait.hook; bait.hook_id+=1000; bait.future_secret={"target_bait_id":1}
	observer.brain_seed=991; observer.brain_rng_state=992; observer.risk_tolerance=0.01
	check(var_to_bytes(Observation.build_for(world,observer))==var_to_bytes(observed),"NPC observation is invariant to hidden hook truth, both RNG streams and player private state")
	observer.position=Vector2(90,250)
	check(observed["self"].position==Vector2(270,200),"held observation stays detached after caller moves observer")
	observed["self"].position=Vector2(20,20); observed.perceived_baits[0].visual.grains[0].pos=Vector2.ZERO
	check(world.baits[0].grains[0].pos!=Vector2.ZERO and observer.position==Vector2(90,250),"mutating NPC observation cannot alter source records")
	world.baits[0].active=false
	for grain: Dictionary in world.baits[0].grains: grain.eaten=true
	var loose: Dictionary=world.baits[0].grains[0]
	loose.eaten=false; loose.free=true; loose.pos=Vector2(92,250)
	check(Observation.find(Observation.build_for(world,observer),world.baits[0].bait_id).food_position==loose.pos,"inactive bait nearest loose grain uses NPC observer")
	world.free()
