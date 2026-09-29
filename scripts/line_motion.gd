extends RefCounted

# Presentation geometry only. Physics, coil ownership and QTE timings remain
# authoritative; both views draw these same continuous segments.
const STEPS := 28
const COIL_STEPS := 64
const FishWinding=preload("res://scripts/fish_winding.gd")
const Grass=preload("res://scripts/grass_binding.gd")
var last_time := -1.0
var last_target := -1
var last_progress := 1.0
var last_unwind := false
var return_target := -1
var return_from := 1.0
var return_age := 0.0

func sample(world: Node2D) -> Dictionary:
	var dt: float=maxf(0,world.elapsed-last_time) if last_time>=0 else 0.0
	if world.elapsed<last_time-0.1 or dt>0.5 or world.hooked!=world.HookState.HOOKED:
		last_target=-1; last_unwind=false; return_target=-1
	var target: int=-1 if world.wraps.is_empty() else int(world.wraps[-1].target)
	var progress: float=1.0 if world.wraps.is_empty() else float(world.wraps[-1].progress)
	var unwind: bool=world.untangle_phase=="unwind"
	if last_unwind and not unwind and target==last_target and target>=0 and progress>=1.0 and last_progress<0.99:
		return_target=target; return_from=last_progress; return_age=0.0
	var overrides: Dictionary={}
	var motion := action(world)
	if return_target==target and target>=0 and not unwind:
		return_age+=dt
		if return_age<0.22:
			var p := lerpf(return_from,1.0,smooth(return_age/0.22))
			overrides={"target":target,"progress":p,"unwind":true}
			motion={"active":true,"unwind":true,"progress":1-p,"strength":pow(sin(PI*p),2)}
		else: return_target=-1
	else: return_target=-1
	var fish_pose:=FishWinding.pose(world)
	var frame := build(world,overrides,fish_pose)
	frame.action=motion
	frame.fish=fish_pose
	last_time=world.elapsed; last_target=target; last_progress=progress; last_unwind=unwind
	return frame

static func smooth(value: float) -> float:
	var p := clampf(value,0,1)
	return p*p*(3.0-2.0*p)

static func turn_progress(value: float) -> float:
	# Short acceleration/deceleration shoulders with a steady middle pace.
	# Unlike a full smoothstep, this avoids racing through half the coil.
	var p := clampf(value,0,1)
	const RAMP := 0.15
	if p<RAMP: return p*p/(2*RAMP*(1-RAMP))
	if p>1-RAMP: return 1-pow(1-p,2)/(2*RAMP*(1-RAMP))
	return (p-RAMP*0.5)/(1-RAMP)

static func action(world: Node2D) -> Dictionary:
	if world.hooked!=world.HookState.HOOKED or world.landing or world.net_state=="caught" or world.wraps.is_empty():
		return {"active":false,"unwind":false,"progress":0.0,"strength":0.0}
	var unwind: bool=world.untangle_phase=="unwind"
	var active: bool=unwind or world.winding()
	var p: float=clampf(world.untangle_age/world.UNWIND_SECONDS if unwind else world.wraps[-1].progress,0,1)
	return {"active":active,"unwind":unwind,"progress":p,"strength":pow(sin(PI*p),2) if active else 0.0}

static func strand(world: Node2D, start: Vector2, end: Vector2, available: float, start_tangent: Vector2=Vector2.ZERO, end_tangent: Vector2=Vector2.ZERO) -> PackedVector2Array:
	var chord := start.distance_to(end)
	var direction := (end-start).normalized()
	var a := start+direction*chord/3
	var b := end-direction*chord/3
	if not start_tangent.is_zero_approx(): a=start+start_tangent.normalized()*minf(9,chord*0.25)
	if not end_tangent.is_zero_approx(): b=end-end_tangent.normalized()*minf(9,chord*0.25)
	var excess := maxf(0,available-chord)
	var bow := minf(30,sqrt(excess*(2*chord+excess))*0.30)
	bow=minf(bow,maxf(0.0,312.0-maxf(start.y,end.y)))
	var normal := direction.orthogonal()
	# A slack strand hangs down rather than flipping to the other side when a
	# moving fish crosses the contact. Anchors stay exact, including at zero length.
	var sag := Vector2(0,bow)
	var points := PackedVector2Array()
	for i in STEPS+1:
		var p := i/float(STEPS)
		var wave: float=sin(world.elapsed*16-p*9)*world.tension*0.32*sin(PI*p)
		points.append(start.bezier_interpolate(a,b,end,p)+sag*sin(PI*p)+normal*wave)
	points[0]=start; points[-1]=end
	return points

