extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const Gate=preload("res://scripts/maps/generation/map_playability_validator.gd")
var passed:=0
var failed:=0
var total:=10000
var output:="res://artifacts/phase05-seed-sweep.json"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed-count="): total=int(argument.trim_prefix("--seed-count="))
		if argument.begins_with("--sweep-output="): output=argument.trim_prefix("--sweep-output=")
	if total<1 or total>10000 or output.is_empty(): push_error("invalid sweep arguments"); quit(2); return
	var begin:=Time.get_ticks_usec()
	var failures:Array=[]
	var histogram:Dictionary={}
	var ranges:Dictionary={}
	var corpus:Dictionary={}
	var identities:Dictionary={}
	var mismatches:=0
	var accepted_invalid:=0
	var generation_usec:=0
	var validation_usec:=0
	for map_seed in total:
		var request:=Request.create(map_seed)
		var start:=Time.get_ticks_usec()
		var first:=Generator.generate(request)
		generation_usec+=Time.get_ticks_usec()-start
		var second:=Generator.generate(request)
		if not first.valid or not second.valid:
			failed+=1; failures.append({"seed":map_seed,"errors":first.errors}); continue
		if var_to_bytes(first)!=var_to_bytes(second) or Definition.canonical(first.definition)!=Definition.canonical(second.definition): mismatches+=1; failed+=1
		else: passed+=1
		start=Time.get_ticks_usec()
		var independent:=Gate.validate(first.definition)
		validation_usec+=Time.get_ticks_usec()-start
		if not independent.valid: accepted_invalid+=1; failed+=1
		else: passed+=1
		identities[first.definition.meta.content_hash]=true
		var attempt:String=str(first.diagnostics.attempt_index)
		histogram[attempt]=histogram.get(attempt,0)+1
		var metrics:Dictionary=first.diagnostics.metrics.duplicate(true)
		metrics.net_open=metrics.net_routes.open; metrics.net_partial=metrics.net_routes.partial; metrics.erase("net_routes")
		for key:String in metrics:
			var value:float=metrics[key]
			if not ranges.has(key): ranges[key]={"min":value,"max":value,"sum":0.0,"min_seed":map_seed,"max_seed":map_seed}
			var entry:Dictionary=ranges[key]
			entry.sum+=value
			if value<entry.min: entry.min=value; entry.min_seed=map_seed
			if value>entry.max: entry.max=value; entry.max_seed=map_seed
		if map_seed%250==0:
			print("MAP_SWEEP_PROGRESS | ",map_seed+1,"/",total," | seconds=",snappedf((Time.get_ticks_usec()-begin)/1000000.0,0.1))
			await process_frame
	for key:String in ranges: ranges[key].mean=ranges[key].sum/maxi(1,total-failures.size()); ranges[key].erase("sum")
	for pair in [["open","cover_density","min_seed"],["dense","cover_density","max_seed"],["bait-spread","bait_spacing","max_seed"],["bait-clustered","bait_spacing","min_seed"],
		["net-friendly","net_open","max_seed"],["net-hostile","net_open","min_seed"],["rope-rich","rope_anchor_count","max_seed"],["rope-poor","rope_anchor_count","min_seed"]]:
		if ranges.has(pair[1]): corpus[pair[0]]=ranges[pair[1]][pair[2]]
	var report:Dictionary={"seed_start":0,"seed_count":total,"accepted_invalid":accepted_invalid,"nondeterministic":mismatches,"failures":failures,
		"distinct_maps":identities.size(),"retry_histogram":histogram,"metrics":ranges,"regression_seeds":corpus,
		"generation_with_validation_mean_ms":generation_usec/1000.0/total,"independent_validation_mean_ms":validation_usec/1000.0/total,
		"elapsed_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"passed":passed,"failed":failed}
	var directory:=output.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: push_error("cannot create sweep directory"); quit(2); return
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("cannot write sweep report"); quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PHASE05_SEED_SWEEP | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
