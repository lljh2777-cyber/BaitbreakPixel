extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("OBSERVATION_PASS | ",label)
	else: failed+=1; push_error("OBSERVATION_FAIL | "+label)

func place(world: Node2D, slot: int, position: Vector2) -> void:
	var bait: Dictionary=world.baits[slot]
	bait.active=true; bait.pos=position; bait.angle=0.0; bait.suction_offset=Vector2.ZERO
	for grain: Dictionary in bait.grains:
		grain.eaten=false; grain.free=false; grain.pos=position+Vector2(grain.offset)

func contains_private(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["hook","hook_id","rod_id","rng_seed","rng_state","removed","tip_before","home","budget","points","progress","created_tick","danger","suspicion"]: return true
			if contains_private(value[key]): return true
	elif value is Array:
		for item in value:
			if contains_private(item): return true
	return false

func _initialize() -> void:
	var world:=World.new(); world.reset_world({"seed":731})
	world.fish=Vector2(250,200)
	place(world,0,Vector2(280,200)); place(world,1,Vector2(350,200)); place(world,2,Vector2(450,200))
	world.baits[3].active=false
	var before: PackedByteArray=var_to_bytes(world.capture_snapshot())
	var observation:=Observation.build(world)
	check(var_to_bytes(world.capture_snapshot())==before,"build preserves world, RNG and entity allocators")
	check(observation.keys()==["tick","self","perceived_baits"] and observation.tick==world.simulation_tick,"top-level observation contract")
	check(not contains_private(observation),"explicit whitelist excludes hidden truth and authority bookkeeping")
	check(observation.perceived_baits.size()==3,"inactive unseen food is absent")
	var near:=Observation.find(observation,world.baits[0].bait_id)
	var medium:=Observation.find(observation,world.baits[1].bait_id)
	var far:=Observation.find(observation,world.baits[2].bait_id)
	check(near.band=="near" and medium.band=="medium" and far.band=="far","distance bands use visible food distance")
	check(far.hints.keys()==["approx_position","approx_size"] and far.hints.approx_position==Vector2(448,208),"far hints expose coarse position and size only")
	check(medium.hints.has("shape") and medium.hints.smell=="food" and medium.hints.has("motion") and not medium.hints.has("disturbances"),"medium hints add shared shape, food scent and visible motion")
	check(near.hints.has("disturbances") and not near.hints.disturbances.displaced,"near hints add observable disturbances")
	check(Observation.distance_band(64)=="near" and Observation.distance_band(64.01)=="medium" and Observation.distance_band(160)=="medium" and Observation.distance_band(160.01)=="far","distance thresholds have explicit inclusive edges")
	check(near.visual.grains[0].keys()==Observation.VISUAL_GRAIN_FIELDS,"grain renderer data follows the explicit allowlist")
	check(near.has_attached_food and near.food_position==world.baits[0].pos and Observation.food_position(observation,near.bait_id)==near.food_position,"AI can target attached food using the public record")
	check(Observation.find(observation,99999).is_empty() and not Observation.food_position(observation,99999).is_finite(),"missing identity cannot target a recycled slot")
	var hint_only:=Observation.build(world,false)
	var without_visuals:=observation.duplicate(true)
	for bait: Dictionary in without_visuals.perceived_baits: bait.erase("visual")
	check(hint_only==without_visuals,"hint-only AI observation preserves all decision fields without copying visual grain records")
	check(Protocol.safe_values(observation) and Protocol.safe_values(hint_only),"both observation modes are finite serializable protocol values")

	var hidden_copy:=World.new(); hidden_copy.restore_snapshot(world.capture_snapshot())
	for bait: Dictionary in hidden_copy.baits:
		bait.hook=not bait.hook; bait.hook_id+=100; bait.rod_id+=20; bait.removed=not bait.removed
		bait.id+=10; bait.created_tick+=500; bait.home+=Vector2(99,33); bait.tip_before+=Vector2(50,70)
		bait.budget+=5; bait.age+=20
		bait.future_secret={"hidden":true}
		for grain: Dictionary in bait.grains:
			grain.id="private"; grain.points+=20; grain.progress=0.95; grain.future_secret=true
	hidden_copy.rng.seed=555; hidden_copy.rng.state=888
	check(Observation.build(hidden_copy)==observation,"changing only hidden truth, RNG and future private fields leaves observations identical")

	near.visual.grains[0].pos+=Vector2(99,99); near.hints.motion.water_drift=Vector2(200,200)
	observation["self"].position+=Vector2(80,80); observation.perceived_baits.clear()
	check(var_to_bytes(world.capture_snapshot())==before,"mutating any observation depth cannot mutate authority")
	observation=Observation.build(world)
	var first_id: int=world.baits[0].bait_id
	var held:=Observation.find(observation,first_id).duplicate(true)
	world.baits[0].grains[0].pos+=Vector2(5,0)
	check(Observation.find(observation,first_id)==held,"later authority changes cannot mutate an existing observation")
	var swap: Dictionary=world.baits[0]; world.baits[0]=world.baits[1]; world.baits[1]=swap
	check(Observation.find(Observation.build(world),first_id).visual.pos==Vector2(280,200),"stable bait identity survives authority slot reorder")

	world.baits[3].grains[0].free=true; world.baits[3].grains[0].pos=Vector2(260,210)
	var loose:=Observation.find(Observation.build(world),world.baits[3].bait_id)
	check(not loose.has_attached_food and loose.food_position==Vector2(260,210) and loose.visual.pos==Vector2(260,210) and loose.visual.grains.size()==1,"inactive bait exposes only visible loose food and its public location")
	world.baits[3].grains[0].pos=Vector2(20,-20)
	var outside:=Observation.build(world)
	check(Observation.find(outside,world.baits[3].bait_id).food_position==null and not Observation.food_position(outside,world.baits[3].bait_id).is_finite() and Protocol.safe_values(outside),"unreachable loose food remains drawable with a null target rather than nonfinite public data")
	world.baits[3].grains[0].eaten=true
	check(Observation.find(Observation.build(world),world.baits[3].bait_id).is_empty(),"eaten loose food disappears from perception")
	world.baits[0].suction_offset=Vector2(2,0)
	check(Observation.find(Observation.build(world),world.baits[0].bait_id).hints.motion.suction_displacement==Vector2(2,0),"observable suction survives the boundary unchanged")
	world.free(); hidden_copy.free()
	print("OBSERVATION | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
