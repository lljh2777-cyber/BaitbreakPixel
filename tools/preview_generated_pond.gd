extends SceneTree
const Preview=preload("res://tools/generated_pond_preview_view.gd")
var map_seed:=42
var output:=""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Preview needs a renderer"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map-seed="):
			var value:=argument.trim_prefix("--map-seed=")
			if not value.is_valid_int() or str(value.to_int())!=value: push_error("Invalid map seed"); quit(2); return
			map_seed=value.to_int()
		if argument.begins_with("--preview-output="): output=argument.trim_prefix("--preview-output=")
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1280,720)
	var preview=Preview.new(); root.add_child(preview)
	if not preview.configure(map_seed): push_error(preview.error_text); quit(2); return
	print("MAP_PREVIEW_READY | seed=",map_seed," | hash=",preview.context.content_hash)
	if not output.is_empty():
		if DirAccess.make_dir_recursive_absolute(output.get_base_dir())!=OK: push_error("Cannot create preview output directory"); quit(2); return
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var error:=root.get_texture().get_image().save_png(output)
		if error!=OK: push_error("Cannot write preview image"); quit(2); return
		quit(0)
