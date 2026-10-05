extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Shore=preload("res://scripts/shore_view.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
const InputAdapter=preload("res://scripts/local_input.gd")
const Pond=preload("res://scripts/pond.gd")
const View=preload("res://scripts/pond_view.gd")
const Observation=preload("res://scripts/fish_observation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PHASE15_PASS | ",label)
	else: failed+=1; push_error("PHASE15_FAIL | "+label)
func tick(w: Node2D, command: Dictionary, frames: int=60, network: bool=false) -> void:
	for n in frames:
		var wire: Dictionary=Protocol.decode(Protocol.encode(command))
		w.advance_tick({},Protocol.input("angler",wire,w.map_context) if network else command)
func fresh(seed_value: int) -> Node2D:
	var w=World.new()
	w.reset_world({"ruleset":"duel","seed":seed_value,"rules":{"water_strength":0,"hunger_enabled":false,"timer_enabled":false}})
	w.fish=Vector2(900,300); w.fish_before=w.fish
	return w
func _initialize() -> void:
	# Real action mapping -> LocalInput -> command sanitizer -> authority.
	var adapter=InputAdapter.new()
	var pond=Pond.new(); pond._register_inputs()
	var local=fresh(2649)
	for pair in [["up","reel",KEY_W],["down","release",KEY_S],["slow","deploy",KEY_Q]]:
		var found:=false
		for event in InputMap.action_get_events(pair[0]):
			if event is InputEventKey and event.physical_keycode==pair[2]: found=true
		check(found,"physical key mapping "+pair[1])
		Input.action_press(pair[0])
		var command: Dictionary=adapter.angler_command(local,Vector2(232,180))
		check(command[pair[1]],"local adapter emits "+pair[1])
		Input.action_release(pair[0])
	var right_button:=InputEventMouseButton.new()
	right_button.button_index=MOUSE_BUTTON_RIGHT; right_button.pressed=true
	Input.parse_input_event(right_button); Input.flush_buffered_events()
	Input.action_press("right")
	var boosted: Dictionary=adapter.angler_command(local,Vector2(232,180))
	check(boosted.dash and boosted.walk==1.0,"physical right mouse plus D emits held boost")
	check(not boosted.drag and boosted.net_events.is_empty(),"right mouse boost does not select net points")
	Input.action_press("left")
	check(adapter.angler_command(local,Vector2.ZERO).walk==0,"A and D cancel even while right mouse held")
	Input.action_release("left"); Input.action_release("right")
	check(adapter.fish_command(local,Vector2.ZERO).dash,"shared right mouse mapping still boosts fish")
	right_button.pressed=false; Input.parse_input_event(right_button); Input.flush_buffered_events()
	check(not adapter.angler_command(local,Vector2.ZERO).dash,"mouse release immediately clears rod boost")
	pond.free(); local.free()
	for seed_value in [42,731,2649]:
		for network in [false,true]:
			var w=fresh(seed_value)
			var label="seed%d %s " % [seed_value,"wire" if network else "local"]
			check(not w.baits[0].active and not w.baits[2].active and not w.angler.casting,label+"physical undeployed")
			check(Shore.rig_index(w)==-1,label+"ambient hook is never the displayed rig")
			tick(w,{"reel":true})
			check(w.angler.free_line_length==132 and w.angler.reel_phase==0 and w.angler.reel_hand_amount==0,label+"undeployed W has no fake motion")
			tick(w,{"deploy":true},1,network)
			check(w.angler.casting and not w.baits[0].active,label+"Q begins actual cast")
			tick(w,{},60,network)
			check(w.baits[0].active and not w.angler.casting and Shore.rig_index(w)==0,label+"cast activates same physical/visual tackle regardless of hook truth")
			var start:float=w.angler.free_line_length
			var position:Vector2=w.baits[0].pos
			tick(w,{"reel":true},60,network)
			check(w.angler.free_line_length<start-30 and Vector2(w.baits[0].pos).y<position.y-20,label+"W1s reels real length and raises bait")
			check(w.angler.feedback_reel_speed(w)<0 and w.angler.reel_hand_mode==-1 and w.angler.reel_phase>0,label+"reeling drives phase/hand")
			start=w.angler.free_line_length; position=w.baits[0].pos
			tick(w,{"release":true},60,network)
			check(w.angler.free_line_length>start+50 and Vector2(w.baits[0].pos).y>position.y+20,label+"S1s pays out real length and lowers bait")
			check(w.angler.feedback_reel_speed(w)>0 and w.angler.reel_hand_mode==1 and w.angler.release_phase>0,label+"release drives distinct phase/hand")
			tick(w,{},60,network)
			start=w.angler.free_line_length
			var reel:float=w.angler.reel_phase; var release:float=w.angler.release_phase
			tick(w,{},60,network)
			check(w.angler.free_line_length==start and w.angler.reel_phase==reel and w.angler.release_phase==release and w.angler.reel_hand_amount==0,label+"idle fully brakes physical/visual motion")
			tick(w,{"reel":true,"release":true},60,network)
			check(w.angler.spool==0 and w.angler.free_line_length==start,label+"opposing keys cancel")
			var x:float=w.angler.x
			tick(w,{"walk":1.0},60,network)
			check(is_equal_approx(w.angler.x-x,90),label+"D1s = 90 (+25 percent)")
			tick(w,{"walk":-1.0},60,network)
			check(is_equal_approx(w.angler.x,x),label+"A/D symmetric")
			w.angler.x=18; tick(w,{"walk":-1.0},1,network)
			check(w.angler.x==18,label+"left bound")
			w.angler.x=w.map_context.size.x-52; tick(w,{"walk":1.0},1,network)
			check(w.angler.x==w.map_context.size.x-52,label+"right bound")
			var p=Presentation.new()
			check(p.accept(w.capture_snapshot(),1.0),label+"schema13 snapshot accepted")
			check(Shore.rig_index(p.sample(1.0))==0 and p.world.angler.free_line_length==w.angler.free_line_length,label+"remote render retains physical ownership/spool")
			p.dispose()
			# Keep boost timing independent of the deployed-bait/ownership fixture.
			w.reset_world({"ruleset":"duel","seed":seed_value,"rules":{"water_strength":0,"hunger_enabled":false,"timer_enabled":false}})
			x=w.angler.x
			tick(w,{"walk":1.0,"dash":true},60,network)
			check(is_equal_approx(w.angler.x-x,180),label+"D plus right mouse moves 180 px in one second")
			tick(w,{"walk":-1.0,"dash":true},60,network)
			check(is_equal_approx(w.angler.x,x),label+"boost is symmetric in both directions")
			tick(w,{"dash":true},10,network)
			check(is_equal_approx(w.angler.x,x),label+"right mouse alone never moves the rod")
			tick(w,{"walk":1.0,"dash":false},60,network)
			check(is_equal_approx(w.angler.x-x,90),label+"releasing boost restores ordinary speed")
			for invalid in [1,"true",2.0]:
				var before:float=w.angler.x
				tick(w,{"walk":1.0,"dash":invalid},1,network)
				check(is_equal_approx(w.angler.x-before,1.5),label+"non-boolean boost rejected "+str(invalid))
			var stopped:float=w.angler.x
			tick(w,Protocol.neutral("angler",w),10,network)
			check(w.angler.x==stopped,label+"neutral input stops movement and boost")
			w.angler.x=18; tick(w,{"walk":-1.0,"dash":true},1,network)
			check(w.angler.x==18,label+"boost left bound")
			w.angler.x=w.map_context.size.x-52; tick(w,{"walk":1.0,"dash":true},1,network)
			check(w.angler.x==w.map_context.size.x-52,label+"boost right bound")
			w.reset_world({"ruleset":"duel","seed":seed_value})
			check(Shore.rig_index(w)==-1 and w.angler.reel_phase==0 and w.angler.release_phase==0 and w.angler.reel_hand_amount==0,label+"restart fully undeployed")
			w.free()
	var w=fresh(2649); tick(w,{"deploy":true},1); tick(w,{},60)
	w.angler.free_line_length=w.rule("line_free_max"); w.angler.free_reel_speed=90
	w.angler.step_tackle_feedback(w,1.0/60)
	check(w.angler.feedback_reel_speed(w)==0 and w.angler.release_phase==0,"physical maximum stops release animation")
	w.angler.free_line_length=45; w.angler.free_reel_speed=-36
	check(w.angler.feedback_reel_speed(w)==0,"physical minimum stops reel animation")
	w.angler.free_line_length=132; w.angler.free_reel_speed=0; w.angler.spool=-1
	w.hooked=w.HookState.MOUTH
	check(w.angler.feedback_reel_speed(w)==0,"mouth QTE blocks fake reel feedback")
	w.landing=true; w.hooked=w.HookState.HOOKED; w.reel_speed=-36
	check(w.angler.feedback_reel_speed(w)==0,"landing blocks fake feedback")
	w.landing=false; w.net_state="caught"
	check(w.angler.feedback_reel_speed(w)==0,"caught blocks fake feedback")
	w.net_state="wait"
	for latched_value in [false,true]:
		w.latched=latched_value; w.rope_length=w.rule("line_max"); w.fish_line_length=w.rule("line_max"); w.reel_speed=90
		check(w.angler.feedback_reel_speed(w)==0,"hooked upper line cap suppresses payout: latched=%s" % latched_value)
		w.rope_length=0; w.fish_line_length=0; w.reel_speed=-36
		check(w.angler.feedback_reel_speed(w)==0,"hooked lower line cap suppresses reel: latched=%s" % latched_value)
	var fixed_x:float=w.angler.x
	w.landing=true; w.angler.update(w,1.0,{"walk":1.0,"dash":true})
	check(w.angler.x==fixed_x,"boost cannot bypass landing movement lock")
	w.landing=false; w.net_state="caught"; w.angler.update(w,1.0,{"walk":1.0,"dash":true})
	check(w.angler.x==fixed_x,"boost cannot bypass captured movement lock")
	w.net_state="wait"
	w.rules.angler_speed=120.0; tick(w,{"walk":1.0,"dash":true},30)
	check(is_equal_approx(w.angler.x-fixed_x,120),"boost respects configured base movement speed")
	var previous:float=-1
	for value in [-10.0,0.0,5.0,20.0,50.0,100.0,110.0]:
		var width:float=View.satiety_bar_width(value)
		check(width>=previous and width>=0 and width<=70,"satiety width bounded/monotonic %s" % value)
		previous=width
	w.satiety=37.5
	check(Observation.build(w).self.satiety==37.5,"HUD reads permitted self satiety")
	w.free()
	print("PHASE15 | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
