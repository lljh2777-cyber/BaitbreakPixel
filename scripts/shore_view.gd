extends RefCounted

# A local presentation of the same 2D pond. The simulation and net routes stay in world coordinates.
const Lake = preload("res://assets/first_person/sunset_lake.png")
const Layout = preload("res://scripts/pond_layout.gd")
const Hand = preload("res://scripts/angler_hand.gd")
var hand := Hand.new()
const SCALE := Vector2(0.925,0.35)
const ORIGIN := Vector2(24,213)
const WATER_LEVEL := 55.0
const CREAM := Color("ffe5bc")
const INK := Color("122b38")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const SHAFT_LENGTH := 180.0
const SHAFT_SEGMENTS := 32

static func to_screen(point: Vector2) -> Vector2:
	return ORIGIN+Vector2(point.x,point.y-WATER_LEVEL)*SCALE

static func to_world(point: Vector2) -> Vector2:
	return (point-ORIGIN)/SCALE+Vector2(0,WATER_LEVEL)

static func projected(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in path: result.append(to_screen(point))
	return result

static func rod_tip(world: Node2D, t: float) -> Vector2:
	return tackle_pose(world,t).tip

static func tackle_pose(world: Node2D, t: float) -> Dictionary:
	var hooked: bool=world.hooked==world.HookState.HOOKED
	var load: float=world.tension if hooked else 0
	var reel_speed: float=world.reel_speed if hooked else world.angler.free_reel_speed
	var pose := Hand.pose(inverse_lerp(18,588,world.angler.x),t,reel_speed)
	var rod := rod_points(pose,load,world.effort_multiplier("angler"),float_position(world,t))
	return {"hand":pose,"rod":rod,"tip":rod[-1],"load":load,"reel_speed":reel_speed}

static func rig_index(world: Node2D) -> int:
	if world.bound_bait>=0: return world.bound_bait
	for index in world.baits.size():
		if world.baits[index].hook and world.baits[index].active and not world.baits[index].removed: return index
	return -1

static func float_position(world: Node2D, t: float) -> Vector2:
	if world.landing or (world.net_state=="caught" and world.fish.y<WATER_LEVEL):
		return to_screen(world.mouth())+Vector2(0,-3)
	var anchor: Vector2=world.angler.anchor()
	var index := rig_index(world)
	var target := anchor+Vector2(0,150)
	if index>=0: target=world.mouth() if world.bound_bait==index else Vector2(world.baits[index].pos)
	if world.hooked==world.HookState.HOOKED and world.rope_path.size()>2: target=world.rope_path[1]
	var ratio := clampf((WATER_LEVEL-anchor.y)/maxf(1,target.y-anchor.y),0,1)
	var x := anchor.lerp(target,ratio).x
	var dip: float=world.tension*1.7 if world.hooked==world.HookState.HOOKED else 0.0
	if world.hooked==world.HookState.MOUTH: dip=3.5
	return Vector2(to_screen(Vector2(x,WATER_LEVEL)).x,ORIGIN.y+sin(t*2.2)*0.6+dip)

static func ellipse(center: Vector2, radii: Vector2, count: int=32) -> PackedVector2Array:
	var path := PackedVector2Array()
	for index in count+1: path.append((center+Vector2.from_angle(index*TAU/float(count))*radii).round())
	return path

static func rod_points(pose: Dictionary, load: float, strength: float, pull_target: Vector2) -> PackedVector2Array:
	var axis: Vector2=pose.axis
	var straight_tip: Vector2=pose.socket+axis*SHAFT_LENGTH
	var pull := (pull_target-straight_tip).normalized()
	var bend := axis.cross(pull)*0.38*clampf(load,0,1)*clampf(1-(strength-1)*0.2,0.8,1.15)
	var points := PackedVector2Array([pose.socket])
	# Equal material lengths: load changes curvature, never the size of the rod.
	# The first segment remains exactly tangent to the rigid handle ferrule.
	for part in SHAFT_SEGMENTS:
		var ratio := part/float(SHAFT_SEGMENTS-1)
		points.append(points[-1]+axis.rotated(bend*ratio*ratio)*(SHAFT_LENGTH/SHAFT_SEGMENTS))
	return points

func draw(view: Node2D, world: Node2D, t: float) -> void:
	view.draw_texture_rect(Lake,Rect2(0,0,640,360),false)
	_underwater(view,world,t)
	_water(view,world,t)
	_net(view,world,t)
	_tackle(view,world,t)

func _ghost(view: Node2D, path: PackedVector2Array, opacity: float, color: Color=Color("0b3242")) -> void:
	for offset in [Vector2(-2,0),Vector2(2,1)]:
		var soft := path.duplicate()
		for index in soft.size(): soft[index]+=offset
		view.draw_colored_polygon(soft,Color(color,opacity*0.20))
	view.draw_colored_polygon(path,Color(color,opacity))

func _underwater(view: Node2D, world: Node2D, t: float) -> void:
	for solid in Layout.SOLIDS:
		_ghost(view,projected(PackedVector2Array(solid.points)),0.18 if solid.kind=="wood" else 0.14)
	for index in Layout.PLANTS.size():
		var plant: Dictionary=Layout.PLANTS[index]
		for stem in 3:
			var x: float=plant.x+(stem-1)*5
			var p := to_screen(Vector2(x,312))
			var top := to_screen(Vector2(x+sin(t*1.5+index+stem)*4,312-plant.height*0.7))
			view.draw_polyline(PackedVector2Array([p,p.lerp(top,0.5)+Vector2(2,0),top]),Color(0.06,0.21,0.24,0.20),3)
	var float_at := float_position(world,t)
	if world.hooked==world.HookState.HOOKED and world.rope_path.size()>1:
		var path := projected(world.rope_path)
		path[0]=float_at
		view.draw_polyline(path,Color(0.51,0.66,0.65,0.10),1)
	for bait in world.baits:
		if not bait.active or bait.removed: continue
		var p := to_screen(bait.pos)
		view.draw_circle(p,2.5,Color(0.65,0.64,0.41,0.11))
	var position := to_screen(world.fish)+Vector2(sin(t*1.3)*1.2,cos(t*1.7)*0.5)
	var direction: Vector2=(world.aim*SCALE).normalized()
	var fish_shape := PackedVector2Array([Vector2(12,0),Vector2(5,-4),Vector2(-5,-4),Vector2(-9,-2),Vector2(-15,-5),Vector2(-13,0),Vector2(-15,5),Vector2(-9,2),Vector2(-5,4),Vector2(5,4)])
	for index in fish_shape.size(): fish_shape[index]=position+fish_shape[index].rotated(direction.angle())
	if world.net_state=="caught" or world.landing:
		view.draw_set_transform(position,direction.angle())
		view.draw_texture(view.fish_texture,Vector2(-12,-6))
		view.draw_set_transform(Vector2.ZERO)
	else:
		var depth := clampf((world.fish.y-80)/220,0,1)
		_ghost(view,fish_shape,lerpf(0.44,0.17,depth)*(0.86+sin(t*1.6)*0.14))
	# No eyes, hook-tip markers, bait particles, nest markers or exact opponent status above water.

func _water(view: Node2D, world: Node2D, t: float) -> void:
	for index in 95:
		var y := 138+posmod(index*29,184)
		var x := fposmod(index*113+sin(t*0.6+index)*7,636)
		var width := 3+posmod(index*17,15)
		view.draw_rect(Rect2(roundf(x),y,width,1),Color(0.37,0.65,0.66,0.06+0.025*sin(t+index)))
	if world.hooked==world.HookState.HOOKED and world.resisting:
		var p := float_position(world,t)
		for index in 3:
			var life := fmod(t*1.5+index/3.0,1)
			view.draw_polyline(ellipse(p,Vector2(9+life*21,2+life*5)),Color(CREAM,(1-life)*0.26),1)

func _tackle(view: Node2D, world: Node2D, t: float) -> void:
	var tackle := tackle_pose(world,t)
	var tip: Vector2=tackle.tip
	var float_at := float_position(world,t)
	var index := rig_index(world)
	var load: float=tackle.load
	var reel_speed: float=tackle.reel_speed
	var pose: Dictionary=tackle.hand
	var wrist: Vector2=pose.wrist
	var hand_angle: float=pose.angle
	var strength: float=world.effort_multiplier("angler")
	var line_end := float_at
	if world.angler.casting:
		var ratio: float=clampf(world.angler.cast_age/world.angler.CAST_SECONDS,0,1)
		line_end=tip.lerp(float_at,ratio)-Vector2(0,sin(ratio*PI)*17)
	if index>=0 or world.angler.casting:
		var line := PackedVector2Array()
		for part in 25:
			var ratio := part/24.0
			line.append((tip.lerp(line_end,ratio)+Vector2(sin(ratio*PI)*(1-load)*(2+world.angler.line_sway*0.16),ratio*(1-ratio)*(1-load)*10)).round())
		view.draw_polyline(line,Color(CREAM,0.85),1)
		if not world.angler.casting and not world.landing and not (world.net_state=="caught" and world.fish.y<WATER_LEVEL):
			for ring in 2:
				var age := fmod(t*0.6+ring*0.5,1)
				view.draw_polyline(ellipse(float_at,Vector2(8+age*12,2+age*3)),Color(CREAM,(1-age)*0.44),1)
		var angle := sin(t*(9 if world.hooked!=world.HookState.FREE else 2))*0.13
		view.draw_set_transform(line_end.round(),angle)
		view.draw_line(Vector2(0,-13),Vector2(0,-5),INK,3)
		view.draw_line(Vector2(0,-12),Vector2(0,-6),GOLD,1)
		view.draw_rect(Rect2(-3,-6,7,5),Color("e24d35"))
		view.draw_rect(Rect2(-2,-7,4,2),Color("ff9670"))
		view.draw_rect(Rect2(-3,-1,7,3),CREAM)
		view.draw_rect(Rect2(-2,2,5,2),Color("3d6e7c"))
		view.draw_set_transform(Vector2.ZERO)
	var rod: PackedVector2Array=tackle.rod
	for part in rod.size(): rod[part]=rod[part].round()
	for part in range(1,rod.size()):
		var width := lerpf(4.5,1.2,part/32.0)
		view.draw_line(rod[part-1],rod[part],Color("13222b"),width+2)
		view.draw_line(rod[part-1],rod[part],Color("3c4b4f") if part<14 else Color("554c3e"),width)
		view.draw_line(rod[part-1]-Vector2(1,0),rod[part]-Vector2(1,0),Color("d4b176") if strength>=1 else Color("758a87"),1)
	for ratio in [0.24,0.48,0.7,0.9,1.0]:
		var p := rod[roundi(ratio*32)]
		view.draw_circle(p+Vector2(1,1),2,INK)
		view.draw_circle(p,1,CREAM)
	hand.draw(view,wrist,hand_angle,t,reel_speed)

func _net(view: Node2D, world: Node2D, _t: float) -> void:
	if world.manual_net and world.net_state in ["prepare","warning","sweep","miss","withdraw","caught"]:
		var p := to_screen(world.net_pos)
		var opening: float=smoothstep(0,1,world.net_age/world.NET_PREPARE) if world.net_state=="prepare" else 1.0
		var rim := PackedVector2Array()
		for index in 41:
			var point: Vector2=world.net_pos+(Vector2.from_angle(index*TAU/40)*world.NET_RIM*maxf(0.2,opening)).rotated(world.net_angle)
			rim.append(to_screen(point).round())
		var handle := PackedVector2Array([Vector2(602,357),Vector2(565,320),p+Vector2(8,5)])
		view.draw_polyline(handle,INK,7)
		view.draw_polyline(handle,Color("ae8751"),4)
		view.draw_colored_polygon(rim,Color(0.46,0.62,0.56,0.12+world.net_capture*0.16))
		for index in range(0,20,3): view.draw_line(rim[index],rim[40-index],Color(0.62,0.72,0.64,0.5),1)
		view.draw_polyline(rim,INK,4); view.draw_polyline(rim,Color("e1c18c"),2)
		if world.net_capture>0 and world.net_state=="sweep":
			view.draw_polyline(ellipse(p,Vector2(37,16)).slice(0,maxi(2,int(world.net_capture*32)+1)),GOLD,2)
			view.label_at(p+Vector2(-24,-21),"收拢 %d%%" % roundi(world.net_capture*100),10,GOLD)
	if not world.angler.net_held or view.game.menu.visible: return
	var target: Vector2=world.manual_net_target(world.angler.cursor)
	var center := to_screen(target)
	var blocked: bool=world.manual_net_blocked(target)
	var color := Color("f58375") if blocked or world.angler.net_cooldown>0 else MINT
	if not world.net_blocks_hooks():
		view.draw_polyline(ellipse(center,Vector2(world.NET_RIM.y+2,world.NET_RIM.y+2)*SCALE),Color(color,0.65),1)
		view.label_at(center+Vector2(-28,-18),"木石挡网" if blocked else "从这里下网",10,color)
	if world.manual_net and world.net_state in ["prepare","warning","sweep"]:
		var pending := projected(world.manual_net_pending_path())
		if pending.size()>1: view.draw_polyline(pending,Color(MINT,0.7),1)
	var water_rect := Rect2(to_screen(Vector2(0,80)),Vector2(640,214)*SCALE)
	view.draw_rect(water_rect,Color(MINT,0.12),false,1)
