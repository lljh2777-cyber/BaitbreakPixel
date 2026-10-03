extends SceneTree
# Read-only instrumentation of the same autonomous policy, for explaining a
# foodless interval. It does not alter actors, resources, goals or hook state.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")

func _initialize() -> void:
	var seed_value:=44009
	var output:="res://artifacts/p32-supply-diagnostic-44009.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.substr(9)
	var world:=World.new()
	world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival","npc_count":3,"npc_foraging_enabled":true})
	var player:=Policy.new(); player.reset("Mixed",world.rules)
	var angler:=Opponent.new()
	var intervals: Array=[]
	var current: Dictionary={}
	for tick in 22200:
		world.advance_tick(player.command(Observation.build(world,false),World.TICK_SECONDS),angler.command(world,World.TICK_SECONDS))
		var food:=0.0
		for bait: Dictionary in world.baits:
			for grain: Dictionary in bait.grains:
				if not grain.eaten and (bait.active or grain.free): food+=float(grain.points)
		if food<=0.000001:
			if current.is_empty(): current={"start_tick":world.simulation_tick,"end_tick":world.simulation_tick,"ticks":0,"hook_states":{},"net_states":{},"cycle_phases":{},"eligible_supply_ticks":0}
			current.end_tick=world.simulation_tick; current.ticks+=1
			for pair in [["hook_states",str(world.hooked)],["net_states",world.net_state],["cycle_phases",world.cycle_phase]]:
				current[pair[0]][pair[1]]=int(current[pair[0]].get(pair[1],0))+1
			if world.hooked==world.HookState.FREE and world.net_state in ["wait","rest"]: current.eligible_supply_ticks+=1
		elif not current.is_empty(): intervals.append(current); current={}
		if world.match_over: break
	if not current.is_empty(): intervals.append(current)
	var report: Dictionary={"seed":seed_value,"mode":"ForagingNPC","ticks":world.simulation_tick,"duration":world.elapsed,
		"winner":world.winner_role,"reason":world.reason,"player_food":world.score,"npc_food":world.round_stats.npc_food_consumed,
		"hook_events":world.round_stats.hook_events,"hook_enum":{"FREE":world.HookState.FREE,"MOUTH":world.HookState.MOUTH,"HOOKED":world.HookState.HOOKED},
		"foodless_intervals":intervals,"note":"Same real 60 Hz default challenge and detached Mixed policy as the paired comparison. Instrumentation only; no forced food, time, position, winner or hook changes."}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Cannot write supply diagnostic"); world.free(); quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SUPPLY_DIAGNOSTIC | ",JSON.stringify(report)); world.free(); quit()
