extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Instinct=preload("res://scripts/fish_instinct.gd")
const Observation=preload("res://scripts/fish_observation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("INSTINCT_FAIL | "+label)
func _initialize() -> void:
	var world:=World.new(); world.reset_world()
	var observation:=Observation.build(world,false)
	check(Instinct.sample(observation,100,world.rules).drive==0,"full fish has no instinct drive")
	var pressure:=Instinct.sample(observation,5,world.rules)
	check(pressure.drive>0 and pressure.bias.length()>0,"low satiety produces food-oriented movement pressure")
	check(pressure.bias.length()<=0.35,"configured strength cap")
	world.rules.instinct_max_strength=0.45; world.rules.instinct_strength=1.5
	pressure=Instinct.sample(observation,0,world.rules)
	check(pressure.bias.length()<=0.450001,"hard cap at highest setting")
	var away: Vector2=-Vector2(pressure.bias).normalized()
	check(Instinct.combine(away,pressure.bias).dot(away)>=0.549999,"opposing player retains minimum control")
	for angle in 72:
		var input:=Vector2.from_angle(angle*TAU/72)
		check(Instinct.combine(input,-input*5).dot(input)>=0.549999,"cap survives extreme supplied bias")
	world.rules.hunger_enabled=false
	check(Instinct.sample(observation,0,world.rules).bias==Vector2.ZERO,"hunger toggle disables bias")
	world.reset_world({"rules":{"satiety_start":0.0}})
	world.advance_tick({"suck":false},{})
	check(world.instinct_drive>0 and not world.feeding,"instinct never auto-feeds")
	check(world.round_stats.instinct_trigger_count==1,"trigger transition counted")
	var clone:=World.new(); clone.reset_world()
	check(clone.restore_snapshot(world.capture_snapshot()) and clone.instinct_drive==world.instinct_drive,"instinct state roundtrips")
	world.free(); clone.free()
	print("INSTINCT | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
