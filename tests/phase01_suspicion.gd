extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Suspicion=preload("res://scripts/fish_suspicion.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("SUSPICION_FAIL | "+label)
func _initialize() -> void:
	var a:=World.new(); a.reset_world(); a.fish=a.baits[0].pos-Vector2(25,0)
	a.baits[0].motion_velocity=Vector2(30,0); a.baits[0].last_disturbance_tick=0
	var b:=World.new(); b.reset_world(); b.restore_snapshot(a.capture_snapshot())
	for bait in b.baits: bait.hook=not bait.hook
	var oa:=Observation.build(a,false); var ob:=Observation.build(b,false)
	var sa:=Suspicion.update({}, {}, oa,1.0,a.rules); var sb:=Suspicion.update({}, {}, ob,1.0,b.rules)
	check(sa==sb,"hidden hook change never changes suspicion")
	check(sa["values"].size()>1 and sa["values"][a.baits[0].bait_id]>0.8,"beliefs are per bait and respond to visible motion")
	check(sa.caution_state=="ALARMED","strong observed disturbance is readable")
	var hungry: Dictionary=oa.duplicate(true); hungry.self.satiety_band="STARVING"
	var hungry_state:=Suspicion.update({}, {}, hungry,1.0,a.rules)
	check(hungry_state["values"]==sa["values"] and hungry_state.risk_tolerance>sa.risk_tolerance,"hunger changes willingness, not evidence")
	check(Suspicion.band(0.5,"ALARMED")=="ALARMED" and Suspicion.band(0.5,"CALM")=="UNEASY","state hysteresis prevents flicker")
	var rising:=Suspicion.update({}, {}, oa,1.0/60,a.rules)
	check(rising["values"][a.baits[0].bait_id]<0.1,"evidence cannot instantly jump to alarm")
	a.baits[0].motion_velocity=a.water_velocity(a.baits[0].pos); a.baits[0].last_disturbance_tick=-1000
	var falling:=Suspicion.update(sa["values"],sa.bands,Observation.build(a,false),1.0/60,a.rules)
	check(falling["values"][a.baits[0].bait_id]>0.8,"recovery is slow")
	a.advance_tick({}, {})
	check(b.restore_snapshot(a.capture_snapshot()),"beliefs and states survive authority snapshot")
	var absent: Dictionary=oa.duplicate(true); absent.perceived_baits=[]
	var retained:=Suspicion.update(sa["values"],sa.bands,absent,1.0/60,a.rules)
	check(retained["values"][a.baits[0].bait_id]>0.8,"brief occlusion does not erase remembered evidence")
	var stable: Dictionary=oa.duplicate(true)
	stable.perceived_baits[0].distance=31.0; stable.perceived_baits[1].distance=30.0
	var focused:=Suspicion.update(sa["values"],sa.bands,stable,1.0/60,a.rules,a.baits[0].bait_id)
	check(focused.focus_bait_id==a.baits[0].bait_id,"focus hysteresis resists near-equal target jitter")
	var old_id: int=a.baits[0].bait_id
	a.suspicion_by_bait[old_id]=0.9
	a.refill_hook_bait(0); a.advance_tick({}, {})
	check(not a.suspicion_by_bait.has(old_id),"destroyed lifecycle evidence is pruned")
	a.free(); b.free()
	print("SUSPICION | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
