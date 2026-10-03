extends SceneTree

# Controlled hook-to-capture diagnostic. Only the pre-contact fixture is placed;
# every post-contact update is an ordinary, unmodified real 60 Hz world tick.
const World=preload("res://scripts/world_simulation.gd")
const Probe=preload("res://tests/phase03_npc_hook_pacing.gd")

func _initialize() -> void:
	var output:=""
	var full:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.substr(9)
		if arg=="--full": full=true
	if output.is_empty() or FileAccess.file_exists(output):
		push_error("Require fresh --output=FILE.json"); quit(2); return
	var rows: Array=[]
	var seeds: Array=[64317,64404,64423] if full else [64317]
	var controls: Array=["reel","ws","auto_reel"] if full else ["reel","auto_reel"]
	for mode: String in ["duel","survival"]:
		for seed_value: int in seeds:
			for depth: float in [130.0,240.0,390.0]:
				for horizontal: float in [0.0,160.0,320.0]:
					for control: String in controls:
						var row:=Probe.measure(mode,seed_value,Vector2(640+horizontal,depth),control)
						rows.append(row)
						print("NPC_PACING | %s seed=%d y=%.0f dx=%.0f %s outcome=%s landing=%.3f terminal=%.3f max_hooked_step=%.3f" % [mode,seed_value,depth,horizontal,control,row.outcome,row.landing_seconds,row.terminal_seconds,row.max_hooked_step])
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Cannot write pacing output"); quit(2); return
	file.store_string(JSON.stringify({"format":"phase03-npc-hook-pacing-v1","tick_seconds":World.TICK_SECONDS,"horizon_seconds":60.0,
		"fixture":"Real mouth contact; pre-contact position and anchor fixed; no post-contact position, rope, tension or NPC-state mutation. Only timer, hunger, water and instinct disabled for isolation; all line/landing rules retain defaults.","rows":rows},"\t")); file.close()
	print("NPC_PACING_SUMMARY | cases=",rows.size()); quit()
