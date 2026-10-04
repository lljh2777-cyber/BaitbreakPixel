extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Fish=preload("res://scripts/fish_winding.gd")
const Shore=preload("res://scripts/shore_view.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("FISH_ORBIT_PASS | ",label)
	else: failed+=1; push_error("FISH_ORBIT_FAIL | "+label)
func fixture(target:int=0) -> Node2D:
	var w=World.new(); w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0})
	w.fish=Vector2(382,245); w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	var c:Dictionary=w.MapGeometry.coil_at(w.targets[target],w.targets[target].bounds.get_center()); c.target=target; c.progress=1.0
	w.wraps.append(c); w.fish=Vector2(c.entry)+Vector2(50,3); w.fish_line_length=44
	w.tension=0.4; w.rope_length=w.line_anchor(0).distance_to(w.mouth()); w._rebuild_rope()
	return w
func run() -> void:
	var worst_step:=0.0
	for target in [0,1,2,4,9,12,18,20,29]:
		var w=fixture(target)
		w.fish=Vector2(w.wraps[0].center); w.aim=Vector2.LEFT
		var renderer=Motion.new()
		var continuous:=true; var connected:=true; var immutable:=true; var in_water:=true
		var far_seen:=false; var near_seen:=false; var last:Vector2=w.fish
		for i in 181:
			var p:=i/180.0
			w.wraps[0].progress=p; w.elapsed=2+p*0.85
			w.fish+=Vector2(0.05,-0.01)
			var snapshot:PackedByteArray=var_to_bytes(w.capture_snapshot())
			var frame:=renderer.sample(w); var pose:Dictionary=frame.fish
			immutable=immutable and snapshot==var_to_bytes(w.capture_snapshot())
			connected=connected and frame.path[-1].is_equal_approx(pose.mouth) and frame.tail==frame.path.slice(frame.path.size()-frame.tail.size())
			connected=connected and Fish.attached_point(w,pose,w._tip(w.bound_bait)).is_equal_approx(pose.mouth)
			var step:float=last.distance_to(pose.position)
			worst_step=maxf(worst_step,step); continuous=continuous and step<5
			last=pose.position
			if p>=0.14 and p<=0.86:
				in_water=in_water and pose.position.x>=8 and pose.position.x<=632 and pose.position.y<=305.01
				far_seen=far_seen or not pose.front; near_seen=near_seen or pose.front
		check(continuous and in_water,"continuous approach, turn and return inside water: target %d" % target)
		check(connected and immutable,"mouth, hook and one line endpoint follow pose without changing physics: target %d" % target)
		check(far_seen and near_seen and not Fish.pose(w).active,"front/back lap completes and releases the visual pose: target %d" % target)
		var angles:=PackedFloat32Array()
		for i in 101:
			w.wraps[0].progress=0.14+0.72*i/100.0
			var pose:=Fish.pose(w)
			var radial:Vector2=(Vector2(pose.position)-Vector2(pose.center))/Vector2(pose.radii)
			angles.append(radial.angle())
		var total:=0.0
		for i in range(1,angles.size()): total+=wrapf(angles[i]-angles[i-1],-PI,PI)
		check(absf(total-TAU)<0.001,"fish travels exactly one full orbit, not just a side-to-side sway: target %d" % target)
		w.untangle_phase="unwind"; w.wraps[0].progress=0.5
		check(not Fish.pose(w).active and renderer.sample(w).path==Motion.build(w).path,"unwinding never starts a fish lap: target %d" % target)
		w.untangle_phase=""; w.landing=true
		check(not Fish.pose(w).active,"landing immediately cancels cosmetic lap: target %d" % target)
		w.landing=false; w.net_state="caught"
		check(not Fish.pose(w).active,"net catch immediately cancels cosmetic lap: target %d" % target)
		w.net_state="idle"; w._clear_hook()
		check(not Fish.pose(w).active and renderer.sample(w).path.is_empty(),"escape clears fish and line animation: target %d" % target)
		w.free()
	# 0.18.3 changes grass into a stem-hugging helix. Wood/stone retain their
	# original paths, effects, rod/hand poses and float positions byte for byte.
	var bytes:=PackedByteArray()
	for target in [0,1]:
		var w=fixture(target); w.untangle_phase="unwind"
		for i in 43:
			w.wraps[0].progress=1-i/42.0; w.untangle_age=i/42.0*w.UNWIND_SECONDS; w.elapsed=4+i/60.0
			var frame:=Motion.new().sample(w)
			bytes.append_array(var_to_bytes([frame.path,frame.front,frame.tail,frame.effects,frame.action,Shore.tackle_pose(w,w.elapsed),Shore.float_position(w,w.elapsed)]))
		w.free()
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	check(hash.finish().hex_encode()=="1a4ed6becc6d6433749a78734ee810f26e209716001cb39462490298fd183ce8","86 wood/stone unwind frames exactly match the pre-change animation")
	var a=fixture(); var b=fixture()
	for w in [a,b]:
		w.wraps[0].progress=0.0; w.fish=Vector2(337,243); w.fish_before=w.fish
		w.high_age=0; w.low_age=0; w.break_hold_seconds=20; w.slack_hold_seconds=20
	var initial:Vector2=a.fish; var renderer=Motion.new(); var identical:=true; var pause_ok:=false
	for i in 60:
		var command:Dictionary={"move":Vector2.RIGHT,"aim":Vector2.RIGHT}
		a.advance_tick(command,{}); b.advance_tick(command,{})
		var frame:=renderer.sample(a)
		if i==20: pause_ok=frame==renderer.sample(a)
		identical=identical and var_to_bytes(a.capture_snapshot())==var_to_bytes(b.capture_snapshot())
	check(identical and a.fish.distance_to(initial)>5,"movement and force simulation continue unchanged throughout the cosmetic lap")
	check(pause_ok,"paused world freezes the complete fish, hook and line frame")
	a.free(); b.free()
	print("FISH_ORBIT_V0182 | passed=",passed," | failed=",failed," | max_step_at_180_samples=",worst_step)
	quit(1 if failed else 0)
