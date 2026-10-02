extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("RANDOM_HOOK_FAIL | "+label)
func assignments(world: Node2D) -> Array:
	var result: Array=[]
	for bait in world.baits: result.append([bait.bait_id,bait.hook,bait.flutter_amplitude,bait.drift_phase])
	return result
func _initialize() -> void:
	var a:=World.new(); var b:=World.new()
	var patterns: Dictionary={}
	for seed_value in 100:
		a.reset_world({"seed":seed_value}); b.reset_world({"seed":seed_value})
		check(assignments(a)==assignments(b),"reproducible creation events")
		var danger:=0
		for bait in a.baits:
			if bait.active: danger+=int(bait.hook)
		check(danger>=1 and danger<=2,"initial active population retains risk and safety")
		patterns[str([a.baits[0].hook,a.baits[1].hook,a.baits[3].hook])]=true
	check(patterns.size()>=5,"slot cannot predict hook assignment")
	a.reset_world({"seed":82,"rules":{"water_strength":0.0}}); b.reset_world({"seed":82,"rules":{"water_strength":0.0}})
	var before:=assignments(a)
	for tick in 300: a.advance_tick({}, {})
	check(assignments(a)==before,"living bait never flips with elapsed time")
	a.reset_world({"seed":82}); b.reset_world({"seed":82})
	a.refill_hook_bait(0); b.refill_hook_bait(0)
	check(assignments(a)==assignments(b) and a.baits[0].bait_id==5,"refill consumes matching event RNG and new identity")
	check(a.truth_events[-1].bait_id==5 and a.truth_events[-1].has("hooked"),"truth creation log stays authoritative")
	a.reset_world({"ruleset":"duel","rules":{"bait_hook_probability":0.0,"bait_danger_min":0.0,"bait_danger_max":0.0}})
	check(not a.baits[0].hook and a.angler.deploy(a),"safe rolled payload still deploys on the one existing rod")
	for tick in 60: a.advance_tick({}, {})
	check(a.baits[0].active and not a.baits[0].hook,"safe tackle remains usable after cast")
	a.free(); b.free()
	print("RANDOM_HOOK | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
