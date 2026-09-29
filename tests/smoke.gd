extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS | ", title)
	else:
		failed += 1
		push_error("FAIL | " + title)

func tick(seconds: float, movement: Vector2 = Vector2.ZERO, suck: bool = false) -> void:
	for index in ceili(seconds * 60): game.step(1.0/60, movement, suck, false)

func fresh(challenge: bool = false) -> void:
	game.reset(challenge)
	game.water_strength = 0 # Isolate input/line checks; current has dedicated and full-round coverage.
	game.set_physics_process(false)
	game.set_process(false)

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	game.save_path = "user://pixel-smoke.cfg"
	game.set_physics_process(false)
	game.set_process(false)
	check(game.menu.visible and game.menu.screen == "title", "Title loads with no game time advancing")
	test_pass_through()
	test_sprint()
	test_water()
	test_wrapping()
	test_bites()
	test_escapes()
	test_practice_tuning()
	test_shared_controls()
	test_hauling()
	test_food()
	test_net()
	test_net_polish()
	test_supply()
	test_round()
	test_menus()
	print("PIXEL_TESTS | passed=", passed, " | failed=", failed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func test_pass_through() -> void:
	fresh()
	game.fish = Vector2(290,270)
	game.move_fish(Vector2(140,0))
	check(game.fish.x==430,"Fish can swim through the full root")
	game.fish = Vector2(193,260)
	game.move_fish(Vector2(0,180))
	check(game.fish.y==299,"Stone is pass-through while pond floor remains a boundary")
	game.fish = Vector2(340,137)
	game.move_fish(Vector2(0,130))
	check(game.fish.y==267,"Fish can enter wood through its upper edge")
	game.fish = Vector2(300,265)
	game.aim = Vector2.RIGHT
	check(game.strength(Vector2(340,265))>0,"Pass-through scenery does not invisibly block suction")
	game.move_fish(Vector2(-1000,-1000))
	check(game.fish.x >=20 and game.fish.y >=80, "Water bounds survive a long movement step")
	game.fish = Vector2(338,239)
	game._update_contacts(0.3)
	check(absf(game.target_opacity[0]-0.68)<0.001 and game.target_opacity[4]==1,"Contact fades cover gently to 68% opacity; other objects stay solid")
	game.fish = Vector2(500,100)
	game._update_contacts(0.3)
	check(game.target_opacity[0]==1,"Cover opacity restores after leaving")
	var old: Vector2 = game.fish
	space()
	check(game.fish==old and game.qte.is_empty(),"Space neither rises nor starts a QTE without a hooked line")
	var clean_keys := true
	for action in ["up","down"]:
		for event in InputMap.action_get_events(action):
			if event.physical_keycode in [KEY_SPACE,KEY_CTRL]: clean_keys=false
	check(clean_keys and InputMap.action_get_events("qte")[0].physical_keycode==KEY_SPACE,"Space owns the shared QTE action; Space and Ctrl are removed from vertical movement")
	fresh()
	game.fish = Vector2(491,258)
	tick(0.25,Vector2.DOWN)
	var grass_distance: float = game.fish.y-258
	fresh()
	game.fish = Vector2(520,258)
	tick(0.25,Vector2.DOWN)
	var water_distance: float = game.fish.y-258
	check(grass_distance>0 and grass_distance<water_distance*0.8,"Dense weeds slow swimming without becoming a hard wall")

func test_sprint() -> void:
	fresh()
	game.fish = Vector2(100,140)
	for frame in range(90): game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.sprinting and game.velocity.x>135 and game.fish.x>285,"Holding right mouse button keeps high speed beyond the old burst duration")
	check(absf(game.stamina-58)<0.1,"Held sprint continuously drains 28 stamina per second")
	for frame in range(20): game.step(1.0/60,Vector2.DOWN,false,false,true)
	check(game.velocity.y>130 and absf(game.velocity.x)<1,"Held sprint follows changing movement direction")
	tick(0.4,Vector2.RIGHT)
	check(not game.sprinting and game.velocity.length()<71,"Releasing right mouse button returns to normal swim speed")
	var low: float = game.stamina
	tick(1)
	check(game.stamina>low,"Stamina recovers after the short recovery delay")
	fresh()
	game.stamina = 4
	for frame in range(120): game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.sprint_exhausted and not game.sprinting and game.velocity.length()<71,"Exhaustion stops sprinting without repeatedly restarting while right mouse button stays held")
	game.step(1.0/60,Vector2.ZERO,false,false,false)
	game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.sprinting,"Recovered stamina and a new right mouse button hold resume sprinting")
	fresh()
	for frame in range(60): game.step(1.0/60,Vector2.ZERO,false,false,true)
	check(game.stamina==100 and not game.sprinting,"Holding right mouse button without a direction does not spend stamina")
	game._enter_hook(0)
	for frame in range(30): game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.stamina==100 and not game.sprinting,"Entry lock prevents sprint and stamina drain")

