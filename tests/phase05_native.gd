extends SceneTree
const Preview=preload("res://tools/generated_pond_preview_view.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const Context=preload("res://scripts/maps/map_context.gd")
var passed:=0
var failed:=0
var output:="res://artifacts/phase05-native"
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("PHASE05_NATIVE_FAIL | "+label)
func _initialize()->void: call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless": push_error("Native preview requires renderer"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK: push_error("invalid capture output"); quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	var preview=Preview.new(); root.add_child(preview)
	var seeds:Array[int]=[42,0,999,2147483647]
	var corpus_file:=FileAccess.open("res://docs/test-reports/data/generation-0270/corpus.json",FileAccess.READ)
	if corpus_file!=null:
		var corpus:Variant=JSON.parse_string(corpus_file.get_as_text())
		for label in ["open","dense","net-hostile"]:
			var map_seed:int=int(corpus[label])
			if map_seed not in seeds: seeds.append(map_seed)
	var images:Dictionary={}
	for map_seed:int in seeds:
		check(preview.configure(map_seed),"preview accepts validated seed "+str(map_seed))
		if preview.result.is_empty(): continue
		var authority:=Definition.canonical(preview.result.definition)
		var before:=var_to_bytes(preview.result)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var picture:=root.get_texture().get_image()
		check(picture.get_size()==Vector2i(1280,720),"full map overview viewport")
		check(picture.save_png(output.path_join("seed-%d.png"%map_seed))==OK,"capture saved")
		check(var_to_bytes(preview.result)==before,"drawing does not change authority or diagnostics")
		check(preview.props.size()==preview.result.diagnostics.metrics.wood_count/2+preview.result.diagnostics.metrics.stone_count,"connected wood rendered once per fade group")
		preview.overlay=false; preview.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
		check(Definition.canonical(preview.result.definition)==authority,"debug visual overlay never changes map authority")
		check(root.get_texture().get_image().get_data()!=picture.get_data(),"inspection overlay changes only pixels")
		preview.overlay=true; preview.queue_redraw()
		images[map_seed]=picture.get_region(Rect2i(24,72,1228,460)).get_data()
		print("PREVIEW_SEED | ",map_seed," | ",preview.context.content_hash)
	check(images[42]!=images[0],"different map seeds change visible layout")
	var previous_seed:int=preview.selected_seed
	preview.seed_box.text="-1"; check(not preview.apply_text() and preview.selected_seed==previous_seed,"invalid seed leaves existing preview intact")
	preview.seed_box.text="42"; check(preview.apply_text(),"manual seed entry rebuilds")
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	# Header timings are nondeterministic; compare complete MapDefinition separately.
	var original:Dictionary=preview.result.definition.duplicate(true)
	check(preview.configure(42) and preview.result.definition==original,"same seed reconstructs exact full definition")
	check(Context.load_map().context.id=="pond_v2","normal game default remains the built-in pond")
	print("PHASE05_NATIVE | passed=%d | failed=%d"%[passed,failed])
	quit(1 if failed else 0)
