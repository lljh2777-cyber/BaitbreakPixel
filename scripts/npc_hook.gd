extends RefCounted

# Single-line NPC authority. Player QTE/wrap/tension state is never repurposed.
# This module acts only AFTER real mouth contact; it is not a decision input.
const State=preload("res://scripts/npc_fish_state.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")
const Layout=preload("res://scripts/pond_layout.gd")
# A wrong target should cost a short handling window, not a full player tug.
# Scale inward spool and physical pull together; payout and failure windows stay
# unchanged, and the player actuator/rules are never modified.
const RETRIEVAL_GAIN := 1.8

static func fresh() -> Dictionary:
	return {"phase":"","age":0.0,"low_age":0.0,"high_age":0.0,"landing_age":0.0,"landing_from":Vector2.ZERO,"struggle_phase":0.0}

static func fresh_result() -> Dictionary:
	return {"tick":-1,"fish_id":-1,"result":"","position":Vector2.ZERO}

static func valid(record: Variant) -> bool:
	if not record is Dictionary: return false
	var defaults:=fresh()
	if record.size()!=defaults.size(): return false
	for key in defaults:
		if not record.has(key) or typeof(record[key])!=typeof(defaults[key]): return false
	if record.phase not in ["","hooked","landing"] or not record.landing_from.is_finite(): return false
	for key: String in ["age","low_age","high_age","landing_age","struggle_phase"]:
		if not is_finite(record[key]) or record[key]<0: return false
	if record.struggle_phase>=TAU: return false
	if record.phase.is_empty() and record!=defaults: return false
	return true

static func valid_result(record: Variant, tick: int, next_id: int) -> bool:
	if not record is Dictionary: return false
	var defaults:=fresh_result()
	if record.size()!=defaults.size(): return false
	for key in defaults:
		if not record.has(key) or typeof(record[key])!=typeof(defaults[key]): return false
	if not record.position.is_finite() or record.tick< -1 or record.tick>tick: return false
	if record.result.is_empty(): return record==defaults
	return record.result in ["hooked","escaped","broken","captured"] and record.tick>=0 and record.fish_id>=2 and record.fish_id<next_id

static func _record(world: Node2D, npc: Dictionary, result: String) -> void:
	world.public_npc_hook_result={"tick":world.simulation_tick,"fish_id":int(npc.fish_id),"result":result,"position":Vector2(npc.position)}

static func _stop_brain(npc: Dictionary, state: String) -> void:
	npc.behavior_state=state; npc.behavior_age=0.0
	npc.feeding=false; npc.power=0.0; npc.target_bait_id=-1; npc.bite_cooldown=0.0
	npc.steering=Vector2.ZERO; npc.decision_age=0.0
	npc.social_reaction_left=0.0; npc.social_recovery_left=0.0; npc.social_compete_left=0.0
	npc.social_origin=Vector2.ZERO; npc.social_bait_id=-1

static func enter(world: Node2D, index: int, npc: Dictionary) -> bool:
	if not world.npc_hook_enabled or world.match_over or world.match_paused or world.hook_target_fish_id!=-1 or world.hooked!=world.HookState.FREE: return false
	if index<0 or index>=world.baits.size() or not npc.active or npc.hook_immunity>0: return false
	var bait: Dictionary=world.baits[index]
	if not bait.active or not bait.hook or bait.removed: return false
	world.hook_target_fish_id=int(npc.fish_id); world.bound_bait=index
	world.npc_hook=fresh(); world.npc_hook.phase="hooked"
	# ID-local phase; neither world.rng nor the NPC decision RNG is consumed.
	world.npc_hook.struggle_phase=float(posmod(int(npc.brain_seed),10000))/10000.0*TAU
	_stop_brain(npc,"HOOKED")
	npc.velocity=Vector2.ZERO
	bait.suction_offset=Vector2.ZERO
	world.tension=0.5; world.reel_speed=0.0; world.high_age=0.0; world.low_age=0.0
	world.rope_length=world.line_anchor(index).distance_to(world.hook_target_mouth())
	world._rebuild_rope()
	world.public_hook_cue={"tick":world.simulation_tick,"position":Vector2(npc.position)}
	world.round_stats.npc_hook_count+=1
	_record(world,npc,"hooked")
	world.notice="有鱼中钩 · 留意浮漂和张力"; world.notice_age=2.0
	world.play_feedback("warn")
	return true

