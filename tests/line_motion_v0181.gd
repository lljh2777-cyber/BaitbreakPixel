extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Shore=preload("res://scripts/shore_view.gd")
const Left=preload("res://scripts/reel_hand.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("LINE_MOTION_PASS | ",label)
	else: failed+=1; push_error("LINE_MOTION_FAIL | "+label)
func fixture(target:int=0) -> Node2D:
	var w=World.new(); w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0})
	w.fish=Vector2(382,245); w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	var c:Dictionary=w.Layout.coil_at(w.targets[target],w.targets[target].bounds.get_center()); c.target=target; c.progress=1.0
	w.wraps.append(c); w.fish=Vector2(c.entry)+Vector2(50,3); w.fish_line_length=44
	w.tension=0.4; w.rope_length=w.line_anchor(0).distance_to(w.mouth()); w._rebuild_rope()
	return w
func distance_to_path(p:Vector2,path:PackedVector2Array) -> float:
	var d:=INF
	for i in range(1,path.size()): d=minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i-1],path[i])))
	return d
func mismatch(a:PackedVector2Array,b:PackedVector2Array) -> float:
	var d:=0.0
	for p in a: d=maxf(d,distance_to_path(p,b))
	for p in b: d=maxf(d,distance_to_path(p,a))
	return d
