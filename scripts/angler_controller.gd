extends RefCounted

# Player and computer produce the same spool target; the pond owns tension and outcomes.
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

func anchor() -> Vector2:
	return Vector2(x+26,48)

func projectile() -> Vector2:
	var ratio := clampf(cast_age/CAST_SECONDS,0,1)
	return cast_from.lerp(cast_to,ratio)-Vector2(0,sin(ratio*PI)*45)

func available_bait(game: Node2D) -> int:
	for index in [0,2]:
		var bait: Dictionary=game.baits[index]
		if not bait.removed and game._remaining(bait,true): return index
	return -1

func cast(game: Node2D, point: Vector2) -> bool:
	if game.hooked!=game.HookState.FREE or game.net_blocks_hooks() or casting or cast_cooldown>0: return false
	var index := available_bait(game)
	if index<0:
		game.notice="钩饵用完了 · 可继续用抄网捕获"
		game.notice_age=3
		return false
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

func update(game: Node2D, delta: float, command: Dictionary) -> void:
	cast_cooldown=maxf(0,cast_cooldown-delta)
	net_cooldown=maxf(0,net_cooldown-delta)
	cursor=Vector2(command.get("target",cursor)).clamp(Vector2(38,80),Vector2(602,294))
	if not game.landing and game.net_state!="caught":
		x=clampf(x+float(command.get("walk",0))*72*delta,18,588)
	spool=0
	if game.hooked==game.HookState.HOOKED:
		spool=1.0 if command.get("release",false) else (-1.0 if command.get("reel",false) else 0.0)
	if command.get("cast",false) and Rect2(0,80,640,233).has_point(Vector2(command.get("target",cursor))): cast(game,cursor)
	if command.get("retrieve",false) and game.hooked==game.HookState.FREE and not casting:
		for bait in game.baits:
			if bait.hook: bait.active=false
	if command.get("net",false) and net_cooldown<=0 and not casting and not game.landing and game.hooked!=game.HookState.MOUTH and game.net_state in ["wait","rest"]:
		game.net_aim=cursor
		game.request_net()
		if game.net_queued: net_cooldown=12
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
	for grain in bait.grains:
		if not grain.eaten and not grain.free: grain.pos=cast_to+Vector2(grain.offset)
	game.sound.play("splash")

func spool_target(raw_tension: float, tuning: Vector2, manual: bool) -> float:
	if manual: return spool*(90.0 if spool>0 else 36.0)
	return clampf(-24*tuning.y+(raw_tension-0.5)*100*tuning.x,-36*tuning.y,24*tuning.y)
