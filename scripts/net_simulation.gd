extends RefCounted

# Authoritative net simulation. Value state lives in the world snapshot; no input or rendering.
const MapGeometry=preload("res://scripts/maps/map_geometry.gd")

static func net_warning_seconds(g: Node2D) -> float:
	return g.rule("net_manual_warning")

static func record_manual_net_point(g: Node2D, point: Vector2) -> void:
	if not g.net_action.observing: return
	if not g.net_action.has_a:
		begin_manual_net(g,point)
		return
	var plan := preview(g,point)
	if not plan.valid:
		g.notice="终点需在可达水域，且与起点保持距离"; g.notice_age=1.5
		return
	commit(g,plan)

static func manual_net_blocked(g: Node2D, point: Vector2) -> bool:
	for solid in g.map_net_blockers:
		if MapGeometry.touches(point,g.net_rim().y+2,solid.polygon): return true
	return false

static func _manual_net_exit(g: Node2D, point: Vector2) -> PackedVector2Array:
	var surface := Vector2(point.x,g.map_context.water.position.y-63)
	if _manual_net_lane_clear(g, point,surface): return PackedVector2Array([point,surface])
	# Inflate the obstacles by the turnable rim, then find a clear lift to the surface.
	var expanded: Array=[]
	for solid in g.map_net_blockers:
		for polygon in Geometry2D.offset_polygon(solid.polygon,g.net_rim().y+2,Geometry2D.JOIN_MITER):
			expanded.append({"points":Array(polygon)})
	var path: PackedVector2Array=g.Rope.solve(surface,point,expanded,g.Rope.routing_limits(g.map_context))
	path.reverse()
	for index in range(1,path.size()):
		if not _manual_net_lane_clear(g, path[index-1],path[index]): return PackedVector2Array()
	return path

static func _manual_net_lane_clear(g: Node2D, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)))
	for step in range(steps+1):
		if manual_net_blocked(g, a.lerp(b,float(step)/steps)): return false
	return true

static func begin_manual_net(g: Node2D, point: Vector2) -> bool:
	if not g.net_action.observing: return false
	if not reachable(g,point) or manual_net_blocked(g,point):
		g.notice="起点放不下抄网 · 选择可达的空水域"; g.notice_age=1.5
		return false
	var exit_path := _manual_net_exit(g,point)
	if exit_path.size()<2:
		g.notice="木石挡住了提网通道"; g.notice_age=1.5
		return false
	g.net_action.has_a=true
	g.net_action.a=point
	g.net_exit_path=exit_path
	return true

static func _prepare_manual_return(g: Node2D) -> void:
	g.net_return_path=PackedVector2Array([g.net_pos])
	# Retrace the drag before taking the collision-cleared lift from the chosen start.
	for index in range(g.net_trail.size()-1,-1,-1):
		if g.net_return_path[-1].distance_to(g.net_trail[index])>0.01: g.net_return_path.append(g.net_trail[index])
	for point in g.net_exit_path:
		if g.net_return_path[-1].distance_to(point)>0.01: g.net_return_path.append(point)

static func cancel_manual_net(g: Node2D) -> void:
	# Planning can be cancelled; a committed sweep is never steered or aborted by release.
	if g.net_action.observing: end_observation(g)

static func request_net(g: Node2D) -> void:
	if g.match_over or g.line_landing(): return
	if g.net_state in ["wait","rest"] and not g.net_action.observing:
		g.net_queued=true
		g.notice="抄网练习已准备 · 留意入水预警"; g.notice_age=2

static func net_active(g: Node2D) -> bool:
	return g.net_state in ["prepare", "warning", "sweep", "miss", "withdraw", "caught"]

static func _net_contact(g: Node2D, point: Vector2, angle: float = NAN) -> bool:
	if is_nan(angle): angle=g.net_angle
	# Use the same conservative turnable footprint for preview, sweep and retraction.
	return manual_net_blocked(g,point)

