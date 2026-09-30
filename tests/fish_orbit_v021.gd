extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Fish=preload("res://scripts/fish_winding.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("ORBIT21_PASS | ",title)
	else: failed+=1; push_error("ORBIT21_FAIL | "+title)
func run() -> void:
	var w:=World.new(); w.reset_world({"ruleset":"duel","rules":{"water_strength":0}})
	w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	for target in w.targets.size():
		var c: Dictionary=w.Layout.coil_at(w.targets[target],w.targets[target].bounds.get_center())
		c.target=target; c.progress=0.0; w.wraps.assign([c])
		w.fish=Vector2(c.center).clamp(Vector2(25,85),Vector2(1255,411)); w.fish_line_length=44
		w.rope_length=w.line_anchor(0).distance_to(w.mouth()); w.untangle_phase=""; w.net_state="wait"
		var previous: Vector2=w.fish; var continuous:=true; var connected:=true; var in_water:=true; var immutable:=true
		var front:=false; var back:=false
		for i in 181:
			w.wraps[0].progress=i/180.0; w.elapsed=2+i/180.0
			var snapshot:=var_to_bytes(w.capture_snapshot())
			var frame:=Motion.new().sample(w); var pose: Dictionary=frame.fish
			continuous=continuous and previous.distance_to(pose.position)<5; previous=pose.position
			connected=connected and frame.path[-1].is_equal_approx(pose.mouth)
			connected=connected and Fish.attached_point(w,pose,w._tip(0)).is_equal_approx(pose.mouth)
			immutable=immutable and snapshot==var_to_bytes(w.capture_snapshot())
			if i>=26 and i<=154:
				in_water=in_water and pose.position.x>=8 and pose.position.x<=1272 and pose.position.y<=425.01
				front=front or pose.front; back=back or not pose.front
		check(continuous and in_water,"continuous lap stays at cover height inside expanded water: "+str(target))
		check(connected and immutable,"fish mouth and rope stay joined without mutating physics: "+str(target))
		check(front and back and not Fish.pose(w).active,"lap uses both depth layers and returns to swimming: "+str(target))
		w.untangle_phase="unwind"; w.wraps[0].progress=0.5
		check(not Fish.pose(w).active,"human unwinding never starts a fish lap: "+str(target))
	w.free(); print("FISH_ORBIT_V021 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
