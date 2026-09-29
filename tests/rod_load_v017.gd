extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Shore=preload("res://scripts/shore_view.gd")
const Hand=preload("res://scripts/angler_hand.gd")
const Left=preload("res://scripts/reel_hand.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("ROD_PASS | ",label)
	else: failed+=1; push_error("ROD_FAIL | "+label)
func fresh() -> Node2D:
	var w=World.new(); w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0})
	w.angler.x=280; w.fish=Vector2(280,235); w.baits[0].active=true
	w._enter_hook(0); w._attach_hook(); w.tension=1.0
	return w
func run() -> void:
	var w=fresh(); var rest:Dictionary=Shore.tackle_pose(w,0)
	w.angler.step_tackle_feedback(w,1.0/60)
	var first:Dictionary=Shore.tackle_pose(w,0)
	var rise:float=rest.hand.wrist.y-first.hand.wrist.y
	check(rise>0 and rise<2 and w.angler.rod_load>0 and w.angler.rod_load<0.2,"hook load begins with a small smooth lift, not an instantaneous jump")
	for frame in 120: w.angler.step_tackle_feedback(w,1.0/60)
	var loaded:Dictionary=Shore.tackle_pose(w,0)
	check(absf(rest.hand.wrist.y-loaded.hand.wrist.y-14)<0.01 and absf(rad_to_deg(loaded.hand.angle-rest.hand.angle)-6)<0.01,"full load raises the wrist 14 pixels and turns the grip 6 degrees")
	var top:=INF; var length:=0.0; var turn:=0.0
	for i in loaded.rod.size():
		top=minf(top,loaded.rod[i].y)
		if i>0: length+=loaded.rod[i].distance_to(loaded.rod[i-1])
		if i>1: turn=maxf(turn,absf((loaded.rod[i-1]-loaded.rod[i-2]).angle_to(loaded.rod[i]-loaded.rod[i-1])))
	check(loaded.tip.y-top>8 and turn<0.17,"loaded rod forms a continuous arch with a downward tip and no sharp hinge")
	check(absf(length-Shore.SHAFT_LENGTH)<0.002 and (loaded.rod[1]-loaded.rod[0]).normalized().dot(loaded.hand.axis)>0.9999,"bending preserves material length and the rigid handle tangent")
	var low:=Shore.rod_points(loaded.hand,0.1,1,Shore.float_position(w,0))
	var straight:Vector2=loaded.hand.socket+loaded.hand.axis*Shore.SHAFT_LENGTH
	check(loaded.tip.distance_to(straight)>low[-1].distance_to(straight)+20,"high tension bends visibly more than light tension")
	w.angler.reel_hand_amount=1; w.angler.reel_hand_mode=-1
	var left:Dictionary=Left.pose(loaded.hand,w.angler)
	var line:=Shore.surface_line(w,loaded.tip,Shore.float_position(w,0))
	check(Left.sprite_point(left.pivot,left).distance_to(left.crank)<0.001 and line[0]==loaded.tip,"left fingers and line endpoint follow the lifted reel and bent tip")
	w.tension=0
	for frame in 60: w.angler.step_tackle_feedback(w,1.0/60)
	var slack:Dictionary=Shore.tackle_pose(w,0)
	check(w.angler.rod_load<0.003 and slack.hand.wrist.y>loaded.hand.wrist.y+9 and slack.hand.wrist.y<rest.hand.wrist.y,"slack straightens the rod and lowers the hand while retaining a small hooked hold")
	w._clear_hook(); var lift_before:float=w.angler.rod_lift
	w.angler.step_tackle_feedback(w,1.0/60)
	check(w.angler.rod_lift>0 and w.angler.rod_lift<lift_before,"escape eases out the raised pose rather than dropping it instantly")
	for frame in 90: w.angler.step_tackle_feedback(w,1.0/60)
	check(w.angler.rod_lift<0.001 and w.angler.rod_load<0.001,"after escape the hand and rod fully settle back")
	var rates:=[]
	for hz in [30,60,120]:
		var other=fresh()
		for frame in hz: other.angler.step_tackle_feedback(other,1.0/hz)
		rates.append(Vector2(other.angler.rod_load,other.angler.rod_lift)); other.free()
	check(rates[0].distance_to(rates[1])<0.00001 and rates[1].distance_to(rates[2])<0.00001,"load and lift easing agree at 30/60/120 Hz")
	var a:Dictionary=w.capture_snapshot(); var b:Dictionary=a.duplicate(true)
	a.state.simulation_tick=10; b.state.simulation_tick=12
	a.rig.rod_load=0.0; b.rig.rod_load=1.0; a.rig.rod_lift=0.2; b.rig.rod_lift=0.8
	var presentation=Presentation.new(); presentation.accept(a,0); presentation.accept(b,0.1)
	var visual:Node2D=presentation.sample(0.1+1.0/60)
	check(absf(visual.angler.rod_load-0.5)<0.001 and absf(visual.angler.rod_lift-0.5)<0.001,"remote players interpolate both bend and arm lift")
	presentation.dispose(); w.free()
	print("ROD_LOAD_V017 | passed=",passed," | failed=",failed," | initial_lift=",rise," | apex_to_tip=",loaded.tip.y-top)
	quit(1 if failed else 0)