static func _plan_net(g: Node2D) -> void:
	# Practice triggers use the same observation and commitment as the human/AI action.
	if begin_observation(g): g.net_action.ai=true

static func net_warning_outline(g: Node2D) -> PackedVector2Array:
	return g.net_warning_shape

static func _make_net_warning_outline(g: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for endpoint in [g.net_pos if g.manual_net and g.net_state=="sweep" else g.net_from,g.net_to]:
		for index in range(48): points.append(endpoint+(Vector2.from_angle(index*TAU/48)*g.net_catch()*1.01).rotated(g.net_angle))
	return Geometry2D.convex_hull(points)

static func _catch_in_net(g: Node2D) -> void:
	g._reset_untangle()
	g.net_action.observing=false
	g.net_capture=1.0
	g.qte=""
	g.qte_result_age=0
	g.wrap_target=-1
	for role in g.effort_checks: g.Effort.reset(g.effort_checks[role])
	g.net_state="caught"
	g.net_age=0
	g.net_return_from=g.net_pos
	g.net_catch_offset=g.fish-g.net_pos
	if g.manual_net: _prepare_manual_return(g)
	g.net_retract_duration=maxf(g.NET_LIFT,_net_retract_length(g)/240)
	g.net_catches+=1
	g.velocity=Vector2.ZERO
	g.sprinting=false
	g.feeding=false
	g.resisting=false
	g.returning=false
	g.home_age=0
	g.play_feedback("fail")
	_net_splash(g, g.net_pos)

static func _net_splash(g: Node2D, point: Vector2) -> void:
	g.net_splash=0.6
	g.net_splash_at=point
	g.play_feedback("splash")

static func _net_retract_length(g: Node2D) -> float:
	if g.manual_net and g.net_return_path.size()>1: return g.Rope.length_of(g.net_return_path)
	return g.net_return_from.distance_to(g.net_from)+g.net_from.distance_to(g.net_park)

static func _net_retract_point(g: Node2D, progress: float) -> Vector2:
	if g.manual_net and g.net_return_path.size()>1:
		var distance := _net_retract_length(g)*smoothstep(0,1,progress)
		for index in range(1,g.net_return_path.size()):
			var span: float=g.net_return_path[index-1].distance_to(g.net_return_path[index])
			if distance<=span: return g.net_return_path[index-1].lerp(g.net_return_path[index],distance/maxf(span,0.001))
			distance-=span
		return g.net_return_path[-1]
	# Retrace the collision-cleared route before lifting at the bank, away from wood and rocks.
	var first: float=g.net_return_from.distance_to(g.net_from)
	var distance := _net_retract_length(g)*smoothstep(0,1,progress)
	if first>0.001 and distance<first: return g.net_return_from.lerp(g.net_from,distance/first)
	var second: float=g.net_from.distance_to(g.net_park)
	return g.net_from.lerp(g.net_park,clampf((distance-first)/maxf(0.001,second),0,1))

static func net_bag_offset(g: Node2D) -> Vector2:
	var back := -Vector2.from_angle(g.net_angle)*22+Vector2(0,6)
	if g.net_state=="caught":
		return back.lerp(Vector2(0,17),smoothstep(0,1,g.net_age/g.NET_SETTLE))
	return back+Vector2(0,sin(g.elapsed*5)*2)

static func _net_reaches_fish(g: Node2D, point: Vector2, center: Vector2) -> bool:
	# The small body allowance around the rim must not reach through cover.
	for solid in g.map_net_blockers:
		var polygon: PackedVector2Array=solid.polygon
		if Geometry2D.is_point_in_polygon(point,polygon): return false
		for index in polygon.size():
			if Geometry2D.segment_intersects_segment(center,point,polygon[index],polygon[(index+1)%polygon.size()])!=null: return false
	return true

static func _net_hit_fraction(g: Node2D, a: Vector2, b: Vector2) -> float:
	if a.length_squared()<=1: return 0
	var motion := b-a
	var aa := motion.length_squared()
	if aa<0.000001: return -1
	var bb := 2*a.dot(motion)
	var cc := a.length_squared()-1
	var discriminant := bb*bb-4*aa*cc
	if discriminant<0: return -1
	var hit := (-bb-sqrt(discriminant))/(2*aa)
	return hit if hit>=0 and hit<=1 else -1

static func _finish_net_recovery(g: Node2D) -> void:
	g.net_capture=0.0
	g.manual_net=false
	g.net_trail.clear()
	g.net_return_path.clear()
	g.net_exit_path.clear()
	g.net_route.clear()
	g.net_route_next=1
	g.net_state="rest"
	g.net_age=0
	g.net_wait=0
	g.net_recovery=2

static func _step_net(g: Node2D, delta: float) -> void:
	g.net_splash=maxf(0,g.net_splash-delta)
	g.net_action.slow_age=maxf(0,g.net_action.slow_age-delta)
	g.net_action.impulse=g.net_action.impulse.move_toward(Vector2.ZERO,delta*260)
	g.net_last_position=g.net_pos
	if g.net_action.observing:
		g.net_action.age+=delta
		if g.net_action.ai: ai_plan(g)
		if g.net_action.observing and g.net_action.age>=g.rule("net_observe_time"): end_observation(g)
	if g.net_state in ["prepare","warning","sweep","miss","withdraw","caught"]:
		var advanced := 0.0
		while advanced<delta-0.0000001:
			var span := minf(1.0/120,delta-advanced)
			_advance_net(g,span,g.fish_before.lerp(g.fish,advanced/delta),g.fish_before.lerp(g.fish,(advanced+span)/delta))
			advanced+=span
			if g.match_over or g.net_state=="rest": break
		g.net_motion=(g.net_pos-g.net_last_position)/maxf(delta,0.001)
		return
	if not g.net_action.observing and g.angler.auto_net and g.challenge and g.started: g.net_wait+=delta
	if not g.net_action.observing and (g.net_queued or (g.angler.auto_net and g.net_wait>=(g.rule("net_first") if g.net_count==0 else g.rule("net_interval")))):
		if begin_observation(g):
			g.net_queued=false
			g.net_action.ai=true
			g.net_wait=0

static func _advance_net(g: Node2D, delta: float, frame_from: Vector2, frame_to: Vector2) -> void:
	var old_pos: Vector2=g.net_pos
	g.net_age+=delta
	if g.net_state=="caught":
		var settle := smoothstep(0,1,g.net_age/g.NET_SETTLE)
		var ratio := clampf((g.net_age-g.NET_SETTLE)/g.net_retract_duration,0,1)
		g.net_pos=_net_retract_point(g,ratio)
		g.fish=g.net_pos+g.net_catch_offset.lerp(net_bag_offset(g),settle)
		g._rebuild_rope()
		if ratio>=1:
			if g.challenge: g.finish(false,"net")
			else:
				g._clear_hook(); g.fish=g.map_context.home+Vector2(0,-14); g.fish_before=g.fish; g.hook_cooldown=2
				g.notice="被抄中了 · 已回到巢边"; g.notice_age=3
				_finish_net_recovery(g)
	elif g.net_state=="miss":
		if g.net_age>=g.NET_MISS:
			g.net_state="withdraw"; g.net_age=0; g.net_return_from=g.net_pos
			_prepare_manual_return(g)
			g.net_retract_duration=maxf(g.NET_WITHDRAW,_net_retract_length(g)/350)
	elif g.net_state=="withdraw":
		g.net_pos=_net_retract_point(g,clampf(g.net_age/g.net_retract_duration,0,1))
		if g.net_age>=g.net_retract_duration: _finish_net_recovery(g)
	elif g.net_state in ["prepare","warning"]:
		if g.net_age>=net_warning_seconds(g):
			g.net_state="sweep"; g.net_age=0; g.net_count+=1
			_net_splash(g,g.net_pos)
	elif g.net_state=="sweep":
		g.net_pos=g.net_pos.move_toward(g.net_to,g.rule("net_manual_speed")*delta)
		# Recheck every small movement, even after a preview: no tunnelling into wood/stone.
		if _net_contact(g,g.net_pos):
			g.net_pos=old_pos; g.net_blocked=true; miss(g)
		else:
			contact(g,frame_from,frame_to,old_pos,g.net_pos)
			if g.net_pos.distance_to(g.net_trail[-1])>0.5: g.net_trail.append(g.net_pos)
			if g.net_state=="sweep" and g.net_pos.distance_to(g.net_to)<0.001: miss(g)
	var surface_y: float=g.map_context.water.position.y-11
	if (old_pos.y-surface_y)*(g.net_pos.y-surface_y)<0: _net_splash(g,Vector2(g.net_pos.x,surface_y))


static func fresh() -> Dictionary:
	return {"observing":false,"age":0.0,"has_a":false,"a":Vector2.ZERO,"ai":false,
		"sample":Vector2.ZERO,"sample_at":0.0,"sample_live":false,"sample_velocity":Vector2.ZERO,
		"admitted":false,"rim_hit":false,"impulse":Vector2.ZERO,"slow_age":0.0}

static func busy(g: Node2D) -> bool:
	return g.net_state in ["prepare","warning","sweep","miss","withdraw","caught"]

static func begin_observation(g: Node2D) -> bool:
	if g.match_over or g.match_paused or g.line_landing() or g.angler.casting or busy(g) or g.angler.net_cooldown>0: return false
	if g.net_action.observing: return false
	g.net_action.observing=true; g.net_action.age=0.0; g.net_action.has_a=false
	g.net_action.ai=false; g.net_action.sample_live=false
	g.notice="左键选起点，再选终点 · E 取消"; g.notice_age=1.5
	return true

static func end_observation(g: Node2D) -> void:
	g.net_action.observing=false
	g.angler.net_cooldown=g.rule("net_cooldown")

static func command(g: Node2D, events: Array) -> void:
	if g.line_landing() or g.match_over:
		cancel_manual_net(g)
		return
	for event in events:
		match event.kind:
			"toggle":
				if g.net_action.observing: end_observation(g)
				else: begin_observation(g)
			"point": record_manual_net_point(g,event.point)
			"cancel", "suspend": cancel_manual_net(g)

static func reachable(g: Node2D, point: Vector2) -> bool:
	return g.map_context.net_area.has_point(point) and point.distance_to(g.angler.anchor())<=g.rule("net_reach")

static func visibility(g: Node2D, point: Vector2) -> float:
	var distance := point.distance_to(g.angler.anchor())
	if distance>g.rule("net_sight"): return 0.0
	for solid in g.map_fish_occluders:
		if Geometry2D.is_point_in_polygon(point,solid.polygon): return 0.0
	var cover: float=0.42 if g.vegetation_drag(point)<1 else 1.0
	return (1.0-smoothstep(g.rule("net_sight")*0.5,g.rule("net_sight"),distance))*cover

static func preview(g: Node2D, target: Vector2) -> Dictionary:
	var a: Vector2=g.net_action.a
	var span := (target-a).limit_length(g.rule("net_max_path"))
	var b := a+span
	var valid: bool=reachable(g,a) and reachable(g,b) and span.length()>=g.rule("net_min_path") and not manual_net_blocked(g,a)
	var end := a
	var blocked := false
	if valid:
		var steps := maxi(1,ceili(span.length()))
		for index in range(1,steps+1):
			var point := a.lerp(b,float(index)/steps)
			if manual_net_blocked(g,point): blocked=true; break
			end=point
	return {"valid":valid and end.distance_to(a)>=2,"a":a,"b":end,"requested":b,"blocked":blocked,"angle":span.angle()}

static func commit(g: Node2D, plan: Dictionary) -> void:
	end_observation(g)
	g.manual_net=true; g.net_capture=0; g.net_queued=false
	g.net_from=plan.a; g.net_to=plan.b; g.net_aim=plan.b; g.net_pos=plan.a; g.net_last_position=plan.a
	g.net_angle=plan.angle; g.net_kind="sweep"; g.net_blocked=plan.blocked
	g.net_park=g.net_exit_path[-1]
	g.net_state="warning"; g.net_age=0; g.net_motion=Vector2.ZERO
	g.net_trail=PackedVector2Array([plan.a]); g.net_route=PackedVector2Array([plan.a,plan.b]); g.net_route_next=1
	g.net_return_path.clear()
	g.net_action.admitted=false; g.net_action.rim_hit=false
	g.net_warning_shape=_make_net_warning_outline(g)
	g.play_feedback("warn"); _net_splash(g,plan.a)

static func miss(g: Node2D) -> void:
	g.net_state="miss"; g.net_age=0; g.net_dodges+=1
	g.notice="木石挡住了抄网" if g.net_blocked else "这一网扫完了 · 正在撤回"
	g.notice_age=2
	if g.net_blocked: g.play_feedback("tap")

static func contact(g: Node2D, fish_from: Vector2, fish_to: Vector2, net_from: Vector2, net_to: Vector2) -> void:
	var a := (fish_from-net_from).rotated(-g.net_angle)
	var b := (fish_to-net_to).rotated(-g.net_angle)
	var inner: float=maxf(4,g.net_rim().y-6)
	var depth: float=g.net_rim().x
	if not _net_reaches_fish(g,fish_to,net_to): g.net_action.admitted=false; return
	# Only a front-to-back crossing of the open mouth admits a fish. Initial overlap,
	# side grazes and back-to-front crossings cannot teleport it into the bag.
	if a.x>0 and b.x<=0:
		var crossing := a.lerp(b,a.x/maxf(0.00001,a.x-b.x))
		if absf(crossing.y)<inner: g.net_action.admitted=true
	if absf(b.y)>=inner or b.x>depth: g.net_action.admitted=false
	if g.net_action.admitted:
		if b.x<=-depth and absf(b.y)<inner:
			g.fish=fish_to; _catch_in_net(g)
		return
	var scale: Vector2=Vector2(depth+6,g.net_rim().y+6)
	var hit := _net_hit_fraction(g,a/scale,b/scale)
	var through_opening := absf(b.y)<inner and b.x>=0 and b.x<a.x
	if hit<0 or through_opening or g.net_action.rim_hit: return
	g.net_action.rim_hit=true
	var side := 1.0 if b.y>=0 else -1.0
	var local_push := Vector2(0.35,side).normalized()
	if b.x<0 and absf(b.y)<inner: local_push=Vector2(-1,side*0.3).normalized()
	g.net_action.impulse=local_push.rotated(g.net_angle)*g.rule("net_push")
	g.net_action.slow_age=g.rule("net_slow_time")
	g.play_feedback("tap")

static func ai_plan(g: Node2D) -> void:
	# Observe an imprecise silhouette, then commit to that sample rather than tracking
	# the live fish during the sweep. Hidden fish produce no target information.
	if not g.net_action.sample_live and visibility(g,g.fish)>0.12:
		g.net_action.sample=g.fish.snapped(Vector2(12,12))
		g.net_action.sample_velocity=g.velocity.limit_length(g.rule("swim_speed")).snapped(Vector2(20,20))
		g.net_action.sample_live=true; g.net_action.sample_at=g.net_action.age
	if g.net_action.age<minf(0.8,g.rule("net_observe_time")*0.7) or not g.net_action.sample_live: return
	var predicted: Vector2=g.net_action.sample+g.net_action.sample_velocity*0.45
	for offset in [Vector2(-65,0),Vector2(65,0),Vector2(0,-65),Vector2(0,65)]:
		var a: Vector2=predicted+offset
		if not reachable(g,a) or not begin_manual_net(g,a): continue
		var plan := preview(g,predicted-offset*0.65)
		if plan.valid:
			commit(g,plan)
			return
	# One decision per observation; no scanning continuously for a perfect opening.
	end_observation(g)
