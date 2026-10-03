extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const InputAdapter=preload("res://scripts/local_input.gd")
const Pond=preload("res://scripts/pond.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("BITE_PASS | ",label)
	else: failed+=1; push_error("BITE_FAIL | "+label)
func fresh() -> Node2D:
	var w=World.new()
	w.reset_world({"seed":8231,"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	w.fish=Vector2(250,200); w.fish_before=w.fish; w.aim=Vector2.RIGHT; w.satiety=50
	for bait in w.baits:
		bait.bait_type="cluster"
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true; grain.visual_kind="cluster"
	return w
func food(w: Node2D, slot: int, index: int, offset: Vector2, loose: bool=true) -> Dictionary:
	var grain: Dictionary=w.baits[slot].grains[index]
	grain.eaten=false; grain.free=loose; grain.pos=w.mouth()+offset; grain.points=1.0
	grain.offset=grain.pos-Vector2(w.baits[slot].pos)
	return grain
func eaten(w: Node2D) -> int:
	return w.counted.size()
func key_event(pressed: bool=true, echo: bool=false) -> InputEventKey:
	var event:=InputEventKey.new(); event.physical_keycode=KEY_F; event.pressed=pressed; event.echo=echo
	return event
func _initialize() -> void:
	var w=fresh()
	check(w.rule("bite_range")==14 and w.rule("bite_intake")==4 and is_equal_approx(w.rule("bite_cooldown"),0.4) and is_equal_approx(w.BITE_FEEDBACK_SECONDS,0.18),"automatic Bite uses 14px, four grains, 0.40s cooldown and 0.18s feedback")
	var cues:Array[String]=[]
	w.feedback_requested.connect(func(cue: String) -> void: cues.append(cue))
	var inside=food(w,0,0,Vector2(13.9,0)); var edge=food(w,0,1,Vector2(14,0)); var outside=food(w,0,2,Vector2(14.01,0))
	w.advance_tick({},{})
	check(inside.eaten and edge.eaten and not outside.eaten,"neutral tick automatically includes mouth-local boundary and excludes outside")
	check(w.score==2 and w.satiety>50 and is_equal_approx(w.bite_cooldown,0.4) and is_equal_approx(w.bite_feedback_age,0.18),"automatic intake uses shared score/satiety and starts exact feedback durations")
	check(cues==["bite"],"one accepted automatic intake emits exactly one Bite cue")
	var score:float=w.score; w._attempt_bite()
	check(w.score==score and not outside.eaten and cues==["bite"],"cooldown blocks immediate intake and duplicate feedback")

	# A restored/reoffered identity must never double award either intake action.
	inside.eaten=false; w.bite_cooldown=0; w.bite_feedback_age=0; cues.clear()
	var satiety:float=w.satiety
	w._attempt_bite()
	check(w.score==score and w.satiety==satiety,"same grain identity cannot award twice through automatic Bite")
	check(w.bite_cooldown==0 and w.bite_feedback_age==0 and cues.is_empty(),"already-counted food alone cannot advertise a fresh intake")
	outside.eaten=true # Isolate de-duplication from legitimate Suck intake of the boundary fixture.
	inside.eaten=false; inside.pos=w.mouth()+Vector2(1,0)
	w.advance_tick({"suck":true},{})
	check(w.score==score and w.satiety==satiety,"Suck cannot re-award a grain already counted by Bite")
	w.free()
	repeat_checks()
	quiet_checks()
	priority_checks()
	w=fresh(); w.rules.bite_intake=1.0
	# Exact ties must use stable bait identity, not world array ordering.
	w.baits[0].bait_id=20; w.baits[1].bait_id=10
	food(w,0,0,Vector2(5,0)); food(w,1,0,Vector2(5,0)); food(w,1,1,Vector2(5,0))
	w.advance_tick({},{})
	check(not w.baits[0].grains[0].eaten and w.baits[1].grains[0].eaten and not w.baits[1].grains[1].eaten,"automatic ties resolve bait_id then grain array order")
	w.free(); w=fresh()
	var inactive=food(w,0,0,Vector2(1,0),false)
	w.advance_tick({},{})
	check(not inactive.eaten and w.bite_feedback_age==0,"undeployed attached reserve food cannot trigger automatic intake")
	w.baits[0].active=true; w.advance_tick({},{})
	check(inactive.eaten,"active attached food is automatically bitten without suction peeling")
	w.free()
	for terminal in ["mouth","landing","caught","finished","paused","returning"]:
		w=fresh(); var grain=food(w,0,0,Vector2(1,0))
		match terminal:
			"mouth": w.hooked=w.HookState.MOUTH
			"landing": w.landing=true
			"caught": w.net_state="caught"
			"finished": w.match_over=true
			"paused": w.match_paused=true
			"returning": w.returning=true
		w.advance_tick({},{})
		check(not grain.eaten and w.bite_cooldown==0 and w.bite_feedback_age==0,terminal+" rejects automatic Bite on a real tick")
		w.free()
	var idle=fresh(); var bite=fresh()
	var far=food(bite,0,1,Vector2(40,0)); var far_position:Vector2=far.pos
	food(bite,0,0,Vector2(3,0))
	idle.advance_tick({},{}); bite.advance_tick({},{})
	check(bite.score==1 and idle.fish==bite.fish and idle.velocity==bite.velocity,"successful automatic Bite adds no movement lunge")
	check(far.pos==far_position and not far.eaten,"automatic Bite does not pull or teleport other food")
	idle.free(); bite.free()
	input_checks()
	hook_checks()
	print("BITE | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
func repeat_checks() -> void:
	var w=fresh(); var cues:Array[String]=[]
	w.feedback_requested.connect(func(cue: String) -> void: cues.append(cue))
	for i in 10: food(w,0,i,Vector2(i+1,0))
	w.advance_tick({},{})
	check(eaten(w)==4 and w.baits[0].grains[3].eaten and not w.baits[0].grains[4].eaten,"single neutral tick takes only four nearest grains")
	var last_intake_tick:int=w.simulation_tick
	var intervals:Array[int]=[]
	var rewards:Array[int]=[eaten(w)]
	for tick in 80:
		var before:int=eaten(w)
		w.advance_tick({},{})
		if eaten(w)!=before:
			intervals.append(w.simulation_tick-last_intake_tick)
			last_intake_tick=w.simulation_tick
			rewards.append(eaten(w))
	check(rewards==[4,8,10],"staying beside food repeats automatically until the remaining grains are consumed")
	check(intervals.size()==2 and intervals[0]==intervals[1] and intervals[0]*w.TICK_SECONDS>=0.4-0.000001 and intervals[0]*w.TICK_SECONDS<=0.4+w.TICK_SECONDS+0.000001,"repeat cadence is deterministic and respects the 0.40s cooldown")
	check(cues==["bite","bite","bite"],"repeat emits one Bite cue per successful intake only")
	check(w.bite_cooldown==0 and w.bite_feedback_age==0,"cooldown and animation expire once food is exhausted")
	w.free()
func quiet_checks() -> void:
	for offset in [Vector2.ZERO,Vector2(24,0),Vector2(80,0)]:
		var w=fresh(); var cues:Array[String]=[]
		w.feedback_requested.connect(func(cue: String) -> void: cues.append(cue))
		if offset!=Vector2.ZERO: food(w,0,0,offset)
		for tick in 70: w.advance_tick({},{})
		check(w.score==0 and w.satiety==50 and w.bite_cooldown==0 and w.bite_feedback_age==0 and cues.is_empty(),"empty/far neutral ticks never animate, sound, reward or cool down: "+str(offset))
		food(w,0,0,Vector2(2,0)); w.advance_tick({},{})
		check(w.score==1 and w.bite_cooldown>0 and cues==["bite"],"nearby food triggers immediately after quiet ticks: "+str(offset))
		w.free()
	var w=fresh(); food(w,0,0,Vector2(2,0)); w.advance_tick({},{})
	var cooldown:float=w.bite_cooldown; var feedback:float=w.bite_feedback_age
	food(w,0,1,Vector2(2,0)); w.match_paused=true
	for tick in 30: w.advance_tick({},{})
	check(w.score==1 and w.bite_cooldown==cooldown and w.bite_feedback_age==feedback,"pause freezes automatic intake and both feedback countdowns")
	w.match_paused=false; w.match_over=true
	for tick in 30: w.advance_tick({},{})
	check(w.score==1 and w.bite_cooldown==cooldown and w.bite_feedback_age==feedback,"ended match freezes automatic intake and both feedback countdowns")
	w.reset_world()
	check(w.bite_cooldown==0 and w.bite_feedback_age==0,"restart clears automatic Bite state")
	w.free()
func priority_checks() -> void:
	var w=fresh()
	for i in 5: food(w,0,i,Vector2(1+i*0.1,0))
	w.advance_tick({"suck":true},{})
	check(eaten(w)==4 and not w.feeding,"eligible automatic Bite wins over held Suck on the same tick")
	w.advance_tick({"suck":true},{})
	check(eaten(w)==5 and w.feeding and w.bite_cooldown>0,"Suck works during automatic Bite cooldown")
	w.free(); w=fresh()
	food(w,0,0,Vector2(24,0)); var before:Vector2=w.baits[0].grains[0].pos
	w.advance_tick({"suck":true},{})
	check(w.feeding and w.baits[0].grains[0].pos.distance_to(w.mouth())<before.distance_to(w.mouth()),"far food leaves held Suck active to draw food toward the mouth")
	check(w.bite_feedback_age==0 and w.bite_cooldown==0,"Suck outside Bite range creates no false Bite feedback")
	w.free(); w=fresh()
	for i in 5: food(w,0,i,Vector2(14.1+i*0.1,0))
	w.advance_tick({"suck":true},{})
	check(eaten(w)==4 and not w.feeding and w.bite_feedback_age>0,"Suck drawing food into mouth range lets automatic Bite take at most four in the same tick")
	w.free(); w=fresh()
	var approaching=food(w,0,0,Vector2(14.1,0))
	w.velocity=Vector2(120,0)
	w.advance_tick({"move":Vector2.RIGHT},{})
	check(approaching.eaten and w.score==1,"swimming into mouth range triggers automatic Bite in the same tick")
	w.free(); w=fresh()
	var retreating=food(w,0,0,Vector2(17.5,0)); w.velocity=Vector2(-300,0)
	w.advance_tick({"move":Vector2.LEFT,"suck":true},{})
	check(not retreating.eaten and w.feeding and w.bite_cooldown==0 and w.bite_feedback_age==0,"swimming away before arbitration retains Suck without a false automatic Bite")
	w.free(); w=fresh()
	var bait:Dictionary=w.baits[0]
	bait.active=true; bait.home=w.mouth()+Vector2(14.2,0); bait.suction_offset=Vector2(-0.4,0); bait.pos=bait.home+bait.suction_offset
	var attached=food(w,0,0,Vector2(17.8,0),false); attached.offset=Vector2.ZERO
	w.advance_tick({"suck":true},{})
	check(attached.eaten and w.score==1 and not w.feeding,"attached food at the suction/recoil boundary cannot starve automatic intake")
	w.free()
func input_checks() -> void:
	var pond=Pond.new(); pond._register_inputs()
	check(not InputMap.has_action("bite"),"no Bite input action or F binding is registered")
	var adapter=InputAdapter.new(); var w=fresh()
	for event in [key_event(),key_event(true,true),key_event(false)]:
		adapter.handle(event,"fish",Vector2.ZERO)
		check(not adapter.fish_command(w,w.mouth()).has("bite"),"F press/echo/release cannot produce a Bite command")
	adapter.handle(key_event(),"angler",Vector2.ZERO)
	check(not adapter.fish_command(w,w.mouth()).has("bite"),"angler F cannot leak a fish Bite flag")
	adapter.reset(); adapter.suspend(); adapter.handle(key_event(),"fish",Vector2.ZERO)
	var command:Dictionary=adapter.fish_command(w,w.mouth())
	check(not command.has("bite") and not adapter.needs_neutral,"F is irrelevant to fish focus-resume neutral gating")
	food(w,0,0,Vector2(1,0)); w.advance_tick(command,{})
	check(w.score==1,"normal no-Bite local input still triggers automatic mouth intake")
	pond.free(); w.free()
func hook_checks() -> void:
	var safe=fresh(); var danger=fresh()
	for w in [safe,danger]:
		var bait:Dictionary=w.baits[0]
		bait.active=true; bait.pos=w.mouth()+Vector2(40,0); bait.home=bait.pos; bait.angle=0; bait.tip_before=bait.pos+Vector2(2,1)
		food(w,0,0,Vector2(10,0))
	danger.baits[0].hook=true
	var safe_rng:int=safe.rng.state; var danger_rng:int=danger.rng.state
	for w in [safe,danger]: w.advance_tick({},{})
	check(Observation.build(safe)==Observation.build(danger),"pre-contact safe/hooked food yields identical full fish observation")
	check(Public.capture(safe)==Public.capture(danger),"pre-contact safe/hooked food yields identical complete public packet")
	check(safe.score==danger.score and safe.satiety==danger.satiety and safe.bite_feedback_age==danger.bite_feedback_age,"safe/hooked automatic intake behaves equally before physical contact")
	check(safe.hooked==safe.HookState.FREE and danger.hooked==danger.HookState.FREE,"automatic Bite adds no probabilistic hook activation")
	check(safe.rng.state==safe_rng and danger.rng.state==danger_rng,"pre-contact automatic Bite consumes no hook RNG")
	for w in [safe,danger]:
		w.bite_cooldown=0; w.bite_feedback_age=0
		var bait:Dictionary=w.baits[0]
		bait.pos=w.mouth()+Vector2(1,-1); bait.home=bait.pos; bait.tip_before=bait.pos+Vector2(2,1)
		food(w,0,1,Vector2(1,0))
		w.advance_tick({},{})
	check(danger.hooked==danger.HookState.MOUTH and safe.hooked==safe.HookState.FREE,"real physical hook contact still enters mouth QTE without a Bite key")
	check(not danger.baits[0].grains[1].eaten and safe.baits[0].grains[1].eaten,"physical hook contact takes precedence over automatic intake reward")
	check(danger.bite_feedback_age==0 and danger.bite_cooldown==0,"physical contact does not advertise successful automatic intake")
	safe.free(); danger.free()
	var w=fresh(); var earlier_food=food(w,0,0,Vector2(1,0))
	var later_bait:Dictionary=w.baits[1]
	later_bait.active=true; later_bait.hook=true; later_bait.pos=w.mouth()+Vector2(1,-1); later_bait.home=later_bait.pos
	later_bait.angle=0; later_bait.tip_before=later_bait.pos+Vector2(2,1)
	w.advance_tick({"suck":true},{})
	check(w.hooked==w.HookState.MOUTH and not earlier_food.eaten and w.score==0 and w.bite_feedback_age==0,"later-bait physical contact cancels earlier-bait deferred Suck and automatic intake")
	w.free()
