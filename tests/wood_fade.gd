extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Layout=preload("res://scripts/pond_layout.gd")
const Art=preload("res://scripts/pixel_art.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("WOOD_FADE_PASS | ",title)
	else: failed+=1; push_error("WOOD_FADE_FAIL | "+title)
func fresh(world: Node2D) -> void:
	world.reset_world({"ruleset":"duel","seed":42,"rules":{"cover_opacity":0.46,"water_strength":0,"timer_enabled":false}})
func group_matches(world: Node2D, group: int, opacity: float) -> bool:
	for index in Layout.SOLIDS.size():
		if Layout.solid_fade_group(index)==group and absf(world.target_opacity[index]-opacity)>0.00001: return false
	return true
func run() -> void:
	var world:=World.new(); var clone:=World.new(); fresh(world); fresh(clone)
	var targets:=var_to_bytes(world.targets)
	for sample: Array in [[1,Vector2(350,350)],[4,Vector2(286,267)],[5,Vector2(394,237)],[6,Vector2(280,398)],[7,Vector2(542,399)],[11,Vector2(314,218)],[12,Vector2(365,239)],[15,Vector2(586,330)],[17,Vector2(1220,380)],[18,Vector2(1186,381)]]:
		fresh(world); var index: int=sample[0]-1; world.fish=sample[1]
		check(world.touching_target(index),"entry fixture touches wood part %d" % sample[0])
		for tick in 12: world._update_contacts(1.0/60)
		var group:=Layout.solid_fade_group(index)
		check(group_matches(world,group,0.46),"touching part %d fades its entire connected trunk, branches and roots" % sample[0])
		var independent:=true
		for other in Layout.SOLIDS.size():
			if Layout.SOLIDS[other].kind=="wood" and Layout.solid_fade_group(other)!=group:
				independent=independent and world.target_opacity[other]==1.0
		check(independent,"touching part %d never fades another tree" % sample[0])
	fresh(world); world.fish=Vector2(350,350)
	for tick in 12: world._update_contacts(1.0/60)
	world.fish=Vector2(286,267); world._update_contacts(1.0/60)
	check(group_matches(world,0,0.46),"moving from trunk to branch keeps the tree at the same opacity")
	check(world.contact_target==3,"physical contact still selects the actual branch rather than its fade group parent")
	world.fish=Vector2(460,120); world._update_contacts(1.0/60)
	check(group_matches(world,0,0.46+4.0/60),"leaving all parts restores the whole tree gradually and in sync")
	for tick in 12: world._update_contacts(1.0/60)
	check(group_matches(world,0,1.0),"the whole tree becomes opaque again after exit")
	fresh(world); world.fish=Vector2(731,400); world._update_contacts(0.1)
	check(world.target_opacity[2]<1 and group_matches(world,0,1) and group_matches(world,6,1) and group_matches(world,16,1),"stone contact remains independent of wood fading")
	fresh(world); world.fish=Vector2(350,350); world._update_contacts(0.1)
	check(clone.restore_snapshot(world.capture_snapshot()) and var_to_bytes(clone.capture_snapshot())==var_to_bytes(world.capture_snapshot()),"group fade state survives the existing snapshot schema")
	var deterministic:=true
	for tick in 90:
		world.advance_tick({"move":Vector2.LEFT},{}); clone.advance_tick({"move":Vector2.LEFT},{})
		deterministic=deterministic and var_to_bytes(world.capture_snapshot())==var_to_bytes(clone.capture_snapshot())
	check(deterministic,"restored fade state continues identically while entering and leaving wood")
	var assemblies:=Art.scene_props(); var seen: Dictionary={}
	for assembly: Dictionary in assemblies:
		for index: int in assembly.targets:
			check(not seen.has(index),"solid %d is rendered exactly once" % index)
			seen[index]=true
	check(seen.size()==Layout.SOLIDS.size() and assemblies.size()==11,"all original solids are covered by eleven independent render assemblies")
	check(var_to_bytes(world.targets)==targets,"shared fading never changes contact, net or coil geometry")
	world.free(); clone.free()
	print("WOOD_FADE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
