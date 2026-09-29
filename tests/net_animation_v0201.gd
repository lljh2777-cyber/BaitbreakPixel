extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Motion=preload("res://scripts/net_motion.gd")
const Visual=preload("res://scripts/net_visual.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed+=1; print("NET_ANIMATION_PASS | ",text)
	else: failed+=1; push_error("NET_ANIMATION_FAIL | "+text)

func fixture(caught: bool=false, blocked: bool=false) -> Node2D:
	var w:=World.new()
	w.reset_world({"ruleset":"duel","challenge":false,"rules":{"water_strength":0.0,"net_reach":620.0,"net_sight":680.0}})
	w.fish=Vector2(260,140) if caught else Vector2(480,130); w.fish_before=w.fish
	var a:=Vector2(230,210) if blocked else Vector2(210,140)
	var b:=Vector2(420,210) if blocked else Vector2(310,140)
	w.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":a},{"kind":"point","point":b}]})
	return w

func run() -> void:
	for scenario in ["empty","catch","blocked"]:
		var w:=fixture(scenario=="catch",scenario=="blocked")
		var motion:=Motion.new()
		var previous: Dictionary={}
		var immutable:=true; var precise:=true; var attached:=true; var stable:=true
		var finite:=true; var rigid:=true; var max_jump:=0.0; var last: Dictionary={}
		var reached_catch:=false
		for tick in 300:
			var before:=var_to_bytes(w.capture_snapshot())
			var frame:=motion.sample(w)
			if not frame.active: break
			var side:=Motion.fish_pose(w,frame)
			var shore:=Motion.shore_pose(w,frame)
			last=shore
			immutable=immutable and before==var_to_bytes(w.capture_snapshot())
			stable=stable and frame==motion.sample(w)
			reached_catch=reached_catch or w.net_state=="caught"
			if w.net_state=="sweep": precise=precise and Vector2(frame.center).distance_to(w.net_pos)<0.001
			rigid=rigid and is_equal_approx(Vector2(side.u).length(),w.net_rim().x) and is_equal_approx(Vector2(side.v).length(),w.net_rim().y)
			for pose in [side,shore]:
				for key in ["center","u","v","bag","bu","bv","socket","grip"]: finite=finite and Vector2(pose[key]).is_finite()
				var relative: Vector2=pose.socket-pose.center
				var on_hoop:=pow(relative.dot(Vector2(pose.u).normalized())/Vector2(pose.u).length(),2)+pow(relative.dot(Vector2(pose.v).normalized())/Vector2(pose.v).length(),2)
				attached=attached and absf(on_hoop-1)<0.001
				for i in 11: finite=finite and Visual.surface(pose,i/10.0,0.5).is_finite()
			if not previous.is_empty(): max_jump=maxf(max_jump,Vector2(shore.center).distance_to(previous.center))
			previous=shore
			w.advance_tick({},{})
		check(immutable,"%s: animation cannot alter capture, obstacle or line state" % scenario)
		check(precise and rigid,"%s: active mouth stays on hitbox; rigid frame never inflates" % scenario)
		check(attached and finite,"%s: handle socket remains on hoop and mesh remains finite" % scenario)
		check(stable,"%s: drawing twice in one tick does not advance spring" % scenario)
		check(max_jump<22,"%s: no phase discontinuity; maximum screen movement %.2f px/frame" % [scenario,max_jump])
		check(Vector2(last.center).x<0 and Vector2(last.center).y>360,"%s: net leaves picture before state clears" % scenario)
		check(reached_catch==(scenario=="catch"),"%s: animation preserves catch/miss outcome" % scenario)
		check(not motion.sample(w).active,"%s: no stale net left after recovery" % scenario)
		w.free()
	test_network(false); test_network(true)
	test_reset_and_frame_rates()
	test_directions()
	test_corner()
	print("NET_ANIMATION_V0201 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func test_network(caught: bool) -> void:
	var w:=fixture(caught)
	var desired:="caught" if caught else "withdraw"
	for tick in 180:
		w.advance_tick({},{})
		if w.net_state==desired and w.net_age>0.45: break
	var a: Dictionary=w.capture_snapshot()
	w.advance_tick({},{}); w.advance_tick({},{})
	var b: Dictionary=w.capture_snapshot()
	var presenter:=Presentation.new(); presenter.accept(a,0); presenter.accept(b,1)
	var display: Node2D=presenter.sample(1+presenter.interval*0.5)
	var delay: float=w.NET_SETTLE if caught else 0.0
	var expected: Vector2=w._net_retract_point((float(a.state.net_age+b.state.net_age)*0.5-delay)/w.net_retract_duration)
	check(display.net_pos.distance_to(expected)<0.001,"network %s: lift samples the exact return path between snapshots" % desired)
	check(display.net_pos.distance_to(a.state.net_pos)>0.01 and display.net_pos.distance_to(b.state.net_pos)>0.01,"network %s: lift does not freeze at 30 Hz" % desired)
	if caught:
		var fish: Vector2=display.net_pos+display.net_catch_offset.lerp(display.net_bag_offset(),smoothstep(0,1,display.net_age/display.NET_SETTLE))
		check(display.fish.distance_to(fish)<0.001,"network: captured fish stays attached to interpolated bag")
	check(var_to_bytes(a)==var_to_bytes(presenter.previous) and var_to_bytes(b)==var_to_bytes(presenter.current),"network %s: source snapshots remain immutable" % desired)
	presenter.dispose(); w.free()

func test_reset_and_frame_rates() -> void:
	var results:=[]
	for fps in [30,60,120]:
		var w:=fixture(); var motion:=Motion.new()
		w.net_state="sweep"; w.net_motion=Vector2(160,0); w.elapsed=0; w.net_pos=Vector2(210,140)
		motion.sample(w)
		for i in fps:
			w.elapsed=(i+1)/float(fps); w.net_pos=Vector2(210,140)+Vector2(160,0)*w.elapsed
			motion.sample(w)
		results.append(motion.drag)
		w.elapsed=0; w.net_pos=Vector2(210,140)
		check(Vector2(motion.sample(w).drag).length()<0.001,"%d Hz: restarting clears bag momentum" % fps)
		w.free()
	check(Vector2(results[0]).distance_to(results[2])<0.001,"bag damping agrees at 30 / 60 / 120 Hz")

func test_directions() -> void:
	var w:=fixture()
	w.net_state="caught"
	for angle in [0.0,PI/2,PI,-PI/2]:
		w.net_angle=angle
		var sound:=true
		for i in 33:
			w.net_age=i*w.NET_SETTLE/32.0; w.elapsed=w.net_age
			var pose:=Motion.fish_pose(w,Motion.new().sample(w))
			sound=sound and Vector2(pose.bu).length()>9 and Vector2(pose.bv).length()>12
			sound=sound and absf(Vector2(pose.bu).normalized().dot(Vector2(pose.bv).normalized()))<0.001
		check(sound,"direction %.2f: pocket settles without collapsing or reversing its mesh" % angle)
	w.free()

func test_corner() -> void:
	var w:=fixture()
	for i in 150:
		w.advance_tick({},{})
		if w.net_state=="withdraw": break
	var corner_distance: float=w.net_return_from.distance_to(w.net_from)
	var fraction: float=corner_distance/w._net_retract_length()
	var low:=0.0; var high:=1.0
	for i in 25:
		var mid: float=(low+high)*0.5
		if smoothstep(0,1,mid)<fraction: low=mid
		else: high=mid
	var time: float=(low+high)*0.5*w.net_retract_duration
	w.net_age=time-1.0/60; w.net_pos=w._net_retract_point(w.net_age/w.net_retract_duration)
	var a: Dictionary=w.capture_snapshot()
	w.net_age=time+1.0/60; w.net_pos=w._net_retract_point(w.net_age/w.net_retract_duration); w.simulation_tick+=2
	var b: Dictionary=w.capture_snapshot()
	var presenter:=Presentation.new(); presenter.accept(a,0); presenter.accept(b,1)
	var display: Node2D=presenter.sample(1+presenter.interval*0.5)
	check(display.net_pos.distance_to(w.net_from)<0.001,"network: interpolation reaches the real path corner instead of cutting diagonally")
	check(display.net_pos.distance_to(Vector2(a.state.net_pos).lerp(b.state.net_pos,0.5))>0.5,"corner fixture distinguishes path sampling from unsafe linear interpolation")
	presenter.dispose(); w.free()
