extends SceneTree

const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("DUAL_PASS | ",message)
	else: failed+=1; push_error("DUAL_FAIL | "+message)

func fresh() -> void:
	game.reset(true,"angler")
	game.fish_brain.reset(2719)
	game.set_physics_process(false)
	game.set_process(false)

func tick(seconds: float, command: Dictionary={}) -> void:
	for frame in ceili(seconds*60): game.controlled_step(1.0/60,command)

func attach(point: Vector2=Vector2(280,180)) -> void:
	game.fish=point
	game.baits[0].active=true
	game._enter_hook(0)
	game._attach_hook()

func run() -> void:
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="dual-test"
	game.save_path="user://dual-role-test.cfg"
	fresh()
	check(game.player_role=="angler" and game.challenge and not game.baits[0].active,"angler starts without automatically cast hooks")
	var food_before: int=game.counted.size()
	game.controlled_step(1.0/60,{"cast":true,"target":Vector2(170,185)})
	check(game.angler.casting and not game.baits[0].active,"cast flies before bait becomes available")
	tick(0.75)
	check(not game.angler.casting and game.baits[0].active and game.baits[0].home==Vector2(170,185),"cast lands at player target")
	game.baits[0].grains[0].eaten=true
	game.controlled_step(1.0/60,{"retrieve":true})
	check(not game.baits[0].active,"E retrieves unhooked bait")
	tick(0.5)
	game.controlled_step(1.0/60,{"cast":true,"target":Vector2(280,150)})
	tick(0.75)
	check(game.baits[0].grains[0].eaten and game.counted.size()==food_before,"recast preserves consumed particles and cannot mint food")
	fresh()
	game.controlled_step(1.0/60,{"cast":true,"target":Vector2(200,12)})
	check(not game.angler.casting,"clicking HUD cannot cast into pond")
	var fish_before: Vector2=game.fish
	tick(1,{"walk":1})
	check(is_equal_approx(game.angler.x,278) and game.fish.distance_to(fish_before)>10,"bank movement and autonomous fish movement are independent")
	fresh(); attach()
	var anchor_before: Vector2=game.line_anchor(0)
	game.angler.update(game,0.2,{"walk":1,"reel":true})
	game._step_line(0.2,false)
	check(game.reel_speed<0 and game.line_anchor(0).x>anchor_before.x,"reel shortens line and walking changes its shore anchor")
	game.angler.update(game,1,{"release":true})
	game._step_line(1,false)
	check(game.reel_speed>0,"held left button pays out line")
	game.angler.update(game,1,{})
	game._step_line(1,false)
	check(is_zero_approx(game.reel_speed),"released buttons hold line length without automatic angler control")
	fresh(); attach()
	game.controlled_step(1.0/60,{"net":true,"target":Vector2(250,170)})
	check(game.net_state=="prepare" and game.angler.net_cooldown>11,"angler can deploy net while fish remains hooked")
	check(game.net_to.distance_to(Vector2(250,170))<1 and game.net_from.x==game.angler.anchor().x,"net targets cursor from player's shore position")
	var cooldown: float=game.angler.net_cooldown
	game.controlled_step(1.0/60,{"net":true})
	check(game.angler.net_cooldown<cooldown,"repeated net press cannot reset active net or bypass cooldown")
	fresh()
	game.angler.x=18
	game.controlled_step(1.0/60,{"net":true,"target":Vector2(602,284)})
	check(game.net_to.distance_to(game.net_from)<=230.01,"manual net has finite reach")
	fresh(); game._enter_hook(0)
	game.controlled_step(1.0/60,{"net":true})
	check(game.net_state=="wait","entry check must resolve before net deployment")
	fresh(); tick(40)
	check(game.net_count==0 and game.net_state=="wait","angler challenge never launches nets autonomously")
	game.restart_round()
	check(game.player_role=="angler" and not game.paused and game.clock==0,"restart retains selected role and resets controller")
	var fish_wins: int=game.wins
	var human_wins: int=game.angler_wins
	game.finish(false,"landed")
	check(game.won and not game.lost and game.angler_wins==human_wins+1,"landing is an angler victory")
	game.finish(false,"landed")
	check(game.angler_wins==human_wins+1,"outcome is recorded only once")
	fresh(); game.finish(true,"home")
	check(game.lost and not game.won and game.wins==fish_wins,"AI home return defeats human without changing fish player records")
	fresh(); game.finish(false,"timeout")
	check(game.lost,"timeout defeats angler")
	fresh(); game.finish(false,"net")
	check(game.won,"net capture is an angler victory")
	# Full opponent round: no score, position, stamina or QTE outcome writes.
	fresh()
	for frame in range(21610):
		game.controlled_step(1.0/60,{})
		if frame%3600==0: print("AI_ROUND | t=",game.clock," food=",game.score," state=",game.fish_brain.state," pos=",game.fish)
		if game.won or game.lost: break
	check(game.lost and game.reason=="home" and game.score>=59.99,"unopposed AI eats finite bait and returns home through real commands")
	print("AI_FINAL | reason=",game.reason," food=",game.score," seconds=",game.clock)
	test_ai_checks()
	test_played_round()
	print("DUAL_TESTS | passed=",passed," | failed=",failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func test_ai_checks() -> void:
	var escapes := 0
	var attachments := 0
	for seed_value in range(20):
		fresh()
		game.fish_brain.reset(seed_value+2700)
		game.fish=Vector2(220,160)
		game.baits[0].active=true
		game._enter_hook(0)
		for frame in 145:
			game.controlled_step(1.0/60,{})
			if game.hooked!=game.HookState.MOUTH: break
		if game.hooked==game.HookState.FREE: escapes+=1
		elif game.hooked==game.HookState.HOOKED: attachments+=1
	check(escapes>0 and attachments>0 and escapes+attachments==20,"AI entry checks can succeed or fail through timed input")
	fresh()
	attach(Vector2(148,230))
	game._update_contacts(0)
	game.fish_brain.was_hooked=true
	game.fish_brain.hook_reaction=0
	game.controlled_step(1.0/60,{"reel":true})
	var before: Vector2=game.fish
	tick(0.4,{"reel":true})
	check(game.qte=="wrap" and game.fish.distance_to(before)>0.1 and game.resisting,"AI continues swimming against pull during wrap QTE")
	fresh()
	game.fish=Vector2(100,150)
	game.angler.x=530
	game.controlled_step(1.0/60,{"net":true,"target":Vector2(560,150)})
	tick(1.5)
	check(game.fish_brain.state!="躲避抄网","distant nets do not force omniscient AI evasion")
	fresh()
	var point: Vector2=game.fish
	game.menu.open("pause")
	tick(2,{"walk":1,"cast":true,"net":true,"target":Vector2(100,150)})
	check(game.clock==0 and game.fish==point and game.angler.x==206 and not game.angler.casting,"pause freezes both controllers and simulation")
	game.menu.close()
	attach(Vector2(232,140))
	game.angler.update(game,0,{"net":true,"target":Vector2(232,175)})
	for frame in 600:
		game.step(1.0/60,Vector2.ZERO,false,false)
		if game.won or game.lost: break
	check(game.won and game.reason=="net" and game.rope_path.size()>1,"manual net captures hooked fish and keeps its line through lifting")

func test_played_round() -> void:
	# Exercise both ends without writing fish positions, outcomes or stamina.
	fresh()
	var paying_out := false
	for frame in 21610:
		var command := {"target":game.fish+Vector2(28,0)}
		if game.hooked==game.HookState.FREE:
			command.cast=frame==1 or (game.escape_count>0 and frame%240==0)
			command.target=Vector2(180,110) if frame<240 else game.fish+Vector2(28,0)
		else:
			if game.tension>0.84: paying_out=true
			if game.tension<0.70: paying_out=false
			command.reel=not paying_out
			command.release=paying_out
			command.walk=signf(game.fish.x-game.angler.anchor().x) if absf(game.fish.x-game.angler.anchor().x)>12 else 0
		game.controlled_step(1.0/60,command)
		if game.won or game.lost: break
	check(game.won and game.reason=="landed" and game.hook_count>0,"full cast/bite/QTE/fight/manual-reel round can land the AI fish")
	print("ANGLER_FULL_ROUND | result=",game.reason," seconds=",game.clock," bites=",game.hook_count," escapes=",game.escape_count)
