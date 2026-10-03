extends RefCounted

# Phase 3 authority records. Player scalar authority deliberately stays untouched.
const Layout=preload("res://scripts/pond_layout.gd")
const DEFAULT_COUNT := 3
const MAX_COUNT := 6
const RADIUS := 10.0
const SPEED := 38.0
const DECISION_SECONDS := 0.12
# These are main-game spawn regions, not additions to the shared map ABI.
const SPAWN_REGIONS := [Rect2(135,108,150,190),Rect2(470,106,175,200),Rect2(875,112,230,200)]

static func derive_seed(round_seed: int, identity: int) -> int:
	return int(("npc-fish-v1:%d:%d" % [round_seed,identity]).sha256_text().substr(0,15).hex_to_int())

static func fresh(identity: int, seed: int, position: Vector2, heading: Vector2, rng_state: int) -> Dictionary:
	return {"fish_id":identity,"active":true,"position":position,"velocity":Vector2.ZERO,"aim":heading,
		"visual_variant":posmod(identity-2,3),"behavior_state":"WANDER","behavior_age":0.0,
		"target_bait_id":-1,"satiety":100.0,"focus_bait_id":-1,"suspicion_by_bait":{},"caution_by_bait":{},
		"risk_tolerance":0.0,"caution_state":"CALM","brain_seed":seed,"brain_rng_state":rng_state,"respawn_age":0.0,
		"decision_age":0.0,"wander_heading":heading,"turn_age":0.0,"steering":heading}

static func observer(state: Dictionary, rules: Dictionary) -> Dictionary:
	return {"fish_id":int(state.fish_id),"position":Vector2(state.position),"mouth":Vector2(state.position)+Vector2(state.aim)*10.0,
		"aim":Vector2(state.aim),"velocity":Vector2(state.velocity),"stamina":float(rules.stamina_max),"stamina_ratio":1.0,
		"satiety":float(state.satiety),"satiety_band":"NORMAL",
		"caution_state":String(state.caution_state),"instinct_drive":0.0,"score":0.0,"power":0.0,"feeding":false}

static func valid(record: Variant, next_id: int) -> bool:
	if not record is Dictionary: return false
	var reference:=fresh(2,1,Vector2.ZERO,Vector2.RIGHT,1)
	if record.size()!=reference.size(): return false
	for key in reference:
		if not record.has(key) or typeof(record[key])!=typeof(reference[key]): return false
	if record.fish_id<2 or record.fish_id>=next_id or record.brain_seed<0: return false
	if record.visual_variant<0 or record.visual_variant>2 or record.behavior_state!="WANDER": return false
	if not record.position.is_finite() or not Layout.fish_bounds(RADIUS).has_point(record.position): return false
	if not record.velocity.is_finite() or record.velocity.length()>SPEED+0.001: return false
	for key in ["aim","wander_heading"]:
		if not record[key].is_finite() or absf(record[key].length()-1.0)>0.001: return false
	if not record.steering.is_finite() or record.steering.length()>1.001: return false
	for key in ["behavior_age","respawn_age","decision_age","turn_age"]:
		if not is_finite(record[key]) or record[key]<0: return false
	if record.decision_age>DECISION_SECONDS+0.000001 or record.turn_age>4.000001: return false
	# Reserved future behavior is deliberately inert in P3.1, not accepted silently.
	if record.target_bait_id!=-1 or record.focus_bait_id!=-1 or record.satiety!=100.0: return false
	if not record.suspicion_by_bait.is_empty() or not record.caution_by_bait.is_empty(): return false
	if record.risk_tolerance!=0.0 or record.caution_state!="CALM" or record.respawn_age!=0.0: return false
	return true
