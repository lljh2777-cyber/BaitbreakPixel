extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Profile=preload("res://scripts/food_profile.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("FEEDING_BALANCE_FAIL | "+label)
func fixture(kind: String) -> Node2D:
	var w:=World.new(); w.reset_world({"seed":200,"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	w.fish=Vector2(250,200); w.fish_before=w.fish; w.aim=Vector2.RIGHT; w.satiety=20
	for bait in w.baits:
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true
	var bait: Dictionary=w._make_bait(0,100,kind)
	bait.bait_id=w.baits[0].bait_id; bait.hook=false; bait.tackle=false; bait.active=true; bait.pos=w.mouth()+Vector2(8,0); bait.home=bait.pos; bait.angle=0
	w.baits[0]=bait
	for i in bait.grains.size():
		var grain: Dictionary=bait.grains[i]
		grain.offset=Vector2(8.0+float(i)*0.1,0); grain.pos=w.mouth()+grain.offset; grain.free=true; grain.points=1.0
	return w
func _initialize() -> void:
	for kind in Profile.TYPES:
		var w:=fixture(kind)
		w.advance_tick({}, {})
		var expected: int={"cluster":4,"worm":6,"chunk":8}[kind]
		check(w.counted.size()==expected,"whole-grain profile Bite capacity "+kind)
		check(w.score==expected,"unchanged score per grain "+kind)
		check(is_equal_approx(w.satiety,20+expected*w.rule("satiety_food_value")*Profile.get_profile(kind).satiety_scale),"independent satiety scale "+kind)
		check(w.round_stats.food_by_type[kind]==expected and w.round_stats.bite_intake_by_type[kind]==expected and w.round_stats.suck_intake_by_type[kind]==0,"typed intake conserves totals "+kind)
		check(w.round_stats.bite_attempts==1 and w.round_stats.bite_successes==1,"one automatic event, no button attempt fiction")
		var before: Dictionary=w.round_stats.duplicate(true)
		w._consume_grain(w.baits[0].grains[0],false,"bite")
		check(w.round_stats==before,"counted grain cannot duplicate intake stats")
		var snapshot: Dictionary=w.capture_snapshot(); var replay:=World.new(); replay.reset_world()
		check(replay.restore_snapshot(snapshot),"schema15 tuned profile and nested stats restore")
		for tick in 40: w.advance_tick({},{}); replay.advance_tick({},{})
		check(var_to_bytes(w.capture_snapshot())==var_to_bytes(replay.capture_snapshot()),"whole-grain budget has no unsnapshotted residue")
		var public:=Public.capture(w)
		check(Public.valid(replay,public) and not public.state.round_stats.has("food_by_type") and not public.state.round_stats.has("bite_attempts"),"new metrics remain authority-only")
		var bad: Dictionary=w.capture_snapshot(); bad.state.round_stats.food_by_type[kind]+=1.0
		check(not replay.restore_snapshot(bad),"nested intake conservation enforced")
		bad=w.capture_snapshot(); bad.state.round_stats.food_by_type.secret=1.0
		check(not replay.restore_snapshot(bad),"unexpected nested stats rejected")
		bad=w.capture_snapshot(); bad.state.round_stats.food_by_type[kind]=NAN
		check(not replay.restore_snapshot(bad),"nonfinite totals rejected")
		bad=w.capture_snapshot(); bad.state.round_stats.last_suck_success_tick=bad.state.simulation_tick+1
		check(not replay.restore_snapshot(bad),"future suction accounting ticks rejected")
		w.free(); replay.free()
	mixed_budget()
	suction_profiles()
	distance_gradient()
	print("FEEDING_BALANCE | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
func mixed_budget() -> void:
	var w:=fixture("cluster")
	for i in w.baits[0].grains.size():
		w.baits[0].grains[i].visual_kind="worm" if i<3 else "cluster"
	w.advance_tick({}, {})
	check(w.counted.size()==5 and w.round_stats.food_by_type.worm==3.0 and w.round_stats.food_by_type.cluster==2.0,"mixed old loose grains spend their own deterministic budget")
	w.bite_cooldown=0; w.rules.bite_intake=0.1
	var before: float=w.score
	check(not w._attempt_bite() and w.score==before and w.bite_cooldown==0,"insufficient budget neither awards fractional grain nor starts cooldown")
	w.free()
func suction_profiles() -> void:
	var peel: Array[float]=[]; var release: Array[float]=[]; var pull: Array[float]=[]
	for kind in Profile.TYPES:
		var w:=fixture(kind); var bait: Dictionary=w.baits[0]
		bait.pos=w.mouth()+Vector2(25,0); bait.home=bait.pos; w.power=0.65
		for grain in bait.grains:
			grain.free=false; grain.offset=Vector2.ZERO; grain.pos=bait.pos
		w._step_bait(0,1.0/60.0,true,w.mouth())
		peel.append(bait.grains[0].progress); release.append(bait.budget); pull.append(Vector2(bait.suction_offset).length())
		# Test converged body response rather than first acceleration-limited tick.
		for tick in 60: w._step_bait(0,1.0/60.0,true,w.mouth())
		pull[-1]=Vector2(bait.suction_offset).length()
		w.free()
	print("PROFILE_PHYSICS ",peel," ",release," ",pull)
	check(peel[0]>peel[1] and peel[1]>peel[2],"suction efficiency changes actual peel physics")
	check(release[0]>release[1] and release[1]>release[2],"fragmentation changes real release budget")
	check(pull[0]>pull[1] and pull[1]>pull[2],"suction changes actual whole-bait movement")

func distance_gradient() -> void:
	var w:=fixture("cluster")
	var reach: float=w.rule("suction_range")
	check(w.rule("bite_range")==10.0,"smaller automatic mouth radius defaults to 10px")
	check(is_equal_approx(w.strength(w.mouth()),1.0) and is_equal_approx(w.strength(w.mouth()+Vector2(reach*0.5,0)),0.5),"smooth field mouth and midpoint anchors")
	check(w.strength(w.mouth()+Vector2(reach,0))==0 and w.strength(w.mouth()+Vector2(reach+0.01,0))==0,"field joins outside at zero")
	check(w.strength(w.mouth()+Vector2(reach*0.99,0))>0,"weak far interior still exerts pull")
	var previous:=1.0
	for i in range(1,101):
		var value: float=w.strength(w.mouth()+Vector2(reach*i/100.0,0))
		check(value<previous,"continuous strictly decreasing longitudinal field %d"%i)
		previous=value
	w.free()
	for kind in Profile.TYPES:
		for power_value in [0.3,0.65,1.0]:
			var moves: Array[float]=[]; var peels: Array[float]=[]; var bodies: Array[float]=[]
			for fraction in [0.3,0.5,0.9]:
				w=fixture(kind); w.power=power_value
				var bait: Dictionary=w.baits[0]
				bait.active=false
				var grain: Dictionary=bait.grains[0]
				for other in bait.grains: other.eaten=true
				grain.eaten=false; grain.pos=w.mouth()+Vector2(reach*fraction,0)
				var before: Vector2=grain.pos
				var pull: float=w.strength(before)
				w._step_bait(0,1.0/60.0,true,w.mouth())
				moves.append(before.distance_to(grain.pos))
				check(absf(moves[-1]-pull*w.rule("pellet_speed")*w.Suction.pellet_gain(power_value)*Profile.get_profile(kind).suction_efficiency/60.0)<0.00004,"loose transport uses field exactly once")
				bait.active=true; bait.pos=before; bait.home=before; bait.suction_offset=Vector2.ZERO
				grain.free=false; grain.offset=Vector2.ZERO; grain.layer=0; grain.progress=0
				w.rules.hook_suction=0
				w._step_bait(0,1.0/60.0,true,w.mouth())
				peels.append(grain.progress)
				w.rules.hook_suction=1; bait.pos=before; bait.suction_offset=Vector2.ZERO
				w._step_bait_suction(bait,10.0,true)
				bodies.append(Vector2(bait.suction_offset).length())
				w.free()
			check(moves[0]>moves[1] and moves[1]>moves[2] and moves[2]>0,"near/mid/far transport "+kind+str(power_value))
			check(peels[0]>peels[1] and peels[1]>peels[2] and peels[2]>0,"near/mid/far peel "+kind+str(power_value))
			check(bodies[0]>bodies[1] and bodies[1]>bodies[2] and bodies[2]>0,"near/mid/far body target "+kind+str(power_value))
	# A weakly pulled loose grain crosses the new Bite boundary during cooldown,
	# then reaches mouth intake without stalling or counting twice.
	w=fixture("chunk"); w.power=0.3; w.bite_cooldown=0.4
	var bait: Dictionary=w.baits[0]; bait.active=false
	for other in bait.grains: other.eaten=true
	var grain: Dictionary=bait.grains[0]; grain.eaten=false; grain.pos=w.mouth()+Vector2(14.1,0)
	for tick in 120: w.advance_tick({"suck":true,"aim":Vector2.RIGHT,"power":0.3},{})
	check(grain.eaten and w.counted.size()==1 and w.score==1,"cooldown handoff has no feeding stall or double intake")
	check(w.round_stats.bite_intake_by_type.chunk+w.round_stats.suck_intake_by_type.chunk==1,"handoff conserves attribution")
	w.free()
