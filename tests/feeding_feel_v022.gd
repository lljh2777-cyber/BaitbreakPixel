extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const AnglerPublic=preload("res://scripts/angler_network_observation.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("FEEDING_PASS | ",title)
	else: failed+=1; push_error("FEEDING_FAIL | "+title)
func fresh(power_value: float, has_hook: bool=false, distance: float=26.0) -> Node2D:
	var w:=World.new(); w.reset_world({"ruleset":"survival","seed":42,"rules":{"water_strength":0,"timer_enabled":false}})
	w.fish=Vector2(700,210); w.aim=Vector2.RIGHT; w.power=power_value; w.hook_cooldown=1000
	for bait in w.baits: bait.active=false
	var bait: Dictionary=w.baits[0]
	# These assertions pin the legacy Cluster response, not a randomly assigned P2.3 profile.
	bait.bait_type="cluster"
	var baseline: Dictionary=w._make_bait(0,0,"cluster")
	for i in bait.grains.size():
		bait.grains[i].visual_kind="cluster"; bait.grains[i].offset=baseline.grains[i].offset
	bait.active=true; bait.hook=has_hook; bait.pos=w.mouth()+Vector2(distance,0); bait.home=bait.pos; bait.angle=0.0
	for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
	return w
func step(w: Node2D, count: int, hz: int=60, sucking: bool=true) -> void:
	for frame in count:
		w.elapsed+=1.0/hz; w.feeding=sucking; w._step_bait(0,1.0/hz,sucking,w.mouth())
func layer_probe(power_value: float, layer: int) -> float:
	var w:=fresh(power_value); var chosen: Dictionary={}
	for grain in w.baits[0].grains:
		grain.eaten=true
		if chosen.is_empty() and grain.layer==layer: chosen=grain
	chosen.eaten=false; chosen.offset=Vector2.ZERO; chosen.pos=w.baits[0].pos
	step(w,6); var progress: float=chosen.progress; w.free(); return progress
func run() -> void:
	for hz in [30,60,120]:
		var gentle:=fresh(0.35); var strong:=fresh(1.0)
		step(gentle,int(hz*0.1),hz); step(strong,int(hz*0.1),hz)
		check(Vector2(strong.baits[0].suction_offset).length()>Vector2(gentle.baits[0].suction_offset).length()*2,"%d Hz: strong suction visibly pulls the whole cluster faster" % hz)
		step(gentle,hz,hz); step(strong,hz,hz)
		check(strong.score>gentle.score+3,"%d Hz: strong suction delivers more food in the same time" % hz)
		check(gentle.score>0,"%d Hz: gentle suction still delivers outer food" % hz)
		gentle.free(); strong.free()
	var outer:=layer_probe(0.35,0); var inner:=layer_probe(0.35,1); var core:=layer_probe(0.35,2)
	check(outer>inner*1.5 and inner>core*1.5,"gentle suction preferentially peels outer food; inner and core resist")
	check(layer_probe(1.0,2)>core*5,"strong suction removes dense core food substantially faster")
	for power_value in [0.35,1.0]:
		var hook:=fresh(power_value,true); var plain:=fresh(power_value,false)
		step(hook,90); step(plain,90)
		check(hook.baits[0].grains==plain.baits[0].grains and hook.baits[0].pos==plain.baits[0].pos,"power %.2f: profile cannot reveal hook identity" % power_value)
		hook.free(); plain.free()
	var far:=fresh(1.0,true); far.hook_cooldown=0
	for frame in 60: far.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(far.hooked==far.HookState.FREE,"gradient no longer drags a 26px hook into the mouth in one second")
	far.free()
	# At 20px, strong target displacement is ~14.8px; at 26px only ~9.5px.
	var gentle:=fresh(0.35,false,20.0); var strong:=fresh(1.0,false,20.0)
	gentle.hook_cooldown=0; strong.hook_cooldown=0; gentle.baits[0].hook=true; strong.baits[0].hook=true
	for frame in 60:
		gentle.advance_tick({"aim":Vector2.RIGHT,"power":0.35,"suck":true},{})
		strong.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(gentle.hooked==gentle.HookState.FREE and gentle.score>0,"gentle outer peeling stays outside hook contact in the 20-pixel fixture")
	check(strong.hooked!=strong.HookState.FREE,"strong whole-cluster pull carries the same hidden hook to the mouth")
	gentle.free(); strong.free()
	for power_value in [0.35,1.0]:
		var w:=fresh(power_value)
		for grain in w.baits[0].grains: grain.eaten=true
		var grain: Dictionary=w.baits[0].grains[0]; grain.eaten=false; grain.free=true; grain.pos=w.mouth()+Vector2(24,0)
		var initial: Vector2=grain.pos
		var expected:=initial
		for tick in 6:
			expected=expected.move_toward(w.mouth(),w.strength(expected)*w.rule("pellet_speed")*w.Suction.pellet_gain(power_value)/60.0)
		step(w,6)
		var moved:=initial.distance_to(grain.pos)
		check(moved>0 and Vector2(grain.pos).distance_to(expected)<0.0001,"power %.2f: detached pellet transport follows the distance field and power gain" % power_value)
		step(w,60)
		check(w.score>0 and w.last_eat_at>=0 and w.last_eat_at<=w.elapsed,"actual intake records a feedback timestamp")
		var captured: Dictionary=w.capture_snapshot(); w.match_paused=true; var frozen: Dictionary=w.capture_snapshot()
		w.advance_tick({"suck":true},{})
		check(w.capture_snapshot()==frozen,"pause freezes intake feedback and body motion")
		var clone:=World.new()
		check(clone.restore_snapshot(captured) and clone.last_eat_at==w.last_eat_at,"intake feedback survives a detached snapshot roundtrip")
		captured.schema=11
		check(not clone.restore_snapshot(captured),"previous schema cannot omit intake feedback state")
		w.free(); clone.free()
	var w:=fresh(0.35); step(w,24)
	var before: Dictionary=AnglerPublic.capture(w); var after: Dictionary=before.duplicate(true)
	before.state.simulation_tick=10; after.state.simulation_tick=12
	before.state.power=0.35; after.state.power=1.0
	before.state.baits[0].suction_offset=Vector2(-4,0); after.state.baits[0].suction_offset=Vector2(-16,0)
	var source_before:=var_to_bytes(before); var source_after:=var_to_bytes(after); var authority_before:=var_to_bytes(w.capture_snapshot())
	var renderer:=Presentation.new(); renderer.accept(before,10); renderer.accept(after,10.1)
	var visual: Node2D=renderer.sample(10.1+1.0/60)
	check(absf(visual.power-0.675)<0.0001 and Vector2(visual.baits[0].suction_offset).distance_to(Vector2(-10,0))<0.001,"remote power and bait deformation interpolate together")
	check(renderer.current==after,"remote presentation never changes the accepted wire feedback snapshot")
	check(var_to_bytes(before)==source_before and var_to_bytes(after)==source_after and var_to_bytes(w.capture_snapshot())==authority_before,"remote sampling preserves both caller-owned wire snapshots and original authority bytes")
	renderer.dispose(); w.free()
	print("FEEDING_FEEL_V022 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