static func step(world: Node2D, delta: float) -> void:
	if world.hook_target_fish_id<2: return
	var npc: Dictionary=world.npc_by_id(world.hook_target_fish_id)
	if npc.is_empty() or not npc.active:
		# Invalid runtime removal cannot leave an orphan line; snapshots reject it.
		_clear_line(world)
		return
	var state: Dictionary=world.npc_hook
	state.age+=delta
	world.round_stats.npc_hooked_seconds+=delta
	if state.phase=="landing":
		state.landing_age+=delta
		var ratio:=clampf(state.landing_age/world.rule("landing_lift"),0,1)
		npc.position=Vector2(state.landing_from).lerp(Vector2(world.line_anchor(world.bound_bait).x,39),ratio*ratio)
		npc.velocity=Vector2.ZERO
		world._rebuild_rope()
		if ratio>=1: capture(world)
		return
	var anchor: Vector2=world.line_anchor(world.bound_bait)
	var origin: Vector2=world.hook_target_mouth()
	var tuning: Vector2=world.line_tuning()
	var raw: float=0.5+(anchor.distance_to(origin)-world.rope_length)/world.rule("line_elastic")
	var desired: float=world.angler.spool_target(raw,tuning,not world.angler.auto_reel,world.rules)
	if desired<0: desired*=RETRIEVAL_GAIN
	if world.Net.busy(world): desired=0.0
	if tuning.y<=0: world.reel_speed=0.0
	elif world.Net.busy(world): world.reel_speed=move_toward(world.reel_speed,0.0,delta*720)
	elif not world.angler.auto_reel: world.reel_speed=world.angler.manual_spool_speed(world.reel_speed,delta*tuning.x*maxf(1,tuning.y),RETRIEVAL_GAIN,world.rules)
	else: world.reel_speed=move_toward(world.reel_speed,desired,delta*60*tuning.x*maxf(1,tuning.y))
	world.rope_length=clampf(world.rope_length+world.reel_speed*delta,0,world.rule("line_max"))
	world.tension=clampf(0.5+(anchor.distance_to(origin)-world.rope_length)/world.rule("line_elastic"),0,1)
	var away: Vector2=(origin-anchor).normalized()
	var phase: float=state.struggle_phase+state.age*3.8
	var strength:=lerpf(26.0,8.0,clampf(state.age/12.0,0,1))*(0.7+0.3*sin(phase))
	var struggle:=away*strength+away.orthogonal()*sin(phase*0.7)*12.0
	var load:=clampf((world.tension-0.12)/0.88,0,1)
	var pull: Vector2=-away*world.rule("line_pull")*RETRIEVAL_GAIN*load*sqrt(tuning.y)
	npc.velocity=Vector2(npc.velocity).move_toward(struggle,delta*70.0)
	var motion: Vector2=(Vector2(npc.velocity)+pull+world.water_velocity(npc.position)).limit_length(State.HOOK_SPEED_LIMIT)
	var bounds:=Layout.fish_bounds(State.RADIUS)
	npc.position=(Vector2(npc.position)+motion*delta).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)
	# Match the existing mobile tackle's finite elastic reach, without wraps.
	if world.uses_mobile_tackle() and tuning.y>0:
		var radial: Vector2=world.hook_target_mouth()-anchor
		var reach: float=world.rope_length+world.rule("line_elastic")*0.5
		if radial.length()>reach:
			npc.position=(anchor+radial.normalized()*reach-Vector2(npc.aim)*10).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)
	world.tension=clampf(0.5+(anchor.distance_to(world.hook_target_mouth())-world.rope_length)/world.rule("line_elastic"),0,1)
	world._rebuild_rope()
	state.high_age=state.high_age+delta if world.tension>=world.rule("tension_high") else 0.0
	state.low_age=state.low_age+delta if world.tension<world.rule("tension_low") else 0.0
	world.high_age=state.high_age; world.low_age=state.low_age
	if state.high_age>=world.break_hold_seconds:
		release(world,true)
		return
	# Automatic NPC slip; player slack QTE and RNG are untouched.
	if state.low_age>=world.slack_hold_seconds+0.65:
		release(world,false)
		return
	if not world.Net.busy(world) and npc.position.y<91 and absf(npc.position.x-anchor.x)<30 and world.tension>=world.rule("tension_low"):
		state.landing_age+=delta
		if state.landing_age>=world.rule("landing_hold"):
			world.Net.cancel_manual_net(world)
			state.phase="landing"; state.landing_age=0.0; state.landing_from=Vector2(npc.position)
			_stop_brain(npc,"LANDING"); npc.velocity=Vector2.ZERO
			world.reel_speed=0.0
	else: state.landing_age=0.0

