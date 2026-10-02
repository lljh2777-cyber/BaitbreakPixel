extends SceneTree
# Development-only labeled data. Labels never enter FishObservation or fish transport.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
func _initialize() -> void:
	var rows: Array=[]
	var output:="res://artifacts/information-diagnostic"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.substr(9)
	for seed_value in range(1,1001):
		var world:=World.new(); world.reset_world({"seed":seed_value}); world.hook_cooldown=999
		var features: Dictionary={}
		for frame in 120:
			world.elapsed+=1.0/60; world.simulation_tick+=1
			for slot in world.baits.size():
				world._step_bait(slot,1.0/60,false,world.mouth())
				if frame<60 or frame%10!=9 or not world.baits[slot].active: continue
				world.fish=Vector2(world.baits[slot].pos)-Vector2(30,0)
				var observed:=Observation.find(Observation.build(world,false),world.baits[slot].bait_id)
				if observed.is_empty(): continue
				var motion: Dictionary=observed.hints.motion
				var residual: float=(Vector2(motion.velocity)-Vector2(motion.water_drift)).length()
				features[slot]=float(features.get(slot,0.0))+residual/6.0
		for slot in features:
			rows.append({"seed":seed_value,"feature":features[slot],"hook":world.baits[slot].hook})
		world.free()
	var threshold:=0.0
	var best:=-1
	for trial in 121:
		var candidate: float=trial*0.25
		var correct:=0
		for row in rows:
			if row.seed<=500 and (float(row.feature)>candidate)==bool(row.hook): correct+=1
		if correct>best: best=correct; threshold=candidate
	var test_rows: Array=[]
	var correct:=0; var fp:=0; var fn:=0; var positive:=0; var negative:=0
	for row in rows:
		if row.seed<=500: continue
		test_rows.append(row)
		var predicted: bool=float(row.feature)>threshold
		if predicted==bool(row.hook): correct+=1
		if predicted and not row.hook: fp+=1
		if not predicted and row.hook: fn+=1
		if row.hook: positive+=1
		else: negative+=1
	test_rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a.feature)<float(b.feature))
	var rank_sum:=0.0
	var index:=0
	while index<test_rows.size():
		var end:=index+1
		while end<test_rows.size() and test_rows[end].feature==test_rows[index].feature: end+=1
		var average_rank: float=(index+1+end)/2.0
		for tied in range(index,end):
			if test_rows[tied].hook: rank_sum+=average_rank
		index=end
	var auc: float=(rank_sum-positive*(positive+1)/2.0)/maxf(1,positive*negative)
	var summary: Dictionary={"seeds":1000,"training_seeds":"1–500","holdout_seeds":"501–1000","feature":"mean observed water-relative bait velocity, 1–2 seconds", "threshold":threshold,"holdout_examples":test_rows.size(),"accuracy":float(correct)/test_rows.size(),"auc":auc,"false_positives":fp,"false_negatives":fn,"note":"Simple held-out classifier is a diagnostic, not proof against every possible classifier or long-duration inference."}
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE)
	if file==null: push_error("cannot write diagnostic"); quit(2); return
	file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("INFORMATION_DIAGNOSTIC | ",JSON.stringify(summary))
	quit(0 if auc>0.55 and auc<0.95 and fp>0 and fn>0 else 1)
