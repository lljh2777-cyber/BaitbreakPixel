extends RefCounted

const LEAD := 0.4
const SWEEP := 2.0
const WIDTH := 0.10
const BOOST := 1.35
const WEAK := 0.60

static func fresh() -> Dictionary:
	return {"active":false,"id":0,"age":0.0,"zone":0.4,"width":WIDTH,"wait":5.0,
		"multiplier":1.0,"effect_age":0.0,"result_age":0.0,"good":false,"progress":0.0,"boost":BOOST,"weak":WEAK}

static func reset(state: Dictionary, wait: float = 5.0) -> void:
	var id: int=state.id
	state.merge(fresh(),true)
	state.id=id
	state.wait=wait

static func open(state: Dictionary, rng: RandomNumberGenerator, tuning: Dictionary = {}) -> void:
	state.id+=1
	state.active=true
	state.age=0.0
	state.width=clampf(float(tuning.get("window",0.2))/SWEEP,0.06,0.25)
	state.zone=rng.randf_range(0.10,0.90-state.width)
	state.boost=clampf(float(tuning.get("boost",BOOST)),1.1,1.8)
	state.weak=clampf(float(tuning.get("weak",WEAK)),0.3,0.9)
	state.result_age=0.0

static func progress(state: Dictionary) -> float:
	return clampf((state.age-LEAD)/SWEEP,0,1)

static func finish(state: Dictionary, pressed: bool, judged_age: float, rng: RandomNumberGenerator) -> bool:
	var at: float=state.age if judged_age<0 else judged_age
	var p := clampf((at-LEAD)/SWEEP,0,1)
	var good: bool=pressed and at>=LEAD and at<=LEAD+SWEEP and p>=state.zone and p<=state.zone+state.width
	state.active=false
	state.good=good
	state.progress=p
	state.result_age=0.7
	state.multiplier=state.boost if good else state.weak
	state.effect_age=2.0 if good else 1.5
	# Count only time spent exerting after the result; tapping/releasing cannot reroll.
	state.wait=clampf(-log(maxf(0.001,rng.randf()))/0.18,3.0,12.0)
	return good

static func valid(state: Variant) -> bool:
	if not state is Dictionary: return false
	for key in fresh():
		if not state.has(key) or typeof(state[key])!=typeof(fresh()[key]): return false
	return state.id>=0 and state.age>=0 and state.age<=3.0 and state.zone>=0.1 and state.zone+state.width<=0.99 and state.width>=0.06 and state.width<=0.25 and state.wait>=0 and state.wait<=12 and state.effect_age>=0 and state.effect_age<=2.0 and state.result_age>=0 and state.result_age<=0.7 and state.multiplier>=0.3 and state.multiplier<=1.8 and state.boost>=1.1 and state.boost<=1.8 and state.weak>=0.3 and state.weak<=0.9
