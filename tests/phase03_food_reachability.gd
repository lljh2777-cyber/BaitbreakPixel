extends SceneTree

# Structural supply gate, deliberately separate from the autonomous policy study.
# Worst-case setup assigns every visible grain to NPCs through shared authority
# intake, then exhausts three additional refills. Only the existing lifecycle is
# advanced (60 Hz); new food is never injected and goals are never reduced.
# A controlled mouth-placement witness then claims later real grains for the
# player. This proves resource availability after depletion, NOT that a live
# player can always outrun competitors, escape hooks or win before starvation.
const World=preload("res://scripts/world_simulation.gd")
const Rules=preload("res://scripts/game_rules.gd")
const SEEDS:=1000
const FIRST_SEED:=51001
const OUTPUT:="res://artifacts/phase03-food-reachability.json"
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("FOOD_REACHABILITY_FAIL | "+label)

func available_food(world: Node2D) -> float:
	var total:=0.0
	for bait: Dictionary in world.baits:
		for grain: Dictionary in bait.grains:
			if not grain.eaten and (bait.active or grain.free): total+=float(grain.points)
	return total

func exhaust_to_npcs(world: Node2D) -> float:
	var taken:=0.0
	var actor:=0
	for bait: Dictionary in world.baits:
		for grain: Dictionary in bait.grains:
			if grain.eaten or (not bait.active and not grain.free): continue
			var npc: Dictionary=world.npc_fishes[actor%world.npc_fishes.size()]
			# This is an adversarial authority fixture, not an AI movement model.
			world._consume_grain(grain,false,"suck",npc)
			taken+=float(grain.points); actor+=1
	return taken

func refill_until_food(world: Node2D) -> int:
	# Existing warning=2 s + configured refill + one transition tick, per
	# exhausted active slot. A small finite transition allowance is explicit.
	var limit:=int(ceil((2.0+world.rule("bait_refill")+1.0)*60.0))
	for tick in limit:
		world._step_supply(World.TICK_SECONDS)
		if available_food(world)>0.000001: return tick+1
	return -1

func player_claim_visible(world: Node2D) -> float:
	var before: float=world.score
	var guard:=0
	while available_food(world)>0.000001 and guard<250:
		var target: Dictionary={}
		for bait: Dictionary in world.baits:
			for grain: Dictionary in bait.grains:
				if not grain.eaten and (bait.active or grain.free): target=grain; break
			if not target.is_empty(): break
		if target.is_empty(): break
		# Shared mouth geometry/range/profile are used. We intentionally do not
		# simulate travel or hook contact in this structural resource witness.
		world.aim=Vector2.RIGHT; world.fish=Vector2(target.pos)-Vector2(10,0); world.fish_before=world.fish
		world.bite_cooldown=0.0
		if not world._attempt_bite(): break
		guard+=1
	return world.score-before

func run_case(seed_value: int, ruleset: String, challenge: bool) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"ruleset":ruleset,"challenge":challenge,"npc_count":6,"npc_foraging_enabled":true})
	var goal: float=world.food_target()
	var rule_goal: float=world.rule("food_goal")
	var initial_bait_id: int=world.next_bait_id
	var npc_food:=exhaust_to_npcs(world)
	var truly_empty:=available_food(world)<=0.000001
	var replenished:=true
	var max_empty_ticks:=0
	var lifecycle_count:=0
	var supply_ticks:=0
	var types: Dictionary={}
	for cycle in 3:
		var previous_id: int=world.next_bait_id
		var ticks:=refill_until_food(world)
		if ticks<0: replenished=false; break
		max_empty_ticks=maxi(max_empty_ticks,ticks); supply_ticks+=ticks
		if world.next_bait_id<=previous_id: replenished=false
		lifecycle_count+=world.next_bait_id-previous_id
		for bait: Dictionary in world.baits:
			if bait.active and world._remaining(bait): types[bait.bait_type]=true
		npc_food+=exhaust_to_npcs(world)
	# Two default 30-point baits suffice for the unchanged 60-point challenge;
	# allow more cycles so unusual legal goals/budgets cannot pass accidentally.
	for cycle in 8:
		if world.score+0.000001>=goal: break
		var previous_id: int=world.next_bait_id
		var ticks:=refill_until_food(world)
		if ticks<0: replenished=false; break
		max_empty_ticks=maxi(max_empty_ticks,ticks); supply_ticks+=ticks
		lifecycle_count+=world.next_bait_id-previous_id
		if world.next_bait_id<=previous_id: replenished=false
		if player_claim_visible(world)<=0.0: replenished=false; break
	var row: Dictionary={"seed":seed_value,"ruleset":ruleset,"challenge":challenge,"npc_count":world.npc_fishes.size(),
		"goal":goal,"final_goal":world.food_target(),"default_food_goal":rule_goal,"final_food_goal":world.rule("food_goal"),
		"initial_supply_exhausted":truly_empty,"supply_resumed_each_time":replenished,"player_food":world.score,
		"npc_food":npc_food,"recorded_npc_food":world.round_stats.npc_food_consumed,
		"goal_reachable_witness":world.score+0.000001>=goal,"lifecycle_events":lifecycle_count,
		"all_created_id_growth":world.next_bait_id-initial_bait_id,"max_empty_supply_ticks":max_empty_ticks,
		"supply_ticks":supply_ticks,"observed_types":types.keys(),"no_forced_match_end":not world.match_over}
	world.free()
	return row

