extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Layout=preload("res://scripts/pond_layout.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_AMBIENT_FAIL | "+label)

func unchanged_legacy(world: Node2D) -> Dictionary:
	var result: Dictionary=world.capture_snapshot()
	result.state.erase("npc_fishes"); result.state.erase("next_fish_id")
	return result

func patrol_checks() -> void:
	for seed_value: int in [1,3184,99173]:
		var w:=World.new(); w.reset_world({"seed":seed_value,"npc_count":6,"ruleset":"duel","rules":{"timer_enabled":false,"hunger_enabled":false}})
		var start: Array[Dictionary]=w.npc_fishes.duplicate(true)
		var movement_ticks:=0; var decision_ticks:=0
		for tick in 10800:
			var before: Dictionary=w.npc_fishes[0].duplicate(true)
			w.advance_tick({}, {})
			if w.npc_fishes[0].position!=before.position: movement_ticks+=1
			if w.npc_fishes[0].decision_age>before.decision_age: decision_ticks+=1
			for npc: Dictionary in w.npc_fishes:
				check(State.valid(npc,w.next_fish_id),"long patrol remains finite, normalized, in bounds, and WANDER-only seed=%d tick=%d id=%d" % [seed_value,tick,npc.fish_id])
		check(movement_ticks>10700,"NPC motion integrates each 60 Hz authority tick")
		check(decision_ticks>1100 and decision_ticks<1600,"brain updates are slower than motion at approximately 0.12 seconds")
		check(not w.match_over and w.npc_fishes.size()==6,"180-second ambient run does not alter match results or population")
		for index in 6: check(start[index].position.distance_to(w.npc_fishes[index].position)>10,"each NPC performs an actual patrol")
		w.free()

func freeze_checks() -> void:
	var w:=World.new(); w.reset_world()
	for tick in 20: w.advance_tick({}, {})
	w.npc_fishes[0].active=false
	var inactive: Dictionary=w.npc_fishes[0].duplicate(true)
	for tick in 60: w.advance_tick({}, {})
	check(inactive==w.npc_fishes[0],"inactive NPC freezes all motion, timers and local RNG")
	w.match_paused=true
	var paused: Dictionary=w.capture_snapshot()
	for tick in 120:
		w.advance_tick({"move":Vector2.RIGHT},{"release":true})
		w.step(1.0/60,Vector2.LEFT,true,true)
	check(paused==w.capture_snapshot(),"pause freezes NPCs and all scalar authority for modern and compatibility tick paths")
	w.match_paused=false; w.finish(false,"ambient freeze test")
	var ended: Dictionary=w.capture_snapshot()
	for tick in 120:
		w.advance_tick({}, {}); w.step(1.0/60,Vector2.RIGHT,false,false)
	check(ended==w.capture_snapshot(),"finished match freezes all NPC state and both tick paths")
	w.free()

func separation_checks() -> void:
	var w:=World.new(); w.reset_world({"npc_count":1})
	w.fish=Vector2(650,200)
	var npc: Dictionary=w.npc_fishes[0]
	npc.position=Vector2(655,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.LEFT
	npc.wander_heading=Vector2.LEFT; npc.steering=Vector2.LEFT; npc.turn_age=2.0; npc.decision_age=0.0
	var before:=unchanged_legacy(w)
	w._tick_npc_fishes(1.0/60)
	check(npc.steering.x>0,"close player avoidance overrides heading toward player")
	check(unchanged_legacy(w)==before,"avoidance cannot push player or affect player authority")
	w.reset_world({"npc_count":2})
	for entry: Dictionary in w.npc_fishes:
		entry.position=Vector2(700,200); entry.velocity=Vector2.ZERO; entry.aim=Vector2.UP
		entry.wander_heading=Vector2.UP; entry.steering=Vector2.UP; entry.turn_age=2.0; entry.decision_age=0.0
	for tick in 180: w._tick_npc_fishes(1.0/60)
	check(w.npc_fishes[0].position.distance_to(w.npc_fishes[1].position)>20,"coincident NPCs deterministically separate without an index-based identity")
	w.free()

func harmless_contact_checks() -> void:
	for hooked_food: bool in [false,true]:
		var w:=World.new(); w.reset_world({"npc_count":1,"ruleset":"duel","rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0}})
		var npc: Dictionary=w.npc_fishes[0]
		npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.steering=Vector2.RIGHT
		for bait: Dictionary in w.baits:
			bait.active=false
			for grain: Dictionary in bait.grains: grain.eaten=true
		var bait: Dictionary=w.baits[1]
		bait.active=true; bait.hook=hooked_food; bait.pos=npc.position; bait.home=npc.position; bait.angle=0.0; bait.tip_before=bait.pos+Vector2(2,1)
		var grain: Dictionary=bait.grains[0]
		grain.eaten=false; grain.free=false; grain.offset=Vector2.ZERO; grain.pos=npc.position
		var old_hook: bool=bait.hook; var old_rng: int=w.rng.state
		for tick in 60: w.advance_tick({}, {})
		check(not grain.eaten and w.score==0 and w.satiety==100,"NPC contact cannot consume food or award player nutrition")
		check(w.hooked==w.HookState.FREE and w.hook_count==0 and w.hook_target_fish_id==-1,"NPC contact cannot enter player Hook/QTE")
		check(bait.hook==old_hook and w.rng.state==old_rng,"NPC contact cannot alter hook assignment or world RNG")
		check(not w.match_over and w.round_stats.food_consumed==0 and w.round_stats.hook_events==0,"NPC contact cannot trigger scoring, hook statistics or match end")
		w.free()

func _initialize() -> void:
	patrol_checks(); freeze_checks(); separation_checks(); harmless_contact_checks()
	print("PHASE03_NPC_AMBIENT_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
