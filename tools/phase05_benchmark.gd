extends SceneTree
# Small, reproducible cold/warm measurements. No frame or file hash scans.
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Gate=preload("res://scripts/maps/generation/map_playability_validator.gd")
const Context=preload("res://scripts/maps/map_context.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Appearance=preload("res://scripts/watergen/generated_water_appearance.gd")
var output:="res://artifacts/p5-performance.json"
func _initialize()->void: call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists(output): quit(2); return
	var rows:Array=[]
	var view:=Appearance.new()
	for seed:int in [42,2166,1346,296,123456789]:
		var start:=Time.get_ticks_usec()
		var generated:=Generator.generate(Request.create(seed))
		var generation_us:=Time.get_ticks_usec()-start
		if not generated.valid: quit(1); return
		start=Time.get_ticks_usec()
		var validation:=Gate.validate(generated.definition)
		var validation_us:=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec()
		var loaded:=Context.from_definition(generated.definition,generated.source)
		var context_us:=Time.get_ticks_usec()-start
		if not validation.valid or not loaded.valid: quit(1); return
		start=Time.get_ticks_usec()
		var ready:=view.prepare(loaded.context,713284)
		var visual_us:=Time.get_ticks_usec()-start
		if not ready or not view.enabled: quit(1); return
		var bakes:int=view.cache.bake_count
		start=Time.get_ticks_usec()
		for repeat in 120:
			if not view.prepare(loaded.context,713284): quit(1); return
		var warm_visual_us:float=(Time.get_ticks_usec()-start)/120.0
		if view.cache.bake_count!=bakes or view.cache.bundles.size()>2: quit(1); return
		var resolved:=Resolver.resolve(generated.source)
		start=Time.get_ticks_usec()
		for repeat in 120:
			if Resolver.resolve(generated.source).context!=resolved.context: quit(1); return
		rows.append({"map_seed":seed,"generation_with_validation_us":generation_us,
			"independent_validation_us":validation_us,"context_with_validation_us":context_us,
			"watergen_prepare_including_bake_upload_us":visual_us,"warm_view_prepare_mean_us":warm_visual_us,
			"warm_resolver_mean_us":(Time.get_ticks_usec()-start)/120.0})
		await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: quit(2); return
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"os":OS.get_name(),
		"renderer":RenderingServer.get_current_rendering_method(),"passed":true,"rows":rows,
		"notes":"Cold visual preparation includes profile load, plan, CPU bake, terrain and texture upload API; not GPU fence timing. Samples may overlap other validation processes. Warm view calls perform no bake or hashing."},"\t"))
	file.close()
	print("PHASE05_BENCHMARK | passed=5 | failed=0")
	quit()