func test_water() -> void:
	fresh()
	game.water_strength=1
	game.fish=Vector2(400,130)
	var before: Vector2 = game.fish
	var bait_before: Vector2 = game.baits[0].pos
	tick(0.8)
	check(game.fish.distance_to(before)>0.3 and game.fish.distance_to(before)<6,"Gentle water current physically drifts idle fish")
	check(Vector2(game.baits[0].pos).distance_to(bait_before)>1 and absf(game.baits[0].angle)>0.02,"Water sways tethered bait and hook together")
	var coherent := true
	for bait in game.baits:
		for grain in bait.grains:
			if Vector2(grain.pos).distance_to(Vector2(bait.pos)+Vector2(grain.offset).rotated(bait.angle))>0.01: coherent=false
	check(coherent and game._tip(0).distance_to(game.baits[0].pos)<3,"Sway keeps hook tip inside the bait and all attached grains in the same transform")
	game.baits[1].grains[0].free=true
	var particle: Vector2=game.baits[1].grains[0].pos
	tick(0.5)
	check(Vector2(game.baits[1].grains[0].pos).distance_to(particle)>0.1,"Detached food also drifts with the current")
	game._enter_hook(0)
	before=game.fish
	tick(0.4)
	check(game.fish==before,"Current does not move fish during the locked entry QTE")
	var time_before: float=game.elapsed
	bait_before=game.baits[0].pos
	game.menu.open("pause")
	tick(1)
	check(game.elapsed==time_before and game.baits[0].pos==bait_before,"Pause freezes water and bait motion together")

func space() -> void:
	game.step(1.0/60,Vector2.ZERO,false,false,false,false,true)

func hook_at(point: Vector2) -> void:
	fresh()
	game.fish = point
	game.aim = Vector2.RIGHT
	game._enter_hook(0)
	game._attach_hook()
	game._update_contacts(1)

func win_wrap() -> void:
	var place: Vector2 = game.fish
	game.step(1.0/60,hold_input(place),false,false,false,false,true)
	for frame in range(160):
		if game.qte!="wrap" or game.qte_progress()>=game.qte_zone+0.06: break
		game.step(1.0/60,hold_input(place),false,false)
	game.step(1.0/60,hold_input(place),false,false,false,false,true)

func hold_input(place: Vector2) -> Vector2:
	return ((place-game.fish)*5-game.line_pull_velocity()-game.water_velocity(game.fish))/70/game.vegetation_drag(game.fish)

func test_wrapping() -> void:
	hook_at(Vector2(338,239))
	check(game.contact_target==0 and game.wraps.is_empty(),"Contact selects root without automatically winding")
	space()
	check(game.qte=="wrap" and game.wraps.is_empty(),"First Space starts QTE without judging its own press")
	var before: Vector2 = game.fish
	game.step(0.1,Vector2.DOWN,false,true,true)
	check(game.qte=="wrap" and game.fish!=before and game.sprinting,"Wrap QTE allows swimming and sprinting; E cannot consume the Space check")
	space()
	check(game.qte.is_empty() and game.wraps.is_empty() and game.hooked==game.HookState.HOOKED,"Early Space fails without unhooking or adding a loop")
	space()
	check(game.qte.is_empty(),"Failed wrap has a short retry cooldown")
	hook_at(Vector2(338,239))
	space()
	tick(2.5)
	check(game.wraps.is_empty() and game.hooked==game.HookState.HOOKED,"Unanswered wrap QTE times out and keeps fish hooked")
	hook_at(Vector2(338,239))
	space()
	game.fish = Vector2(460,120)
	space()
	check(game.wraps.is_empty(),"Losing target contact cannot complete a stale QTE")
	hook_at(Vector2(338,239))
	win_wrap()
	check(game.wraps.size()==1 and game.winding() and game.hooked==game.HookState.HOOKED and game.escape_count==0,"Successful Space adds one animated loop, not an instant escape")
	if game.wraps.is_empty(): return
	var short_path: int = game.visible_coil(game.wraps[0]).size()
	before = game.fish
	tick(0.4,Vector2.RIGHT)
	check(game.fish!=before and game.visible_coil(game.wraps[0]).size()>short_path,"Winding grows visibly while fish keeps swimming")
	tick(0.5)
	var loop: PackedVector2Array = game.wraps[0].loop
	check(not game.winding() and loop[0].distance_to(loop[-1])<0.001,"Animation completes exactly one closed turn")
	check(game.tension>0.25,"Swimming away while winding can spend the initial slack")
	game.contact_target=0
	check(not game._begin_wrap() and game.wraps.size()==1,"Same object cannot accumulate duplicate loops from repeated presses")
	var old_center: Vector2 = game.wraps[0].center
	game.move_fish(Vector2(80,0))
	game._step_line(0,false)
	check(game.wraps.size()==1 and game.wraps[0].center==old_center and game.hooked==game.HookState.HOOKED,"Swimming away preserves the established loop instead of detaching it")
	game.fish = Vector2(263,268)
	game._update_contacts(1)
	win_wrap()
	check(game.wraps.size()==2 and game.wraps[0].center==old_center,"Another contacted object can gain its own turn without losing the first")
	game.reset(false)
	check(game.wraps.is_empty() and game.wrap_target==-1 and game.qte.is_empty(),"Restart clears contact, QTE and winding animation")
	for data in [{"point":Vector2(193,294),"kind":"stone"},{"point":Vector2(25,275),"kind":"grass"}]:
		hook_at(data.point)
		var selected: int = game.contact_target
		win_wrap()
		check(selected>=0 and game.targets[selected].kind==data.kind and game.wraps.size()==1,"Space wrapping works on "+data.kind)
	hook_at(Vector2(338,239))
	game.water_strength=1
	win_wrap()
	tick(0.9)
	var moved := false
	for frame in range(240):
		if game.hooked!=game.HookState.HOOKED: break
		var movement: Vector2 = hold_input(Vector2(game.wraps[-1].entry)-game.aim*10)
		var press_space: bool = game.qte=="slack" and game.qte_progress()>=game.qte_zone+0.06
		before = game.fish
		game.step(1.0/60,movement,false,false,false,false,press_space)
		moved = moved or game.fish.distance_to(before)>0.001
	check(moved and game.hooked==game.HookState.FREE and game.wraps.is_empty(),"With current and faster spool: Space wrap, move to maintain slack, Space eject, clear all loops")
	hook_at(Vector2(338,239))
	space()
	game.menu.open("pause")
	var age: float = game.qte_age
	tick(2)
	check(game.qte_age==age and game.wraps.is_empty(),"Pause freezes the new QTE")

