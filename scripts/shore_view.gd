extends RefCounted

# A local presentation of the same 2D pond. The simulation and net routes stay in world coordinates.
const Lake = preload("res://assets/first_person/sunset_lake.png")
const LineMotion = preload("res://scripts/line_motion.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const Art = preload("res://scripts/pixel_art.gd")
const NPCFishPublic = preload("res://scripts/npc_fish_public_state.gd")
const Net = preload("res://scripts/net_simulation.gd")
const Hand = preload("res://scripts/angler_hand.gd")
const ReelHand = preload("res://scripts/reel_hand.gd")
var hand := Hand.new()
var reel_hand := ReelHand.new()
const SCALE := Vector2(0.925,0.35)
const ORIGIN := Vector2(24,213)
const WATER_LEVEL := 55.0
const CREAM := Color("ffe5bc")
const INK := Color("122b38")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const SHAFT_LENGTH := 109.58981932643195
const SHAFT_SEGMENTS := 48

static func projection_at(y: float) -> Vector2:
	# Fixed perspective: the distant float lane is narrower than near water.
	# This depends only on world depth, never on the angler, hand or line.
	var near := clampf((y-WATER_LEVEL)/(Layout.FLOOR-1-WATER_LEVEL),0,1)
	return Vector2(lerpf(243,ORIGIN.x,near),lerpf(0.44,SCALE.x,near))

static func to_screen(point: Vector2, _world: Node2D=null) -> Vector2:
	var projection := projection_at(point.y)
	return Vector2(projection.x+point.x*(640.0/Layout.SIZE.x)*projection.y,ORIGIN.y+(point.y-WATER_LEVEL)*(257.0/(Layout.FLOOR-1-WATER_LEVEL))*SCALE.y)

static func to_world(point: Vector2, _world: Node2D=null) -> Vector2:
	var y := (point.y-ORIGIN.y)/(SCALE.y*257.0/(Layout.FLOOR-1-WATER_LEVEL))+WATER_LEVEL
	var projection := projection_at(y)
	return Vector2((point.x-projection.x)/projection.y*(Layout.SIZE.x/640.0),y)

static func projected(path: PackedVector2Array, world: Node2D=null) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in path: result.append(to_screen(point,world))
	return result

static func rod_tip(world: Node2D, t: float) -> Vector2:
	return tackle_pose(world,t).tip

static func tackle_pose(world: Node2D, t: float, motion: Dictionary={}) -> Dictionary:
	var load:float=world.angler.rod_load
	var reel_speed: float=world.angler.feedback_reel_speed(world)
	# The existing replicated sway gives the held rig a small, damped follow-through.
	var held_x: float=world.angler.x+world.angler.line_sway*0.2
	if motion.is_empty(): motion=LineMotion.action(world)
	var brace: float=world.angler.rod_lift
	if motion.active:
		var sweep: float=sin(TAU*LineMotion.smooth(motion.progress))*motion.strength
		held_x+=sweep*(22.0 if motion.unwind else -9.0)
		brace=clampf(brace+motion.strength*(0.13 if motion.unwind else 0.055),0,1)
	var pose := Hand.pose(inverse_lerp(18,Layout.SIZE.x-52,held_x),t,reel_speed,brace)
	var rod := rod_points(pose,load,world.effort_multiplier("angler"),float_position(world,t,motion))
	return {"hand":pose,"rod":rod,"tip":rod[-1],"load":load,"reel_speed":reel_speed}

static func rig_index(world: Node2D) -> int:
	# Ownership/deployment is physical tackle state, never hidden hook assignment.
	if world.bound_bait>=0: return world.bound_bait
	for index in world.baits.size():
		if world.baits[index].tackle and world.baits[index].active and not world.baits[index].removed: return index
	return -1

static func float_position(world: Node2D, t: float, motion: Dictionary={}) -> Vector2:
	if world.line_landing() or (world.net_state=="caught" and world.fish.y<WATER_LEVEL):
		return to_screen(world.hook_target_mouth() if world.line_landing() else world.mouth(),world)+Vector2(0,-3)
	var anchor: Vector2=world.angler.anchor()
	var index := rig_index(world)
	var target := anchor+Vector2(0,150)
	if index>=0: target=world.hook_target_mouth() if world.bound_bait==index else Vector2(world.baits[index].pos)
	if world.line_hooked() and world.rope_path.size()>2: target=world.rope_path[1]
	var x:float=world.angler.surface_x if world.angler.surface_live else target.x
	var dip: float=world.tension*1.7 if world.line_hooked() else 0.0
	if world.hooked==world.HookState.MOUTH: dip=3.5
	if motion.is_empty(): motion=LineMotion.action(world)
	if motion.active: dip+=sin(motion.progress*TAU)*motion.strength*(0.7 if motion.unwind else 1.25)
	return Vector2(to_screen(Vector2(x,WATER_LEVEL),world).x,ORIGIN.y+sin(t*2.2)*0.6+dip)

static func ellipse(center: Vector2, radii: Vector2, count: int=32) -> PackedVector2Array:
	var path := PackedVector2Array()
	for index in count+1: path.append((center+Vector2.from_angle(index*TAU/float(count))*radii).round())
	return path

static func surface_line(world: Node2D, tip: Vector2, end: Vector2) -> PackedVector2Array:
	var load:float=world.tension if world.line_hooked() else 0.35
	var slack:=0.0
	if world.line_hooked():
		slack=maxf(0,world.rope_length-world.Rope.length_of(world.rope_path))
	elif rig_index(world)>=0:
		var bait: Dictionary=world.baits[rig_index(world)]
		slack=maxf(0,world.angler.free_line_length-world.angler.anchor().distance_to(bait.pos))
	var sag:=lerpf(13,1.5,load)+minf(slack*0.22,25)
	var trail:float=clampf(-world.angler.surface_velocity*0.11,-12,12)*(1-load*0.7)
	var line:=PackedVector2Array()
	for part in 33:
		var ratio:=part/32.0
		line.append(tip.lerp(end,ratio)+Vector2(trail*sin(ratio*PI),sag*4*ratio*(1-ratio)))
	return line

static func rod_points(pose: Dictionary, load: float, strength: float, pull_target: Vector2) -> PackedVector2Array:
	var axis: Vector2=pose.axis
	var straight_tip: Vector2=pose.socket+axis*SHAFT_LENGTH
	var pull := (pull_target-straight_tip).normalized()
	var bend := clampf(axis.cross(pull)*3.0,-2.2,2.2)*clampf(load,0,1)*clampf(1-(strength-1)*0.2,0.8,1.15)
	var points := PackedVector2Array([pose.socket])
	# Equal material lengths: load changes curvature, never the size of the rod.
	# The first segment remains exactly tangent to the rigid handle ferrule.
	for part in SHAFT_SEGMENTS:
		var ratio := part/float(SHAFT_SEGMENTS-1)
		var flex:=ratio*ratio*(0.28+0.72*ratio)
		points.append(points[-1]+axis.rotated(bend*flex)*(SHAFT_LENGTH/SHAFT_SEGMENTS))
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
		_ghost(view,projected(PackedVector2Array(solid.points),world),0.18 if solid.kind=="wood" else 0.14)
	for index in Layout.PLANTS.size():
		var plant: Dictionary=Layout.PLANTS[index]
		for stem in 3:
			var x: float=plant.x+(stem-1)*5
			var p := to_screen(Vector2(x,plant.y),world)
			var top := to_screen(Vector2(x+sin(t*1.5+index+stem)*4,plant.y-plant.height*0.7),world)
			view.draw_polyline(PackedVector2Array([p,p.lerp(top,0.5)+Vector2(2,0),top]),Color(0.06,0.21,0.24,0.20),3)
	var float_at := float_position(world,t,view.line_frame.action)
	if world.line_hooked() and view.line_frame.path.size()>1:
		var path := projected(view.line_frame.path,world)
		path[0]=float_at
		view.draw_polyline(path,Color(0.51,0.66,0.65,0.10),1)
	for bait_index in world.baits.size():
		var bait: Dictionary=world.baits[bait_index]
		if not bait.active or bait.removed: continue
		var p := to_screen(view._bait_point(bait_index,bait.pos),world)
		view.draw_circle(p,2.5,Color(0.65,0.64,0.41,0.11))
	_ambient_fishes(view,world,t)
	var position := to_screen(world.fish,world)+Vector2(sin(t*1.3)*1.2,cos(t*1.7)*0.5)
	var direction: Vector2=(to_screen(world.fish+world.aim)-to_screen(world.fish)).normalized()
	var fish_shape := PackedVector2Array([Vector2(12,0),Vector2(5,-4),Vector2(-5,-4),Vector2(-9,-2),Vector2(-15,-5),Vector2(-13,0),Vector2(-15,5),Vector2(-9,2),Vector2(-5,4),Vector2(5,4)])
	var fish_pose: Dictionary=view.line_frame.fish
	if fish_pose.active:
		position=to_screen(fish_pose.position,world)
		var axis_x: Vector2=(to_screen(Vector2(fish_pose.position)+Vector2(fish_pose.axis_x),world)-position)
		var axis_y: Vector2=(to_screen(Vector2(fish_pose.position)+Vector2(fish_pose.axis_y),world)-position)
		for index in fish_shape.size(): fish_shape[index]=position+axis_x*fish_shape[index].x+axis_y*fish_shape[index].y
	else:
		for index in fish_shape.size(): fish_shape[index]=position+fish_shape[index].rotated(direction.angle())
	if world.net_state=="caught":
		pass # The carried fish is drawn between the back and front of the moving pocket.
	elif world.landing:
		view.draw_set_transform(position,direction.angle())
		view.draw_texture(view.fish_texture,Vector2(-12,-6))
		view.draw_set_transform(Vector2.ZERO)
	else:
		var depth := clampf((world.fish.y-80)/220,0,1)
		_ghost(view,fish_shape,lerpf(0.44,0.17,depth)*(0.86+sin(t*1.6)*0.14))
	# No eyes, hook-tip markers, bait particles, nest markers or exact opponent status above water.

func _ambient_fishes(view: Node2D, world: Node2D, t: float) -> void:
	for fish: Dictionary in NPCFishPublic.capture(world.npc_fishes,world.hook_target_fish_id,world.npc_hook):
		var source: Vector2=fish.position
		var phase: float=t*1.3+int(fish.fish_id)*1.71
		var contact: bool=fish.animation_state in ["hooked","landing"]
		# A hooked silhouette and its line share one physical endpoint; ambient
		# presentation drift must never make the line slide off the fish.
		var position:=to_screen(source,world)+Vector2(sin(phase)*1.2,cos(phase*1.3)*0.5)
		var direction: Vector2=(to_screen(source+Vector2(fish.aim),world)-to_screen(source,world)).normalized()
		if contact:
			# Shore silhouettes are enlarged for readability. Anchor their visible
			# nose to the projected physical mouth, not their enlarged body center.
			var nose:=10.0 if fish.animation_state=="landing" else 8.0 if int(fish.visual_variant)==2 else 9.0
			position=to_screen(world.hook_target_mouth(),world)-direction*nose
		if fish.animation_state=="landing":
			var tilt:=direction.angle()
			var flip:=1.0
			if direction.x<0:
				tilt-=PI; flip=-1.0
			view.draw_set_transform(position.round(),tilt,Vector2(flip,1))
			view.draw_texture(view.npc_textures[int(fish.visual_variant)],Vector2(-10,-5))
			view.draw_set_transform(Vector2.ZERO)
			continue
		var shape:=Art.npc_shadow(int(fish.visual_variant))
		for index in shape.size(): shape[index]=position+shape[index].rotated(direction.angle())
		var depth:=clampf((source.y-80)/220,0,1)
		_ghost(view,shape,lerpf(0.44,0.17,depth)*(0.86+sin(phase)*0.14)*0.72)

static func draw_observed_npcs(view: Node2D, world: Node2D) -> void:
	# Same visibility and approximate 3 px location as the existing player
	# silhouette. No eyes, identity marker, exact mouth, or private AI status.
	for fish: Dictionary in NPCFishPublic.capture(world.npc_fishes,world.hook_target_fish_id,world.npc_hook):
		var visibility:=Net.visibility(world,Vector2(fish.position))
		if visibility<=0.02: continue
		var position: Vector2=Vector2(fish.position).snapped(Vector2(3,3))
		var facing: float=-1.0 if Vector2(fish.aim).x<0 else 1.0
		var shape:=Art.npc_shadow(int(fish.visual_variant))
		for index in shape.size(): shape[index]=position+shape[index]*Vector2(facing,1)
		view.draw_colored_polygon(shape,Color(0.06,0.18,0.23,visibility*0.5))

func _water(view: Node2D, world: Node2D, t: float) -> void:
	for index in 95:
		var y := 138+posmod(index*29,184)
		var x := fposmod(index*113+sin(t*0.6+index)*7,636)
		var width := 3+posmod(index*17,15)
		view.draw_rect(Rect2(roundf(x),y,width,1),Color(0.37,0.65,0.66,0.06+0.025*sin(t+index)))
	if world.line_hooked() and (world.resisting if world.hook_target_fish_id<=1 else not world.line_landing()):
		var p := float_position(world,t,view.line_frame.action)
		for index in 3:
			var life := fmod(t*1.5+index/3.0,1)
			view.draw_polyline(ellipse(p,Vector2(9+life*21,2+life*5)),Color(CREAM,(1-life)*0.26),1)

func _tackle(view: Node2D, world: Node2D, t: float) -> void:
	var tackle := tackle_pose(world,t,view.line_frame.action)
	var tip: Vector2=tackle.tip
	var float_at := float_position(world,t,view.line_frame.action)
	var index := rig_index(world)
	var load: float=tackle.load
	var reel_speed: float=tackle.reel_speed
	var pose: Dictionary=tackle.hand
	var line_end := float_at
	if world.angler.casting:
		var ratio: float=clampf(world.angler.cast_age/world.angler.CAST_SECONDS,0,1)
		line_end=tip.lerp(float_at,ratio)-Vector2(0,sin(ratio*PI)*17)
	if index>=0 or world.angler.casting:
		var line := surface_line(world,tip,line_end)
		for part in line.size(): line[part]=line[part].round()
		view.draw_polyline(line,Color(CREAM,0.85),1)
		# Feed marks follow integrated physical spool motion, including network playback.
		# No held-key animation while undeployed, blocked, or at a line limit.
		if absf(reel_speed)>0.5 and not world.angler.casting and not world.Net.busy(world):
			var phase: float=world.angler.reel_phase/TAU if reel_speed<0 else world.angler.release_phase/TAU
			for mark in 3:
				var travel: float=fposmod(phase+float(mark)/3.0,1.0)
				if reel_speed<0: travel=1.0-travel
				var part: int=clampi(int(travel*(line.size()-2)),0,line.size()-2)
				view.draw_line(line[part],line[part+1],GOLD if reel_speed<0 else MINT,2)
		if not world.angler.casting and not world.line_landing() and not (world.net_state=="caught" and world.fish.y<WATER_LEVEL):
			for ring in 2:
				var age := fmod(t*0.6+ring*0.5,1)
				view.draw_polyline(ellipse(float_at,Vector2(8+age*12,2+age*3)),Color(CREAM,(1-age)*0.44),1)
		var motion: Dictionary=view.line_frame.action
		if motion.active:
			for ring in 2:
				var life: float=clampf((motion.progress-ring*0.16)/0.84,0,1)
				view.draw_polyline(ellipse(float_at,Vector2(9+life*21,2+life*6)),Color(CREAM,motion.strength*(1-life)*0.38),1)
		var angle := clampf(world.angler.surface_velocity*0.006,-0.32,0.32)+sin(t*2.2)*0.035
		if motion.active: angle+=sin(TAU*motion.progress)*motion.strength*0.08
		view.draw_set_transform(line_end.round(),angle)
		view.draw_line(Vector2(0,-13),Vector2(0,-5),INK,3)
		view.draw_line(Vector2(0,-12),Vector2(0,-6),GOLD,1)
		view.draw_rect(Rect2(-3,-6,7,5),Color("e24d35"))
		view.draw_rect(Rect2(-2,-7,4,2),Color("ff9670"))
		view.draw_rect(Rect2(-3,-1,7,3),CREAM)
		view.draw_rect(Rect2(-2,2,5,2),Color("3d6e7c"))
		view.draw_set_transform(Vector2.ZERO)
	hand.draw_rod(view,tackle.rod)
	hand.draw(view,pose,t,reel_speed)
	reel_hand.draw(view,pose,world)

func _net(view: Node2D, world: Node2D, _t: float) -> void:
	view.NetVisual.draw_shore(view,world,view.net_frame,reel_hand)
