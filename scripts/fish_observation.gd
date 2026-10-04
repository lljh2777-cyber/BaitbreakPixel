extends RefCounted

# Pure, detached fish-facing data. Render geometry is exact for compatibility;
# decision hints add detail with proximity without classifying food as safe/dangerous.
# Never copy whole bait/grain records: new authority fields stay private by default.
const Registry=preload("res://scripts/maps/map_registry.gd")
# The two-argument helper is retained for the schema-15 network adapter. Its
# default geometry remains pond_v2 until P4.3; authority always passes its water.
static var _compatibility_water := Rect2()
const Feeding=preload("res://scripts/fish_feeding.gd")
const FoodProfile=preload("res://scripts/food_profile.gd")
const NEAR_DISTANCE := 64.0
const MEDIUM_DISTANCE := 160.0
const FAR_POSITION_STEP := 16.0
const VISUAL_GRAIN_FIELDS: Array[String] = ["offset","pos","layer","fleck","free","eaten","visual_kind"]

# Preserve the exact legacy player keys, values and insertion order. Caller-supplied
# observer records may contain private AI state, so never duplicate them wholesale.
const SELF_FIELDS: Array[String] = ["fish_id","position","mouth","aim","velocity","stamina","stamina_ratio","caution_state","satiety","satiety_band","instinct_drive","score","power","feeding"]

static func player_self(world: Node2D) -> Dictionary:
	return {"fish_id":int(world.fish_id),"position":Vector2(world.fish),"mouth":world.mouth(),
		"aim":Vector2(world.aim),"velocity":Vector2(world.velocity),"stamina":float(world.stamina),"stamina_ratio":world.stamina_ratio(),"caution_state":world.caution_state,"satiety":float(world.satiety),"satiety_band":world.satiety_band(),"instinct_drive":float(world.instinct_drive),
		"score":float(world.score),"power":float(world.power),"feeding":bool(world.feeding)}

static func build(world: Node2D, include_visuals: bool = true) -> Dictionary:
	return build_for(world,player_self(world),include_visuals)

static func build_for(world: Node2D, observer_state: Dictionary, include_visuals: bool = true) -> Dictionary:
	var public_self: Dictionary={}
	for key: String in SELF_FIELDS: public_self[key]=observer_state[key]
	# The self contract contains only scalar/vector/string/bool public facts.
	# Detach it even when a future caller retains and edits its observer dictionary.
	public_self=public_self.duplicate(true)
	var observed: Array[Dictionary]=[]
	var fish_position: Vector2=public_self.position
	for bait: Dictionary in world.baits:
		var facts:=_facts(bait,fish_position,world.map_context.water)
		if facts.visible_count==0: continue
		var food: Variant=facts.food_position
		var distance: float=fish_position.distance_to(Vector2(food) if food is Vector2 else Vector2(facts.pos))
		var band:=distance_band(distance)
		var hints:=_hints(facts,band,world.water_velocity(facts.pos))
		if hints.has("motion"): hints.motion.velocity=Vector2(bait.get("motion_velocity",Vector2.ZERO))
		if hints.has("disturbances"): hints.disturbances.recent_motion=int(world.simulation_tick)-int(bait.get("last_disturbance_tick",-1000))<=60
		var entry: Dictionary={"bait_id":int(bait.bait_id),"band":band,"distance":distance,
			"hints":hints,"has_attached_food":facts.attached,"food_position":food}
		if include_visuals: entry.visual=_visual(bait,facts)
		observed.append(entry)
	return {"tick":int(world.simulation_tick),"self":public_self,"perceived_baits":observed}

# NPC opt-in extension: player build()/build_for() retain their exact legacy
# shape, and player suspicion never consumes another fish's private emotions.
# Capture actions before moving any NPC so array order cannot create new cues.
static func social_fish(world: Node2D) -> Array[Dictionary]:
	var visible: Array[Dictionary]=[{"fish_id":int(world.fish_id),"position":Vector2(world.fish),
		"mouth":world.mouth(),"feeding":bool(world.feeding) or float(world.bite_feedback_age)>0.0}]
	for npc: Dictionary in world.npc_fishes:
		if not bool(npc.get("active",true)): continue
		# Suction and a just-completed bite are physical feeding actions, not
		# target selection, satiety, suspicion, or a promise the food is safe.
		visible.append({"fish_id":int(npc.fish_id),"position":Vector2(npc.position),
			"mouth":Feeding.mouth(Vector2(npc.position),Vector2(npc.aim)),
			"feeding":bool(npc.get("feeding",false)) or float(npc.get("bite_cooldown",0.0))>0.65})
	visible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.fish_id<b.fish_id)
	return visible

