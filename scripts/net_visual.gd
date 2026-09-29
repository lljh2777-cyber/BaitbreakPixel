extends RefCounted

# A rigid brass hoop and flexible, coarse mesh, shared by the two views.
# Geometry stays in floating point until rasterization on the native pixel grid.
const Motion=preload("res://scripts/net_motion.gd")
const ReelHand=preload("res://scripts/reel_hand.gd")
const INK:=Color("203d43")
const RIM:=Color("afa888")
const LIGHT:=Color("e3d8ae")
const MESH:=Color(0.52,0.72,0.68,0.42)

static func ring(center: Vector2, u: Vector2, v: Vector2) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i in 49:
		var angle:=i*TAU/48.0
		points.append(center+u*cos(angle)+v*sin(angle))
	return points

static func line(view: Node2D, points: PackedVector2Array, color: Color, width: float=1) -> void:
	var pixels:=PackedVector2Array()
	for point in points:
		var pixel:=point.round()
		if pixels.is_empty() or pixels[-1]!=pixel: pixels.append(pixel)
	if pixels.size()>1: view.draw_polyline(pixels,color,width,false)

static func shaft(view: Node2D, pose: Dictionary) -> void:
	var direction: Vector2=(pose.socket-pose.grip).normalized()
	var start: Vector2=pose.grip-direction*(74 if pose.shore else 0)
	var path:=PackedVector2Array([start,pose.socket])
	line(view,path,INK,5)
	line(view,path,Color("8b714b"),3)
	line(view,PackedVector2Array([start-direction.orthogonal(),pose.socket-direction.orthogonal()]),Color("c4a979"))
	var collar: Vector2=pose.socket-direction*7
	line(view,PackedVector2Array([collar,pose.socket+direction]),Color("3e5556"),5)
	line(view,PackedVector2Array([collar-direction.orthogonal(),pose.socket+direction-direction.orthogonal()]),Color("acbdb0"),2)
	if pose.shore:
		# A wrapped grip behind the fingers makes the handle's contact point legible.
		line(view,PackedVector2Array([pose.grip-direction*12,pose.grip+direction*8]),Color("504b39"),5)

static func back(view: Node2D, pose: Dictionary) -> void:
	shaft(view,pose)
	var rim:=ring(pose.center,pose.u,pose.v)
	var bottom:=ring(pose.bag,pose.bu,pose.bv)
	var silhouette:=Geometry2D.convex_hull(rim+bottom)
	view.draw_colored_polygon(silhouette,Color(0.07,0.21,0.25,0.20))
	view.draw_colored_polygon(bottom,Color(0.13,0.29,0.30,0.14))
	line(view,silhouette,Color(0.39,0.57,0.52,0.50))
	line(view,rim,INK,3)
	line(view,rim,Color("727f72"),1)

static func surface(pose: Dictionary, across: float, depth: float) -> Vector2:
	# The visible half of the pocket: diamonds curve around the belly, not across an empty disc.
	var theta:=PI*across-(0.0 if pose.shore else PI/2)
	var u: Vector2=Vector2(pose.u).lerp(pose.bu,depth)
	var v: Vector2=Vector2(pose.v).lerp(pose.bv,depth)
	var center: Vector2=Vector2(pose.center).lerp(pose.bag,depth)
	return center+u*cos(theta)+v*sin(theta)

static func front(view: Node2D, pose: Dictionary) -> void:
	# Wide diamonds stay readable at 640 x 360; no starburst spokes or dense crosshatching.
	for slope in [-0.55,0.55]:
		for stripe in range(-4,10):
			var points:=PackedVector2Array()
			for step in 17:
				var depth:=step/16.0
				var across: float=stripe/6.0+slope*depth
				if across>=0 and across<=1: points.append(surface(pose,across,depth))
			if points.size()>1: line(view,points,MESH)
	var rim:=ring(pose.center,pose.u,pose.v)
	# Full outline has an unbroken silhouette. Lighting follows the hoop, never random flicker.
	line(view,rim,INK,3)
	line(view,rim,RIM,2)
	for i in range(1,rim.size()):
		if rim[i].y<pose.center.y:
			line(view,PackedVector2Array([rim[i-1],rim[i]]),LIGHT)
		elif i%4<2:
			line(view,PackedVector2Array([rim[i-1],rim[i]]),Color("83a39b"))

static func water(view: Node2D, world: Node2D, frame: Dictionary, pose: Dictionary) -> void:
	var p: Vector2=pose.center
	var submerged: float=frame.enter*(1-frame.out)
	if frame.warning:
		var entry: float=clampf((frame.enter-0.62)/0.38,0,1)
		if entry>0:
			var ripple:=ring(p+Vector2(0,6),Vector2(16+entry*20,0),Vector2(0,3+entry*4))
			line(view,ripple,Color(LIGHT,sin(entry*PI)*0.45))
	if world.net_state=="sweep":
		var direction: Vector2=Vector2.from_angle(world.net_angle)
		if pose.shore: direction=Vector2(direction.x,direction.y*0.4).normalized()
		for i in 5:
			var life:=fposmod(world.net_age*1.7+i/5.0,1)
			var origin:=p-direction*(13+life*29)+direction.orthogonal()*sin(i*2.4)*12
			line(view,PackedVector2Array([origin,origin-direction*(4+life*5)]),Color(0.67,0.83,0.77,(1-life)*0.35*submerged))
	if world.net_state in ["caught","withdraw"] and world.net_pos.y<75:
		for i in 5:
			var life:=fposmod(world.net_age*2.1+i/5.0,1)
			var origin: Vector2=pose.bag+Vector2((i-2)*5,9+life*life*25)
			line(view,PackedVector2Array([origin,origin+Vector2(0,2+life*3)]),Color(0.73,0.86,0.79,(1-life)*0.55))
	if frame.caught and world.net_age<0.4:
		var life: float=world.net_age/0.4
		for i in 5:
			var bubble: Vector2=pose.bag+Vector2((i-2)*(4+life*3),-life*18+sin(i*2.3)*5)
			view.draw_rect(Rect2(bubble.round(),Vector2(1,2)),Color(LIGHT,(1-life)*0.6))

static func draw_shore(view: Node2D, world: Node2D, frame: Dictionary, hand: RefCounted) -> void:
	if not frame.active: return
	var pose:=Motion.shore_pose(world,frame)
	water(view,world,frame,pose)
	back(view,pose)
	if frame.caught:
		var settle: float=frame.settle
		var position: Vector2=Vector2(pose.center).lerp(pose.bag,settle)
		# Carry the fish inside the same pocket as the mesh, including the final lift towards camera.
		var kick:=sin(world.net_age*24)*1.2*(1-settle*0.75)
		view.draw_set_transform(position.round(),kick*0.10)
		view.draw_texture(view.fish_texture,Vector2(-12,-6))
		view.draw_set_transform(Vector2.ZERO)
	front(view,pose)
	hand.draw_hand(view,{"grip":pose.grip,"angle":pose.hand_angle,"cell":0,"pivot":ReelHand.GRIP})
