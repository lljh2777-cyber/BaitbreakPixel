extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("STATS_FAIL | "+label)
func _initialize() -> void:
	var a:=World.new(); var b:=World.new()
	a.reset_world({"seed":145,"rules":{"hunger_enabled":false}}); b.reset_world({"seed":145,"rules":{"hunger_enabled":false}})
	for tick in 360:
		var command: Dictionary={"move":Vector2.RIGHT,"suck":tick%60<30}
		a.advance_tick(command,{}); b.advance_tick(command,{})
	check(var_to_bytes(a.capture_snapshot())==var_to_bytes(b.capture_snapshot()),"same seed and commands reproduce complete authority")
	check(is_equal_approx(a.round_stats.round_duration,6.0),"duration measures simulation time")
	check(a.round_stats.feeding_attempts==6,"feeding transitions counted")
	check(a.round_stats.feeding_aborts==6,"aborted attempts counted")
	check(is_equal_approx(a.round_stats.satiety_mean,100.0),"Phase0 physiology placeholder is neutral")
	var stats: Dictionary=a.round_stats.duplicate(true)
	a.match_paused=true; a.advance_tick({}, {})
	check(a.round_stats==stats,"pause does not accumulate statistics")
	a.match_paused=false; a.finish(true,"test"); a.advance_tick({}, {})
	check(a.round_stats==stats,"ended match does not accumulate statistics")
	check(a.Stats.valid(a.round_stats),"expanded stats validate")
	# Consumption on an earlier tick still makes the feeding session successful.
	b.reset_world()
	b.advance_tick({"suck":true},{})
	b.score=1.0
	b.advance_tick({"suck":true},{})
	b.advance_tick({"suck":false},{})
	check(b.round_stats.feeding_aborts==0,"successful session stop is not an abort")
	b._enter_hook(0)
	check(b.round_stats.hook_events==0,"mouth contact is not an attached hook")
	b._attach_hook()
	check(b.round_stats.hook_events==1,"actual attachment records hook event")
	a.free(); b.free()
	print("STATS | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