static func build_social_for(world: Node2D, observer_state: Dictionary, include_visuals: bool=false, public_fish: Variant=null) -> Dictionary:
	var observation:=build_for(world,observer_state,include_visuals)
	var position: Vector2=observation.self.position
	var feeding_fish: Array[Dictionary]=[]
	var sources: Array=social_fish(world) if public_fish==null else public_fish
	for other: Dictionary in sources:
		if int(other.fish_id)==int(observation.self.fish_id) or not bool(other.feeding): continue
		if position.distance_to(Vector2(other.position))>MEDIUM_DISTANCE: continue
		feeding_fish.append({"fish_id":int(other.fish_id),"position":Vector2(other.position),
			"mouth":Vector2(other.mouth),"feeding":true})
	var danger_events: Array[Dictionary]=[]
	var event: Dictionary=world.public_hook_cue
	var age:=int(world.simulation_tick)-int(event.tick)
	if int(event.tick)>=0 and age>=0 and age<=45 and position.distance_to(Vector2(event.position))<=150.0:
		danger_events.append({"tick":int(event.tick),"position":Vector2(event.position)})
	observation.social_cues={"feeding_fish":feeding_fish,"danger_events":danger_events}
	return observation

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
		"visual_kind":facts.visual_kind,"shape_hint":facts.shape_hint,"smell_hint":facts.smell_hint,
		"grains":grains}

static func _facts(bait: Dictionary, fish_position: Vector2, water_bounds: Rect2=Rect2()) -> Dictionary:
	if not water_bounds.has_area():
		if not _compatibility_water.has_area():
			var loaded:=Registry.load_map()
			assert(loaded.valid,"default network compatibility map must validate")
			_compatibility_water=loaded.definition.bounds.water
		water_bounds=_compatibility_water
	# Hint-only callers allocate no visual grain array or per-grain dictionary.
	var count:=0
	var loose:=0
	var attached:=false
	var center:=Vector2.ZERO
	var extent:=0.0
	var nearest: Variant=null
	var best:=INF
	var attached_kind: String=""
	var loose_kind: String=""
	for grain: Dictionary in bait.grains:
		if grain.eaten or (not grain.free and not bait.active): continue
		count+=1
		center+=Vector2(grain.pos)
		if bait.active: extent=maxf(extent,Vector2(bait.pos).distance_to(grain.pos))
		if not grain.free:
			attached=true
			if attached_kind.is_empty(): attached_kind=String(grain.visual_kind)
		else:
			loose+=1
			if loose_kind.is_empty(): loose_kind=String(grain.visual_kind)
			if water_bounds.has_point(grain.pos):
				var distance: float=fish_position.distance_squared_to(grain.pos)
				if distance<best:
					best=distance; nearest=Vector2(grain.pos); loose_kind=String(grain.visual_kind)
	# An inactive bait contributes only its visible loose food, not its hidden home.
	if bait.active: center=Vector2(bait.pos)
	elif count>0:
		center/=count
		for grain: Dictionary in bait.grains:
			if not grain.eaten and grain.free: extent=maxf(extent,center.distance_to(grain.pos))
	# Derive type cues only from visible food. A replenished hidden reserve may
	# have a different authority type from the old loose grains still in the water.
	var visual_kind:=attached_kind if attached else loose_kind
	var profile:=FoodProfile.get_profile(visual_kind)
	return {"visual_kind":visual_kind,"shape_hint":String(profile.get("shape_hint","")),"smell_hint":String(profile.get("smell_hint","")),
		"visible_count":count,"loose":loose,"attached":attached,"pos":center,"extent":extent,
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
		hints.shape_hint=facts.shape_hint
		hints.smell_hint=facts.smell_hint
		hints.motion={"water_drift":water_drift,"suction_displacement":Vector2(facts.suction_offset)}
	if band=="near":
		hints.disturbances={"displaced":Vector2(facts.suction_offset).length()>0.25,"loose_grains":int(facts.loose)}
	return hints
