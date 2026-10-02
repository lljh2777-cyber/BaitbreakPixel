extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("ENTITY_FAIL | "+label)
func _initialize() -> void:
	var world:=World.new()
	world.reset_world({"seed":731})
	var ids: Array=[]
	for bait in world.baits: ids.append(bait.bait_id)
	check(ids==[1,2,3,4],"initial unique IDs")
	check(world.fish_id==1 and world.rod_id==1,"single entity identity")
	for frame in 60: world.advance_tick({}, {})
	for index in ids.size(): check(world.baits[index].bait_id==ids[index],"stable alive ID")
	world.refill_hook_bait(0)
	check(world.baits[0].bait_id==5 and world.bait_slot(1)==-1 and world.bait_slot(5)==0,"refill allocates fresh identity")
	var snapshot: Dictionary=world.capture_snapshot()
	var copy:=World.new(); copy.reset_world()
	check(copy.restore_snapshot(snapshot),"new schema restores")
	check(var_to_bytes(snapshot)==var_to_bytes(copy.capture_snapshot()),"snapshot retains IDs and allocator")
	var invalid: Dictionary=snapshot.duplicate(true)
	invalid.state.baits[1].bait_id=invalid.state.baits[0].bait_id
	check(not copy.restore_snapshot(invalid),"reject duplicate identity")
	world.reset_world({"seed":731})
	check(world.baits[0].bait_id==1 and world.next_bait_id==5,"new round resets namespace")
	world.free(); copy.free()
	print("ENTITY | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
