extends RefCounted

# Phase 3 authority records. Player scalar authority deliberately stays untouched.
const Layout=preload("res://scripts/pond_layout.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")
const DEFAULT_COUNT := 3
const MAX_COUNT := 6
const RADIUS := 10.0
const SPEED := 38.0
const DECISION_SECONDS := 0.12
const FLEE_SECONDS := 1.2
const SOCIAL_RECOVERY_SECONDS := 2.4
const COMPETE_SECONDS := 0.6
const SOCIAL_MEMORY_FIELDS: Array[String]=["social_reaction_left","social_recovery_left","social_origin","social_bait_id","social_motion_level","social_danger_tick","social_compete_left"]
# These are main-game spawn regions, not additions to the shared map ABI.
const SPAWN_REGIONS := [Rect2(135,108,150,190),Rect2(470,106,175,200),Rect2(875,112,230,200)]

static func derive_seed(round_seed: int, identity: int) -> int:
	return int(("npc-fish-v1:%d:%d" % [round_seed,identity]).sha256_text().substr(0,15).hex_to_int())

static func fresh(identity: int, seed: int, position: Vector2, heading: Vector2, rng_state: int) -> Dictionary:
	return {"fish_id":identity,"active":true,"position":position,"velocity":Vector2.ZERO,"aim":heading,
		"visual_variant":posmod(identity-2,3),"behavior_state":"WANDER","behavior_age":0.0,
		"target_bait_id":-1,"satiety":70.0,"focus_bait_id":-1,"suspicion_by_bait":{},"caution_by_bait":{},
		"risk_tolerance":0.0,"caution_state":"CALM","brain_seed":seed,"brain_rng_state":rng_state,"respawn_age":0.0,
		"decision_age":0.0,"wander_heading":heading,"turn_age":0.0,"steering":heading,
		"feeding":false,"power":0.0,"bite_cooldown":0.0,"intent_aim":heading,
		"social_reaction_left":0.0,"social_recovery_left":0.0,"social_origin":Vector2.ZERO,"social_bait_id":-1,
		"social_motion_level":0,"social_danger_tick":-1,"social_compete_left":0.0}

static func observer(state: Dictionary, rules: Dictionary) -> Dictionary:
	return {"fish_id":int(state.fish_id),"position":Vector2(state.position),"mouth":Feeding.mouth(Vector2(state.position),Vector2(state.aim)),
		"aim":Vector2(state.aim),"velocity":Vector2(state.velocity),"stamina":float(rules.stamina_max),"stamina_ratio":1.0,
		"satiety":float(state.satiety),"satiety_band":satiety_band(float(state.satiety),rules),
		"caution_state":String(state.caution_state),"instinct_drive":0.0,"score":0.0,"power":float(state.power),"feeding":bool(state.feeding)}

static func satiety_band(value: float, rules: Dictionary) -> String:
	if not bool(rules.hunger_enabled): return "NORMAL"
	if value<=float(rules.satiety_starving_threshold): return "STARVING"
	if value<=float(rules.satiety_critical_threshold): return "CRITICAL"
	if value<=float(rules.satiety_low_threshold): return "HUNGRY"
	return "NORMAL"

static func valid(record: Variant, next_id: int) -> bool:
	if not record is Dictionary: return false
	var reference:=fresh(2,1,Vector2.ZERO,Vector2.RIGHT,1)
	if record.size()!=reference.size(): return false
	for key in reference:
		if not record.has(key) or typeof(record[key])!=typeof(reference[key]): return false
	if record.fish_id<2 or record.fish_id>=next_id or record.brain_seed<0: return false
	if record.visual_variant<0 or record.visual_variant>2 or record.behavior_state not in ["WANDER","APPROACH_FOOD","FEED","HESITATE","FLEE","COMPETE"]: return false
	if not record.position.is_finite() or not Layout.fish_bounds(RADIUS).has_point(record.position): return false
	if not record.velocity.is_finite() or record.velocity.length()>SPEED+0.001: return false
	for key in ["aim","wander_heading","intent_aim"]:
		if not record[key].is_finite() or absf(record[key].length()-1.0)>0.001: return false
	if not record.steering.is_finite() or record.steering.length()>1.001: return false
	for key in ["behavior_age","respawn_age","decision_age","turn_age"]:
		if not is_finite(record[key]) or record[key]<0: return false
	if record.decision_age>DECISION_SECONDS+0.000001 or record.turn_age>4.000001: return false
	for key in ["target_bait_id","focus_bait_id"]:
		if record[key]!=-1 and record[key]<1: return false
	if not is_finite(record.satiety) or record.satiety<0.0 or record.satiety>100.0: return false
	if not is_finite(record.power) or record.power<0.0 or record.power>1.0: return false
	if not is_finite(record.bite_cooldown) or record.bite_cooldown<0.0 or record.bite_cooldown>0.800001: return false
	if not is_finite(record.risk_tolerance) or record.risk_tolerance<0.0 or record.risk_tolerance>0.600001: return false
	if record.caution_state not in ["CALM","UNEASY","ALARMED"] or record.respawn_age!=0.0: return false
	if record.suspicion_by_bait.size()!=record.caution_by_bait.size(): return false
	for id in record.suspicion_by_bait:
		if not id is int or id<1: return false
		var value: Variant=record.suspicion_by_bait[id]
		if not value is float or not is_finite(value) or value<0.0 or value>1.0: return false
		if not record.caution_by_bait.has(id): return false
		var caution: Variant=record.caution_by_bait[id]
		if not caution is String or caution not in ["CALM","UNEASY","ALARMED"]: return false
	if record.focus_bait_id!=-1 and not record.suspicion_by_bait.has(record.focus_bait_id): return false
	for pair: Array in [["social_reaction_left",FLEE_SECONDS],["social_recovery_left",SOCIAL_RECOVERY_SECONDS],["social_compete_left",COMPETE_SECONDS]]:
		var value: float=record[pair[0]]
		if not is_finite(value) or value<0.0 or value>float(pair[1])+0.000001: return false
	if not record.social_origin.is_finite(): return false
	if record.social_bait_id!=-1 and record.social_bait_id<1: return false
	if record.social_motion_level<0 or record.social_motion_level>2 or record.social_danger_tick< -1: return false
	var reacting: bool=record.behavior_state in ["HESITATE","FLEE"]
	if reacting!=(record.social_reaction_left>0.0): return false
	if reacting and record.social_recovery_left<record.social_reaction_left: return false
	if record.behavior_state=="HESITATE" and (record.social_bait_id<1 or record.social_reaction_left>0.840001): return false
	if not reacting and (record.social_origin!=Vector2.ZERO or record.social_bait_id!=-1): return false
	if reacting and record.social_compete_left!=0.0: return false
	if record.behavior_state=="COMPETE" and record.social_compete_left<=0.0: return false
	if record.social_compete_left>0.0 and record.behavior_state not in ["APPROACH_FOOD","COMPETE","FEED"]: return false
	if record.behavior_state in ["WANDER","FLEE"]:
		if record.target_bait_id!=-1 or record.feeding: return false
	elif record.behavior_state=="HESITATE":
		if record.feeding: return false
		if record.target_bait_id!=-1 and (record.target_bait_id!=record.social_bait_id or not record.suspicion_by_bait.has(record.target_bait_id)): return false
	elif record.target_bait_id<1 or not record.suspicion_by_bait.has(record.target_bait_id): return false
	if record.feeding and record.behavior_state!="FEED": return false
	# Current-shape WANDER/100 remains meaningful. Missing social memory and
	# future capture/respawn states are rejected rather than silently migrated.
	return true
