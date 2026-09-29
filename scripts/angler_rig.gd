extends RefCounted

# Human controls feed the shared simulation; free hooks use an inertial tether.
var x := 206.0
var cursor := Vector2(232,180)
var spool := 0.0
var auto_reel := false
var auto_net := false
var casting := false
var cast_age := 0.0
var cast_from := Vector2.ZERO
var cast_to := Vector2.ZERO
var cast_index := -1
var cast_cooldown := 0.0
var net_cooldown := 0.0
var net_held := false
var dragging := false
var needs_neutral := false
var hook_velocity := Vector2.ZERO
var free_line_length := 132.0
var free_reel_speed := 0.0
var previous_anchor := Vector2(232,48)
var anchor_before := Vector2(232,48)
var line_sway := 0.0
var sway_speed := 0.0
var surface_x := 232.0
var surface_velocity := 0.0
var surface_live := false
var reel_phase := 0.0
var release_phase := 0.0
var reel_hand_mode := 0
var reel_hand_amount := 0.0
var rod_load := 0.0
var rod_lift := 0.0
const Rules = preload("res://scripts/game_rules.gd")
const CAST_SECONDS := 0.7

func reset() -> void:
	x=206
	cursor=Vector2(232,180)
	spool=0
	auto_reel=false
	auto_net=false
	casting=false
	cast_age=0
	cast_from=Vector2.ZERO
	cast_to=Vector2.ZERO
	cast_index=-1
	cast_cooldown=0
	net_cooldown=0
	net_held=false
	dragging=false
	needs_neutral=false
	hook_velocity=Vector2.ZERO
	free_line_length=132
	free_reel_speed=0
	previous_anchor=anchor()
	anchor_before=anchor()
	line_sway=0
	sway_speed=0
	surface_x=anchor().x
	surface_velocity=0
	surface_live=false
	reel_phase=0
	release_phase=0
	reel_hand_mode=0
	reel_hand_amount=0
	rod_load=0
	rod_lift=0

func surface_target(game: Node2D) -> Vector2:
	if game.bound_bait>=0:
		if game.rope_path.size()>2: return game.rope_path[1]
		return game.mouth()
	for bait in game.baits:
		if bait.hook and bait.active and not bait.removed: return bait.pos
	return Vector2(INF,INF)

func feedback_reel_speed(game: Node2D) -> float:
	if casting or game.landing or game.net_state=="caught": return 0.0
	if game.hooked==game.HookState.HOOKED: return game.reel_speed
	if game.hooked!=game.HookState.FREE: return 0.0
	# Free tackle has a separate spool. Ignore its cached speed after retrieval
	# or a broken line, and stop the animation at the physical line limits.
	if (free_reel_speed>0 and free_line_length>=game.rule("line_free_max")) or (free_reel_speed<0 and free_line_length<=45): return 0.0
	for bait in game.baits:
		if bait.hook and bait.active and not bait.removed: return free_reel_speed
	return 0.0

func step_tackle_feedback(game: Node2D, delta: float) -> void:
	if not game.uses_mobile_tackle(): return
	var bracing:bool=game.hooked==game.HookState.HOOKED and not game.landing and game.net_state!="caught"
	var target_load:float=clampf(game.tension,0,1) if bracing else 0.0
	var target_lift:=0.25+0.75*target_load if bracing else 0.0
	rod_load=lerpf(rod_load,target_load,1-exp(-delta*(10 if target_load>rod_load else 6)))
	rod_lift=lerpf(rod_lift,target_lift,1-exp(-delta*(8 if target_lift>rod_lift else 5)))
	var target := surface_target(game)
	if casting:
		surface_x=cast_to.x; surface_velocity=0; surface_live=false
	elif not target.is_finite():
		surface_live=false; surface_velocity=0
	else:
		if not surface_live:
			surface_x=target.x; surface_velocity=0; surface_live=true
		# A buoy has its own momentum. The submerged hook/fish supplies most of
		# its lateral pull; rod motion reaches it through a tension-dependent spring.
		var load:float=game.tension if game.hooked==game.HookState.HOOKED else 0.35
		var goal := lerpf(anchor().x,target.x,0.78)
		var count := maxi(1,ceili(delta*120))
		for part in count:
			var dt := delta/count
			var current:float=game.water_velocity(Vector2(surface_x,60)).x
			var relative := surface_velocity-current
			var drag := relative*(4.5+absf(relative)*0.025)
			surface_velocity+=((goal-surface_x)*(4.5+load*13)-drag)*dt
			surface_x+=surface_velocity*dt
			if surface_x<20 or surface_x>620:
				surface_x=clampf(surface_x,20,620); surface_velocity=0
	var speed:=feedback_reel_speed(game)
	var desired := 0
	if not net_held and absf(speed)>0.5:
		desired=-1 if speed<0 else 1
	# Integrate phase, not elapsed*speed: slowing, reversing and pausing never
	# teleport the handle or make the left hand jump to another point on its orbit.
	reel_phase=fposmod(reel_phase+maxf(0,-speed)/36*TAU*1.3*delta,TAU)
	release_phase=fposmod(release_phase+maxf(0,speed)/90*TAU*0.7*delta,TAU)
	if reel_hand_mode==0: reel_hand_mode=desired
	var reaching := desired!=0 and desired==reel_hand_mode
	reel_hand_amount=move_toward(reel_hand_amount,1.0 if reaching else 0.0,delta*(5 if reaching else 6))
	if reel_hand_amount==0: reel_hand_mode=desired