func run() -> void:
	var max_step:=0.0
	var step_at:=""
	for target in [0,1,12]:
		var w=fixture(target)
		for unwind in [false,true]:
			w.untangle_phase="unwind" if unwind else ""
			var previous:=PackedVector2Array(); var valid:=true; var exact:=true; var shared_tail:=true; var immutable:=true
			for frame in 61:
				var p:=frame/60.0
				w.wraps[0].progress=1-p if unwind else p
				w.untangle_age=p*w.UNWIND_SECONDS if unwind else 0.0
				var state:PackedByteArray=var_to_bytes(w.capture_snapshot())
				var data:=Motion.build(w)
				immutable=immutable and state==var_to_bytes(w.capture_snapshot())
				valid=valid and data.front.size()==data.path.size()-1
				exact=exact and data.path[0]==w.line_anchor(0) and data.path[-1]==w.mouth()
				shared_tail=shared_tail and data.path.slice(data.path.size()-data.tail.size())==data.tail
				for point in data.path: valid=valid and point.is_finite()
				if not previous.is_empty():
					var difference:=mismatch(previous,data.path)
					if difference>max_step: max_step=difference; step_at="target=%d unwind=%s frame=%d" % [target,unwind,frame]
				previous=data.path
			check(valid and exact,"finite continuous route with exact endpoints for target %d unwind=%s" % [target,unwind])
			check(shared_tail and immutable,"front/back share one tail and do not mutate game state for target %d unwind=%s" % [target,unwind])
		w.untangle_phase="unwind"; w.wraps[0].progress=0.0001
		var before:PackedVector2Array=Motion.build(w).path
		var offset:float=w.fish_line_length-Vector2(w.wraps[0].entry).distance_to(w.mouth())
		w.wraps.clear(); w.untangle_phase=""; w.rope_length=w.line_anchor(0).distance_to(w.mouth())+offset+0.32*32
		check(mismatch(before,Motion.build(w).path)<0.20,"last contact releases without a visible snap for target %d" % target)
		w.free()
	check(max_step<5.0,"animation remains bounded between consecutive phase samples: %.3f px" % max_step)
	var w=fixture(); var c:Dictionary=w.wraps[0]
	var first:=Motion.coil(c,0,false); var final:=Motion.coil(c,1,false); var middle:=Motion.coil(c,0.5,false)
	check(first.turn==0 and final.turn==1 and final.points[0]==final.points[-1],"complete coil closes precisely at the original contact")
	check(Motion.coil(c,0.01,false).turn<0.001 and 1-Motion.coil(c,0.99,false).turn<0.001,"winding eases into and out of its turn")
	check(middle.points[32].distance_to(c.center)>Vector2(c.radii).length()*0.7,"in-flight coil has visible loose clearance before seating")
	var near_count:=0
	for value in final.front:
		if value: near_count+=1
	check(near_count>=30 and near_count<=33,"near half crosses in front of cover while far half stays behind")
	w.angler.reel_hand_mode=-1; w.angler.reel_hand_amount=1; w.angler.rod_load=0.4; w.angler.rod_lift=0.55
	w.untangle_phase="unwind"
	var grip_steps:=0.0; var last:=Vector2.ZERO; var rigid:=true; var connected:=true; var first_wrist:=Vector2.ZERO; var last_wrist:=Vector2.ZERO
	for frame in 85:
		w.untangle_age=frame/84.0*w.UNWIND_SECONDS; w.wraps[0].progress=1.0-frame/84.0
		var pose:=Shore.tackle_pose(w,0); var left:=Left.pose(pose.hand,w.angler)
		var length:=0.0
		for i in range(1,pose.rod.size()): length+=pose.rod[i].distance_to(pose.rod[i-1])
		rigid=rigid and absf(length-Shore.SHAFT_LENGTH)<0.01
		connected=connected and Left.sprite_point(left.pivot,left).distance_to(left.crank)<0.001 and Shore.surface_line(w,pose.tip,Shore.float_position(w,0))[0]==pose.tip
		if frame>0: grip_steps=maxf(grip_steps,last.distance_to(pose.hand.wrist))
		if frame==0: first_wrist=pose.hand.wrist
		last=pose.hand.wrist; last_wrist=last
	check(rigid and connected,"unwind arm sweep preserves shaft length, left fingers and line/rod joints")
	check(grip_steps>0.05 and grip_steps<1.0 and first_wrist.distance_to(last_wrist)<0.001,"wrist moves smoothly and settles to the same pose without snapping")
	var second:Dictionary=w.Layout.coil_at(w.targets[3],Vector2(265,270)); second.target=3; second.progress=0.5
	w.wraps[0].progress=1.0; w.wraps.append(second); w.untangle_phase=""
	var multiple:=Motion.build(w)
	check(multiple.front.size()==multiple.path.size()-1 and multiple.path[0]==w.line_anchor(0) and multiple.path[-1]==w.mouth(),"multiple wraps share a single connected route")
	w._clear_hook(); check(Motion.build(w).path.is_empty() and not Motion.action(w).active,"escape removes all cosmetic line and action effects")
	w.free(); w=fixture()
	w.untangle_phase="unwind"; w.untangle_target=w.wraps[0].target; w.wraps[0].progress=0.42; w.untangle_age=0.58*w.UNWIND_SECONDS; w.elapsed=2.0
	var renderer=Motion.new(); var moving:Dictionary=renderer.sample(w)
	w._reset_untangle(); w.elapsed+=1.0/60
	var authoritative:PackedByteArray=var_to_bytes(w.capture_snapshot())
	var returning:Dictionary=renderer.sample(w)
	check(w.wraps[0].progress==1 and mismatch(moving.path,returning.path)<3,"interrupted unwind visually reseats instead of popping a whole turn into view")
	check(var_to_bytes(w.capture_snapshot())==authoritative and returning.action.active,"cosmetic recovery does not delay the actual restored coil")
	check(returning==renderer.sample(w),"pause freezes both line recovery and matching hand gesture")
	for frame in 15: w.elapsed+=1.0/60; returning=renderer.sample(w)
	check(returning.path==Motion.build(w).path and not returning.action.active,"recovery settles exactly onto the authoritative full coil")
	w._clear_hook(); w.elapsed=0
	check(renderer.sample(w).path.is_empty(),"new round and escape clear cached animation")
	w.free()
	print("LINE_MOTION_V0181 | passed=",passed," | failed=",failed," | max_step=",max_step," | wrist_step=",grip_steps," | ",step_at)
	quit(1 if failed else 0)
