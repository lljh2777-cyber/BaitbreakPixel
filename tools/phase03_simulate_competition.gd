extends SceneTree

# Real 60 Hz, paired population experiment. The player receives the unchanged
# P2 Mixed detached observation; authority reads here are instrumentation only.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")
const MODES: Array[String]=["NoNPC","PassiveNPC","ForagingNPC"]
const VERSION:=1

func _initialize() -> void:
	var count:=4
	var first_seed:=43001
	var max_ticks:=22200
	var output:="res://artifacts/phase03-competition"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): first_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--max-ticks="): max_ticks=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.substr(9)
	if count<1 or count>1000 or max_ticks<1 or max_ticks>108600:
		push_error("Invalid NPC experiment bounds"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Cannot create NPC experiment output"); quit(2); return
	var started:=Time.get_ticks_msec()
	var rows: Array=[]
	for index in count:
		for mode: String in MODES:
			var row:=run_round(first_seed+index,mode,max_ticks)
			rows.append(row)
			print("NPC_COMPARISON_PROGRESS | seed=%d mode=%s food=%.3f npc_food=%.3f hooks=%d duration=%.3f winner=%s reason=%s" % [row.seed,mode,row.player_food,row.npc_food,row.hook_events,row.duration,row.winner,row.reason])
			if not save_json(output.path_join("rounds.json"),rows): quit(2); return
	var summary: Dictionary={"format":"phase03-competition-v1","paired_seeds":count,"first_seed":first_seed,"last_seed":first_seed+count-1,
		"modes":MODES,"tick_seconds":World.TICK_SECONDS,"max_ticks":max_ticks,"controller":"unchanged P2 Mixed", "controller_version":Policy.VERSION,
		"rules":"unmodified default survival challenge","harness_version":VERSION,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"definitions":{"player":"Only detached FishObservation enters the P2 Mixed player. No hidden hook/QTE escape adapter; qte remains false.",
			"angler":"Existing survival AnglerBrain, unchanged across paired modes.","lifecycle_events":"New BAIT_CREATED identities after the four initial slots, measured from next_bait_id growth.",
			"lifecycle_per_sim_minute":"60 times lifecycle_events divided by actual simulation elapsed seconds.",
			"censoring":"All rounds retained; max-tick unfinished rounds explicitly incomplete and are not treated as completed losses.",
			"npc_hook_count":"Not implemented until P3.4; recorded as null, not measured zero.","wrong_catches":"Not implemented until P3.4; recorded as null, not measured zero."},
		"limit":"Diagnostic autonomous-policy comparison, not a human win-rate or full food-reachability guarantee. No balancing to 50 percent and no seed/outcome filtering."}
	if not save_json(output.path_join("summary.json"),summary): quit(2); return
	print("NPC_COMPARISON_SUMMARY | ",JSON.stringify(summary)); quit()

func run_round(seed_value: int, mode: String, max_ticks: int) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival","npc_count":0 if mode=="NoNPC" else 3,"npc_foraging_enabled":mode=="ForagingNPC"})
	var controller:=Policy.new(); controller.reset("Mixed",world.rules)
	var opponent:=Opponent.new()
	var initial_allocator: int=world.next_bait_id
	var goal: float=world.food_target()
	var states: Dictionary={"WANDER":0,"APPROACH_FOOD":0,"FEED":0}
	var no_food_ticks:=0
	var longest_no_food_ticks:=0
	var current_no_food_ticks:=0
	var total_available_food_min:=INF
	var last_score:=0.0
	var stalled_ticks:=0
	var longest_stalled_ticks:=0
	var visits: Dictionary={}
	for frame in max_ticks:
		var observation:=Observation.build(world,false)
		var command: Dictionary=controller.command(observation,World.TICK_SECONDS)
		world.advance_tick(command,opponent.command(world,World.TICK_SECONDS))
		for npc: Dictionary in world.npc_fishes:
			if npc.active:
				states[npc.behavior_state]=int(states.get(npc.behavior_state,0))+1
				if npc.target_bait_id>=0: visits[int(npc.target_bait_id)]=true
		var food:=available_food(world)
		total_available_food_min=minf(total_available_food_min,food)
		if food<=0.000001:
			no_food_ticks+=1; current_no_food_ticks+=1
			longest_no_food_ticks=maxi(longest_no_food_ticks,current_no_food_ticks)
		else: current_no_food_ticks=0
		if world.score>last_score+0.000001: stalled_ticks=0
		else: stalled_ticks+=1
		longest_stalled_ticks=maxi(longest_stalled_ticks,stalled_ticks)
		last_score=world.score
		if not is_equal_approx(world.food_target(),goal):
			push_error("Player goal changed during competition"); world.free(); quit(3); return {}
		if world.match_over: break
	var lifecycle_events: int=world.next_bait_id-initial_allocator
	var stats: Dictionary=world.round_stats.duplicate(true)
	var row: Dictionary={"seed":seed_value,"mode":mode,"ticks":world.simulation_tick,"duration":world.elapsed,
		"completed":world.match_over,"winner":world.winner_role,"reason":world.reason,"home_win":world.winner_role=="fish" and world.reason=="home",
		"food_goal":goal,"player_food":world.score,"player_food_by_type":stats.food_by_type,"satiety_final":world.satiety,
		"satiety_mean":stats.satiety_mean,"satiety_min":stats.satiety_min,"hook_events":stats.hook_events,"hook_contacts":world.hook_count,
		"npc_food":float(stats.get("npc_food_consumed",0.0)),"npc_food_by_type":stats.get("npc_food_by_type",{}),
		"npc_feeding_events":int(stats.get("npc_feeding_events",0)),"player_npc_food_contests":int(stats.get("player_npc_food_contests",0)),
		"npc_target_switches":int(stats.get("npc_target_switches",0)),"npc_hook_count":null,"wrong_catches":null,
		"lifecycle_events":lifecycle_events,"lifecycle_per_sim_minute":60.0*lifecycle_events/maxf(0.000001,world.elapsed),
		"npc_state_seconds":{},"npc_distinct_target_ids":visits.size(),"no_food_seconds":no_food_ticks*World.TICK_SECONDS,
		"longest_no_food_seconds":longest_no_food_ticks*World.TICK_SECONDS,"longest_player_no_intake_seconds":longest_stalled_ticks*World.TICK_SECONDS,
		"minimum_available_food":total_available_food_min,"stats":stats}
	for state in states: row.npc_state_seconds[state]=int(states[state])*World.TICK_SECONDS
	world.free()
	return row

func available_food(world: Node2D) -> float:
	var total:=0.0
	for bait: Dictionary in world.baits:
		for grain: Dictionary in bait.grains:
			if not grain.eaten and (bait.active or grain.free): total+=float(grain.points)
	return total

func save_json(path: String, value: Variant) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("Cannot write "+path); return false
	file.store_string(JSON.stringify(value,"\t")); file.close(); return true