static func coil(wrap: Dictionary, progress: float, unwind: bool) -> Dictionary:
	var p := clampf(progress,0,1)
	# Unthread the turn first, then ease the freed bend back into the main line.
	var turn := turn_progress(inverse_lerp(0.20,1.0,p)) if unwind else turn_progress(p)
	var attach := smooth(p/0.50)
	var grass: bool=wrap.get("grass",false)
	var loose := sin(PI*p)*((1.5 if unwind else 1.2) if grass else (5.0 if unwind else 3.5))
	var points := PackedVector2Array()
	var front: Array[bool]=[]
	for i in COIL_STEPS+1:
		var fraction := turn*i/float(COIL_STEPS)
		var angle := (0.0 if grass else -PI/2)+TAU*fraction
		# The loose turn lifts away, then seats against the object. Its ends
		# remain at the original contact, so there is never a detached loop.
		var expansion := loose*pow(sin(PI*fraction),2)
		var radii: Vector2=wrap.radii+Vector2(expansion,expansion*0.50)
		var point:=Vector2(wrap.center)+Vector2(cos(angle),sin(angle))*radii
		if grass:
			# A small oblique turn hugs a few stalks rather than surrounding the
			# rectangular interaction area with a conspicuous horizontal halo.
			point.y+=(fraction-0.5)*float(wrap.pitch)+sin(angle)*float(wrap.slant)+sin(angle*2)*0.35
		points.append(point)
		if i>0: front.append(sin(angle)>0 and sin((0.0 if grass else -PI/2)+TAU*turn*(i-1)/float(COIL_STEPS))>=0)
	points[0]=wrap.entry
	if is_equal_approx(turn,1.0): points[-1]=Vector2(wrap.entry)+Vector2(0,float(wrap.pitch)) if grass else Vector2(wrap.entry)
	var tangent:=Vector2.from_angle(TAU*turn)
	if grass: tangent=Vector2(-sin(TAU*turn)*wrap.radii.x,cos(TAU*turn)*(wrap.radii.y+wrap.slant)+wrap.pitch/TAU).normalized()
	return {"points":points,"front":front,"tangent":tangent,"attach":attach,"turn":turn}

static func append_piece(data: Dictionary, points: PackedVector2Array, front: bool, flags: Array=[]) -> void:
	if data.path.is_empty(): data.path.append(points[0])
	for i in range(1,points.size()):
		data.path.append(points[i])
		data.front.append(front if flags.is_empty() else flags[i-1])

static func lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0])
	for i in range(1,points.size()): result.append(result[-1]+points[i-1].distance_to(points[i]))
	return result

static func point_at(points: PackedVector2Array, distances: PackedFloat32Array, ratio: float) -> Vector2:
	if distances[-1]<0.0001: return points[0]
	var distance := clampf(ratio,0,1)*distances[-1]
	var end := clampi(distances.bsearch(distance),1,points.size()-1)
	return points[end-1].lerp(points[end],clampf((distance-distances[end-1])/maxf(0.0001,distances[end]-distances[end-1]),0,1))

static func build(world: Node2D, override: Dictionary={}, fish_pose: Dictionary={}) -> Dictionary:
	var data := {"path":PackedVector2Array(),"front":[],"effects":[],"tail":PackedVector2Array(),"grass":[]}
	if world.hooked!=world.HookState.HOOKED or world.bound_bait<0: return data
	var previous: Vector2=world.line_anchor(world.bound_bait)
	var mouth: Vector2=world.mouth()
	var fish_orbit: bool=fish_pose.get("active",false)
	if fish_orbit: mouth=fish_pose.mouth
	if world.wraps.is_empty():
		data.tail=strand(world,previous,mouth,world.rope_length)
		append_piece(data,data.tail,false)
		return data
	for index in world.wraps.size():
		var wrap: Dictionary=world.wraps[index]
		var last: bool=index==world.wraps.size()-1
		var unwind: bool=last and world.untangle_phase=="unwind"
		var progress: float=wrap.progress
		if override.get("target",-1)==wrap.target:
			progress=override.progress; unwind=override.unwind
		var moving: bool=progress<1 or unwind
		var cover:=Grass.profile(world,wrap,progress)
		var visible_wrap: Dictionary=wrap if cover.is_empty() else cover.wrap
		var geometry := coil(visible_wrap,progress,unwind)
		var ring: PackedVector2Array=geometry.points
		var local := {"path":PackedVector2Array(),"front":[]}
		append_piece(local,strand(world,previous,ring[0],previous.distance_to(ring[0]),Vector2.ZERO,Vector2.RIGHT),false)
		var coil_start: int=maxi(0,data.path.size()-1)+local.path.size()-1
		append_piece(local,ring,false,geometry.front)
		if not cover.is_empty():
			cover.from=coil_start; cover.to=coil_start+COIL_STEPS
			data.grass.append(cover)
		var head_index: int=local.path.size()-1
		var tail: PackedVector2Array=PackedVector2Array()
		if last:
			tail=strand(world,ring[-1],mouth,world.fish_line_length,geometry.tangent)
			append_piece(local,tail,fish_pose.front if fish_orbit else true)
			if moving:
				var offset: float=world.fish_line_length-Vector2(wrap.entry).distance_to(mouth)
				var released: float=previous.distance_to(mouth)+offset+(0.32*world.LINE_ELASTIC_PIXELS if index==0 else 0.0)
				if not unwind and index==0: released=world.rope_length
				var plain := strand(world,previous,mouth,released)
				var route_lengths := lengths(local.path)
				var plain_lengths := lengths(plain)
				for i in local.path.size():
					var p: float=route_lengths[i]/maxf(0.001,route_lengths[-1])
					local.path[i]=point_at(plain,plain_lengths,p).lerp(local.path[i],geometry.attach)
				# No duplicated straight connector remains behind the animated tail.
				tail=local.path.slice(head_index)
			data.tail=tail
		if moving:
			data.effects.append({"point":local.path[head_index],"center":visible_wrap.center,"radii":visible_wrap.radii,"strength":sin(PI*progress),"progress":1.0-progress if unwind else progress,"unwind":unwind,"head_front":geometry.front[-1] if not cover.is_empty() else geometry.turn>0.25 and geometry.turn<0.75,"trail":local.path.slice(maxi(0,head_index-7),head_index+1)})
		append_piece(data,local.path,false,local.front)
		previous=ring[-1]
	return data


