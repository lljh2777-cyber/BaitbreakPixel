extends RefCounted

# Only legal observations enter this model. It has no world/bait truth reference.
static func evidence(bait: Dictionary, rules: Dictionary) -> float:
	var hints: Dictionary=bait.hints
	var motion: Dictionary=hints.get("motion",{})
	var velocity: Vector2=motion.get("velocity",Vector2.ZERO)
	var drift: Vector2=motion.get("water_drift",Vector2.ZERO)
	var abnormal: float=clampf((velocity-drift).length()/12.0,0,1) if not motion.is_empty() else 0.0
	var displaced: float=clampf(Vector2(motion.get("suction_displacement",Vector2.ZERO)).length()/16.0,0,1)
	var disturbed: float=1.0 if hints.get("disturbances",{}).get("recent_motion",false) else 0.0
	return clampf(abnormal*float(rules.suspicion_motion_weight)+disturbed*float(rules.suspicion_disturbance_weight)+displaced*0.18,0,1)

static func tolerance(self_state: Dictionary, bait: Dictionary) -> float:
	var hunger: float={"NORMAL":0.0,"HUNGRY":0.15,"CRITICAL":0.30,"STARVING":0.40}.get(self_state.satiety_band,0.0)
	var attraction: float=0.06 if bait.get("hints",{}).get("smell","")=="food" else 0.0
	var fatigue: float=0.15 if float(self_state.get("stamina_ratio",1.0))<0.2 else 0.0
	return clampf(hunger+attraction-fatigue,0,0.6)

static func band(value: float, previous: String) -> String:
	if previous=="ALARMED" and value>=0.42: return "ALARMED"
	if value>=0.55: return "ALARMED"
	if previous in ["UNEASY","ALARMED"] and value>=0.12: return "UNEASY"
	return "UNEASY" if value>=0.22 else "CALM"

static func update(previous: Dictionary, previous_bands: Dictionary, observation: Dictionary, delta: float, rules: Dictionary) -> Dictionary:
	var values: Dictionary={}
	var bands: Dictionary={}
	var focus:=-1
	var nearest:=INF
	var focus_tolerance:=0.0
	for bait: Dictionary in observation.perceived_baits:
		var id: int=bait.bait_id
		var old: float=previous.get(id,0.0)
		var target:=evidence(bait,rules)
		var rate: float=4.0 if target>old else float(rules.suspicion_decay)
		values[id]=clampf(lerpf(old,target,1.0-exp(-maxf(0,delta)*rate)),0,1)
		var risk:=tolerance(observation.self,bait)
		bands[id]=band(maxf(0,float(values[id])-risk),previous_bands.get(id,"CALM"))
		if bait.food_position is Vector2 and float(bait.distance)<nearest:
			nearest=float(bait.distance); focus=id; focus_tolerance=risk
	return {"values":values,"bands":bands,"focus_bait_id":focus,"risk_tolerance":focus_tolerance,
		"caution_state":bands.get(focus,"CALM")}
