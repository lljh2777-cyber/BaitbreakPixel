extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Brain=preload("res://scripts/fish_brain.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("POLICY_FAIL | "+label)
func _initialize() -> void:
	var world:=World.new(); world.reset_world(); world.fish=Vector2(400,200)
	for index in world.baits.size():
		var bait: Dictionary=world.baits[index]
		bait.active=index<2; bait.pos=world.fish+Vector2(30+index*30,0); bait.suction_offset=Vector2.ZERO
		bait.motion_velocity=Vector2(30,0) if index==0 else world.water_velocity(bait.pos)
		bait.last_disturbance_tick=0 if index==0 else -1000
		for grain in bait.grains: grain.pos=Vector2(bait.pos)+Vector2(grain.offset)
	var distance:=Brain.new(); distance.reset(74)
	var cautious:=Brain.new(); cautious.reset(74); cautious.use_caution=true
	distance.command(world,1.0); var command:=cautious.command(world,1.0)
	check(distance.food_target==world.baits[0].bait_id,"distance policy selects nearest observed food")
	check(cautious.food_target==world.baits[1].bait_id,"cautious policy trades distance for quieter observed target")
	var other:=World.new(); other.reset_world(); other.restore_snapshot(world.capture_snapshot())
	for bait in other.baits: bait.hook=not bait.hook
	var comparison:=Brain.new(); comparison.reset(74); comparison.use_caution=true
	check(comparison.command(other,1.0)==command,"policy command invariant to hidden hook truth")
	world.free(); other.free()
	print("POLICY | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