func test_bites() -> void:
	fresh()
	check(game.hook_point(0,Vector2(0,10)).distance_to(game._tip(0))<7.1,"World hook shrinks while its tip stays attached to the bait")
	game.fish=game._tip(0)-Vector2(13,6)
	game.aim=Vector2.RIGHT
	game.step(1.0/60,Vector2.ZERO,false,false)
	check(game.hooked==game.HookState.MOUTH,"Grazing the enlarged tip range starts a bite outside the old radius")
	fresh()
	game.aim = Vector2.RIGHT
	game.fish = game._tip(0)-Vector2(13,0)
	game.step(1.0/60,Vector2.RIGHT,false,false)
	check(game.hooked == game.HookState.MOUTH, "Swept hook-tip contact starts entry QTE")
	var place: Vector2 = game.fish
	tick(0.4,Vector2.DOWN)
	check(game.fish == place, "Entry QTE locks movement")
	game.step(1.0/60,Vector2.ZERO,false,false,false,false,true)
	check(game.hooked == game.HookState.HOOKED, "Early Space fails and attaches hook")
	tick(0.25,Vector2.LEFT)
	check(game.hooked == game.HookState.HOOKED and game.fish != place, "Moving after failure retains attached hook")
	fresh()
	game._enter_hook(0)
	game.qte_age = 0.4 + (game.qte_zone+0.08)*2
	game.step(1.0/60,Vector2.ZERO,false,false,false,false,true)
	check(game.hooked == game.HookState.FREE and game.escape_count == 1, "Entry Space inside green interval ejects hook")
	fresh()
	game._enter_hook(0)
	tick(2.6)
	check(game.hooked == game.HookState.HOOKED, "Unanswered entry QTE fails into persistent hooked state")

func test_escapes() -> void:
	fresh()
	game.fish = Vector2(260,170)
	game._enter_hook(0)
	game._attach_hook()
	game.fish += Vector2(0,48)
	game._step_line(0,false)
	check(game.tension >= 0.9, "Swimming away increases tension")
	for frame in range(168): game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.hooked == game.HookState.HOOKED, "Line cannot break before three continuous seconds")
	for frame in range(18): game.step(1.0/60,Vector2.RIGHT,false,false,true)
	check(game.hooked == game.HookState.FREE and game.baits[0].removed, "Sustained high tension breaks line and removes spent hook")
	fresh()
	game.fish = Vector2(260,220)
	game._enter_hook(0)
	game._attach_hook()
	game.fish -= Vector2(0,40)
	tick(0.6)
	check(game.qte == "slack", "Low tension opens ring QTE")
	var position_before: Vector2 = game.fish
	tick(0.3,Vector2.UP)
	check(game.fish.y < position_before.y and game.qte == "slack", "Slack QTE allows simultaneous movement")
	game.qte_age = 0.4 + (game.qte_zone+0.07)*2
	game.step(1.0/60,Vector2.UP,false,false,false,false,true)
	check(game.hooked == game.HookState.FREE and not game.baits[0].removed, "Moving while pressing Space at low tension unhooks without breaking line")
	fresh()
	game.fish = Vector2(260,220)
	game._enter_hook(0)
	game._attach_hook()
	game.fish.y -= 40
	tick(0.6)
	game.fish.y += 42
	game.qte_age = 0.4+(game.qte_zone+0.08)*2
	game.step(1.0/60,Vector2.ZERO,false,false,false,false,true)
	check(game.hooked == game.HookState.HOOKED and game.qte.is_empty(), "Re-tension cancels slack QTE before a same-frame Space success")
	var old_length: float = game.rope_length
	game.fish.y += 40
	game.reel_speed=0
	game._step_line(0.5,false)
	check(game.rope_length-old_length>1.5 and game.rope_length-old_length<=12.01, "High-tension payout responds but remains speed-limited")
	game.fish.y -= 100
	old_length = game.rope_length
	game._step_line(0.5,false)
	check(old_length-game.rope_length>2 and old_length-game.rope_length<=18.01, "Low-tension reeling responds but remains speed-limited")
	fresh()
	game.fish=Vector2(260,170)
	game._enter_hook(0)
	game._attach_hook()
	game.fish.y+=24
	tick(3)
	check(game.hooked==game.HookState.HOOKED and game.tension<0.7,"Automatic payout eases stationary high tension; breaking requires continued effort")
	hook_at(Vector2(260,220))
	game.fish.y-=40
	var depth: float=game.fish.y
	tick(1)
	check(game.fish.y<depth and game.hooked==game.HookState.HOOKED,"Automatic reeling continues hauling instead of merely seeking neutral tension")