func anchor() -> Vector2: return Vector2(x+26,48)

func projectile() -> Vector2:
	var ratio := clampf(cast_age/CAST_SECONDS,0,1)
	return cast_from.lerp(cast_to,ratio)-Vector2(0,sin(ratio*PI)*28)

func available_bait(game: Node2D) -> int:
	for index in [0,2]:
		var bait: Dictionary=game.baits[index]
		if not bait.removed and game._remaining(bait,true): return index
	return -1

func deploy(game: Node2D) -> bool:
	if game.hooked!=game.HookState.FREE or game.net_blocks_hooks() or net_held or casting or cast_cooldown>0: return false
	for bait in game.baits:
		if bait.hook and bait.active and not bait.removed and game._remaining(bait,true):
			game.notice="钩饵已在水中 · W 收线 / S 放线，收至岸边可取回"
			game.notice_age=2
			return false
	if available_bait(game)<0: game.refill_hook_bait(0)
	return cast(game,anchor()+Vector2(0,game.rule("cast_depth")))

func cast(game: Node2D, point: Vector2) -> bool:
	if game.hooked!=game.HookState.FREE or game.net_blocks_hooks() or casting or cast_cooldown>0: return false
	var index := available_bait(game)
	if index<0: return false
	for bait in game.baits:
		if bait.hook: bait.active=false
	cast_index=index
	cast_from=anchor()
	cast_to=point.clamp(Vector2(38,100),Vector2(602,284))
	cast_age=0
	casting=true
	cast_cooldown=1.2
	game.play_feedback("warn")
	return true

func suspend_controls(game: Node2D) -> void:
	needs_neutral=true
	net_held=false
	dragging=false
	spool=0
	game.cancel_manual_net()

func steer_net(game: Node2D, point: Vector2) -> void:
	if needs_neutral or casting or game.match_paused or game.match_over or game.landing or game.hooked==game.HookState.MOUTH: return
	cursor=point.clamp(Vector2(30,80),Vector2(610,294))
	if game.manual_net and game.net_state in ["prepare","warning","sweep"]:
		game.record_manual_net_point(cursor)
	elif net_cooldown<=0 and game.net_state in ["wait","rest"] and Rect2(0,80,640,233).has_point(point):
		if game.begin_manual_net(cursor): net_cooldown=game.rule("net_cooldown")

