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
	if ok: passed+=1; print("TACKLE_PASS | ",label)
	else: failed+=1; push_error("TACKLE_FAIL | "+label)
func fresh() -> Node2D:
	var w=World.new(); w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0,"seed":51})
	w.angler.x=880; w.fish=Vector2(910,275); w.baits[0].active=true
	w.baits[0].pos=w.angler.anchor()+Vector2(0,132); w.angler.previous_anchor=w.angler.anchor()
	w.angler.step_tackle_feedback(w,1.0/60)
	return w
func run() -> void:
	var w=fresh(); var start_tip:=Shore.rod_tip(w,0); var start_float:=Shore.float_position(w,0)
	w.advance_tick({}, {"walk":-1})
	var rod_move:=absf(Shore.rod_tip(w,0).x-start_tip.x)
	var float_move:=absf(Shore.float_position(w,0).x-start_float.x)
	check(rod_move>0.2 and float_move<rod_move*0.2,"rod moves first; water entry point cannot follow instantly")
	var left:=false; var right:=false; var endpoints:=true
	for frame in 480:
		w.advance_tick({}, {"walk":-1 if frame<180 else (1 if frame>=240 and frame<420 else 0)})
		var tip:=Shore.rod_tip(w,0); var buoy:=Shore.float_position(w,0)
		left=left or buoy.x<tip.x-4; right=right or buoy.x>tip.x+4
		var line:=Shore.surface_line(w,tip,buoy)
		endpoints=endpoints and line[0]==tip and line[-1]==buoy
	check(left and right,"inertial line naturally crosses to both sides during left/right reversal")
	check(endpoints,"line stays attached to the actual tip and the independently moving float")
	var following=fresh()
	for frame in 90: following.advance_tick({}, {"walk":-1})
	var speed:float=following.angler.surface_velocity; var at:float=following.angler.surface_x
	following.advance_tick({}, {})
	check(absf(speed)>5 and absf(following.angler.surface_velocity-speed)<5 and following.angler.surface_x!=at,"stopping the rod retains float momentum without a teleport or velocity reset")
	var positions:=[]
	for hz in [30,60,120]:
		var other=fresh()
		other.baits[0].pos=Vector2(280,220)
		for frame in hz*3: other.angler.step_tackle_feedback(other,1.0/hz)
		positions.append(other.angler.surface_x); other.free()
	check(absf(positions[0]-positions[2])<0.01 and absf(positions[1]-positions[2])<0.01,"water-resistance integration agrees at 30/60/120 Hz")
	w.angler.x=280; w.fish=Vector2(310,235); w._enter_hook(0); w._attach_hook(); w.break_hold_seconds=10; w.slack_hold_seconds=3
	for frame in 45: w.advance_tick({"move":Vector2.DOWN}, {"reel":true})
	check(w.reel_speed<0 and w.angler.reel_hand_mode==-1 and w.angler.reel_hand_amount>0.99,"W deploys the winding hand while hooked and actually reeling")
	var phase:float=w.angler.reel_phase
	var right_pose:Dictionary=Shore.tackle_pose(w,0).hand
	var hand_state:=Left.pose(right_pose,w.angler)
	check(Left.sprite_point(hand_state.pivot,hand_state).distance_to(hand_state.crank)<0.001,"winding fingers share the crank knob's exact moving anchor")
	w.advance_tick({"move":Vector2.DOWN}, {"reel":true})
	check(absf(angle_difference(phase,w.angler.reel_phase))>0.01 and absf(angle_difference(phase,w.angler.reel_phase))<0.25,"reel phase integrates actual speed smoothly")
	var amounts_ok:=true; var old_amount:float=w.angler.reel_hand_amount
	for frame in 60:
		w.advance_tick({"move":Vector2.DOWN}, {"release":true})
		amounts_ok=amounts_ok and absf(w.angler.reel_hand_amount-old_amount)<=0.101
		old_amount=w.angler.reel_hand_amount
	check(amounts_ok and w.reel_speed>0 and w.angler.reel_hand_mode==1 and w.angler.reel_hand_amount>0.99,"W to S retracts and repositions the hand instead of snapping poses")
	hand_state=Left.pose(Shore.tackle_pose(w,0).hand,w.angler)
	check(Left.sprite_point(hand_state.pivot,hand_state).distance_to(hand_state.adjuster)<0.001,"pay-out fingers hold the reel adjuster; they do not wind backwards")
	phase=w.angler.reel_phase
	for frame in 30: w.advance_tick({"move":Vector2.DOWN}, {"release":true})
	check(w.angler.reel_phase==phase,"paying out leaves the crank phase stationary")
	var snapshot:Dictionary=w.capture_snapshot(); var copy=World.new()
	check(copy.restore_snapshot(snapshot) and copy.capture_snapshot()==snapshot,"float velocity and both hand phases survive snapshot round trips")
	for frame in 30:
		w.advance_tick({"move":Vector2.DOWN},{"release":true})
		copy.advance_tick({"move":Vector2.DOWN},{"release":true})
	check(w.capture_snapshot()==copy.capture_snapshot(),"restored tackle feedback replays deterministically")
	w.match_paused=true; var paused:Dictionary=w.capture_snapshot()
	w.advance_tick({}, {"reel":true,"walk":1})
	check(w.capture_snapshot()==paused,"pause freezes float and hand animation")
	w.match_paused=false
	for frame in 50: w.advance_tick({"move":Vector2.DOWN},{})
	check(w.angler.reel_hand_amount==0,"letting go smoothly returns the left hand off screen")
	var older:Dictionary=w.capture_snapshot(); var newer:Dictionary=older.duplicate(true)
	older.state.simulation_tick=10; newer.state.simulation_tick=12
	older.rig.surface_live=true; newer.rig.surface_live=true
	older.rig.surface_x=100.0; newer.rig.surface_x=200.0
	older.rig.reel_phase=TAU-0.08; newer.rig.reel_phase=0.08
	older.rig.release_phase=TAU-0.06; newer.rig.release_phase=0.06
	older.rig.reel_hand_mode=-1; newer.rig.reel_hand_mode=-1
	older.rig.reel_hand_amount=0.2; newer.rig.reel_hand_amount=0.6
	var presentation=Presentation.new(); presentation.accept(older,10.0); presentation.accept(newer,10.1)
	var visual:Node2D=presentation.sample(10.1+1.0/60)
	check(absf(visual.angler.surface_x-150)<0.001 and absf(visual.angler.reel_hand_amount-0.4)<0.001,"remote float and reaching hand interpolate between network frames")
	check(absf(angle_difference(0,visual.angler.reel_phase))<0.001 and absf(angle_difference(0,visual.angler.release_phase))<0.001,"remote reel phases cross 360 degrees without spinning backwards")
	presentation.dispose()
	var free_rig=fresh()
	for frame in 30: free_rig.advance_tick({}, {"reel":true})
	check(free_rig.hooked==free_rig.HookState.FREE and free_rig.angler.free_reel_speed<0 and free_rig.angler.reel_hand_mode==-1 and free_rig.angler.reel_hand_amount==1,"W animates the winding hand before any fish bites")
	for frame in 60: free_rig.advance_tick({}, {"release":true})
	check(free_rig.angler.free_reel_speed>0 and free_rig.angler.reel_hand_mode==1 and free_rig.angler.reel_hand_amount==1,"S switches to the pay-out gesture before a bite")
	phase=free_rig.angler.reel_phase; var release_phase:float=free_rig.angler.release_phase
	for frame in 10: free_rig.advance_tick({}, {"release":true})
	check(free_rig.angler.reel_phase==phase and free_rig.angler.release_phase!=release_phase and Shore.tackle_pose(free_rig,0).reel_speed>0,"free pay-out advances the spool phase without reversing the crank")
	for frame in 30: free_rig.advance_tick({}, {})
	check(free_rig.angler.free_reel_speed==0 and free_rig.angler.reel_hand_amount==0,"letting go before a bite also stops and retracts the hand")
	for frame in 30: free_rig.advance_tick({}, {"reel":true})
	free_rig._enter_hook(0)
	for frame in 20: free_rig.advance_tick({}, {"reel":true})
	check(free_rig.hooked==free_rig.HookState.MOUTH and free_rig.angler.feedback_reel_speed(free_rig)==0 and free_rig.angler.reel_hand_amount==0,"entry QTE suppresses stale free-spool motion while reeling is locked")
	free_rig._attach_hook(); free_rig.break_hold_seconds=10
	for frame in 25: free_rig.advance_tick({"move":Vector2.DOWN}, {"reel":true})
	check(free_rig.angler.reel_hand_mode==-1 and free_rig.angler.reel_hand_amount==1,"the hooked spool takes over the same animation after the bite")
	free_rig._release_hook(false)
	for frame in 40: free_rig.advance_tick({}, {"release":true})
	check(free_rig.hooked==free_rig.HookState.FREE and free_rig.angler.reel_hand_mode==1 and free_rig.angler.reel_hand_amount==1,"after escape the free rig keeps supporting pay-out animation")
	free_rig.angler.free_line_length=520; free_rig.angler.free_reel_speed=90
	check(free_rig.angler.feedback_reel_speed(free_rig)==0,"a fully paid-out free line does not show endless spooling")
	free_rig.angler.free_line_length=132
	for bait in free_rig.baits: bait.active=false
	for frame in 30: free_rig.advance_tick({}, {"reel":true})
	check(free_rig.angler.feedback_reel_speed(free_rig)==0 and free_rig.angler.reel_hand_amount==0,"cached speed cannot animate an undeployed or retrieved rig")
	free_rig.free()
	w.free(); copy.free(); following.free()
	print("TACKLE_V016 | passed=",passed," | failed=",failed," | first_rod=",rod_move," | first_float=",float_move," | dt_positions=",positions)
	quit(1 if failed else 0)