func test_practice_tuning() -> void:
	var response_distances: Array[float]=[]
	for sensitivity in [0.25,2.5]:
		hook_at(Vector2(260,170))
		game.set_practice_line_tuning(sensitivity,1)
		game.rope_length-=8
		var before: float=game.rope_length
		game._step_line(0.2,false)
		response_distances.append(game.rope_length-before)
	check(response_distances[1]>response_distances[0]*3,"Practice sensitivity changes the response to the same tension error")
	var force_distances: Array[float]=[]
	for force in [0.25,2.5]:
		hook_at(Vector2(260,170))
		game.set_practice_line_tuning(2.5,force)
		game.rope_length-=80
		var before: float=game.rope_length
		game._step_line(0.5,false)
		force_distances.append(game.rope_length-before)
	check(force_distances[1]>force_distances[0]*5,"Practice force changes maximum payout speed independently of sensitivity")
	game.set_practice_line_tuning(1,0)
	var held: float=game.rope_length
	game._step_line(0.3,false)
	check(game.rope_length==held and game.reel_speed==0,"Zero practice force stops automatic adjustment immediately")
	game.set_practice_line_tuning(1.75,0.4)
	game.reset(true)
	check(game.line_tuning()==Vector2.ONE,"Challenge ignores practice tuning and uses fixed parameters")
	game.menu.open("practice")
	check(not game.menu.visible and not game.paused,"Challenge cannot open practice controls")
	game.reset(false)
	check(game.line_tuning()==Vector2(1.75,0.4),"Practice values survive a round restart and a challenge round")
	game.save_profile()
	game.set_practice_line_tuning(1,1)
	game._load_profile()
	check(game.line_tuning()==Vector2(1.75,0.4),"Practice values survive saving and loading the profile")
	game.menu.open("practice")
	var sensitivity_slider: HSlider=game.menu.content.find_child("LineSensitivity",true,false)
	var force_slider: HSlider=game.menu.content.find_child("LineForce",true,false)
	sensitivity_slider.value=150
	force_slider.value=80
	check(game.line_tuning()==Vector2(1.5,0.8) and game.paused,"Both visible practice sliders update their distinct settings while paused")
	for practice_button in game.menu.content.find_children("*","Button",true,false):
		if practice_button.text=="恢复默认": practice_button.pressed.emit(); break
	check(game.line_tuning()==Vector2.ONE,"Practice reset button restores both defaults")
	game.set_practice_line_tuning(-20,90)
	check(game.line_tuning()==Vector2(0.25,2.5),"Out-of-range saved tuning is clamped")
	game.set_practice_line_tuning(NAN,INF)
	check(game.line_tuning()==Vector2.ONE,"Non-finite tuning falls back to defaults")
	game.save_profile()
	game.menu.close()

func test_shared_controls() -> void:
	var dash_events: Array[InputEvent]=InputMap.action_get_events("dash")
	check(dash_events.size()==1 and dash_events[0] is InputEventMouseButton and dash_events[0].button_index==MOUSE_BUTTON_RIGHT,"Sprint binds only to right mouse button")
	fresh()
	game._enter_hook(0)
	game.qte_age=0.4+(game.qte_zone+0.06)*2
	game.step(1.0/60,Vector2.ZERO,false,true)
	check(game.qte=="entry" and game.hooked==game.HookState.MOUTH,"E no longer judges entry QTE")
	space()
	check(game.hooked==game.HookState.FREE,"Space judges entry QTE")
	hook_at(Vector2(338,239))
	game.rope_length+=80
	tick(0.6)
	check(game.qte=="slack" and game.contact_target>=0,"Slack QTE can coexist with available wrap contact")
	game.qte_age=0.4+(game.qte_zone+0.06)*2
	game.step(1.0/60,Vector2.ZERO,false,true)
	check(game.qte=="slack","E no longer judges slack QTE")
	space()
	check(game.hooked==game.HookState.FREE and game.wraps.is_empty(),"Space judges active slack instead of replacing it with a wrap QTE")
	hook_at(Vector2(338,239))
	game.rope_length+=80
	tick(0.6)
	space()
	check(game.hooked==game.HookState.HOOKED and game.qte.is_empty() and game.wraps.is_empty(),"An early Space fails slack without also starting a wrap")
	fresh()
	game.score=18
	game.fish=game.HOME
	space()
	check(not game.returning,"Space does not accidentally start the separate return-home action")
	game.step(1.0/60,Vector2.ZERO,false,true)
	check(game.returning,"E remains the return-home key")

