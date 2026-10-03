extends SceneTree

# P3.4 §50 offline experiment only. No labels or instrumentation drive actors.
# The P3.2 controller and survival opponent are used unchanged in every arm.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")
const MODES: Array[String]=["NoNPC","PassiveNPC","ForagingNPC","HookableNPC"]
const VERSION:=1

func _initialize() -> void:
	var count:=8
	var first_seed:=64301
	var max_ticks:=22200
	var output:="res://artifacts/p34-hook-diagnostics"
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
		for mode: String in MODES:
			var row:=run_round(first_seed+index,mode,max_ticks)
			if row.is_empty(): quit(3); return
			rows.append(row)
			print("NPC_HOOK_DIAGNOSTIC_PROGRESS | seed=%d mode=%s player_food=%.3f npc_food=%.3f player_hooks=%d npc_hooks=%d wrong_catches=%d duration=%.3f winner=%s reason=%s" % [row.seed,mode,row.player_food,row.npc_food,row.hook_events,row.npc_hook_count,row.wrong_catches,row.duration,row.winner,row.reason])
			if not save_json(output.path_join("rounds.json"),rows): quit(2); return
	var summary: Dictionary={"format":"phase03-hook-diagnostics-v1","harness_version":VERSION,
		"paired_seeds":count,"first_seed":first_seed,"last_seed":first_seed+count-1,"modes":MODES,
		"tick_seconds":World.TICK_SECONDS,"max_ticks":max_ticks,"controller":"unchanged P2 Mixed","controller_version":Policy.VERSION,
		"rules":"unmodified default survival challenge","wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"definitions":{"arms":"0 NPC; 3 passive; 3 foraging/social with NPC hooks disabled; 3 foraging/social with NPC hooks enabled. All other settings are identical.",
			"player":"Detached FishObservation only enters the unchanged P2 Mixed policy; no hook-truth oracle and no QTE escape adapter.",
			"angler":"Existing survival AnglerBrain through ordinary command authority, unchanged across every arm.",
			"hooks":"hook_events and hook_contacts remain player-only. npc_hook_count, npc_escapes, npc_breaks and wrong_catches are distinct actual authority counters.",
			"wrong_catches":"NPC successfully lifted out of water. This does not finish the player-versus-angler match.",
			"npc_hooked_seconds":"Actual authority time occupied by NPC hook/landing handling; reported independently from player hooked_seconds.",
			"lifecycle_events":"New bait identities after initial setup, measured by next_bait_id growth.",
			"censoring":"All seed/arm outcomes retained. Horizon-limited rounds are explicitly incomplete, not silently treated as completed defeats.",
			"comparison":"Paired same-seed descriptive diagnostics. No accepted P3.2 food/rule balance, player policy or opponent tuning changes."},
		"limits":"Autonomous-policy diagnostic, not human win rate, final balance approval or food-reachability proof. No 50% win target, seed selection or favorable-outcome filtering. Historical P3.2/P3.3 evidence is not replaced."}
	if not save_json(output.path_join("summary.json"),summary): quit(2); return
	print("NPC_HOOK_DIAGNOSTIC_SUMMARY | ",JSON.stringify(summary)); quit()

func run_round(seed_value: int, mode: String, max_ticks: int) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival",
		"npc_count":0 if mode=="NoNPC" else 3,"npc_foraging_enabled":mode in ["ForagingNPC","HookableNPC"],
		"npc_social_enabled":true,"npc_hook_enabled":mode=="HookableNPC"})
	var player:=Policy.new(); player.reset("Mixed",world.rules)
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
	for frame in max_ticks:
		world.advance_tick(player.command(Observation.build(world,false),World.TICK_SECONDS),opponent.command(world,World.TICK_SECONDS))
		if world.hook_target_fish_id>1 and world.hook_target_fish_id!=previous_target: observed_npc_attachments+=1
		previous_target=world.hook_target_fish_id
		var food:=available_food(world)
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
	var stats: Dictionary=world.round_stats.duplicate(true)
	for key: String in ["npc_hook_count","npc_escapes","npc_breaks","wrong_catches","npc_hooked_seconds"]:
		if not stats.has(key): push_error("Missing measured P3.4 counter: "+key); world.free(); return {}
	var lifecycle_events: int=world.next_bait_id-initial_allocator
	var row: Dictionary={"seed":seed_value,"mode":mode,"ticks":world.simulation_tick,"duration":world.elapsed,
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
	world.free(); return row

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
