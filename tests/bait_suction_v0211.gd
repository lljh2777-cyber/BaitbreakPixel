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
	bait.active=true; bait.hook=has_hook; bait.pos=w.mouth()+Vector2(26,0); bait.home=bait.pos
	bait.angle=0.0; bait.tip_before=w._tip(0)
	for grain in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
	return w
func run() -> void:
	for power_value in [0.35,1.0]:
		for hz in [30,60,120]:
			var hook:=fresh("survival",true,power_value)
			var plain:=fresh("survival",false,power_value)
			var body_equal:=true; var grains_equal:=true; var particles_move:=false
			for frame in hz*2:
				hook.elapsed=float(frame)/hz; plain.elapsed=hook.elapsed
				var before: Array=hook.baits[0].grains.duplicate(true)
				hook._step_bait(0,1.0/hz,true,hook.mouth()); plain._step_bait(0,1.0/hz,true,plain.mouth())
				body_equal=body_equal and hook.baits[0].pos==plain.baits[0].pos and hook.baits[0].angle==plain.baits[0].angle
				grains_equal=grains_equal and hook.baits[0].grains==plain.baits[0].grains
				for i in before.size():
					if before[i].free and not before[i].eaten:
						particles_move=particles_move or Vector2(hook.baits[0].grains[i].pos).distance_to(hook.mouth())<Vector2(before[i].pos).distance_to(hook.mouth())
			var label:="power %.2f / %d Hz" % [power_value,hz]
			check(body_equal and hook.baits[0].pos==hook.baits[0].home,label+": no hook-only whole-cluster attraction")
			check(grains_equal,label+": identical detachment and pellet trajectories throughout suction")
			check(particles_move and hook.score>0 and hook.score==plain.score,label+": both foods reach the mouth and award identical points")
			hook.free(); plain.free()
	for has_hook in [true,false]:
		var sucked:=fresh("duel",has_hook); var idle:=fresh("duel",has_hook)
		var same_body:=true
		for frame in 90:
			sucked._step_bait(0,1.0/60,true,sucked.mouth()); idle._step_bait(0,1.0/60,false,idle.mouth())
			same_body=same_body and sucked.baits[0].pos==idle.baits[0].pos and sucked.baits[0].angle==idle.baits[0].angle and sucked.angler.hook_velocity==idle.angler.hook_velocity
		check(same_body,"duel hook=%s: suction cannot move the cluster or add rig acceleration" % has_hook)
		sucked.free(); idle.free()
	for multiplier in [0.0,1.0,2.0]:
		var w:=fresh("survival",false,1.0,multiplier)
		for grain in w.baits[0].grains: grain.eaten=true
		var grain: Dictionary=w.baits[0].grains[0]; grain.eaten=false; grain.free=true; grain.pos=w.mouth()+Vector2(24,0)
		var before: Vector2=grain.pos
		w._step_bait(0,1.0/60,true,w.mouth())
		check(absf(before.distance_to(grain.pos)-w.rule("pellet_speed")*multiplier/60)<0.0001,"shared suction multiplier %.1f controls loose pellet speed" % multiplier)
		before=grain.pos; w._step_bait(0,1.0/60,false,w.mouth())
		check(grain.pos==before,"releasing suction stops pellet attraction at multiplier %.1f" % multiplier)
		w.free()
	var w:=fresh(); var clone:=World.new()
	for frame in 40: w.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(clone.restore_snapshot(w.capture_snapshot()),"partly eaten bait restores with existing snapshot schema")
	for frame in 60:
		w.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
		clone.advance_tick({"aim":Vector2.RIGHT,"power":1.0,"suck":true},{})
	check(w.capture_snapshot()==clone.capture_snapshot(),"restored suction replays deterministically")
	w.free(); clone.free()
	for has_hook in [true,false]:
		w=fresh("survival",has_hook); w.hook_cooldown=0
		w.baits[0].pos=w.mouth()+Vector2(1,-1); w.baits[0].home=w.baits[0].pos
		w._step_bait(0,1.0/60,true,w.mouth())
		check(w.hooked==(w.HookState.MOUTH if has_hook else w.HookState.FREE),"mouth contact hook=%s keeps the correct bite result" % has_hook)
		w.free()
	print("BAIT_SUCTION_V0211 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
