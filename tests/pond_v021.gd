extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Layout=preload("res://scripts/pond_layout.gd")
const Camera=preload("res://scripts/pond_camera.gd")
const Shore=preload("res://scripts/shore_view.gd")
const Brain=preload("res://scripts/fish_brain.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Grass=preload("res://scripts/grass_binding.gd")
const Motion=preload("res://scripts/line_motion.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("POND21_PASS | ",title)
	else: failed+=1; push_error("POND21_FAIL | "+title)
func fresh(w: Node2D, seed_value: int=2719) -> void:
	w.reset_world({"ruleset":"duel","seed":seed_value,"rules":{"water_strength":0,"timer_enabled":false}})
func run() -> void:
	var w:=World.new(); var clone:=World.new(); fresh(w)
	w.fish=Vector2(900,370)
	for i in 240: w.advance_tick({"move":Vector2.RIGHT},{})
	check(w.fish.x>1050 and w.fish.y>350,"fish can swim past both old viewport boundaries")
	w.move_fish(Vector2(10000,10000))
	check(Layout.fish_bounds(12).has_point(w.fish-Vector2.ONE),"far bank and floor still bound fish movement")
	w.move_fish(Vector2(-10000,-10000))
	check(w.fish.x>=20 and w.fish.y>=80,"near bank and surface remain bounded")
	for point in [Layout.SPAWN,Vector2(650,200),Vector2(1040,410)]:
		w.fish=point
		var off:=Camera.offset(w,"fish")
		check(off.x>=0 and off.x<=640 and off.y>=0 and off.y<=120,"camera stays inside map at "+str(point))
		check(Camera.to_world(Camera.to_screen(point,w,"fish"),w,"fish")==point,"fish pointer roundtrip at "+str(point))
		check(Rect2(0,35,640,298).has_point(Camera.to_screen(point,w,"fish")),"fish remains below HUD and above hint bar")
	var maps:=true
	for point in [Vector2(100,100),Vector2(780,270),Vector2(1210,415)]:
		maps=maps and Shore.to_world(Shore.to_screen(point,w),w).distance_to(point)<0.001
	check(maps,"shore perspective has an exact inverse across the expanded pond")
	for i in 1000: w.advance_tick({}, {"walk":1})
	check(w.angler.x>1200 and w.angler.anchor().x<1280,"angler reaches the far bank without exceeding map")
	w.fish=Vector2(1150,220)
	var old_offset:=Camera.offset(w,"angler")
	w.fish=Vector2(40,410)
	check(Camera.offset(w,"angler")==old_offset,"observation camera cannot reveal hidden fish through its position")
	w.angler.free_line_length=320
	var p:=Vector2(1130,290)
	check(Camera.to_world(Camera.to_screen(p,w,"angler"),w,"angler")==p,"deep observation click roundtrip")
	var clean:=Protocol.input("angler",{"target":p,"net_events":[{"kind":"point","point":p}]},w.map_context)
	check(clean.target==p and clean.net_events[0].point==p,"network input no longer truncates far-bank world coordinates")
	w.angler.x=1054; w.fish=Vector2(1120,180); w.fish_before=w.fish
	w.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(1070,180)},{"kind":"point","point":Vector2(1170,180)}]})
	check(w.net_from.x>640 and w.net_to.x>640 and w.net_state=="warning","far-bank net commits actual world endpoints")
	check(clone.restore_snapshot(w.capture_snapshot()),"expanded map snapshot restores")
	var same:=true
	for i in 120:
		w.advance_tick({},{}); clone.advance_tick({},{})
		same=same and var_to_bytes(w.capture_snapshot())==var_to_bytes(clone.capture_snapshot())
	check(same and w.net_catches==1,"far-bank directional capture and lift replay identically")
	var invalid: Dictionary=w.capture_snapshot(); invalid.map_id="pond_v1"
	check(not clone.restore_snapshot(invalid),"old map snapshots cannot silently use new cover geometry")
	fresh(w,42); fresh(clone,42)
	check(var_to_bytes(w.capture_snapshot())==var_to_bytes(clone.capture_snapshot()),"bait locations use authoritative seeded random state")
	var initial: Array=[]
	for bait in w.baits: initial.append(bait.home)
	fresh(w,43); var changed:=false; var seen: Array=[]; var count:=0
	for i in w.baits.size():
		var bait: Dictionary=w.baits[i]; changed=changed or bait.home!=initial[i]
		if bait.active: count+=1
		seen.append(bait.home)
	check(changed and seen.size()==4 and seen[0]!=seen[1] and seen[1]!=seen[3],"new seed changes bait positions and keeps food groups separated")
	check(count==2,"duel starts with two neutral food groups before the human casts")
	w.reset_world({"ruleset":"survival","seed":43})
	count=0
	for bait in w.baits:
		if bait.active: count+=1
	var type_shapes:=true
	var active_types: Dictionary={}
	for bait in w.baits:
		if bait.active: active_types[bait.bait_type]=true
		var reference: Dictionary=w._make_bait(0,0,bait.bait_type)
		for i in bait.grains.size(): type_shapes=type_shapes and bait.grains[i].offset==reference.grains[i].offset
	check(count==3 and active_types.size()==3 and type_shapes,"fish solo offers three type silhouettes independent of hook truth or slot")
	var brain:=Brain.new(); brain.reset(99); w.fish=Vector2(400,230); w.aim=Vector2.RIGHT
	for i in w.baits.size(): w.baits[i].active=i<2; w.baits[i].pos=Vector2(470+i*150,230)
	var a: Dictionary=brain.command(w,1.0/60)
	w.baits[0].hook=false; w.baits[1].hook=true; brain.reset(99)
	check(brain.command(w,1.0/60)==a,"fish AI makes the same feeding decision when hook identities swap")
	var contact:=true; var anchored:=true; var solid_clear:=true
	for i in Layout.PLANTS.size():
		var plant: Dictionary=Layout.PLANTS[i]
		var target_index: int=Layout.SOLIDS.size()+i
		var target: Dictionary=w.targets[target_index]
		var center:=Vector2(plant.x,plant.y-plant.height*0.4)
		contact=contact and Layout.touches(center,1,target.polygon)
		var wrap:=Layout.coil_at(target,center); wrap.target=target_index
		var binding:=Grass.profile(w,wrap,1)
		anchored=anchored and Grass.deform(Vector2(plant.x,plant.y),binding).distance_to(Vector2(plant.x,plant.y))<0.001
	check(contact,"all plants share actual root heights with interaction targets")
	check(anchored,"winding deforms stalks but never detaches their roots")
	for solid in Layout.SOLIDS:
		for point in solid.points: solid_clear=solid_clear and point.x>=0 and point.x<=1280 and point.y<=Layout.FLOOR
	check(solid_clear,"wood and rock silhouettes remain within the map")
	fresh(w); w.fish=Vector2(1120,355); w.baits[0].active=true
	w._enter_hook(0); w._attach_hook(); w._update_contacts(0)
	check(w.contact_target>=0 and w._begin_wrap(),"far-bank vegetation supports the existing escape QTE")
	var before:=var_to_bytes(w.capture_snapshot()); var motion:=Motion.new(); motion.sample(w)
	check(before==var_to_bytes(w.capture_snapshot()),"expanded cover presentation never changes simulation")
	w.free(); clone.free()
	print("POND_V021 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