func test_hauling() -> void:
	for start in [Vector2(260,220),Vector2(550,270),Vector2(70,280)]:
		fresh(true)
		game.fish=start
		game._enter_hook(0)
		game._attach_hook()
		var original_length: float=game.rope_length
		tick(1)
		check(game.fish.y<start.y-10 and game.rope_length<original_length,"Idle hooked fish is physically reeled upward from "+str(start))
		tick(24)
		check(game.lost and game.reason=="landed" and game.fish.y<53,"Inaction ends in an actual lift out of water from "+str(start))
	hook_at(Vector2(260,220))
	game.score=12.75
	tick(15)
	check(game.line_catches==1 and not game.lost and game.hooked==game.HookState.FREE and game.fish.distance_to(game.HOME)<25,"Practice hauling returns the fish to its nest")
	check(game.score==12.75 and game.escape_count==0 and game.rope_path.is_empty(),"Practice capture preserves food, clears the line, and does not count as escape")
	var times: Array[float]=[]
	for fps in [30,60,120]:
		fresh(true)
		game.fish=Vector2(280,245)
		game._enter_hook(0)
		game._attach_hook()
		for frame in range(fps*20):
			game.step(1.0/fps,Vector2.ZERO,false,false)
			if game.lost: break
		times.append(game.elapsed)
	check(times.max()-times.min()<0.2,"Passive hauling has consistent timing at 30, 60, and 120 Hz")
	hook_at(Vector2(338,239))
	space()
	var before: Vector2=game.fish
	tick(0.25)
	check(game.qte=="wrap" and game.fish.y<before.y and not game.movement_locked(),"The line still pulls during an unanswered wrap QTE")
	hook_at(Vector2(338,239))
	var start: Vector2=game.fish
	win_wrap()
	check(game.wraps.size()==1 and game.stamina<100 and game.fish.distance_to(start)<8,"Moving against the line maintains contact and wins the wrap QTE at a stamina cost")
	if not game.wraps.is_empty():
		game.move_fish(Vector2(30,0))
		game._step_line(0,false)
		before=game.fish
		tick(0.2)
		check(game.winding() and game.fish.x<before.x,"During winding the taut fish-side line still pulls toward the coil")
	hook_at(Vector2(350,200))
	game.stamina=60
	before=game.fish
	for frame in range(60): game.step(1.0/60,-game.line_pull_velocity().normalized(),false,false)
	check(game.stamina<52 and game.fish.y>before.y,"Normal swimming can resist hauling but spends stamina")
	var depleted: float=game.stamina
	tick(1)
	check(game.stamina>depleted,"Giving up resistance lets stamina recover while the line keeps hauling")
	hook_at(Vector2(350,200))
	game.stamina=0
	for frame in range(60): game.step(1.0/60,Vector2.DOWN,false,false)
	check(game.velocity.length()<30 and game.stamina<1,"Holding against a taut line when exhausted does not regenerate stamina or retain full speed")
	hook_at(Vector2(260,220))
	game.set_practice_line_tuning(1,0)
	before=game.fish
	tick(3)
	check(game.fish==before and game.line_pull_velocity()==Vector2.ZERO,"Practice force zero disables physical hauling as well as the spool")
	game.set_practice_line_tuning(1,1)
	tick(0.5)
	check(game.fish.y<before.y-5,"Restoring force resumes active hauling in the current round")
	hook_at(Vector2(490,216))
	game.stamina=45
	game.power=1
	for frame in range(210):
		game.aim=(Vector2(game.baits[1].pos)-game.mouth()).normalized()
		var movement: Vector2=hold_input(Vector2(501,216))/0.68
		game.step(1.0/60,movement,true,false)
	check(game.score>0 and game.stamina>45 and game.hooked==game.HookState.HOOKED,"Hooked fish can swim against the line while eating real bait to restore stamina")
	hook_at(Vector2(350,200))
	for frame in range(20): game.step(1.0/60,Vector2.RIGHT,true,false)
	check(game.velocity.length()<48 and game.feeding,"Hooked suction trades swim speed for food and recovery")
	hook_at(Vector2(232,86))
	game.challenge=true
	tick(0.7)
	check(game.landing and not game.lost,"Landing starts with a visible lift rather than an instant loss")
	before=game.fish
	var age: float=game.landing_age
	game.menu.open("pause")
	tick(1,Vector2.DOWN)
	check(game.fish==before and game.landing_age==age,"Pause freezes the landing animation")
	game.menu.close()
	tick(1.1,Vector2.DOWN)
	check(game.lost and game.reason=="landed" and game.fish.y<53,"Once lifted, swimming cannot cancel the capture")
	game.reset(false)
	check(not game.landing and not game.resisting and not game.feeding and game.line_catches==0,"Restart clears all hauling, feeding and landing state")

func eat_bait(index: int, seconds: float) -> void:
	game.power = 0.75
	for frame in ceili(seconds*60):
		game.aim = (Vector2(game.baits[index].pos)-game.mouth()).normalized()
		var movement := Vector2.ZERO
		if game.challenge:
			if game.net_state in ["prepare","warning","sweep"]: movement=avoid_net_direction()
			elif game.fish.distance_to(Vector2(501,216))>2: movement=(Vector2(501,216)-game.fish).normalized()
		game.step(1.0/60,movement,true,false)

