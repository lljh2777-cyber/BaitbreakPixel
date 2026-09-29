extends RefCounted

const LEAD := 0.4
const SWEEP := 2.0
const WIDTH := 0.10
const BOOST := 1.35
const WEAK := 0.60

static func fresh() -> Dictionary:
	return {"active":false,"id":0,"kind":"effort","message":"","age":0.0,"zone":0.4,"width":WIDTH,"wait":5.0,
		"multiplier":1.0,"effect_age":0.0,"result_age":0.0,"good":false,"progress":0.0,"boost":BOOST,"weak":WEAK,"lead":LEAD,"sweep":SWEEP,"boost_seconds":2.0,"weak_seconds":1.5}

static func reset(state: Dictionary, wait: float = 5.0) -> void:
	var id: int=state.id
	state.merge(fresh(),true)
	state.id=id
	state.wait=wait

static func open(state: Dictionary, rng: RandomNumberGenerator, tuning: Dictionary = {}) -> void:
	state.id+=1
	state.kind="effort"
	state.message=""
	state.active=true
	state.age=0.0
	state.lead=float(tuning.get("lead",LEAD))
	state.sweep=float(tuning.get("sweep",SWEEP))
	state.width=clampf(float(tuning.get("window",0.2))/state.sweep,0.005,0.8)
	state.zone=rng.randf_range(0.10,0.90-state.width) if tuning.get("random",true) else float(tuning.get("zone",0.6))
	state.boost_seconds=float(tuning.get("boost_seconds",2.0))
	state.weak_seconds=float(tuning.get("weak_seconds",1.5))
	state.boost=clampf(float(tuning.get("boost",BOOST)),1.05,2.5)
	state.weak=clampf(float(tuning.get("weak",WEAK)),0.1,1.0)
	state.result_age=0.0

static func progress(state: Dictionary) -> float:
	return clampf((state.age-float(state.lead))/float(state.sweep),0,1)

static func finish(state: Dictionary, pressed: bool, judged_age: float, rng: RandomNumberGenerator) -> bool:
	var at: float=state.age if judged_age<0 else judged_age
	var p := clampf((at-float(state.lead))/float(state.sweep),0,1)
	var good: bool=pressed and at>=state.lead and at<=state.lead+state.sweep and p>=state.zone and p<=state.zone+state.width
	state.active=false
	state.good=good
	state.progress=p
	state.result_age=0.7
	state.multiplier=state.boost if good else state.weak
	state.effect_age=state.boost_seconds if good else state.weak_seconds
	# Count only time spent exerting after the result; tapping/releasing cannot reroll.
	state.wait=clampf(-log(maxf(0.001,rng.randf()))/0.18,3.0,12.0)
	return good

static func valid(state: Variant) -> bool:
	if not state is Dictionary: return false
	for key in fresh():
		if not state.has(key) or typeof(state[key])!=typeof(fresh()[key]): return false
	if not state.kind in ["effort","untangle"] or state.message.length()>80: return false
	return state.id>=0 and state.age>=0 and state.age<=10.3 and state.lead>=0 and state.lead<=2 and state.sweep>=0.5 and state.sweep<=8 and state.zone>=0.099 and state.zone+state.width<=0.99 and state.width>=0.0049 and state.width<=0.801 and state.wait>=0 and state.wait<=12 and state.effect_age>=0 and state.effect_age<=6 and state.result_age>=0 and state.result_age<=0.7 and state.multiplier>=0.1 and state.multiplier<=2.5 and state.boost>=1.05 and state.boost<=2.5 and state.weak>=0.1 and state.weak<=1 and state.boost_seconds>=0.2 and state.boost_seconds<=6 and state.weak_seconds>=0.2 and state.weak_seconds<=6
