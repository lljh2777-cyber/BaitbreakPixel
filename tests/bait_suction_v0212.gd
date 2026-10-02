extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("BAIT_SUCTION_PASS | ",title)
	else: failed+=1; push_error("BAIT_SUCTION_FAIL | "+title)
func fresh(mode: String="survival", has_hook: bool=true, power_value: float=1.0, multiplier: float=1.0) -> Node2D:
	var w:=World.new()
	w.reset_world({"ruleset":mode,"seed":42,"rules":{"water_strength":0,"timer_enabled":false,"hook_suction":multiplier}})
	w.fish=Vector2(700,210); w.aim=Vector2.RIGHT; w.power=power_value; w.hook_cooldown=1000
	w.angler.x=650; w.angler.previous_anchor=w.angler.anchor(); w.angler.free_line_length=360
	for bait in w.baits: bait.active=false
	var bait: Dictionary=w.baits[0]
	# These assertions pin the legacy Cluster response, not a randomly assigned P2.3 profile.
	bait.bait_type="cluster"
	var baseline: Dictionary=w._make_bait(0,0,"cluster")
	for i in bait.grains.size():
		bait.grains[i].visual_kind="cluster"; bait.grains[i].offset=baseline.grains[i].offset
	bait.active=true; bait.hook=has_hook; bait.pos=w.mouth()+Vector2(26,0); bait.home=bait.pos
	bait.angle=0.0; bait.tip_before=w._tip(0)
	for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
	return w