func test_food() -> void:
	fresh()
	game.fish=Vector2(196,153)
	game.aim=Vector2.RIGHT
	game.power=0.35
	var assembly_before: Vector2=game.baits[0].pos
	tick(0.1,Vector2.ZERO,true)
	check(assembly_before.x-Vector2(game.baits[0].pos).x>3,"Default 35% suction visibly moves the lighter hook and bait without requiring maximum power")
	fresh()
	game.fish = Vector2(501,216)
	game.aim = Vector2.RIGHT
	eat_bait(1,2)
	var inner_detached := false
	var outer_remaining := false
	for grain in game.baits[1].grains:
		if grain.layer > 0 and grain.free: inner_detached = true
		if grain.layer == 0 and not grain.free: outer_remaining = true
	check(not (inner_detached and outer_remaining), "Bait sheds outer shell before inner grains")
	eat_bait(1,22)
	check(absf(game.score-30) < 0.001 and game.counted.size()==44, "Actual cone suction eats a whole loose bait for exactly 30 points")
	tick(2,Vector2.ZERO,true)
	check(absf(game.score-30)<0.001, "Consumed grains cannot award duplicate points")
	fresh()
	game.fish = Vector2(206,153)
	game.aim = Vector2.RIGHT
	game.power = 1
	var origin: Vector2 = game.baits[0].pos
	tick(0.1,Vector2.ZERO,true)
	check(Vector2(game.baits[0].pos).x < origin.x-2, "Strong suction pulls hook and layered bait assembly together")
	tick(0.7,Vector2.ZERO,true)
	check(game.hooked==game.HookState.MOUTH,"Stronger pull and expanded bite range can pull the hook into the mouth without swimming")

func test_net() -> void:
	fresh()
	game.request_net()
	tick(0.1)
	check(not game._net_contact(game.net_from) and game.net_from.distance_to(game.net_to)>30,"Practice at the starting nest brings in a usable net above the bank rocks")
	fresh()
	game.fish = Vector2(490,220)
	game.request_net()
	game.step(1.0/60,Vector2.ZERO,false,false)
	var locked_from: Vector2 = game.net_from
	var locked_to: Vector2 = game.net_to
	tick(2,Vector2.UP)
	check(game.net_state == "warning" and game.net_from == locked_from and game.net_to == locked_to, "Net telegraph fixes direction and sweep lane before attack")
	tick(4.7)
	check(not game.lost and game.net_state == "rest", "Leaving warning lane dodges entire sweep")
	fresh(true)
	game.fish = Vector2(490,150)
	game.request_net()
	tick(6)
	check(game.lost and game.reason == "net" and game.menu.screen == "result", "Challenge capture lifts the fish before opening the result screen")
	fresh()
	game.fish = Vector2(490,245)
	game.request_net()
	game.step(1.0/60,Vector2.ZERO,false,false)
	var net_clear := true
	for step in range(101):
		if game._net_contact(game.net_from.lerp(game.net_to,step/100.0)): net_clear = false
	check(net_clear and game.net_to.x > 560,"Net rim stops before the new leaning wood; warning shows shortened lane")
	tick(7)
	check(not game.lost and game.net_state=="rest","Solid wood offers cover instead of letting the net pass through")
	fresh()
	game._enter_hook(0)
	game._attach_hook()
	game.request_net()
	tick(1)
	check(game.net_state == "wait" and game.hooked == game.HookState.HOOKED, "Hook struggle defers net attack")
	fresh()
	game.fish=Vector2(490,150)
	game.score=12
	game.request_net()
	for frame in range(360):
		game.step(1.0/60,Vector2.ZERO,false,false)
		if game.net_state=="caught": break
	check(game.net_state=="caught" and game.net_catches==1 and not game.lost,"Practice catch enters a visible lift animation instead of ending the round")
	var energy: float=game.stamina
	game.step(0.1,Vector2.RIGHT,false,false,true)
	check(game.movement_locked() and game.velocity==Vector2.ZERO and not game.sprinting and game.stamina>=energy,"Caught fish cannot swim or sprint out of the net")
	var age: float=game.net_age
	var position_before: Vector2=game.fish
	game.menu.open("pause")
	tick(1)
	check(game.net_age==age and game.fish==position_before,"Pause freezes the capture animation")
	game.menu.close()
	tick(1.7)
	check(not game.lost and game.net_state=="rest" and game.fish.distance_to(game.HOME)<22 and game.score==12,"Practice capture returns fish to the nest and preserves earned food")
	fresh()
	game.net_count=1
	game.fish=Vector2(490,150)
	game.request_net()
	tick(0.1)
	locked_from=game.net_from
	locked_to=game.net_to
	check(game.net_kind=="drop" and locked_from.y<locked_to.y,"The next attack descends diagonally from the surface")
	tick(2,Vector2.RIGHT)
	check(game.net_from==locked_from and game.net_to==locked_to,"Descending attack does not chase the fish after warning starts")
	tick(4)
	check(game.net_catches==0 and game.net_dodges==1,"Swimming sideways evades the descending net")
	fresh()
	game.net_count=1
	game.fish=Vector2(490,150)
	game.request_net()
	tick(6)
	check(game.net_catches==1,"Descending net catches a fish that stays in its warned path")
	fresh()
	for attempt in range(5):
		game.fish=Vector2(490,150)
		game.velocity=Vector2.ZERO
		game.request_net()
		for frame in range(180):
			game.step(1.0/60,Vector2.ZERO,false,false)
			if game.net_state=="prepare": break
		var escape := Vector2.UP if game.net_kind=="sweep" else Vector2.RIGHT
		tick(6,escape)
	check(game.net_count==5 and game.net_dodges==5 and game.net_catches==0,"Practice can repeat more than three attacks, alternating sweep and descent")
	fresh(true)
	game.fish=Vector2(490,150)
	tick(18.5)
	check(game.net_state=="prepare" and game.net_count==0,"First challenge net appears about 18 seconds after leaving the nest")
	fresh()
	game.fish=Vector2(490,150)
	game.request_net()
	tick(1)
	var danger: PackedVector2Array=game.net_warning_outline()
	var covers := true
	for sample in range(11):
		var center: Vector2=game.net_from.lerp(game.net_to,sample/10.0)
		for ring in range(8):
			if not Geometry2D.is_point_in_polygon(center+Vector2.from_angle(ring*TAU/8)*game.NET_CATCH*0.9,danger): covers=false
	check(covers,"Warning outline covers the swept catch volume, including the end caps")
	check(game.net_catches==0 and game.hooked==game.HookState.FREE,"Warning itself cannot capture fish or start another hook check")