static func _clear_line(world: Node2D) -> void:
	world.hook_target_fish_id=-1; world.bound_bait=-1; world.npc_hook=fresh()
	world.rope_path.clear(); world.rope_length=0.0; world.tension=0.0; world.reel_speed=0.0
	world.high_age=0.0; world.low_age=0.0

static func release(world: Node2D, broken: bool) -> void:
	if world.hook_target_fish_id<2: return
	var npc: Dictionary=world.npc_by_id(world.hook_target_fish_id)
	if npc.is_empty(): _clear_line(world); return
	var bait: Dictionary=world.baits[world.bound_bait]
	bait.pos=world.hook_target_mouth()-Vector2(2,1).rotated(bait.angle)
	bait.home=bait.pos; bait.tip_before=world.hook_target_mouth(); bait.suction_offset=Vector2.ZERO
	if broken: bait.removed=true
	if world.uses_mobile_tackle():
		world.angler.free_line_length=world.angler.anchor().distance_to(bait.pos)
		world.angler.previous_anchor=world.angler.anchor()
		world.angler.hook_velocity=Vector2(npc.velocity)*0.3
	world.round_stats["npc_breaks" if broken else "npc_escapes"]+=1
	_record(world,npc,"broken" if broken else "escaped")
	_stop_brain(npc,"WANDER")
	npc.velocity=Vector2(npc.velocity).limit_length(State.SPEED)
	npc.hook_immunity=State.HOOK_IMMUNITY_SECONDS
	_clear_line(world)
	world.notice="鱼挣断了线 · 重新挂饵" if broken else "鱼挣脱了 · 继续留意钓点"
	world.notice_age=3.0
	world.play_feedback("break" if broken else "success")

static func capture(world: Node2D) -> void:
	if world.hook_target_fish_id<2: return
	var npc: Dictionary=world.npc_by_id(world.hook_target_fish_id)
	if npc.is_empty(): _clear_line(world); return
	var bait: Dictionary=world.baits[world.bound_bait]
	bait.removed=true; bait.active=false; bait.suction_offset=Vector2.ZERO
	for grain: Dictionary in bait.grains:
		if not grain.free: grain.eaten=true # Left the pond on the captured tackle; no score award.
	_stop_brain(npc,"CAPTURED")
	npc.active=false; npc.respawn_age=State.RESPAWN_SECONDS; npc.velocity=Vector2.ZERO
	world.round_stats.wrong_catches+=1
	_record(world,npc,"captured")
	_clear_line(world)
	world.angler.cast_cooldown=maxf(world.angler.cast_cooldown,1.2)
	world.angler.free_reel_speed=0.0; world.angler.hook_velocity=Vector2.ZERO
	world.notice="钓到的是另一条鱼 · 比赛继续，重新挂饵下钩"; world.notice_age=3.0
	world.play_feedback("splash")
	# Deliberately no finish(), match_over, winner, player hook count or score.

static func respawn(world: Node2D, delta: float) -> void:
	var ready: Array[Dictionary]=[]
	for npc: Dictionary in world.npc_fishes:
		if not npc.active and npc.behavior_state=="CAPTURED":
			npc.respawn_age=maxf(0.0,npc.respawn_age-delta)
			if npc.respawn_age<=0: ready.append(npc)
	for npc: Dictionary in ready:
		world.npc_fishes.erase(npc)
		if world.spawn_npc()<0:
			npc.respawn_age=0.5
			world.npc_fishes.append(npc)
