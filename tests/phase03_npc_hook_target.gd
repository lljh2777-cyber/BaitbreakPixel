extends SceneTree

# P3.4 authority gate: contact fixtures drive the same swept mouth path as play.
# Outcome fixtures exercise ordinary 60 Hz command/physics; no NPC winner exists.
const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("NPC_HOOK_PASS | ",label)
	else: failed+=1; push_error("NPC_HOOK_FAIL | "+label)

func fixture(mode: String="survival", count: int=1) -> Node2D:
	var world:=World.new()
	world.reset_world({"seed":64317,"ruleset":mode,"challenge":true,"npc_count":count,
		"npc_foraging_enabled":true,"npc_social_enabled":true,"npc_hook_enabled":true,
		"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0}})
	world.fish=Vector2(1050,280); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	for index in world.npc_fishes.size():
		var npc: Dictionary=world.npc_fishes[index]
		npc.position=Vector2(620+index*150,220); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
		npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=State.DECISION_SECONDS
	for bait: Dictionary in world.baits:
		bait.active=false; bait.removed=false; bait.hook=false; bait.tackle=false; bait.suction_offset=Vector2.ZERO
		for grain: Dictionary in bait.grains: grain.eaten=true
	return world

func place_hook(world: Node2D, position: Vector2, slot: int=1) -> void:
	var bait: Dictionary=world.baits[slot]
	bait.active=true; bait.hook=true; bait.removed=false; bait.angle=0.0
	bait.pos=position-Vector2(2,1); bait.home=bait.pos; bait.tip_before=position; bait.suction_offset=Vector2.ZERO

func npc_contact(world: Node2D, index: int=0, slot: int=1) -> void:
	var npc: Dictionary=world.npc_fishes[index]
	place_hook(world,Feeding.mouth(npc.position,npc.aim)+Vector2(npc.aim)*3,slot)
	world._step_bait(slot,0.0,false,world.mouth())

func fresh_food(world: Node2D, position: Vector2, slot: int=0) -> Dictionary:
	var grain: Dictionary=world.baits[slot].grains[0]
	grain.eaten=false; grain.free=true; grain.pos=position; grain.points=1.0
	return grain

func mouth_contact_checks() -> void:
	for condition: String in ["true_contact","safe","removed","inactive","outside","body_only","disabled"]:
		var world:=fixture()
		var npc: Dictionary=world.npc_fishes[0]
		var center:=Feeding.mouth(npc.position,npc.aim)+Vector2(npc.aim)*3
		place_hook(world,center)
		match condition:
			"safe": world.baits[1].hook=false
			"removed": world.baits[1].removed=true
			"inactive": world.baits[1].active=false
			"outside": place_hook(world,center+Vector2(0,world.rule("bite_radius")+0.01))
			"body_only": place_hook(world,npc.position)
			"disabled": world.npc_hook_enabled=false
		var old_rng: int=world.rng.state
		world.advance_tick({},{})
		var attached: bool=world.hook_target_fish_id==int(npc.fish_id)
		check(attached==(condition=="true_contact"),"real mouth-contact eligibility: "+condition)
		check(world.hooked==World.HookState.FREE and world.hook_count==0 and world.round_stats.hook_events==0,"NPC contact never aliases player HookState or counters: "+condition)
		if attached:
			check(npc.behavior_state=="HOOKED" and world.npc_hook.phase=="hooked" and world.round_stats.npc_hook_count==1,"physical NPC contact directly attaches and records exactly one NPC event")
			check(world.qte.is_empty() and world.qte_id==0 and world.rng.state==old_rng,"NPC attachment creates no player QTE or main RNG draw")
			check(world.public_hook_cue.tick==world.simulation_tick and world.public_npc_hook_result.result=="hooked","actual attachment emits only realized social/result evidence")
		world.free()
	var swept:=fixture()
	var npc: Dictionary=swept.npc_fishes[0]
	var center:=Feeding.mouth(npc.position,npc.aim)+Vector2(npc.aim)*3
	place_hook(swept,center+Vector2(24,0)); swept.baits[1].tip_before=center-Vector2(24,0)
	check(swept.baits[1].tip_before.distance_to(center)>swept.rule("bite_radius") and swept._tip(1).distance_to(center)>swept.rule("bite_radius"),"swept fixture has both hook endpoints outside contact radius")
	swept._step_bait(1,0.0,false,swept.mouth())
	check(swept.hook_target_fish_id==npc.fish_id,"continuous relative swept hook crossing catches NPC without endpoint overlap")
	swept.free()
	var moving:=fixture()
	var swimmer: Dictionary=moving.npc_fishes[0]
	var old_mouth:=Feeding.mouth(swimmer.position,swimmer.aim)
	place_hook(moving,old_mouth+Vector2(23,0))
	swimmer.position+=Vector2(40,0)
	var previous: Dictionary={int(swimmer.fish_id):old_mouth}
	var pending: Array[Dictionary]=[]
	moving._step_bait(1,0.0,false,moving.mouth(),false,pending,previous)
	check(moving.hook_target_fish_id==swimmer.fish_id,"relative sweep also catches a moving NPC crossing a stationary hook")
	moving.free()
	for direction: Vector2 in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		var rotated:=fixture()
		rotated.npc_fishes[0].aim=direction; rotated.npc_fishes[0].intent_aim=direction
		npc_contact(rotated)
		check(rotated.hook_target_fish_id==2,"NPC mouth contact uses rotated shared geometry: "+str(direction))
		rotated.free()

func target_discrimination() -> void:
	var world:=fixture("survival",2)
	world.npc_fishes[1].position=world.npc_fishes[0].position
	world.npc_fishes.reverse()
	npc_contact(world,0)
	check(world.hook_target_fish_id==2,"simultaneous NPC contacts choose stable fish ID rather than array order")
	var target: Dictionary=world.npc_by_id(2)
	var other: Dictionary=world.npc_by_id(3)
	check(target.behavior_state=="HOOKED" and other.behavior_state!="HOOKED","only the selected NPC enters hooked authority")
	world.fish=Vector2(400,300); target.position+=Vector2(33,-12); world._rebuild_rope()
	check(world.hook_target_mouth()==Feeding.mouth(target.position,target.aim) and world.rope_path[-1]==world.hook_target_mouth(),"line endpoint follows selected NPC mouth after movement and array reorder")
	check(world.rope_path[-1]!=world.mouth() and world._tip(1)==world.hook_target_mouth(),"hook visual point and rope endpoint cannot latch onto free player")
	place_hook(world,Feeding.mouth(other.position,other.aim)+Vector2(other.aim)*3,3)
	world._step_bait(3,0.0,false,world.mouth())
	check(world.hook_target_fish_id==2 and world.bound_bait==1 and world.round_stats.npc_hook_count==1,"one global line cannot be stolen by second NPC contact")
	world._enter_hook(3)
	check(world.hook_target_fish_id==2 and world.hooked==World.HookState.FREE,"player entry guard cannot overwrite an occupied NPC line")
	world.free()
	world=fixture()
	world.fish=world.npc_fishes[0].position; world.fish_before=world.fish; world.aim=Vector2.RIGHT
	npc_contact(world)
	check(world.hook_target_fish_id==1 and world.hooked==World.HookState.MOUTH and world.qte=="entry","simultaneous player/NPC contact preserves player entry QTE priority")
	world._attach_hook()
	check(world.hook_target_fish_id==1 and world.hooked==World.HookState.HOOKED and world.round_stats.hook_events==1 and world.round_stats.npc_hook_count==0,"player attachment keeps distinct original player counters and path")
	world._release_hook(false)
	check(world.hook_target_fish_id==-1 and world.hooked==World.HookState.FREE and world.escape_count==1,"existing player release clears target and keeps player escape count")
	world.free()

func independent_player() -> void:
	var world:=fixture(); npc_contact(world)
	var npc_id: int=world.hook_target_fish_id
	var origin: Vector2=world.fish
	var grain:=fresh_food(world,world.mouth()+Vector2(2,0))
	world.advance_tick({"move":Vector2.LEFT},{})
	check(grain.eaten and world.score==1.0 and world.hook_target_fish_id==npc_id,"free player genuinely eats and scores while NPC owns hook")
	for tick in 20: world.advance_tick({"move":Vector2.LEFT},{})
	check(world.fish.x<origin.x-2 and not world.movement_locked() and world.line_pull_velocity()==Vector2.ZERO,"NPC pull never locks, drags or exhausts the player movement state")
	var hooked_food:=fresh_food(world,world.hook_target_mouth(),2)
	world._step_npc_feeding(World.TICK_SECONDS)
	check(not hooked_food.eaten and not world.npc_by_id(npc_id).feeding,"hooked NPC is excluded from automatic Bite and Suck authority")
	world.fish=world.HOME; world.fish_before=world.fish; world.velocity=Vector2.ZERO; world.score=world.food_target()
	check(world.can_home(),"player HOME remains eligible while another fish owns the line")
	world.advance_tick({"home":true},{})
	for tick in int(ceil(world.rule("home_hold")/World.TICK_SECONDS))+3:
		world.advance_tick({},{})
	check(world.match_over and world.winner_role=="fish" and world.reason=="home","player can complete normal HOME victory during NPC hook handling")
	world.free()

func spool_and_rng() -> void:
	var reel:=fixture("duel"); var release:=fixture("duel")
	for world in [reel,release]: npc_contact(world)
	var initial: float=reel.rope_length
	for tick in 20:
		reel.advance_tick({}, {"reel":true}); release.advance_tick({}, {"release":true})
	check(reel.rope_length<initial and release.rope_length>initial and reel.reel_speed<0 and release.reel_speed>0,"normal W/S actuator shortens/pays out the NPC line without a custom command")
	check(reel.angler.feedback_reel_speed(reel)<0 and release.angler.feedback_reel_speed(release)>0,"real actuator feedback follows NPC reeling direction")
	check(reel.npc_fishes[0].position!=Vector2(620,220) and reel.qte.is_empty() and release.qte.is_empty(),"NPC automatically struggles under real movement without player QTE")
	reel.free(); release.free()
	var a:=fixture(); var b:=fixture()
	var before: int=a.rng.state
	npc_contact(a)
	for tick in 60: a.NPCHook.step(a,World.TICK_SECONDS)
	a.NPCHook.release(a,false)
	check(a.rng.state==before and b.rng.state==before and a.qte_id==0,"NPC attach/automatic struggle/release leaves Hook/QTE RNG untouched")
	a._open_qte("entry"); b._open_qte("entry")
	check(a.qte_zone==b.qte_zone and a.rng.state==b.rng.state,"next randomized player QTE is identical after NPC-only handling")
	a.free(); b.free()
	var replacement:=fixture(); npc_contact(replacement)
	replacement.NPCHook.capture(replacement)
	var rng_before: int=replacement.rng.state
	# Isolate replacement from legitimate fresh-bait lifecycle RNG consumption.
	replacement.NPCHook.respawn(replacement,State.RESPAWN_SECONDS)
	check(replacement.npc_fishes[0].fish_id==3 and replacement.rng.state==rng_before,"NPC delayed replacement itself consumes no main Hook/QTE RNG")
	replacement.free()

func escape_break_capture() -> void:
	for broken: bool in [false,true]:
		var world:=fixture()
		# A forced taut line needs >3 s of water travel to test the break timer,
		# otherwise faster NPC retrieval legitimately reaches shore first.
		if broken: world.npc_fishes[0].position=Vector2(620,440)
		npc_contact(world)
		var identity: int=world.hook_target_fish_id
		world.rope_length=0.0 if broken else world.rule("line_max")
		var player: Vector2=world.fish
		for tick in 360:
			world.advance_tick({}, {})
			if world.hook_target_fish_id<0: break
		check(world.hook_target_fish_id==-1 and world.npc_hook.phase.is_empty() and world.bound_bait==-1 and world.rope_path.is_empty(),"real sustained "+("high tension breaks" if broken else "slack escapes")+" and clears single line")
		var npc: Dictionary=world.npc_by_id(identity)
		check(npc.active and npc.behavior_state=="WANDER" and npc.hook_immunity>0,"resolved NPC rejoins ecology with contact immunity")
		check(world.round_stats["npc_breaks" if broken else "npc_escapes"]==1 and world.round_stats.wrong_catches==0,"NPC resolution increments only its actual outcome counter")
		check(world.public_npc_hook_result.result==("broken" if broken else "escaped") and world.baits[1].removed==broken,"public realized outcome and bait lifecycle distinguish escape/break")
		if not broken:
			npc_contact(world)
			check(world.hook_target_fish_id==-1 and world.round_stats.npc_hook_count==1,"post-escape contact immunity prevents same-mouth immediate rehook")
		check(not world.match_over and world.winner_role.is_empty() and world.fish==player and world.escape_count==0 and world.round_stats.breaks==0 and world.round_stats.slips==0,"NPC resolution never declares winner or pollutes player escape history")
		world.free()
	var world:=fixture(); npc_contact(world)
	var identity: int=world.hook_target_fish_id
	var npc: Dictionary=world.npc_by_id(identity)
	npc.position=Vector2(world.line_anchor(1).x-10,80); npc.velocity=Vector2.ZERO
	world.rope_length=world.line_anchor(1).distance_to(world.hook_target_mouth())
	var saw_landing:=false
	for tick in 360:
		world.advance_tick({}, {"auto_reel":true})
		saw_landing=saw_landing or world.npc_hook.phase=="landing"
		if not npc.active: break
	check(saw_landing and not npc.active and npc.behavior_state=="CAPTURED","ordinary reel/shore hold/lift traverses NPC landing and capture")
	check(world.round_stats.wrong_catches==1 and world.hook_target_fish_id==-1 and not world.baits[1].active and world.baits[1].removed,"wrong catch removes active NPC and used tackle, releases line")
	check(not world.match_over and world.winner_role.is_empty() and world.line_catches==0 and world.score==0,"NPC landing cannot end match, award player food, or count as player landing")
	check(npc.respawn_age>0 and npc.respawn_age<=State.RESPAWN_SECONDS,"captured NPC starts bounded delayed replacement")
	var allocator: int=world.next_fish_id
	for tick in 60: world.advance_tick({}, {})
	check(not world.npc_by_id(identity).is_empty() and not world.npc_by_id(identity).active and world.next_fish_id==allocator,"captured identity stays absent from active ecology before delay")
	for tick in int(ceil(State.RESPAWN_SECONDS/World.TICK_SECONDS))+5: world.advance_tick({}, {})
	check(world.npc_by_id(identity).is_empty() and world.npc_fishes.size()==1 and world.npc_fishes[0].active and world.npc_fishes[0].fish_id>=allocator and world.next_fish_id>allocator,"replacement restores population using a fresh, never-reused stable ID")
	check(not world.match_over and world.winner_role.is_empty(),"match continues through capture, wait and replacement")
	world.free()

func pause_and_terminal() -> void:
	for phase: String in ["hooked","landing","captured"]:
		var world:=fixture(); npc_contact(world)
		if phase=="landing":
			world.npc_hook.phase="landing"; world.npc_hook.landing_from=world.npc_fishes[0].position
			world.npc_fishes[0].behavior_state="LANDING"
		elif phase=="captured": world.NPCHook.capture(world)
		world.match_paused=true
		var frozen: Dictionary=world.capture_snapshot()
		for tick in 12: world.advance_tick({}, {"reel":true})
		check(world.capture_snapshot()==frozen,"pause freezes NPC "+phase+" progress, line and replacement timers")
		world.match_paused=false; world.match_over=true; world.winner_role="fish"; world.reason="home"
		frozen=world.capture_snapshot()
		for tick in 12: world.advance_tick({}, {"reel":true})
		check(world.capture_snapshot()==frozen,"terminal player match freezes NPC "+phase+" without changing result")
		world.free()

func pre_contact_privacy() -> void:
	var safe:=fixture(); var hooked:=fixture()
	for world in [safe,hooked]:
		place_hook(world,Vector2(720,220)); world.baits[1].hook=world==hooked
		fresh_food(world,Vector2(700,220),1)
	var equal:=true
	for tick in 12:
		equal=equal and Observation.build_social_for(safe,State.observer(safe.npc_fishes[0],safe.rules),false)==Observation.build_social_for(hooked,State.observer(hooked.npc_fishes[0],hooked.rules),false)
		equal=equal and FishWire.capture(safe)==FishWire.capture(hooked) and AnglerWire.capture(safe).state.npc_fishes==AnglerWire.capture(hooked).state.npc_fishes
		safe.advance_tick({},{}); hooked.advance_tick({},{})
		equal=equal and safe.npc_fishes==hooked.npc_fishes
	check(equal and safe.hook_target_fish_id==-1 and hooked.hook_target_fish_id==-1,"enabled NPC Hook preserves exact pre-contact perception, fish payload, angler NPC projection and NPC decisions under opposing hidden truth")
	safe.free(); hooked.free()

func _initialize() -> void:
	mouth_contact_checks(); target_discrimination(); independent_player(); spool_and_rng(); escape_break_capture(); pause_and_terminal(); pre_contact_privacy()
	print("PHASE03_NPC_HOOK_TARGET_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
