extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("SATIETY_FAIL | "+label)
func _initialize() -> void:
	var world:=World.new(); world.reset_world()
	var start: float=world.satiety
	world.advance_tick({}, {})
	check(world.satiety<start and is_equal_approx(world.satiety,100.0-2.445/60.0),"calibrated monotone decay")
	check(world.satiety_band()=="NORMAL","normal band")
	world.satiety=60; check(world.satiety_band()=="HUNGRY","hungry band")
	world.satiety=25; check(world.satiety_band()=="CRITICAL","critical band")
	world.satiety=10; check(world.satiety_band()=="STARVING","starving band")
	world.satiety=0.001; world.advance_tick({}, {}); check(world.satiety==0,"lower clamp")
	world.match_paused=true; world.satiety=50; world.advance_tick({}, {}); check(world.satiety==50,"pause freezes physiology")
	world.match_paused=false; world.finish(true,"test"); world.advance_tick({}, {}); check(world.satiety==50,"result freezes physiology")
	world.reset_world({"rules":{"satiety_decay":0.0}}); world.satiety=99.9
	world.fish=Vector2(250,200); world.aim=Vector2.RIGHT; world.baits[0].hook=false
	for bait in world.baits:
		for grain in bait.grains: grain.eaten=true
	var food: Dictionary=world.baits[0].grains[0]; food.eaten=false; food.free=true; food.pos=world.mouth()+Vector2(1,0)
	world.advance_tick({"suck":true},{})
	check(world.satiety==100 and world.score>0,"safe consumed food restores satiety with upper clamp")
	world.satiety=0; check(world.satiety_recovery()<1,"low satiety reduces recovery only")
	world.rules.hunger_enabled=false; check(world.satiety_recovery()==1,"disabled hunger preserves recovery")
	world.advance_tick({}, {}); check(world.satiety==0,"disabled hunger freezes decay")
	var clone:=World.new(); clone.reset_world()
	check(clone.restore_snapshot(world.capture_snapshot()) and clone.satiety==0,"schema13 retains satiety")
	var invalid: Dictionary=world.capture_snapshot(); invalid.state.satiety=101.0
	check(not clone.restore_snapshot(invalid),"snapshot rejects invalid satiety")
	world.free(); clone.free()
	print("SATIETY | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
