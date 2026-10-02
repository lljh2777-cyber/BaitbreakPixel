extends SceneTree

# Deterministic, render-free real-world simulation. No outcome is synthesized.
const World=preload("res://scripts/world_simulation.gd")
const FishBrain=preload("res://scripts/fish_brain.gd")
const AnglerBrain=preload("res://scripts/angler_brain.gd")

func _initialize() -> void:
	var count:=10
	var first_seed:=1
	var output:="res://artifacts/batch-baseline"
	var strategy:="baseline"
	var trace_enabled:=false
	for arg in OS.get_cmdline_user_args():
		if arg=="--trace": trace_enabled=true
		if arg.begins_with("--rounds="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): first_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.substr(9)
		if arg.begins_with("--strategy="): strategy=arg.get_slice("=",1)
	if count<1 or count>10000: push_error("rounds must be 1..10000"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: push_error("cannot create batch output"); quit(2); return
	var rows: Array=[]
	var durations: Array[float]=[]
	var wins:=0
	var hooks:=0
	var food:=0.0
	var started:=Time.get_ticks_msec()
	for index in count:
		var seed_value:=first_seed+index
		var world:=World.new()
		world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival"})
		var brain:=FishBrain.new(); brain.reset(seed_value+100000); brain.use_caution=strategy=="cautious"; brain.commit_meal=strategy!="baseline"
		var opponent:=AnglerBrain.new()
		var trace: Array=[]
		var previous_target:=-1
		var previous_feeding:=false
		for frame in 22200:
			var command: Dictionary=brain.command(world,World.TICK_SECONDS)
			if trace_enabled and (brain.food_target!=previous_target or bool(command.suck)!=previous_feeding):
				trace.append({"time":world.elapsed,"bait_id":brain.food_target,"feeding":command.suck,"food":world.score,"state":brain.state})
				previous_target=brain.food_target; previous_feeding=command.suck
			world.advance_tick(command,opponent.command(world,World.TICK_SECONDS))
			if world.match_over: break
		var row: Dictionary={"seed":seed_value,"strategy":strategy,"meal_commitment":brain.commit_meal,"duration":world.elapsed,"completed":world.match_over,
			"winner":world.winner_role,"reason":world.reason,"food_consumed":world.score,"hook_contacts":world.hook_count,"hook_events":world.round_stats.get("hook_events",null),"escapes":world.escape_count,
			"stats":world.round_stats.duplicate(true)}
		if trace_enabled: row.decision_trace=trace
		rows.append(row); durations.append(world.elapsed)
		wins+=int(world.winner_role=="fish"); hooks+=world.hook_count; food+=world.score
		world.free()
		if (index+1)%10==0: print("BATCH_PROGRESS | ",index+1,"/",count)
	durations.sort()
	var median: float=durations[count/2] if count%2 else (durations[count/2-1]+durations[count/2])/2.0
	var summary: Dictionary={"rounds":count,"first_seed":first_seed,"strategy":strategy,"tick_seconds":World.TICK_SECONDS,
		"median_round_duration":median,"fish_win_rate":float(wins)/count,"hook_contacts_mean":float(hooks)/count,
		"food_consumed_mean":food/count,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"note":"Bot strategy evidence, not human playability acceptance. Timed-out incomplete rows are explicitly marked."}
	var file:=FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	if file==null: push_error("cannot write summary"); quit(2); return
	file.store_string(JSON.stringify(summary,"\t")); file.close()
	file=FileAccess.open(output.path_join("rounds.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	file=FileAccess.open(output.path_join("rounds.csv"),FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["seed","strategy","duration","completed","winner","reason","food_consumed","hook_contacts","hook_events","escapes"]))
	for row in rows:
		file.store_csv_line(PackedStringArray([str(row.seed),str(row.strategy),str(row.duration),str(row.completed),row.winner,row.reason,str(row.food_consumed),str(row.hook_contacts),str(row.hook_events),str(row.escapes)]))
	file.close()
	print("BATCH_SUMMARY | ",JSON.stringify(summary))
	quit()