func _initialize() -> void:
	var rows: Array=[]
	var defaults:=Rules.defaults()
	var began:=Time.get_ticks_msec()
	var configurations: Array=[]
	for ruleset: String in ["survival","duel"]:
		for challenge: bool in [true,false]:
			var summary: Dictionary={"ruleset":ruleset,"challenge":challenge,"seeds":SEEDS,"failed_seeds":[],
				"max_empty_supply_ticks":0,"minimum_player_food":INF,"minimum_npc_food":INF,"minimum_lifecycle_events":1000000}
			var all_empty:=true; var all_resumed:=true; var all_goal:=true; var all_unchanged:=true; var all_ownership:=true; var all_lifecycle:=true
			for offset in SEEDS:
				var row:=run_case(FIRST_SEED+offset,ruleset,challenge)
				rows.append(row)
				all_empty=all_empty and row.initial_supply_exhausted
				all_resumed=all_resumed and row.supply_resumed_each_time
				all_goal=all_goal and row.goal_reachable_witness
				all_unchanged=all_unchanged and row.goal==row.final_goal and row.default_food_goal==defaults.food_goal and row.final_food_goal==defaults.food_goal
				all_ownership=all_ownership and is_equal_approx(row.npc_food,row.recorded_npc_food) and row.npc_food>0.0
				all_lifecycle=all_lifecycle and row.lifecycle_events>=4 and row.no_forced_match_end and row.npc_count==6
				if not row.supply_resumed_each_time or not row.goal_reachable_witness: summary.failed_seeds.append(row.seed)
				summary.max_empty_supply_ticks=maxi(summary.max_empty_supply_ticks,row.max_empty_supply_ticks)
				summary.minimum_player_food=minf(summary.minimum_player_food,row.player_food)
				summary.minimum_npc_food=minf(summary.minimum_npc_food,row.npc_food)
				summary.minimum_lifecycle_events=mini(summary.minimum_lifecycle_events,row.lifecycle_events)
			var label:="%s %s / 1000 seeds" % [ruleset,"challenge" if challenge else "practice"]
			check(all_empty,"every scenario actually starts with visible food exhausted by NPC authority: "+label)
			check(all_resumed,"three repeated NPC depletion cycles and player cycles each renew real food: "+label)
			check(all_goal,"controlled shared-mouth witness obtains unchanged target after competition: "+label)
			check(all_unchanged,"default food_goal never lowered for NPC consumption: "+label)
			check(all_ownership,"NPC physical grain depletion reconciles with NPC-only statistics: "+label)
			check(all_lifecycle,"at least four fresh identities with all six competitors and no forced result: "+label)
			configurations.append(summary)
			print("FOOD_REACHABILITY_CONFIG | ",JSON.stringify(summary))
	var report: Dictionary={"format":"phase03-food-supply-gate-v1","first_seed":FIRST_SEED,"last_seed":FIRST_SEED+SEEDS-1,
		"distinct_seeds":SEEDS,"configurations":configurations,"scenario_count":rows.size(),"tick_seconds":World.TICK_SECONDS,
		"assertion_count_basis":"24 aggregate invariants over 4000 fully retained scenario rows, plus artifact write; tick/seed loops are not inflated assertion counts.",
		"method":"Adversarial initial and three repeated all-visible-food NPC depletion via shared authority intake. Advance existing warning/refill/redeploy lifecycle at 60 Hz until real new identities and edible food appear. Shared automatic Bite with controlled player mouth placement and reset cooldown claims replenished real food to unchanged goal. No new food injection, private hook selection, goal reduction, timer acceleration or forced winner.",
		"limitations":"Structural supply and ownership witness only. Does not advance travel, live competing AI, hunger, hook contact or escape; player claim cooldown is reset in the resource witness. This does not prove every real-time player policy can win; separate autonomous paired experiment and human playtest are required.",
		"wall_seconds":(Time.get_ticks_msec()-began)/1000.0,"rows":rows}
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	check(file!=null,"complete 4000-scenario artifact writable")
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FOOD_REACHABILITY_ARTIFACT | "+OUTPUT)
	print("PHASE03_FOOD_REACHABILITY_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
