extends SceneTree
const Hand=preload("res://scripts/angler_hand.gd")
const Shore=preload("res://scripts/shore_view.gd")
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("MOTION_PASS | ",label)
	else: failed+=1; push_error("MOTION_FAIL | "+label)
func run() -> void:
	var world=World.new(); world.reset_world({"ruleset":"duel","challenge":false,"water_strength":0})
	var rock:=Vector2(145,285); var fixed_rock:=Shore.to_screen(rock,world)
	var fixed_cursor:=Shore.to_world(Vector2(380,265),world)
	var before:=Shore.tackle_pose(world,0)
	for frame in 60: world.advance_tick({}, {"walk":1})
	var after:=Shore.tackle_pose(world,0)
	var grip_move:float=after.hand.wrist.x-before.hand.wrist.x
	check(grip_move>20 and after.tip.x-before.tip.x>25,"one second of D visibly moves both hand and tip, not just the underwater image")
	check(Shore.to_screen(rock,world)==fixed_rock and Shore.to_world(Vector2(380,265),world)==fixed_cursor,"A/D leaves fixed scenery and net pointer coordinates exactly stationary")
	var fixed_hand:Vector2=Shore.tackle_pose(world,0).hand.wrist
	world.baits[0].active=true; world.baits[0].pos=Vector2(30,100)
	var hand_a:Vector2=Shore.tackle_pose(world,0).hand.wrist
	world.baits[0].pos=Vector2(600,280)
	check(Shore.tackle_pose(world,0).hand.wrist==hand_a and hand_a==fixed_hand,"hook or float motion cannot drag the hand or cancel the player's sweep")
	world.angler.line_sway=0
	world.angler.surface_live=false
	var first:=Hand.pose(0,0,0); var last:=Hand.pose(1,0,0)
	check(last.wrist.x-first.wrist.x>200 and rad_to_deg(last.angle-first.angle)>17,"full sweep has a substantial wrist arc and visible grip rotation")
	check(absf(first.wrist.y-last.wrist.y)<1 and Hand.pose(0.5,0,0).wrist.y<first.wrist.y-8,"wrist travels on an arc with the elbow outside the picture")
	var stationary:=true; var inverse_ok:=true; var angle_ok:=true; var length_ok:=true
	var rigid:=true; var visible:=true; var connected:=true; var min_angle:=180.0; var max_angle:=0.0; var max_step:=0.0
	for load in [0.0,0.5,1.0]:
		world.angler.rod_load=load; world.angler.rod_lift=0.25+0.75*load
		var previous:=PackedVector2Array()
		for frame in 952:
			var step:=frame if frame<476 else 951-frame
			world.angler.x=18+step*1.2; world.hooked=world.HookState.HOOKED
			world.tension=load; world.bound_bait=0; world.fish=Vector2(world.angler.x,230); world.aim=Vector2.RIGHT
			world.rope_path=PackedVector2Array([world.angler.anchor(),world.mouth()])
			var tackle:=Shore.tackle_pose(world,0); var pose:Dictionary=tackle.hand; var rod:PackedVector2Array=tackle.rod
			var bobber:=Shore.float_position(world,0)
			var angle:=rad_to_deg(absf((pose.socket-tackle.tip).angle_to(bobber-tackle.tip)))
			min_angle=minf(min_angle,angle); max_angle=maxf(max_angle,angle)
			var line:=Shore.surface_line(world,tackle.tip,bobber)
			angle_ok=angle_ok and line[0]==tackle.tip and line[-1]==bobber and tackle.tip.y<bobber.y
			for point:Vector2 in line: angle_ok=angle_ok and point.is_finite() and Rect2(0,29,640,298).has_point(point)
			var length:=0.0
			for i in range(1,rod.size()): length+=rod[i].distance_to(rod[i-1])
			length_ok=length_ok and absf(length-Shore.SHAFT_LENGTH)<0.002
			connected=connected and rod[0].distance_to(Hand.point(Hand.SOCKET,pose.wrist,pose.angle))<0.001
			connected=connected and (rod[1]-rod[0]).normalized().dot(pose.axis)>0.9999
			var palm:=Hand.point(Vector2(1160,942),pose.wrist,pose.angle)
			var reel:=Hand.point(Vector2(1030,923),pose.wrist,pose.angle)
			rigid=rigid and absf(palm.distance_to(reel)-Vector2(130,19).length()*Hand.SIZE)<0.001
			visible=visible and Rect2(295,230,320,97).has_point(palm) and Rect2(290,225,320,102).has_point(reel)
			stationary=stationary and Shore.to_screen(rock,world)==fixed_rock
			for point in [Vector2(0,55),Vector2(30,80),world.fish,Vector2(610,294),Vector2(640,312)]:
				inverse_ok=inverse_ok and Shore.to_world(Shore.to_screen(point,world),world).distance_to(point)<0.001
			var points:=PackedVector2Array([pose.wrist,pose.socket,tackle.tip,bobber])
			if not previous.is_empty():
				for i in points.size(): max_step=maxf(max_step,points[i].distance_to(previous[i]))
			previous=points
	check(stationary and inverse_ok,"fixed perspective and its net-input inverse remain stable through all positions")
	check(angle_ok,"independent line stays attached and inside the lake through the sweep and under load")
	check(length_ok and connected,"shaft retains length and stays attached to grip and line")
	check(rigid and visible,"reference hand and reel keep their shape and stay above the footer")
	check(max_step<1,"left/right reversal does not jump")
	print("ARM_MOTION_V0159 | passed=",passed," | failed=",failed," | grip_1s=",grip_move," | grip_sweep=",last.wrist.x-first.wrist.x," | angle=",min_angle,"..",max_angle," | max_step=",max_step)
	world.free(); quit(1 if failed else 0)
