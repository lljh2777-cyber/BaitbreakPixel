extends RefCounted

# Local animation only. The open mouth never lags behind the active collision shape.
# Bag drag is a damped spring; presentation must never write back into the world.
const Shore=preload("res://scripts/shore_view.gd")
var last_time: float=-1.0
var last_center:=Vector2.ZERO
var was_active:=false
var drag:=Vector2.ZERO
var drag_velocity:=Vector2.ZERO
var presented_velocity:=Vector2.ZERO

static func path_point(path: PackedVector2Array, ratio: float) -> Vector2:
	var total:=0.0
	for i in range(1,path.size()): total+=path[i-1].distance_to(path[i])
	var remaining:=total*clampf(ratio,0,1)
	for i in range(1,path.size()):
		var span:=path[i-1].distance_to(path[i])
		if remaining<=span: return path[i-1].lerp(path[i],remaining/maxf(span,0.001))
		remaining-=span
	return path[-1]

func sample(world: Node2D) -> Dictionary:
	var active: bool=world.net_active()
	var now: float=world.elapsed
	var dt:=now-last_time
	var restart: bool=not was_active or dt<0 or dt>0.5
	last_time=now
	was_active=active
	if not active:
		drag=Vector2.ZERO; drag_velocity=Vector2.ZERO
		return {"active":false}
	var warning: bool=world.net_state in ["prepare","warning"]
	var enter:=smoothstep(0,1,world.net_age/maxf(0.001,world.net_warning_seconds())) if warning else 1.0
	var center: Vector2=world.net_pos
	if warning and world.net_exit_path.size()>1:
		center=path_point(world.net_exit_path,1-enter)
	var velocity: Vector2=world.net_motion
	if not restart and dt>0.00001: velocity=(center-last_center)/dt
	if not restart and dt==0: velocity=presented_velocity
	presented_velocity=velocity
	last_center=center
	if restart: drag=Vector2.ZERO; drag_velocity=Vector2.ZERO
	elif dt>0:
		# Exact critically damped integration avoids overshoot and frame-rate-dependent wobble.
		var target:=(-velocity*0.045).limit_length(9)
		var displacement:=drag-target
		var impulse:=drag_velocity+displacement*13.0
		var decay:=exp(-13.0*dt)
		drag=target+(displacement+impulse*dt)*decay
		drag_velocity=(drag_velocity-impulse*13.0*dt)*decay
	var caught: bool=world.net_state=="caught"
	var settle:=smoothstep(0,1,world.net_age/world.NET_SETTLE) if caught else 0.0
	var retract: bool=world.net_state in ["withdraw","caught"]
	var lift_age: float=world.net_age-(world.NET_SETTLE if caught else 0.0)
	var lift:=clampf(lift_age/maxf(0.001,world.net_retract_duration),0,1) if retract else 0.0
	# Reserve a broad part of the recovery for bringing the net back to the near bank.
	# Waiting until its last few world pixels above water caused a one-frame whip out of view.
	var out:=smoothstep(0.35,1.0,lift)
	return {"active":true,"center":center,"drag":drag,"velocity":velocity,
		"enter":enter,"out":out,"caught":caught,"settle":settle,"warning":warning,
		"bag":center+world.net_bag_offset()+drag*(1.0-settle*0.75)}

static func fish_pose(world: Node2D, frame: Dictionary) -> Dictionary:
	var center: Vector2=frame.center
	var axis:=Vector2.from_angle(world.net_angle)
	var rim: Vector2=world.net_rim()
	var u:=axis*rim.x
	var v:=axis.orthogonal()*rim.y
	var pole_start:=Vector2(world.angler.x+7,world.map_context.water.position.y-18) if world.manual_net else Vector2(world.net_from.x,world.map_context.water.position.y-28)
	var socket:=edge_toward(center,u,v,pole_start)
	var settle: float=frame.settle
	# Ellipse axes are periodic over PI. Rotate to the nearest hanging orientation;
	# interpolating opposite vectors would collapse a leftward sweep's pocket halfway.
	var bag_angle:=lerp_angle(world.net_angle,roundf(world.net_angle/PI)*PI,settle)
	var bag_axis:=Vector2.from_angle(bag_angle)
	return {"center":center,"u":u,"v":v,"bag":frame.bag,
		"bu":bag_axis*lerpf(maxf(10,rim.x*0.85),16*world.rule("net_scale"),settle),
		"bv":bag_axis.orthogonal()*lerpf(rim.y*0.64,18*world.rule("net_scale"),settle),
		"socket":socket,"grip":pole_start,"caught":frame.caught,"shore":false}

static func shore_pose(world: Node2D, frame: Dictionary) -> Dictionary:
	var center:=Shore.to_screen(frame.center,world)
	var enter: float=frame.enter
	var out: float=frame.out
	# Lift the rigid hoop over the water, dip at A, then pull it towards the camera on exit.
	center=Vector2(-64,385).lerp(center,enter)-Vector2(0,sin(enter*PI)*24)
	center=center.lerp(Vector2(-68,412),out)
	var scale: float=world.rule("net_scale")*lerpf(0.88,1.06,clampf((world.net_pos.y-Shore.surface_y(world))/257.0,0,1))
	var angle: float=-0.38+sin(world.net_angle)*0.16-(1-enter)*0.28-out*0.28
	var u:=Vector2.from_angle(angle)*24*scale
	var v:=Vector2.from_angle(angle).orthogonal()*12*scale
	var grip:=Vector2(147+clampf((center.x-180)*0.20,-15,50),312+clampf((center.y-255)*0.1,-5,6))
	grip.x=minf(grip.x,center.x-78) # Follow a near-left net without folding the shaft back across the wrist.
	grip=Vector2(96,420).lerp(grip,enter).lerp(Vector2(34,427),out)
	var socket:=edge_toward(center,u,v,grip)
	var projected_drag:=Shore.to_screen(frame.center+frame.drag,world)-Shore.to_screen(frame.center,world)
	var bag_offset:=Vector2(-7,18)+projected_drag*0.8
	bag_offset=bag_offset.lerp(Vector2(0,22),frame.settle)
	var bag:=center+bag_offset*scale
	return {"center":center,"u":u,"v":v,"bag":bag,
		"bu":Vector2(15,1)*scale,"bv":Vector2(-2,12)*scale,
		"socket":socket,"grip":grip,"caught":frame.caught,"shore":true,
		"hand_angle":clampf((socket-grip).angle()+0.72,-0.48,0.45)}

static func edge_toward(center: Vector2, u: Vector2, v: Vector2, target: Vector2) -> Vector2:
	var direction: Vector2=target-center
	var a:=direction.dot(u.normalized())/maxf(u.length(),0.001)
	var b:=direction.dot(v.normalized())/maxf(v.length(),0.001)
	var length:=maxf(Vector2(a,b).length(),0.001)
	return center+u*(a/length)+v*(b/length)
