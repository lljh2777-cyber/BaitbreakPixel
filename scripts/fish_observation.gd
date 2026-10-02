extends RefCounted

# Pure, detached fish-facing data. Render geometry is exact for compatibility;
# decision hints add detail with proximity without classifying food as safe/dangerous.
# Never copy whole bait/grain records: new authority fields stay private by default.
const Layout=preload("res://scripts/pond_layout.gd")
const NEAR_DISTANCE := 64.0
const MEDIUM_DISTANCE := 160.0
const FAR_POSITION_STEP := 16.0
const VISUAL_GRAIN_FIELDS: Array[String] = ["offset","pos","layer","fleck","free","eaten"]

static func build(world: Node2D, include_visuals: bool = true) -> Dictionary:
	var observed: Array[Dictionary]=[]
	var fish_position: Vector2=world.fish
	for bait: Dictionary in world.baits:
		var facts:=_facts(bait,fish_position)
		if facts.visible_count==0: continue
		var food: Variant=facts.food_position
		var distance: float=fish_position.distance_to(Vector2(food) if food is Vector2 else Vector2(facts.pos))
		var band:=distance_band(distance)
		var hints:=_hints(facts,band,world.water_velocity(facts.pos))
		var entry: Dictionary={"bait_id":int(bait.bait_id),"band":band,"distance":distance,
			"hints":hints,"has_attached_food":facts.attached,"food_position":food}
		if include_visuals: entry.visual=_visual(bait,facts)
		observed.append(entry)
	return {"tick":int(world.simulation_tick),
		"self":{"fish_id":int(world.fish_id),"position":fish_position,"mouth":world.mouth(),
			"aim":Vector2(world.aim),"velocity":Vector2(world.velocity),"stamina":float(world.stamina),"satiety_band":world.satiety_band(),
			"score":float(world.score),"power":float(world.power),"feeding":bool(world.feeding)},
		"perceived_baits":observed}

static func distance_band(distance: float) -> String:
	if distance<=NEAR_DISTANCE: return "near"
	if distance<=MEDIUM_DISTANCE: return "medium"
	return "far"

static func find(observation: Dictionary, bait_id: int) -> Dictionary:
	for bait: Dictionary in observation.perceived_baits:
		if bait.bait_id==bait_id: return bait
	return {}

static func food_position(observation: Dictionary, bait_id: int) -> Vector2:
	var bait:=find(observation,bait_id)
	return Vector2(bait.food_position) if not bait.is_empty() and bait.food_position is Vector2 else Vector2(INF,INF)

static func _visual(bait: Dictionary, facts: Dictionary) -> Dictionary:
	var grains: Array[Dictionary]=[]
	for grain: Dictionary in bait.grains:
		if grain.eaten or (not grain.free and not bait.active): continue
		var public_grain: Dictionary={}
		for key: String in VISUAL_GRAIN_FIELDS: public_grain[key]=grain[key]
		grains.append(public_grain)
	return {"bait_id":int(bait.bait_id),"active":bool(bait.active),
		"pos":Vector2(facts.pos),
		"angle":float(bait.angle) if bait.active else 0.0,
		"suction_offset":Vector2(facts.suction_offset),
		"grains":grains}

static func _facts(bait: Dictionary, fish_position: Vector2) -> Dictionary:
	# Hint-only callers allocate no visual grain array or per-grain dictionary.
	var count:=0
	var loose:=0
	var attached:=false
	var center:=Vector2.ZERO
	var extent:=0.0
	var nearest: Variant=null
	var best:=INF
	for grain: Dictionary in bait.grains:
		if grain.eaten or (not grain.free and not bait.active): continue
		count+=1
		center+=Vector2(grain.pos)
		if bait.active: extent=maxf(extent,Vector2(bait.pos).distance_to(grain.pos))
		if not grain.free: attached=true
		else:
			loose+=1
			if Layout.WATER.has_point(grain.pos):
				var distance: float=fish_position.distance_squared_to(grain.pos)
				if distance<best: best=distance; nearest=Vector2(grain.pos)
	# An inactive bait contributes only its visible loose food, not its hidden home.
	if bait.active: center=Vector2(bait.pos)
	elif count>0:
		center/=count
		for grain: Dictionary in bait.grains:
			if not grain.eaten and grain.free: extent=maxf(extent,center.distance_to(grain.pos))
	return {"visible_count":count,"loose":loose,"attached":attached,"pos":center,"extent":extent,
		"suction_offset":Vector2(bait.suction_offset) if bait.active else Vector2.ZERO,
		"food_position":Vector2(bait.pos) if attached else nearest}

static func _hints(facts: Dictionary, band: String, water_drift: Vector2) -> Dictionary:
	var position: Vector2=facts.pos
	var hints: Dictionary={"approx_position":position.snapped(Vector2.ONE*FAR_POSITION_STEP),
		"approx_size":maxf(4.0,roundf(float(facts.extent)*2.0/4.0)*4.0)}
	if band in ["medium","near"]:
		hints.shape="grain_cluster" if facts.attached else "loose_grains"
		# Existing food shares one scent; this is presence, never hook evidence.
		hints.smell="food"
		hints.motion={"water_drift":water_drift,"suction_displacement":Vector2(facts.suction_offset)}
	if band=="near":
		hints.disturbances={"displaced":Vector2(facts.suction_offset).length()>0.25,"loose_grains":int(facts.loose)}
	return hints
