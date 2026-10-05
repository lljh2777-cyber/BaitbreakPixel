extends "res://tools/phase05_gameplay_sweep.gd"
func run() -> void:
	generator_version=2
	output="res://artifacts/relief-rounds.jsonl"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if FileAccess.file_exists(output): push_error("report already exists"); quit(2); return
	var file:=FileAccess.open(output,FileAccess.WRITE)
	var failed:=0
	var completed:=0
	for base in [0,40,80,240,920]:
		for variant in 4:
			var row:=round_case(base+variant)
			file.store_line(JSON.stringify(row)); file.flush()
			if not row.valid or not row.completed or row.supply_deadlock: failed+=1
			completed+=1
			print("RELIEF_ROUND | seed=%d | mode=%s | policy=%s | seconds=%.2f | reason=%s | valid=%s" % [row.map_seed,row.mode,row.policy,row.duration,row.reason,str(row.valid)])
			await process_frame
	file.close()
	print("TERRAIN_ROUNDS | passed=%d | failed=%d" % [completed-failed,failed])
	quit(1 if failed else 0)