func update(game: Node2D, delta: float, command: Dictionary) -> void:
	auto_reel=command.get("auto_reel",false)
	auto_net=command.get("auto_net",false)
	cast_cooldown=maxf(0,cast_cooldown-delta)
	net_cooldown=maxf(0,net_cooldown-delta)
	var raw_cursor := Vector2(command.get("target",cursor))
	cursor=raw_cursor.clamp(Vector2(30,80),Vector2(610,294))
	anchor_before=anchor()
	if not game.landing and game.net_state!="caught": x=clampf(x+clampf(float(command.get("walk",0)),-1,1)*game.rule("angler_speed")*delta,18,588)
	var bank_speed := (anchor().x-anchor_before.x)/maxf(delta,0.001)
	var count := maxi(1,ceili(delta*120))
	for part in count:
		var dt := delta/count
		sway_speed+=(-32*line_sway-4.8*sway_speed-bank_speed*4)*dt
		line_sway=clampf(line_sway+sway_speed*dt,-22,22)
	spool=float(bool(command.get("release",false)))-float(bool(command.get("reel",false)))
	if game.hooked==game.HookState.MOUTH or game.landing or game.net_state=="caught": spool=0
	if needs_neutral:
		if not command.get("net_hold",false) and not command.get("drag",false): needs_neutral=false
		net_held=false
		dragging=false
	else:
		net_held=command.get("net_hold",false)
		dragging=net_held and command.get("drag",false)
	for event in command.get("net_events",[]):
		match event.kind:
			"point": steer_net(game,event.point)
			"cancel": game.cancel_manual_net()
			"suspend": suspend_controls(game)
	if not net_held or not dragging:
		game.cancel_manual_net()
	else:
		steer_net(game,raw_cursor)
	if command.get("deploy",false): deploy(game)
	if not casting: return
	cast_age+=delta
	if cast_age<CAST_SECONDS: return
	casting=false
	var bait: Dictionary=game.baits[cast_index]
	bait.home=cast_to
	bait.pos=cast_to
	bait.angle=0
	bait.age=0
	bait.active=true
	bait.tip_before=cast_to+Vector2(2,1)
	free_line_length=anchor().distance_to(cast_to)
	free_reel_speed=0
	hook_velocity=Vector2.ZERO
	previous_anchor=anchor()
	for grain in bait.grains:
		if not grain.eaten and not grain.free: grain.pos=cast_to+Vector2(grain.offset)
	game.play_feedback("splash")

func step_free_hook(game: Node2D, index: int, delta: float, sucking: bool) -> void:
	var bait: Dictionary=game.baits[index]
	var position: Vector2=bait.pos
	var bank_velocity := (anchor()-previous_anchor)/maxf(delta,0.001)
	var count := maxi(1,ceili(delta*120))
	for part in count:
		var dt := delta/count
		free_reel_speed=manual_spool_speed(free_reel_speed,dt*game.rule("line_response"),1.0,game.rules)
		free_line_length=clampf(free_line_length+free_reel_speed*dt,45,game.rule("line_free_max"))
		var attachment := previous_anchor.lerp(anchor(),float(part+1)/count)
		var force := Vector2(0,150)+Vector2(game.water_velocity(position))*2-hook_velocity*1.0
		if sucking:
			force+=(game.mouth()-position).normalized()*game.strength(position)*game.power*480*game.rule("hook_suction")
		hook_velocity+=force*dt
		position+=hook_velocity*dt
		var radial := position-attachment
		if radial.length()>free_line_length:
			var normal := radial.normalized()
			position=attachment+normal*free_line_length
			var outward := (hook_velocity-bank_velocity).dot(normal)-free_reel_speed
			if outward>0: hook_velocity-=normal*outward
		var bounded := position.clamp(Vector2(20,79),Vector2(620,299))
		if not is_equal_approx(bounded.x,position.x): hook_velocity.x=0
		if not is_equal_approx(bounded.y,position.y): hook_velocity.y=0
		position=bounded
	bait.pos=position
	bait.home=position
	bait.angle=clampf((position-anchor()).angle()-PI/2,-0.7,0.7)+hook_velocity.x*0.002
	previous_anchor=anchor()
	if spool<0 and free_line_length<=45.01 and position.distance_to(anchor())<49:
		bait.active=false
		free_reel_speed=0
		hook_velocity=Vector2.ZERO
		game.notice="钩饵已收回 · Q 重新下钩"
		game.notice_age=2

func spool_target(raw_tension: float, tuning: Vector2, manual: bool, values: Dictionary = {}) -> float:
	if manual: return spool*(float(values.get("release_speed",90.0)) if spool>0 else float(values.get("reel_speed",36.0)))
	return clampf(-float(values.get("auto_reel",24))*tuning.y+(raw_tension-float(values.get("auto_tension",0.5)))*float(values.get("auto_gain",100))*tuning.x,-float(values.get("reel_speed",36))*tuning.y,float(values.get("auto_release",24))*tuning.y)

func manual_spool_speed(current: float, delta: float, force_gain: float = 1.0, values: Dictionary = {}) -> float:
	var target := spool_target(0,Vector2.ONE,true,values)
	if target<0: target*=force_gain
	# Brake promptly on release/reversal; accelerating the new direction stays smooth.
	if current*target<0:
		var brake_time := absf(current)/720.0
		if delta<=brake_time: return move_toward(current,0,delta*720)
		return move_toward(0,target,(delta-brake_time)*180)
	return move_toward(current,target,delta*(720 if is_zero_approx(target) else 180))