func test_net_polish() -> void:
	for kind in range(2):
		fresh()
		game.fish=Vector2(490,150)
		game.net_count=kind
		game.request_net()
		tick(1.0/60)
		check(game.net_pos.y<53,"Net starts above the water before entering: "+str(kind))
		var original_from: Vector2=game.net_from
		var original_to: Vector2=game.net_to
		var outline: PackedVector2Array=game.net_warning_outline()
		var clear := true
		var covered := true
		for sample in range(31):
			var point := original_from.lerp(original_to,sample/30.0)
			if game._net_contact(point): clear=false
			for angle in range(16):
				var boundary: Vector2 = point+(Vector2.from_angle(angle*TAU/16)*game.NET_CATCH*0.99).rotated(game.net_angle)
				if not Geometry2D.is_point_in_polygon(boundary,outline): covered=false
		check(clear and covered,"Rotated warning encloses the actual clear capture route: "+str(kind))
		tick(1)
		check(game.net_pos==original_from and game.net_state=="warning","Entry smoothly arrives at the locked warning position")
		game.fish=game.net_from
		game.fish_before=game.fish
		game._step_net(0.3)
		check(game.net_catches==0,"The waiting net cannot capture a fish before the warning ends")
		check(game.net_from==original_from and game.net_to==original_to and game.net_warning_outline()==outline,"Warning remains fixed when the fish changes direction")
		game.fish=Vector2(50,285)
		game.fish_before=game.fish
		game.net_state="sweep"
		game.net_age=0
		game.net_pos=original_from
		game._step_net(0.1)
		var start_speed: float=game.net_motion.length()
		game.net_age=0.7
		game.net_pos=original_from.lerp(original_to,smoothstep(0,1,0.7/game.NET_SWEEP))
		game._step_net(0.1)
		check(game.net_motion.length()>start_speed*2,"Sweep accelerates instead of moving at one constant speed")
		game.net_age=game.NET_SWEEP
		game.net_pos=original_to
		game._step_net(1.0/60)
		check(game.net_state=="miss" and game.net_dodges==1,"An empty sweep enters one brief miss reaction")
		game._step_net(game.NET_MISS+0.02)
		check(game.net_state=="withdraw","Miss reaction leads into retreat")
		clear=true
		for frame in range(360):
			game._step_net(1.0/60)
			if game._net_contact(game.net_pos): clear=false
			if game.net_state=="rest": break
		check(clear and game.net_pos.y<53 and game.net_state=="rest","Retreat retraces clear water and exits above the surface")
	fresh()
	check(not game._net_reaches_fish(Vector2(338,239),Vector2(290,239)),"Fish inside wood is protected from an inflated catch allowance")
	check(not game._net_reaches_fish(Vector2(370,239),Vector2(300,239)),"The catch allowance cannot reach through wood to its far side")
	check(game._net_reaches_fish(Vector2(490,150),Vector2(510,150)),"Open-water fish remains catchable")
	var capture_times: Array[float]=[]
	for fps in [15,30,60,120]:
		fresh(true)
		game.fish=Vector2(490,150)
		game.request_net()
		for frame in range(fps*8):
			game.step(1.0/fps,Vector2.ZERO,false,false)
			if game.net_state=="caught": break
		check(game.net_state=="caught" and game.net_catch_offset.length()<42,"First impact stays close to the visible rim at "+str(fps)+" Hz")
		capture_times.append(game.elapsed)
		game._step_net(game.NET_SETTLE+0.01)
		check(game.fish.distance_to(game.net_pos+game.net_bag_offset())<1,"Captured fish settles into the rendered bag")
		var old: Vector2=game.fish
		game.menu.open("pause")
		tick(0.5)
		check(game.fish==old,"Pause freezes the bag and fish together")
		game.menu.close()
		tick(4)
		check(game.lost and game.reason=="net" and game.fish.y<53,"Capture finishes only after the fish leaves the water")
	check(capture_times.max()-capture_times.min()<0.12,"Capture timing remains stable across 15 to 120 Hz")
	fresh()
	game.net_from=Vector2(100,150)
	game.net_to=Vector2(540,150)
	game.net_pos=game.net_from
	game.net_angle=0
	game.net_park=Vector2(100,5)
	game.net_state="sweep"
	game.fish_before=Vector2(400,150)
	game.fish=Vector2(100,150)
	game._step_net(0.8)
	check(game.net_catches==1 and game.net_state=="caught" and game.net_catch_offset.length()<42,"A large frame with fish and net crossing cannot tunnel or snap to a distant frame endpoint")
	fresh()
	game.fish=Vector2(490,245)
	game.request_net()
	for frame in range(400):
		game.step(1.0/60,Vector2.ZERO,false,false)
		if game.net_state=="miss": break
	check(game.net_blocked and game.net_state=="miss" and game.net_catches==0,"Wood contact has an explicit blocked-net reaction and does not catch fish behind it")
	game.request_net()
	check(not game.net_queued,"Repeated requests cannot interrupt an active recoil or add duplicate attacks")
	game.reset(false)
	check(game.net_warning_outline().is_empty() and game.net_splash==0 and game.net_motion==Vector2.ZERO,"Restart clears net effects, warning geometry and motion")

