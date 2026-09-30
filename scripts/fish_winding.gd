extends RefCounted
const Layout=preload("res://scripts/pond_layout.gd")
const Grass=preload("res://scripts/grass_binding.gd")

# A presentation-only lap. Input, tension, contact and net catches continue to
# use the authoritative fish. No displacement is written back to the world.
static func smooth(value: float) -> float:
	var p:=clampf(value,0,1)
	return p*p*(3-2*p)

static func pose(world: Node2D) -> Dictionary:
	var result: Dictionary={"active":false,"position":world.fish,"mouth":world.mouth(),"front":true}
	if world.hooked!=world.HookState.HOOKED or not world.winding() or world.landing or world.net_state=="caught": return result
	var wrap: Dictionary=world.wraps[-1]
	var p: float=clampf(wrap.progress,0,1)
	var cover:=Grass.profile(world,wrap,p)
	if not cover.is_empty(): wrap=cover.wrap
	# Approach, one complete lap, then rejoin the still-moving player. The lap
	# slows at its ends so neither the mouth nor the body teleports into a turn.
	var lap:=clampf((p-0.14)/0.72,0,1)
	var turn:=lap*lap/(2*0.12*0.88) if lap<0.12 else 1-pow(1-lap,2)/(2*0.12*0.88) if lap>0.88 else (lap-0.06)/0.88
	var angle: float=-PI/2+TAU*turn
	var blend:=smooth(p/0.14)*(1-smooth((p-0.86)/0.14))
	var center: Vector2=wrap.center
	center.y=clampf(center.y,85,Layout.FLOOR-21)
	var radius:=Vector2(float(wrap.radii.x)+14,13)
	radius.x=minf(radius.x,maxf(7,minf(center.x-9,Layout.SIZE.x-9-center.x)))
	var orbit:=center+Vector2(cos(angle),sin(angle))*radius
	var position: Vector2=Vector2(world.fish).lerp(orbit,blend)
	# Projected yaw: narrow gently while rounding either end of the obstacle,
	# instead of abruptly mirroring or turning the belly upside down.
	var near: float=sin(angle)
	var scale: float=0.95+near*0.05
	var orbit_x:=Vector2(-sin(angle),cos(angle)*0.30)*scale
	var facing: Vector2=world.aim
	var upright: Vector2=facing.orthogonal()*(1 if facing.x>=0 else -1)
	var axis_x:=Vector2.from_angle(lerp_angle(facing.angle(),orbit_x.angle(),blend))*lerpf(1,orbit_x.length(),blend)
	var axis_y:=upright.lerp(Vector2(0,scale),blend)
	result.merge({"active":true,"position":position,"mouth":position.round()+axis_x*10,"front":blend<0.95 or near>=0,"axis_x":axis_x,"axis_y":axis_y,"blend":blend,"lap":turn,"center":center,"radii":radius,"shade":lerpf(1,0.87,blend*maxf(0,-near)),"end_on":blend*(1-smooth(absf(sin(angle))/0.38)),"toward_camera":cos(angle)>0},true)
	return result

static func attached_point(world: Node2D, visual: Dictionary, point: Vector2) -> Vector2:
	if not visual.active: return point
	var delta: Vector2=point-world.mouth()
	var right: Vector2=world.aim
	var down: Vector2=right.orthogonal()*(1 if right.x>=0 else -1)
	return Vector2(visual.mouth)+Vector2(visual.axis_x)*delta.dot(right)+Vector2(visual.axis_y)*delta.dot(down)
