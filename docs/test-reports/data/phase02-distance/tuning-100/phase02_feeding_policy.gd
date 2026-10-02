extends RefCounted

# Benchmark-only controller. Its sole runtime input is detached FishObservation.
# It never receives World, authority bait/grain records, hook truth or QTE state.
const Layout=preload("res://scripts/pond_layout.gd")
const Rules=preload("res://scripts/game_rules.gd")
const POLICIES: Array[String]=["SuckOnly","BiteOnly","Mixed"]
const VERSION:=1
const SUCTION_STANDOFF:=31.0 # Mouth-to-food-center, not fish-center distance.
const BITE_STANDOFF:=6.0
var policy:="Mixed"
var target_id:=-1
var target_kind:="unknown"
var mode:="seek"
var switches:=0
var home_requested:=false
var rules: Dictionary=Rules.defaults()
var choice_counts: Dictionary={"suck":0,"bite":0}
var mode_seconds: Dictionary={"suck":0.0,"bite":0.0,"seek":0.0,"home":0.0}
var previous_mode:="seek"
var last_score:=-1.0
var stalled_seconds:=0.0
var decision_age:=0.0
var avoided_id:=-1
var avoid_seconds:=0.0

func reset(name: String, public_rules: Dictionary={}) -> void:
	assert(name in POLICIES)
	policy=name; rules=Rules.normalize(public_rules)
	target_id=-1; target_kind="unknown"; mode="seek"; previous_mode="seek"
	switches=0; home_requested=false; last_score=-1.0; stalled_seconds=0.0
	decision_age=0.0; avoided_id=-1; avoid_seconds=0.0
	choice_counts={"suck":0,"bite":0}
	mode_seconds={"suck":0.0,"bite":0.0,"seek":0.0,"home":0.0}

static func observed_kind(bait: Dictionary) -> String:
	# Far-band observations do not identify a food type; never fill it from truth.
	return {"grain_cluster":"cluster","slender_curved":"worm","solid_chunk":"chunk"}.get(bait.get("hints",{}).get("shape_hint",""),"unknown")

func choose_mode(bait: Dictionary, self_state: Dictionary) -> String:
	if policy=="SuckOnly": return "suck"
	if policy=="BiteOnly": return "bite"
	if not bait.get("has_attached_food",false): return "suck"
	var kind:=observed_kind(bait)
	var caution: String=self_state.get("caution_state","CALM")
	var hungry: bool=float(self_state.get("satiety",100.0))<=45.0
	var critical: bool=self_state.get("satiety_band","NORMAL") in ["CRITICAL","STARVING"]
	if caution=="ALARMED" and not critical: return "suck"
	if kind=="cluster" or kind=="unknown": return "bite" if critical and caution=="CALM" else "suck"
	if kind=="chunk": return "bite" if caution=="CALM" or hungry else "suck"
	return "bite" if caution=="CALM" or critical else "suck"

func command(observation: Dictionary, delta: float) -> Dictionary:
	var self_state: Dictionary=observation.self
	var position: Vector2=self_state.position
	var aim: Vector2=self_state.aim
	var result: Dictionary={"move":Vector2.ZERO,"aim":aim,"power":float(rules.suction_initial),
		"suck":false,"dash":false,"slow":false,"qte":false,"home":false}
	# Public goal and map constants are identical for all policies. No can_home(),
	# hidden hooked state, or legacy FishBrain escape/QTE oracle is consulted.
	if float(self_state.score)>=float(rules.food_goal)-0.001:
		mode="home"
		var offset:=Layout.HOME-position
		result.move=(offset*3.0/float(rules.swim_speed)).limit_length(1.0) if offset.length()>5 else Vector2.ZERO
		if offset.length()<25 and not home_requested:
			result.home=true; home_requested=true
		_record(delta)
		return result
	if float(self_state.score)>last_score+0.000001: stalled_seconds=0.0
	else: stalled_seconds+=delta
	last_score=float(self_state.score)
	decision_age-=delta; avoid_seconds=maxf(0.0,avoid_seconds-delta)
	if stalled_seconds>8.0 and target_id>=0:
		avoided_id=target_id; avoid_seconds=3.0; target_id=-1; stalled_seconds=0.0
	var selected: Dictionary={}
	for bait: Dictionary in observation.perceived_baits:
		if int(bait.bait_id)==target_id and bait.food_position is Vector2: selected=bait; break
	if selected.is_empty() or decision_age<=0.0 and mode=="seek":
		decision_age=0.6
		var best:=INF
		for bait: Dictionary in observation.perceived_baits:
			if not bait.food_position is Vector2: continue
			var distance: float=position.distance_to(bait.food_position)
			if int(bait.bait_id)==avoided_id and avoid_seconds>0: distance+=120.0
			if distance<best: best=distance; selected=bait
		if not selected.is_empty(): target_id=int(selected.bait_id)
	if selected.is_empty():
		mode="seek"; target_kind="unknown"; _record(delta); return result
	target_kind=observed_kind(selected)
	mode=choose_mode(selected,self_state)
	var food: Vector2=selected.food_position
	var heading: Vector2=(food-position).normalized()
	if heading.length_squared()<0.01: heading=aim
	var mouth_offset: float=Vector2(self_state.mouth).distance_to(position)
	var standoff:=SUCTION_STANDOFF if mode=="suck" else BITE_STANDOFF
	var destination: Vector2=food-heading*(mouth_offset+standoff)
	# Detached food is already travelling to us; don't retreat from every grain.
	if mode=="suck" and not selected.get("has_attached_food",false) and position.distance_to(food)<mouth_offset+float(rules.suction_range):
		destination=position
	var offset:=destination-position
	var drift: Vector2=selected.get("hints",{}).get("motion",{}).get("water_drift",Vector2.ZERO)
	result.aim=heading
	result.suck=mode=="suck" and offset.length()<12.0
	var speed: float=float(rules.swim_speed)*(float(rules.feeding_speed) if result.suck else 1.0)
	# Observed velocity damps overshoot; no hidden vegetation/current query.
	var wanted:=offset*3.0-drift-Vector2(self_state.velocity)*0.15
	result.move=(wanted/maxf(1.0,speed)).limit_length(1.0)
	_record(delta)
	return result

func _record(delta: float) -> void:
	mode_seconds[mode]+=delta
	if mode!=previous_mode:
		if mode in ["suck","bite"]:
			choice_counts[mode]+=1
			if previous_mode in ["suck","bite"]: switches+=1
		previous_mode=mode
