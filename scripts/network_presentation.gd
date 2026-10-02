extends RefCounted

# A separate render-only world. The latest authority state is never interpolated in place.
const World=preload("res://scripts/world_simulation.gd")
const FishNetworkObservation=preload("res://scripts/fish_network_observation.gd")
var world := World.new()
var previous: Dictionary={}
var current: Dictionary={}
var received_at := 0.0
var interval := 1.0/30.0

func clear() -> void:
	previous.clear()
	current.clear()

func accept(snapshot: Dictionary, now: float, role: String = "angler") -> bool:
	var accepted: bool=FishNetworkObservation.apply(world,snapshot) if role=="fish" else world.restore_snapshot(snapshot)
	if not accepted: return false
	previous=current if current.get("format","")==snapshot.get("format","") else {}
	current=snapshot.duplicate(true)
	if not previous.is_empty(): interval=clampf((snapshot.state.simulation_tick-previous.state.simulation_tick)/60.0,1.0/60,0.15)
	received_at=now
	return true

func sample(now: float) -> Node2D:
	if current.is_empty() or previous.is_empty(): return world
	var a: Dictionary=previous.state
	var b: Dictionary=current.state
	var check_roles: Array=["fish"] if current.get("format")==FishNetworkObservation.FORMAT else ["fish","angler"]
	var ratio := clampf((now-received_at)/interval,0,1)
	world.elapsed=lerpf(a.elapsed,b.elapsed,ratio)
	world.power=lerpf(a.power,b.power,ratio)
	world.simulation_tick=roundi(lerpf(a.simulation_tick,b.simulation_tick,ratio))
	if a.hooked==b.hooked and a.net_state==b.net_state and not b.net_state=="caught" and not b.landing:
		world.fish=Vector2(a.fish).lerp(b.fish,ratio)
		world.aim=Vector2(a.aim).slerp(b.aim,ratio)
	else: world.fish=b.fish; world.aim=b.aim
	world.fish_before=world.fish-(Vector2(b.fish)-Vector2(b.fish_before))
	world.net_capture=lerpf(a.net_capture,b.net_capture,ratio) if a.net_state=="sweep" and b.net_state=="sweep" else b.net_capture
	world.angler.x=lerpf(previous.rig.x,current.rig.x,ratio)
	world.angler.line_sway=lerpf(previous.rig.line_sway,current.rig.line_sway,ratio)
	world.angler.rod_load=lerpf(previous.rig.rod_load,current.rig.rod_load,ratio)
	world.angler.rod_lift=lerpf(previous.rig.rod_lift,current.rig.rod_lift,ratio)
	world.angler.surface_x=lerpf(previous.rig.surface_x,current.rig.surface_x,ratio) if previous.rig.surface_live==current.rig.surface_live else current.rig.surface_x
	world.angler.surface_velocity=lerpf(previous.rig.surface_velocity,current.rig.surface_velocity,ratio)
	world.angler.reel_phase=fposmod(lerp_angle(previous.rig.reel_phase,current.rig.reel_phase,ratio),TAU)
	world.angler.release_phase=fposmod(lerp_angle(previous.rig.release_phase,current.rig.release_phase,ratio),TAU)
	world.angler.reel_hand_amount=lerpf(previous.rig.reel_hand_amount,current.rig.reel_hand_amount,ratio) if previous.rig.reel_hand_mode==current.rig.reel_hand_mode else current.rig.reel_hand_amount
	world.untangle_age=lerpf(a.untangle_age,b.untangle_age,ratio) if a.untangle_phase==b.untangle_phase else b.untangle_age
	if a.wraps.size()==b.wraps.size():
		for index in b.wraps.size():
			if a.wraps[index].target==b.wraps[index].target:
				world.wraps[index].progress=lerpf(a.wraps[index].progress,b.wraps[index].progress,ratio)
	for index in world.baits.size():
		if index>=a.baits.size(): continue
		var old: Dictionary=a.baits[index]
		var latest: Dictionary=b.baits[index]
		if old.bait_id!=latest.bait_id or old.active!=latest.active: continue
		world.baits[index].pos=Vector2(old.pos).lerp(latest.pos,ratio)
		world.baits[index].angle=lerp_angle(old.angle,latest.angle,ratio)
		world.baits[index].suction_offset=Vector2(old.suction_offset).lerp(latest.suction_offset,ratio)
		if old.grains.size()!=latest.grains.size(): continue
		for grain in latest.grains.size():
			if old.grains[grain].id==latest.grains[grain].id:
				world.baits[index].grains[grain].pos=Vector2(old.grains[grain].pos).lerp(latest.grains[grain].pos,ratio)
	if not b.qte.is_empty() and a.qte_id==b.qte_id and a.qte==b.qte:
		world.qte_age=lerpf(a.qte_age,b.qte_age,ratio)
	else: world.qte_age=b.qte_age
	for role in check_roles:
		var old: Dictionary=a.effort_checks[role]
		var latest: Dictionary=b.effort_checks[role]
		if old.active and latest.active and old.id==latest.id:
			world.effort_checks[role].age=lerpf(old.age,latest.age,ratio)
		else: world.effort_checks[role].age=latest.age
	# On a newly appearing check use the current tick, matching its unsmoothed age.
	var changed_check: bool=a.qte_id!=b.qte_id or a.qte!=b.qte
	for role in check_roles:
		changed_check=changed_check or a.effort_checks[role].id!=b.effort_checks[role].id or a.effort_checks[role].active!=b.effort_checks[role].active
	if changed_check: world.simulation_tick=b.simulation_tick; world.qte_age=b.qte_age
	if changed_check:
		for role in check_roles: world.effort_checks[role].age=b.effort_checks[role].age
	if a.net_action.observing and b.net_action.observing:
		world.net_action.age=lerpf(a.net_action.age,b.net_action.age,ratio)
	# A sweep is a single segment. During retraction interpolate time on the actual
	# collision-cleared path, never a chord that cuts across an obstacle corner.
	if a.net_state=="sweep" and b.net_state=="sweep": world.net_pos=Vector2(a.net_pos).lerp(b.net_pos,ratio)
	if a.net_state==b.net_state:
		world.net_age=lerpf(a.net_age,b.net_age,ratio)
		if b.net_state in ["withdraw","caught"]:
			var delay: float=world.NET_SETTLE if b.net_state=="caught" else 0.0
			world.net_pos=world._net_retract_point(clampf((world.net_age-delay)/world.net_retract_duration,0,1))
			if b.net_state=="caught":
				world.fish=world.net_pos+world.net_catch_offset.lerp(world.net_bag_offset(),smoothstep(0,1,world.net_age/world.NET_SETTLE))
	if world.hooked==world.HookState.HOOKED: world._rebuild_rope()
	return world

func dispose() -> void:
	if is_instance_valid(world): world.free()
