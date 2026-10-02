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
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true
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
	check(w.rule("bite_range")==18 and w.rule("bite_intake")==4 and is_equal_approx(w.rule("bite_cooldown"),0.4),"default Bite tuning")
	var inside=food(w,0,0,Vector2(17.9,0)); var edge=food(w,0,1,Vector2(18,0)); var outside=food(w,0,2,Vector2(18.01,0))
	w._attempt_bite()
	check(inside.eaten and edge.eaten and not outside.eaten,"mouth-local range includes boundary and excludes outside")
	check(w.score==2 and w.satiety>50 and w.bite_cooldown>0 and w.bite_feedback_age>0,"Bite consumes through score/satiety and feedback path")
	var score:float=w.score; w._attempt_bite()
	check(w.score==score and not outside.eaten,"cooldown blocks immediate retry")

	# A restored/reoffered identity must never double award either intake action.
	inside.eaten=false; w.bite_cooldown=0
	var satiety:float=w.satiety
	w._attempt_bite()
	check(w.score==score and w.satiety==satiety,"same grain identity cannot award twice through Bite")
	inside.eaten=false; inside.pos=w.mouth()+Vector2(1,0)
	w.advance_tick({"suck":true},{})
	check(w.score==score and w.satiety==satiety,"Suck cannot re-award a grain already counted by Bite")
	w.free(); w=fresh()
	for i in 6: food(w,0,i,Vector2(i+1,0))
	w._attempt_bite()
	check(eaten(w)==4 and w.baits[0].grains[3].eaten and not w.baits[0].grains[4].eaten,"single bite takes four nearest grains")
	for tick in 25: w.advance_tick({}, {})
	check(w.bite_cooldown==0 and w.bite_feedback_age==0,"cooldown and neutral animation expire")
	w.advance_tick({"bite":true},{})
	check(eaten(w)==6,"new press can bite after cooldown")
	w.free(); w=fresh()
	w.advance_tick({"bite":true},{})
	check(w.score==0 and w.satiety==50 and w.bite_cooldown==0 and w.bite_feedback_age>0,"empty bite has neutral animation but no food reward or cooldown")
	food(w,0,0,Vector2(2,0)); w.advance_tick({"bite":true},{})
	check(w.score==1 and w.bite_cooldown>0,"empty attempt does not delay next nearby-food Bite")
	var cooldown:float=w.bite_cooldown
	w.match_paused=true; w.advance_tick({"bite":true},{})
	check(w.bite_cooldown==cooldown,"pause freezes Bite countdown")
	w.match_paused=false; w.reset_world()
	check(w.bite_cooldown==0 and w.bite_feedback_age==0,"restart clears Bite state")
	w.free(); w=fresh()
	for i in 5: food(w,0,i,Vector2(1+i*0.1,0))
	w.advance_tick({"bite":true,"suck":true},{})
	check(eaten(w)==4 and not w.feeding,"Bite wins over held Suck on the same tick")
	w.advance_tick({"suck":true},{})
	check(eaten(w)==5,"Suck remains available next tick")
	w.free(); w=fresh()
	w.rules.bite_intake=1.0
	# Exact ties must use stable bait identity, not world array ordering.
	w.baits[0].bait_id=20; w.baits[1].bait_id=10
	food(w,0,0,Vector2(5,0)); food(w,1,0,Vector2(5,0)); food(w,1,1,Vector2(5,0))
	w._attempt_bite()
	check(not w.baits[0].grains[0].eaten and w.baits[1].grains[0].eaten and not w.baits[1].grains[1].eaten,"ties resolve bait_id then grain array order")
	w.free(); w=fresh()
	var inactive=food(w,0,0,Vector2(1,0),false)
	w._attempt_bite()
	check(not inactive.eaten,"undeployed attached reserve food cannot be bitten")
	w.bite_cooldown=0; w.baits[0].active=true; w._attempt_bite()
	check(inactive.eaten,"active attached food can be bitten without suction peeling")
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
		w._attempt_bite()
		check(not grain.eaten and w.bite_cooldown==0,terminal+" rejects Bite")
		w.free()
	var idle=fresh(); var bite=fresh()
	idle.advance_tick({},{}); bite.advance_tick({"bite":true},{})
	check(idle.fish==bite.fish and idle.velocity==bite.velocity,"empty Bite adds no movement lunge")
	idle.free(); bite.free()
	input_checks()
	hook_checks()
	print("BITE | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
func input_checks() -> void:
	var pond=Pond.new(); pond._register_inputs()
	var found:=false
	for event in InputMap.action_get_events("bite"):
		if event is InputEventKey and event.physical_keycode==KEY_F: found=true
	check(found,"F is an independent Bite action")
	var adapter=InputAdapter.new(); var w=fresh()
	adapter.handle(key_event(),"fish",Vector2.ZERO)
	check(adapter.fish_command(w,w.mouth()).bite,"non-echo F down queues Bite")
	check(not adapter.fish_command(w,w.mouth()).bite,"held key cannot repeat consumed edge")
	adapter.handle(key_event(true,true),"fish",Vector2.ZERO)
	adapter.handle(key_event(false),"fish",Vector2.ZERO)
	check(not adapter.fish_command(w,w.mouth()).bite,"echo and release never queue Bite")
	adapter.handle(key_event(),"angler",Vector2.ZERO)
	check(not adapter.fish_command(w,w.mouth()).bite,"angler F never leaks fish Bite")
	adapter.handle(key_event(),"fish",Vector2.ZERO); adapter.reset()
	check(not adapter.fish_command(w,w.mouth()).bite,"reset discards queued Bite")
	adapter.handle(key_event(),"fish",Vector2.ZERO); adapter.suspend()
	check(not adapter.fish_command(w,w.mouth()).bite,"suspend discards queued Bite")
	Input.action_press("bite"); adapter.suspend()
	adapter.handle(key_event(),"fish",Vector2.ZERO)
	check(not adapter.fish_command(w,w.mouth()).bite and adapter.needs_neutral,"focus resume while F held waits for neutral")
	Input.action_release("bite"); adapter.fish_command(w,w.mouth())
	adapter.handle(key_event(),"fish",Vector2.ZERO)
	check(adapter.fish_command(w,w.mouth()).bite and not adapter.needs_neutral,"release then new F press recovers after suspend")
	pond.free(); w.free()
func hook_checks() -> void:
	var safe=fresh(); var danger=fresh()
	for w in [safe,danger]:
		var bait:Dictionary=w.baits[0]
		bait.active=true; bait.pos=w.mouth()+Vector2(40,0); bait.home=bait.pos; bait.angle=0; bait.tip_before=bait.pos+Vector2(2,1)
		food(w,0,0,Vector2(10,0))
	danger.baits[0].hook=true
	var safe_rng:int=safe.rng.state; var danger_rng:int=danger.rng.state
	for w in [safe,danger]: w.advance_tick({"bite":true},{})
	check(Observation.build(safe)==Observation.build(danger),"pre-contact safe/hooked food yields identical full fish observation")
	check(Public.capture(safe)==Public.capture(danger),"pre-contact safe/hooked food yields identical complete public packet")
	check(safe.score==danger.score and safe.satiety==danger.satiety and safe.bite_feedback_age==danger.bite_feedback_age,"safe/hooked food behaves equally before physical hook contact")
	check(safe.hooked==safe.HookState.FREE and danger.hooked==danger.HookState.FREE,"Bite adds no probabilistic hook activation")
	check(safe.rng.state==safe_rng and danger.rng.state==danger_rng,"pre-contact Bite consumes no hook RNG")
	for w in [safe,danger]:
		w.bite_cooldown=0
		var bait:Dictionary=w.baits[0]
		bait.pos=w.mouth()+Vector2(1,-1); bait.home=bait.pos; bait.tip_before=bait.pos+Vector2(2,1)
		food(w,0,1,Vector2(1,0))
		w.advance_tick({"bite":true},{})
	check(danger.hooked==danger.HookState.MOUTH and safe.hooked==safe.HookState.FREE,"real physical hook contact still enters mouth QTE")
	check(not danger.baits[0].grains[1].eaten and safe.baits[0].grains[1].eaten,"physical hook contact takes precedence over Bite reward")
	safe.free(); danger.free()
