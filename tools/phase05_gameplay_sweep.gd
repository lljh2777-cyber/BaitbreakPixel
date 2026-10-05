extends SceneTree
# Full rounds at the production 60 Hz tick with default rules and three NPCs.
# Reports are diagnostics, never a claim that these controllers model human skill.
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Fish=preload("res://scripts/fish_brain.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Angler=preload("res://scripts/angler_brain.gd")
const SEEDS=[42,2166,1346,937,1141,144,296,64,22,0,1,2,3,4,5,6,7,8,9,10,100,999,73501,123456789,2147483647]
const MAX_TICKS:=22200
var generator_version:=1
var first:=0
var count:=1000
var output:="res://artifacts/phase05-gameplay.jsonl"
func _initialize()->void: call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--first="): first=int(arg.get_slice("=",1))
		if arg.begins_with("--count="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if first<0 or count<1 or first+count>1000 or FileAccess.file_exists(output): push_error("invalid sweep bounds or existing report"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: quit(2); return
	var failed:=0
	for index in range(first,first+count):
		var row:=round_case(index)
		file.store_line(JSON.stringify(row)); file.flush()
		if not row.valid or not row.completed or row.supply_deadlock: failed+=1
		print("P5_GAMEPLAY | run=%d | map=%d | seconds=%.2f | winner=%s | reason=%s | valid=%s" % [index,row.map_seed,row.duration,row.winner,row.reason,str(row.valid)])
		await process_frame
	file.close()
	print("PHASE05_GAMEPLAY | passed=%d | failed=%d" % [count-failed,failed])
	quit(1 if failed else 0)
func round_case(index:int)->Dictionary:
	var map_seed:int=SEEDS[index/40]
	var simulation_seed:int=73501+(index%40)/2
	var native_ai:=index%2==0
	var mode:String="survival" if (index%40)/2%2==0 else "duel"
	var g:=World.new()
	var valid:bool=g.reset_world({"map_source":Resolver.generated(map_seed,generator_version),"seed":simulation_seed,"challenge":true,"ruleset":mode})
	var player:=Fish.new(); player.reset(simulation_seed+173)
	var policy:=Policy.new(); policy.reset("Mixed",g.rules)
	var opponent:=Angler.new()
	var no_food_seconds:=0.0; var longest_no_food:=0.0
	var return_stall:=0.0; var max_return_stall:=0.0
	var last_supply:int=g.next_bait_id
	var supply_stall:=0.0; var max_supply_stall:=0.0
	for tick in MAX_TICKS:
		if g.match_over or not valid: break
		var command:Dictionary=player.command(g,World.TICK_SECONDS) if native_ai else policy.command(Observation.build(g,false),World.TICK_SECONDS)
		var other:Dictionary=opponent.command(g,World.TICK_SECONDS)
		if mode=="duel": other.deploy=tick%120==0
		g.advance_tick(command,other)
		if tick%60!=59: continue
		valid=valid and g.fish.is_finite() and (g.net_state=="caught" or g.landing or g.map_context.water.grow(14).has_point(g.fish))
		if g.map_context.has_relief and g.net_state!="caught" and not g.landing: valid=valid and not g.map_context.bed_blocked(g.fish,12)
		for npc:Dictionary in g.npc_fishes:
			valid=valid and npc.position.is_finite()
			if npc.active and g.npc_hook.phase!="landing": valid=valid and not g.map_context.bed_blocked(npc.position,World.NPCFishState.RADIUS)
		for bait:Dictionary in g.baits:
			for grain:Dictionary in bait.grains:
				if not grain.eaten and (grain.free or bait.active): valid=valid and not g.map_context.bed_blocked(grain.pos,2)
		var available:=0.0
		for bait:Dictionary in g.baits:
			for grain:Dictionary in bait.grains:
				if not grain.eaten and (bait.active or grain.free): available+=float(grain.points)
		no_food_seconds=no_food_seconds+1 if available<=0.000001 else 0.0
		longest_no_food=maxf(longest_no_food,no_food_seconds)
		# Flag sustained starvation only while production supply is eligible and
		# has allocated no new bait. Food elsewhere is a controller/pathing issue.
		var eligible:bool=g.hooked==g.HookState.FREE and g.net_state in ["wait","rest"]
		supply_stall=supply_stall+1 if eligible and available<=0.000001 and last_supply==g.next_bait_id else 0.0
		max_supply_stall=maxf(max_supply_stall,supply_stall); last_supply=g.next_bait_id
		return_stall=return_stall+1 if g.score>=g.food_target() and not g.returning else 0.0
		max_return_stall=maxf(max_return_stall,return_stall)
	var probe:=World.new()
	valid=valid and probe.restore_snapshot(g.capture_snapshot())
	var row:Dictionary={"harness_version":3,"generator_version":generator_version,"run":index,"map_seed":map_seed,"simulation_seed":simulation_seed,"policy":"native_AI" if native_ai else "Mixed_observation",
		"mode":mode,"valid":valid,"completed":g.match_over,"duration":g.elapsed,"ticks":g.simulation_tick,"winner":g.winner_role,"reason":g.reason,
		"food":g.score,"npc_food":g.round_stats.npc_food_consumed,"hook_events":g.round_stats.hook_events,"npc_wrong_hooks":g.round_stats.npc_hook_count,
		"net_catch":g.reason=="net","wrap_usage":g.round_stats.wrap_good,"home_completion":g.reason=="home","supply_deadlock":max_supply_stall>=20,
		"longest_no_food_seconds":longest_no_food,"longest_eligible_supply_stall":max_supply_stall,"longest_return_stall":max_return_stall}
	probe.free(); g.free(); return row