func run() -> void:
	for power_value in [0.35,1.0]:
		for hz in [30,60,120]:
			var hook:=fresh("survival",true,power_value)
			var plain:=fresh("survival",false,power_value)
			var body_equal:=true; var grains_equal:=true; var particles_move:=false; var max_shift:=0.0
			for frame in hz*2:
				hook.elapsed=float(frame)/hz; plain.elapsed=hook.elapsed
				var before: Array=hook.baits[0].grains.duplicate(true)
				hook._step_bait(0,1.0/hz,true,hook.mouth()); plain._step_bait(0,1.0/hz,true,plain.mouth())
				body_equal=body_equal and hook.baits[0].pos==plain.baits[0].pos and hook.baits[0].angle==plain.baits[0].angle
				max_shift=maxf(max_shift,Vector2(hook.baits[0].pos).distance_to(hook.baits[0].home))
				grains_equal=grains_equal and hook.baits[0].grains==plain.baits[0].grains
				for i in before.size():
					if before[i].free and not before[i].eaten:
						particles_move=particles_move or Vector2(hook.baits[0].grains[i].pos).distance_to(hook.mouth())<Vector2(before[i].pos).distance_to(hook.mouth())
			var label:="power %.2f / %d Hz" % [power_value,hz]
			check(body_equal and max_shift>2,label+": both whole clusters visibly move toward the mouth at matching positions")
			check(grains_equal,label+": identical detachment and pellet trajectories throughout suction")
			check(particles_move and hook.score>0 and hook.score==plain.score,label+": both foods reach the mouth and award identical points")
			hook.free(); plain.free()
	var weak:=fresh("survival",false,0.35); var strong:=fresh("survival",false,1.0)
	for frame in 18:
		weak._step_bait(0,1.0/60,true,weak.mouth()); strong._step_bait(0,1.0/60,true,strong.mouth())
	check(Vector2(strong.baits[0].suction_offset).length()>Vector2(weak.baits[0].suction_offset).length()+2,"higher suction power visibly moves the whole bait farther")
	weak.free(); strong.free()
	for has_hook in [true,false]:
		var sucked:=fresh("duel",has_hook); var idle:=fresh("duel",has_hook)
		var same_base:=true; var moved:=false
		for frame in 90:
			sucked._step_bait(0,1.0/60,true,sucked.mouth()); idle._step_bait(0,1.0/60,false,idle.mouth())
			var base: Vector2=Vector2(sucked.baits[0].pos)-Vector2(sucked.baits[0].suction_offset)
			same_base=same_base and base.distance_to(idle.baits[0].pos)<0.03 and sucked.angler.hook_velocity.distance_to(idle.angler.hook_velocity)<0.03
			moved=moved or Vector2(sucked.baits[0].suction_offset).length()>2
		check(moved,"duel hook=%s: the whole bait actually moves under suction" % has_hook)
		check(same_base,"duel hook=%s: shared attraction retains passive rig motion without double accumulation" % has_hook)
		sucked.free(); idle.free()
	for multiplier in [0.0,1.0,2.0]:
		var w:=fresh("survival",false,1.0,multiplier)
		var base: Vector2=w.baits[0].pos
		var expected:=minf(base.distance_to(w.mouth()),w.strength(base)*26*multiplier)
		for frame in 50: w._step_bait(0,1.0/60,true,w.mouth())
		check(absf(base.distance_to(w.baits[0].pos)-expected)<0.0001,"shared multiplier %.1f controls whole-cluster displacement" % multiplier)
		for frame in 60: w._step_bait(0,1.0/60,false,w.mouth())
		check(Vector2(w.baits[0].pos).distance_to(base)<0.0001,"releasing suction smoothly restores the cluster at multiplier %.1f" % multiplier)
		for grain in w.baits[0].grains: grain.eaten=true
		var grain: Dictionary=w.baits[0].grains[0]; grain.eaten=false; grain.free=true; grain.pos=w.mouth()+Vector2(24,0)
		var before: Vector2=grain.pos
		w._step_bait(0,1.0/60,true,w.mouth())
		check(absf(before.distance_to(grain.pos)-w.strength(before)*w.rule("pellet_speed")/60)<0.0001,"whole-cluster multiplier does not alter detached pellet speed")
		w.free()
	var outside:=fresh(); outside.aim=Vector2.LEFT
	outside._step_bait(0,1.0/60,true,outside.mouth())
	check(outside.baits[0].suction_offset==Vector2.ZERO,"food outside the suction cone cannot be pulled")
	outside.free()
	var w:=fresh(); var clone:=World.new()
	for frame in 40: w.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(clone.restore_snapshot(w.capture_snapshot()),"partly displaced bait restores with its suction offset")
	for frame in 60:
		w.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
		clone.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(w.capture_snapshot()==clone.capture_snapshot(),"restored suction replays deterministically")
	var old: Dictionary=w.capture_snapshot(); old.schema=10
	check(not clone.restore_snapshot(old),"previous schema cannot silently discard whole-cluster motion")
	w.free(); clone.free()
	for has_hook in [true,false]:
		w=fresh("survival",has_hook); w.hook_cooldown=0
		w.baits[0].pos=w.mouth()+Vector2(1,-1); w.baits[0].home=w.baits[0].pos
		w._step_bait(0,1.0/60,true,w.mouth())
		check(w.hooked==(w.HookState.MOUTH if has_hook else w.HookState.FREE),"mouth contact hook=%s keeps the correct bite result" % has_hook)
		w.free()
	# The gradient requires closer approach for real hook contact; 26px is tested separately.
	for has_hook in [true,false]:
		w=fresh("survival",has_hook); w.hook_cooldown=0
		w.baits[0].pos=w.mouth()+Vector2(20,0); w.baits[0].home=w.baits[0].pos; w.baits[0].tip_before=w._tip(0)
		for frame in 60: w.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
		check(w.hooked!=(w.HookState.FREE) if has_hook else w.hooked==w.HookState.FREE,"pulling a whole cluster to the mouth hook=%s keeps the real bite result" % has_hook)
		w.free()
	w=fresh("duel")
	w.baits[0].suction_offset=Vector2(-5,0); w.baits[0].pos+=Vector2(-5,0)
	var cast: bool=w.angler.cast(w,Vector2(740,250))
	w.angler.update(w,0.8,{})
	check(cast and w.baits[0].suction_offset==Vector2.ZERO and w.baits[0].pos==w.angler.cast_to,"recasting clears the previous suction displacement")
	w.free()
	print("BAIT_SUCTION_V0212 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
