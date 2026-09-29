extends RefCounted

# A separate render-only world. The latest authority state is never interpolated in place.
const World=preload("res://scripts/world_simulation.gd")
var world := World.new()
var previous: Dictionary={}
var current: Dictionary={}
var received_at := 0.0
var interval := 1.0/30.0

func clear() -> void:
	previous.clear()
	current.clear()

func accept(snapshot: Dictionary, now: float) -> void:
	previous=current
	current=snapshot
	if not previous.is_empty(): interval=clampf((snapshot.state.simulation_tick-previous.state.simulation_tick)/60.0,1.0/60,0.15)
	received_at=now
	world.restore_snapshot(snapshot)

func sample(now: float) -> Node2D:
	if current.is_empty() or previous.is_empty(): return world
	var a: Dictionary=previous.state
	var b: Dictionary=current.state
	var ratio := clampf((now-received_at)/interval,0,1)
	world.elapsed=lerpf(a.elapsed,b.elapsed,ratio)
	world.simulation_tick=roundi(lerpf(a.simulation_tick,b.simulation_tick,ratio))
	if a.hooked==b.hooked and a.net_state==b.net_state and not b.net_state=="caught" and not b.landing:
		world.fish=Vector2(a.fish).lerp(b.fish,ratio)
		world.aim=Vector2(a.aim).slerp(b.aim,ratio)
	else: world.fish=b.fish; world.aim=b.aim
	world.angler.x=lerpf(previous.rig.x,current.rig.x,ratio)
	for index in world.baits.size():
		var old: Dictionary=a.baits[index]
		var latest: Dictionary=b.baits[index]
		if old.id!=latest.id or old.active!=latest.active: continue
		world.baits[index].pos=Vector2(old.pos).lerp(latest.pos,ratio)
		world.baits[index].angle=lerp_angle(old.angle,latest.angle,ratio)
		if old.grains.size()!=latest.grains.size(): continue
		for grain in latest.grains.size():
			if old.grains[grain].id==latest.grains[grain].id:
				world.baits[index].grains[grain].pos=Vector2(old.grains[grain].pos).lerp(latest.grains[grain].pos,ratio)
	if not b.qte.is_empty() and a.qte_id==b.qte_id and a.qte==b.qte:
		world.qte_age=lerpf(a.qte_age,b.qte_age,ratio)
	else: world.qte_age=b.qte_age; world.simulation_tick=b.simulation_tick
	# Net position remains on its authoritative polyline; never lerp across a corner.
	if world.hooked==world.HookState.HOOKED: world._rebuild_rope()
	return world

func dispose() -> void:
	if is_instance_valid(world): world.free()