func test_supply() -> void:
	fresh(true)
	game.baits[0].grains[0].free = true
	game.baits[0].grains[0].pos = Vector2(200,200)
	game.baits[0].age = 31
	game._step_supply(0.1)
	check(game.cycle_phase == "warning", "Old bait flashes before recall")
	game._step_supply(2.1)
	check(not game.baits[0].active and game.baits[0].grains[0].free, "Recall preserves detached edible grains")
	game._step_supply(5.1)
	check(game.baits[2].active and 0 in game.supply_queue, "Refill rotates in reserve and queues remaining original grains")
	var ids := {}
	var total := 0.0
	for bait in game.baits:
		for grain in bait.grains:
			ids[grain.id] = true
			total += grain.points
	check(ids.size()==176 and absf(total-120)<0.001, "Finite supply has 176 unique grains and 120 points; no infinite refill")

func avoid_net_direction() -> Vector2:
	if game.net_kind=="drop":
		var safe_x: float=clampf(game.net_to.x+(90 if game.net_to.x<520 else -90),35,605)
		return Vector2(signf(safe_x-game.fish.x),0) if absf(safe_x-game.fish.x)>3 else Vector2.ZERO
	var safe_y := 85.0 if game.net_from.y>172 else 285.0
	return Vector2(0,signf(safe_y-game.fish.y)) if absf(safe_y-game.fish.y)>3 else Vector2.ZERO

func swim_to(target: Vector2) -> void:
	for frame in range(1200):
		if game.fish.distance_to(target)<2 or game.won or game.lost: break
		var direction: Vector2 = (target-game.fish).normalized()
		if game.net_state in ["prepare","warning","sweep"]:
			direction = avoid_net_direction()
		game.aim = direction
		game.step(1.0/60,direction,false,false,false,true)
	game.velocity = Vector2.ZERO

func test_round() -> void:
	fresh(true)
	game.water_strength = 1
	# Full round with currents: swim, eat two finite supplies and return without assigning score.
	swim_to(Vector2(90,125))
	swim_to(Vector2(501,125))
	swim_to(Vector2(501,216))
	game.aim = Vector2.RIGHT
	eat_bait(1,24)
	for frame in range(2400):
		if game.baits[3].active: break
		game.step(1.0/60,Vector2.ZERO,false,false)
	eat_bait(3,24)
	check(absf(game.score-60)<0.001 and not game.lost, "Full challenge acquires target from two actual food supplies")
	swim_to(Vector2(501,125))
	swim_to(Vector2(90,125))
	swim_to(game.HOME)
	game.step(1.0/60,Vector2.ZERO,false,true)
	tick(2.1)
	check(game.won and game.reason=="home" and game.menu.screen=="result", "Playable movement + eating + return completes challenge")
	var prior_wins: int = game.wins
	game.finish(true,"home")
	check(game.wins == prior_wins, "Completed round cannot award a win twice")
	fresh(true)
	game.started = true
	game.clock = game.TIME_LIMIT - 0.01
	game.step(1.0/60,Vector2.ZERO,false,false)
	check(game.lost and game.reason=="timeout", "Challenge timeout produces loss")
	fresh(true)
	game.fish = Vector2(232,86)
	game._enter_hook(0)
	game._attach_hook()
	tick(2)
	check(game.lost and game.reason=="landed", "Lingering on hook near surface triggers landing loss")

func test_menus() -> void:
	fresh(true)
	game.menu.open("pause")
	var old: Vector2 = game.fish
	tick(2,Vector2.RIGHT,true)
	check(game.fish == old and game.clock == 0, "Pause stops movement, eating and countdown")
	game.menu.open("help")
	game.menu.first_button.pressed.emit()
	check(game.menu.screen=="pause", "Help returns to its originating pause screen")
	game.menu.close()
	game.menu.open("help")
	game.menu.first_button.pressed.emit()
	check(game.menu.screen=="pause", "In-game H help returns to pause safely")
	game.volume = 0.37
	game.best_score = 61.5
	game.wins = 2
	game.save_profile()
	game.volume = 0.1
	game.best_score = 0
	game.wins = 0
	game._load_profile()
	check(game.save_error==OK and absf(game.volume-0.37)<0.001 and game.wins==2 and game.best_score==61.5, "Settings and records survive a config reload")
	game.menu.open("title")
	game.menu.first_button.pressed.emit()
	check(not game.menu.visible and game.challenge and not game.paused and game.score==0, "Title start button creates a fresh playable challenge")
