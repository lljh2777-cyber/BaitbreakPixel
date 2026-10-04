extends SceneTree

# P3.5 offline matrix. Metrics never enter actor inputs.
# Preserve production defaults and the three existing observation-only policies.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")
const MODES: Array[String]=["NoNPC","PassiveNPC","ForagingNPC","HookableNPC"]
const VERSION:=1

func _initialize() -> void:
	var count:=8
	var first_seed:=73501
	var max_ticks:=22200
	var output:="res://artifacts/p35-ecology-diagnostics"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): first_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--max-ticks="): max_ticks=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.substr(9)
	if count<1 or count>1000 or max_ticks<1 or max_ticks>108600:
		push_error("Invalid four-arm experiment bounds"); quit(2); return
	if FileAccess.file_exists(output.path_join("rounds.json")) or FileAccess.file_exists(output.path_join("summary.json")):
		push_error("Refusing to overwrite diagnostic evidence"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Cannot create diagnostic output"); quit(2); return
	var rows: Array=[]
	var started:=Time.get_ticks_msec()
	for index in count:
		for game_mode: String in ["survival","duel"]:
			for challenge_mode: bool in [true,false]:
				for policy_name: String in Policy.POLICIES:
					for mode: String in MODES:
						var row:=run_round(first_seed+index,mode,max_ticks,game_mode,challenge_mode,policy_name)
						if row.is_empty(): quit(3); return
						rows.append(row)
						print("ECOLOGY_PROGRESS | seed=%d stratum=%s mode=%s food=%.3f npc_food=%.3f npc_hooks=%d catches=%d duration=%.3f winner=%s reason=%s" % [row.seed,row.stratum_key,mode,row.player_food,row.npc_food,row.npc_hook_count,row.wrong_catches,row.duration,row.winner,row.reason])
						if not save_json(output.path_join("rounds.json"),rows): quit(2); return
	var summary: Dictionary={"format":"phase03-ecology-diagnostics-v1","harness_version":VERSION,
		"paired_seeds":count,"first_seed":first_seed,"last_seed":first_seed+count-1,"modes":MODES,
		"tick_seconds":World.TICK_SECONDS,"max_ticks":max_ticks,"policies":Policy.POLICIES,
		"strata_per_seed":12,"rows":rows.size(),"controller_version":Policy.VERSION,
		"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"limits":"All outcomes retained; practice has goal-copy adapter; duel adds periodic normal deploy command. Existing opponents/policies are imperfect. No human balance approval, fixed win-rate target or food reachability proof."}
	if not save_json(output.path_join("summary.json"),summary): quit(2); return
	print("ECOLOGY_SUMMARY | ",JSON.stringify(summary)); quit()

func run_round(seed_value: int, mode: String, max_ticks: int, game_mode: String, challenge_mode: bool, policy_name: String) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"challenge":challenge_mode,"ruleset":game_mode,
		"npc_count":0 if mode=="NoNPC" else 3,"npc_foraging_enabled":mode in ["ForagingNPC","HookableNPC"],
		"npc_social_enabled":true,"npc_hook_enabled":mode=="HookableNPC"})
	# Adapt only the public objective in the controller copy, not authority rules.
	var public_rules: Dictionary=world.rules.duplicate(true)
	public_rules.food_goal=world.food_target()
	var player:=Policy.new(); player.reset(policy_name,public_rules)
	var opponent:=Opponent.new()
	var initial_allocator: int=world.next_bait_id
	var initial_fish_allocator: int=world.next_fish_id
	var goal: float=world.food_target()
	var initial_rules: Dictionary=world.rules.duplicate(true)
	var no_food_ticks:=0
	var current_no_food_ticks:=0
	var longest_no_food_ticks:=0
	var stalled_ticks:=0
	var longest_stalled_ticks:=0
	var last_score:=0.0
	var minimum_available_food:=INF
	var observed_npc_attachments:=0
	var previous_target: int=world.hook_target_fish_id
	var metric: Dictionary={"npc_active_seconds":0.0,"npc_satiety_integral":0.0,"npc_satiety_min":null,
		"npc_critical_seconds":0.0,"npc_starving_seconds":0.0,"npc_social_reaction_entries":0,
		"npc_state_seconds":{"WANDER":0.0,"APPROACH_FOOD":0.0,"FEED":0.0,"HESITATE":0.0,"FLEE":0.0,"COMPETE":0.0,"HOOKED":0.0,"LANDING":0.0},
		"successful_respawns":0,"pending_respawns":0,"supply_eligible_seconds":0.0,"no_food_supply_eligible_seconds":0.0,
		"player_food_while_npc_hooked":0.0,"player_intake_ticks_while_npc_hooked":0,"npc_occupied_ticks":0,
		"player_food_goal_tick":-1,"player_home_attempts":0}
	var known_ids: Dictionary={}
	var previous_states: Dictionary={}
	for npc: Dictionary in world.npc_fishes: known_ids[int(npc.fish_id)]=true
	var player_satiety_integral:=0.0
	var player_satiety_min: float=world.satiety
	var player_critical_seconds:=0.0
	for frame in max_ticks:
		# Exposure and food opportunity use the state before this actual tick.
		var occupied: bool=world.hook_target_fish_id>1
		if occupied: metric.npc_occupied_ticks+=1
		var food:=available_food(world)
		var supply_eligible:=supply_can_step(world)
		if supply_eligible:
			metric.supply_eligible_seconds+=World.TICK_SECONDS
			if food<=0.000001: metric.no_food_supply_eligible_seconds+=World.TICK_SECONDS
		player_satiety_integral+=world.satiety*World.TICK_SECONDS
		player_satiety_min=minf(player_satiety_min,world.satiety)
		if world.satiety<=float(world.rules.satiety_critical_threshold): player_critical_seconds+=World.TICK_SECONDS
		for npc: Dictionary in world.npc_fishes:
			if not npc.active: continue
			metric.npc_active_seconds+=World.TICK_SECONDS
			metric.npc_satiety_integral+=float(npc.satiety)*World.TICK_SECONDS
			if metric.npc_satiety_min==null or float(npc.satiety)<float(metric.npc_satiety_min): metric.npc_satiety_min=float(npc.satiety)
			if float(npc.satiety)<=float(world.rules.satiety_critical_threshold): metric.npc_critical_seconds+=World.TICK_SECONDS
			if float(npc.satiety)<=float(world.rules.satiety_starving_threshold): metric.npc_starving_seconds+=World.TICK_SECONDS
			metric.npc_state_seconds[npc.behavior_state]+=World.TICK_SECONDS
		var player_command: Dictionary=player.command(Observation.build(world,false),World.TICK_SECONDS)
		if bool(player_command.home): metric.player_home_attempts+=1
		var angler_command: Dictionary=opponent.command(world,World.TICK_SECONDS)
		# Time-only deployment ensures duel is actually cast/recast, through the
		# exact normal actuator; it never inspects food or hidden hook assignment.
		if game_mode=="duel": angler_command.deploy=frame%120==0
		var score_before: float=world.score
		world.advance_tick(player_command,angler_command)
		if occupied and world.score>score_before+0.000001:
			metric.player_food_while_npc_hooked+=world.score-score_before
			metric.player_intake_ticks_while_npc_hooked+=1
		if metric.player_food_goal_tick<0 and world.score>=goal-0.000001: metric.player_food_goal_tick=world.simulation_tick
		for npc: Dictionary in world.npc_fishes:
			var identity:=int(npc.fish_id)
			if not known_ids.has(identity):
				known_ids[identity]=true
				metric.successful_respawns+=1
			if npc.active and npc.behavior_state in ["HESITATE","FLEE"] and previous_states.get(identity,"")!=npc.behavior_state: metric.npc_social_reaction_entries+=1
			previous_states[identity]=npc.behavior_state
		if world.hook_target_fish_id>1 and world.hook_target_fish_id!=previous_target: observed_npc_attachments+=1
		previous_target=world.hook_target_fish_id
		minimum_available_food=minf(minimum_available_food,food)
		if food<=0.000001:
			no_food_ticks+=1; current_no_food_ticks+=1
			longest_no_food_ticks=maxi(longest_no_food_ticks,current_no_food_ticks)
		else: current_no_food_ticks=0
		if world.score>last_score+0.000001: stalled_ticks=0
		else: stalled_ticks+=1
		longest_stalled_ticks=maxi(longest_stalled_ticks,stalled_ticks)
		last_score=world.score
		if not is_equal_approx(world.food_target(),goal) or world.rules!=initial_rules:
			push_error("Food goal or accepted rules changed during diagnostic"); world.free(); return {}
		if world.match_over: break
	for npc: Dictionary in world.npc_fishes:
		if not npc.active and npc.behavior_state=="CAPTURED": metric.pending_respawns+=1
	metric.player_satiety_final=world.satiety
	metric.player_satiety_min=minf(player_satiety_min,world.satiety)
	metric.player_satiety_mean=player_satiety_integral/world.elapsed
	metric.player_critical_seconds=player_critical_seconds
	metric.npc_feeding_events=world.round_stats.npc_feeding_events
	metric.player_npc_food_contests=world.round_stats.player_npc_food_contests
	metric.npc_target_switches=world.round_stats.npc_target_switches
	var stats: Dictionary=world.round_stats.duplicate(true)
	for key: String in ["npc_hook_count","npc_escapes","npc_breaks","wrong_catches","npc_hooked_seconds"]:
		if not stats.has(key): push_error("Missing measured P3.4 counter: "+key); world.free(); return {}
	var lifecycle_events: int=world.next_bait_id-initial_allocator
	var row: Dictionary={"seed":seed_value,"mode":mode,"game_mode":game_mode,"challenge":challenge_mode,"policy":policy_name,
		"npc_count":0 if mode=="NoNPC" else 3,"stratum_key":"%s/%s/%s" % [game_mode,"challenge" if challenge_mode else "practice",policy_name],"max_ticks":max_ticks,"ticks":world.simulation_tick,"duration":world.elapsed,
		"completed":world.match_over,"winner":world.winner_role,"reason":world.reason,"home_win":world.winner_role=="fish" and world.reason=="home",
		"food_goal":goal,"rules":initial_rules,"player_food":world.score,"player_food_by_type":stats.food_by_type,
		"hook_events":stats.hook_events,"hook_contacts":world.hook_count,"player_hooked_seconds":stats.hooked_seconds,
		"npc_food":stats.npc_food_consumed,"npc_food_by_type":stats.npc_food_by_type,
		"npc_hook_count":stats.npc_hook_count,"npc_escapes":stats.npc_escapes,"npc_breaks":stats.npc_breaks,
		"wrong_catches":stats.wrong_catches,"npc_hooked_seconds":stats.npc_hooked_seconds,
		"observed_npc_attachments":observed_npc_attachments,"final_hook_target_fish_id":world.hook_target_fish_id,
		"replacement_ids_allocated":world.next_fish_id-initial_fish_allocator,
		"lifecycle_events":lifecycle_events,"lifecycle_per_sim_minute":60.0*lifecycle_events/maxf(0.000001,world.elapsed),
		"no_food_seconds":no_food_ticks*World.TICK_SECONDS,"longest_no_food_seconds":longest_no_food_ticks*World.TICK_SECONDS,
		"longest_player_no_intake_seconds":longest_stalled_ticks*World.TICK_SECONDS,"minimum_available_food":minimum_available_food,"stats":stats}
	row.merge(metric)
	world.free(); return row

func supply_can_step(world: Node2D) -> bool:
	# Mirrors only production supply's top-level eligibility. A bound slot can
	# still wait; this is not a promise of an instant refill or a deadlock proof.
	return not ((not world.challenge and (not world.npc_foraging_enabled or world.npc_fishes.is_empty())) or world.hooked!=world.HookState.FREE or not world.net_state in ["wait","rest"])

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
