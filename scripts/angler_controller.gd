extends RefCounted

# Human controls feed the shared simulation; free hooks use an inertial tether.
var x := 206.0
var cursor := Vector2(232,180)
var spool := 0.0
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
const CAST_SECONDS := 0.7

func reset() -> void:
	x=206
	cursor=Vector2(232,180)
	spool=0
	casting=false
	cast_age=0
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
	return cast(game,anchor()+Vector2(0,132))

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
	game.sound.play("warn")
	return true

func suspend_controls(game: Node2D) -> void:
	needs_neutral=true
	net_held=false
	dragging=false
	spool=0
	game.cancel_manual_net()

func update(game: Node2D, delta: float, command: Dictionary) -> void:
	cast_cooldown=maxf(0,cast_cooldown-delta)
	net_cooldown=maxf(0,net_cooldown-delta)
	var raw_cursor := Vector2(command.get("target",cursor))
	cursor=raw_cursor.clamp(Vector2(30,80),Vector2(610,294))
	anchor_before=anchor()
	if not game.landing and game.net_state!="caught": x=clampf(x+clampf(float(command.get("walk",0)),-1,1)*72*delta,18,588)
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
	if not net_held or not dragging:
		game.cancel_manual_net()
	elif not casting and not game.landing and game.hooked!=game.HookState.MOUTH:
		if game.manual_net and game.net_state in ["prepare","warning","sweep"]:
			game.net_aim=cursor
			game.net_to=game.manual_net_target(cursor)
			game.net_warning_shape=game._make_net_warning_outline()
		elif net_cooldown<=0 and game.net_state in ["wait","rest"] and Rect2(0,80,640,233).has_point(raw_cursor):
			game.begin_manual_net(cursor)
			net_cooldown=12
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
	game.sound.play("splash")

func step_free_hook(game: Node2D, index: int, delta: float, sucking: bool) -> void:
	var bait: Dictionary=game.baits[index]
	var position: Vector2=bait.pos
	var bank_velocity := (anchor()-previous_anchor)/maxf(delta,0.001)
	var count := maxi(1,ceili(delta*120))
	for part in count:
		var dt := delta/count
		free_reel_speed=move_toward(free_reel_speed,spool_target(0,Vector2.ONE,true),180*dt)
		free_line_length=clampf(free_line_length+free_reel_speed*dt,45,520)
		var attachment := previous_anchor.lerp(anchor(),float(part+1)/count)
		var force := Vector2(0,150)+Vector2(game.water_velocity(position))*2-hook_velocity*1.0
		if sucking:
			force+=(game.mouth()-position).normalized()*game.strength(position)*game.power*480
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

func spool_target(raw_tension: float, tuning: Vector2, manual: bool) -> float:
	if manual: return spool*(90.0 if spool>0 else 36.0)
	return clampf(-24*tuning.y+(raw_tension-0.5)*100*tuning.x,-36*tuning.y,24*tuning.y)
