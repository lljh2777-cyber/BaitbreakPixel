extends SceneTree

const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("ANGLER_PASS | ",message)
	else: failed+=1; push_error("ANGLER_FAIL | "+message)

func fresh() -> void:
	game.reset(true,"angler")
	game.set_escape_timing(0.5,0.4,3.0)
	game.fish_brain.reset(2719)
	game.water_strength=0
	game.fish=Vector2(600,100)
	game.set_process(false)
	game.set_physics_process(false)

func tick(seconds: float, command: Dictionary={}, rate: int=60) -> void:
	for frame in ceili(seconds*rate):
		var input: Dictionary=command.duplicate(true)
		input.net_events=game.local_input.net_events.duplicate(true)
		game.local_input.net_events.clear()
		game.simulate(1.0/rate,{"aim":game.aim,"power":game.power},input)

func attach(point: Vector2=Vector2(232,160)) -> void:
	game.fish=point
	game.baits[0].active=true
	game._enter_hook(0)
	game._attach_hook()

func run() -> void:
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="test"
	game.save_path="user://angler-v010-test.cfg"
	test_rig()
	test_net()
	test_timing()
	test_rounds()
	print("ANGLER_V010_TESTS | passed=",passed," | failed=",failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func test_rig() -> void:
	fresh()
	tick(0.02,{"deploy":true})
	check(game.angler.casting and not game.baits[0].active,"Q lowers bait with a visible deployment interval")
	tick(0.8)
	check(game.baits[0].active and absf(game.baits[0].pos.x-game.angler.anchor().x)<1,"rig enters below the angler")
	var before: Vector2=game.baits[0].pos
	tick(0.75,{"walk":1})
	var end: Vector2=game.baits[0].pos
	check(end.x>before.x+2 and end.x<game.angler.anchor().x-10,"walking transfers force while hook lags behind the rod")
	var speed: float=game.angler.hook_velocity.x
	tick(0.3)
	check(speed>1 and game.baits[0].pos.x>end.x+2,"hook retains momentum after angler stops")
	var overshoot:=false
	for frame in 300:
		tick(1.0/60)
		if game.baits[0].pos.x>game.angler.anchor().x+2: overshoot=true
	check(overshoot,"tether swings past rest position instead of easing directly to a stop")
	tick(12)
	check(absf(game.baits[0].pos.x-game.angler.anchor().x)<2 and game.angler.hook_velocity.length()<3,"water damping settles inertial swing")
	var length_before: float=game.angler.free_line_length
	tick(0.6,{"reel":true})
	check(game.angler.free_line_length<length_before-10,"W reels a free hook upward")
	var short_length: float=game.angler.free_line_length
	tick(0.9,{"release":true})
	check(game.angler.free_line_length>short_length+25,"S pays out free line as well as hooked line")
	tick(5,{"reel":true})
	check(not game.baits[0].active,"reeling fully in stows the existing bait")
	var ids: Array=[]
	for bait in game.baits:
		if bait.hook:
			bait.active=false
			bait.removed=true
			for grain in bait.grains: grain.eaten=true; ids.append(grain.id)
	game.counted[ids[0]]=true
	tick(0.8,{"deploy":true})
	var unique:=true
	for grain in game.baits[0].grains:
		if grain.id in ids: unique=false
	check(game.baits[0].active and not game.baits[0].removed and unique and game.counted.has(ids[0]),"Q replaces spent/broken tackle with new grain identities and retains score history")
	var batch: int=game.bait_batch
	tick(1.6,{"deploy":true})
	check(game.bait_batch==batch,"Q cannot replenish a usable bait on every frame")
	attach()
	tick(0.05,{"deploy":true})
	check(game.hooked==game.HookState.HOOKED and not game.angler.casting,"Q cannot detach an already hooked fish")
	fresh(); attach()
	tick(0.3,{"reel":true})
	check(game.reel_speed<0,"W also reels a hooked line")
	tick(0.7,{"release":true})
	check(game.reel_speed>0,"S also pays out a hooked line")
	var samples: Array[Vector2]=[]
	for rate in [30,60,120]:
		fresh(); tick(1,{"deploy":true},rate); tick(0.8,{"walk":1},rate); tick(0.6,{},rate)
		samples.append(game.baits[0].pos)
	check(samples[0].distance_to(samples[2])<2 and samples[1].distance_to(samples[2])<2,"hook inertia remains stable at 30, 60 and 120 Hz")

func test_net() -> void:
	fresh()
	tick(0.1,{"drag":true,"target":Vector2(232,160)})
	check(game.net_state=="wait","left mouse alone does not cast, reel or deploy a net")
	tick(0.1,{"net_hold":true})
	check(game.net_state=="wait" and game.angler.net_held,"E alone arms without automatically capturing")
	tick(0.2,{"net_hold":true,"drag":true,"target":Vector2(232,160)})
	check(game.manual_net and game.net_state=="prepare","E plus dragging starts continuous manual net")
	check(game.net_from==Vector2(232,160) and game.net_pos==game.net_from,"net opens at the underwater click without travelling from shore")
	var before: Vector2=game.net_pos
	tick(0.01,{"drag":true})
	check(game.net_state=="withdraw" and game.net_pos.y<=before.y+0.1,"releasing E during entry cancels without dipping farther into water")
	tick(1)
	check(game.net_state=="rest" and game.net_catches==0,"cancelled entry returns safely without capture")
	fresh()
	tick(2,{"net_hold":true,"drag":true,"target":Vector2(230,160)})
	var downward: Vector2=game.net_pos
	tick(0.3,{"net_hold":true,"drag":true,"target":Vector2(275,160)})
	check(game.net_state=="sweep" and game.net_pos.x>downward.x+25,"dragging changes live net direction instead of locking an old target")
	check(game.net_from==Vector2(230,160),"changing drag direction keeps the original underwater start")
	var current: Vector2=game.net_pos
	tick(0.01,{"drag":true,"target":game.fish})
	check(game.net_state=="withdraw" and game.net_pos.distance_to(current)<2 and game.net_return_path.size()>5,"release cancels mid-sweep and records the curved return route")
	var safe:=true
	for frame in 180:
		var old: Vector2=game.net_pos
		tick(1.0/60)
		if game.net_pos.distance_to(old)>15 or game._net_contact(game.net_pos): safe=false
	check(safe and game.net_catches==0,"return follows clear water continuously and cannot capture")
	var cooldown: float=game.angler.net_cooldown
	tick(0.1,{"net_hold":true,"drag":true,"target":Vector2(232,160)})
	check(not game.manual_net and game.angler.net_cooldown<cooldown,"cancelling cannot bypass net cooldown")
	fresh()
	tick(0.1,{"net_hold":true,"drag":true,"target":Vector2(337,260)})
	check(not game.manual_net and game.angler.net_cooldown==0,"starting inside wood is rejected without spending cooldown")
	tick(1.6,{"net_hold":true,"drag":true,"target":Vector2(337,120)})
	tick(0.5,{"net_hold":true,"drag":true,"target":Vector2(337,260)})
	check(game.net_blocked and game.net_state in ["miss","withdraw","rest"],"turnable net still stops at wood and stone")
	for point in [Vector2(60,145),Vector2(510,140),Vector2(510,220),Vector2(60,275)]:
		fresh()
		tick(0.4,{"net_hold":true,"drag":true,"target":point})
		check(game.manual_net and game.net_from==point and game.net_pos==point,"arbitrary water start remains local through opening: "+str(point))
	fresh()
	game.fish=Vector2(60,275)
	tick(1.5,{"net_hold":true,"drag":true,"target":Vector2(55,110)})
	tick(3.4,{"net_hold":true,"drag":true,"target":Vector2(580,110)})
	check(game.net_state=="sweep" and game.net_pos.distance_to(Vector2(580,110))<1,"continuous drag can cross the pond beyond the old 230-pixel reach")
	var exits_clear:=true
	var tested:=0
	for x in range(40,601,20):
		for y in range(90,281,20):
			var point:=Vector2(x,y)
			if game.manual_net_blocked(point): continue
			var path: PackedVector2Array=game._manual_net_exit(point)
			tested+=1
			if path.is_empty() or path[0]!=point or path[-1].y>5:
				print("EXIT_INVALID | ",point," | ",path)
				exits_clear=false
				continue
			for index in range(1,path.size()):
				var steps:=ceili(path[index-1].distance_to(path[index]))
				for part in range(steps+1):
					if game.manual_net_blocked(path[index-1].lerp(path[index],float(part)/maxi(steps,1))):
						print("EXIT_COLLISION | ",point," | ",path)
						exits_clear=false
						break
	check(exits_clear and tested>150,"all sampled open-water starts have a collision-cleared lift to the surface")
	fresh()
	game.fish=Vector2(510,140)
	tick(1.3,{"net_hold":true,"drag":true,"target":Vector2(510,140)})
	check(game.net_catches==0 and game.net_state=="warning","placing a net on the fish still gives the full entry warning before capture")
	tick(3,{"net_hold":true,"drag":true,"target":Vector2(510,140)})
	check(game.won and game.reason=="net" and game.net_pos.y<=5,"a far underwater start catches and lifts the fish out of water")
	fresh()
	tick(1.6,{"net_hold":true,"drag":true,"target":Vector2(232,160)})
	game.menu.open("pause")
	var paused_pos: Vector2=game.net_pos
	game.controlled_step(1,{"net_hold":true,"drag":true})
	check(game.net_pos==paused_pos and game.local_input.needs_neutral,"pause suspends local net input and freezes position")
	game.menu.close()
	tick(2,{"net_hold":true,"drag":true,"target":Vector2(232,160)})
	check(not game.manual_net,"resume cannot accidentally reuse a still-held gesture")
	fresh(); attach(Vector2(232,170))
	tick(5,{"net_hold":true,"drag":true,"target":Vector2(232,150)})
	check(game.won and game.reason=="net" and game.rope_path.size()>1,"drag net captures a hooked fish and keeps its line throughout lifting")

func test_timing() -> void:
	fresh(); attach()
	game.set_escape_timing(1.2,0.8,2.5)
	game.rope_length+=80
	for frame in 50: game._step_line(1.0/60,false)
	check(game.qte.is_empty(),"longer low-tension delay prevents an early slack QTE")
	for frame in 30: game._step_line(1.0/60,false)
	check(game.qte=="slack" and is_equal_approx(game.qte_width,0.4),"slack check uses configurable wait and green-zone duration")
	game.qte_age=0.4+(game.qte_zone+0.30)*2
	game._step_qte(0,true)
	check(game.hooked==game.HookState.FREE,"wider slack success window affects actual judgment")
	fresh()
	game.set_escape_timing(0.5,0.12,3)
	game._enter_hook(0)
	var width: float=game.qte_width
	game.set_escape_timing(0.5,1.0,3)
	check(game.qte_width==width,"changing settings does not resize an ongoing QTE unexpectedly")
	game.qte_age=0.4+(game.qte_zone+0.1)*2
	game._step_qte(0,true)
	check(game.hooked==game.HookState.HOOKED and game.qte_result_width==width,"narrow mouth window and result art retain the same judgment width")
	fresh(); attach()
	game.set_escape_timing(0.5,0.4,2.5)
	game.rope_length-=60
	for frame in 120: game._step_line(1.0/60,false)
	check(game.hooked==game.HookState.HOOKED,"line does not break before the configured high-tension duration")
	for frame in 40: game._step_line(1.0/60,false)
	check(game.hooked==game.HookState.FREE and game.baits[0].removed,"continuous high tension breaks at the configured duration")
	fresh(); attach()
	game.rope_length-=60
	for frame in 90: game._step_line(1.0/60,false)
	game.rope_length+=120
	game._step_line(0.1,false)
	check(game.high_age==0,"relieving tension resets the break timer instead of accumulating it")
	game.set_escape_timing(1.1,0.72,4.6)
	game.save_profile()
	game.set_escape_timing(0.5,0.4,3)
	game._load_profile()
	check(is_equal_approx(game.slack_hold_seconds,1.1) and is_equal_approx(game.mouth_window_seconds,0.72) and is_equal_approx(game.break_hold_seconds,4.6),"all timing settings survive saving and reloading")
	game.set_escape_timing(NAN,-10,INF)
	check(game.slack_hold_seconds==0.5 and game.mouth_window_seconds==0.12 and game.break_hold_seconds==3,"invalid saved settings are clamped or restored")

func test_rounds() -> void:
	fresh()
	game.fish=Vector2(66,265)
	game.water_strength=1
	for frame in 21610:
		game.controlled_step(1.0/60,{})
		if game.won or game.lost: break
	check(game.lost and game.reason=="home","AI still completes an unopposed real feeding and home-return round")
	fresh()
	game.fish=Vector2(66,265)
	game.water_strength=1
	var paying_out:=false
	for frame in 21610:
		var command: Dictionary={}
		if game.hooked==game.HookState.FREE:
			command.deploy=frame%120==0
			command.reel=game.baits[0].active and game.angler.free_line_length>72
		else:
			if game.tension>0.84: paying_out=true
			if game.tension<0.70: paying_out=false
			command.reel=not paying_out
			command.release=paying_out
		command.walk=signf(game.fish.x-game.angler.anchor().x) if absf(game.fish.x-game.angler.anchor().x)>18 else 0
		game.controlled_step(1.0/60,command)
		if game.won or game.lost: break
	print("ANGLER_ROUND | won=",game.won," reason=",game.reason," time=",game.clock," bites=",game.hook_count)
	check(game.won and game.reason=="landed" and game.hook_count>0,"Q deployment and W/S line control can complete a real AI opponent round")
