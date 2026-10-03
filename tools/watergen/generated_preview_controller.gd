extends "res://tools/watergen/preview_controller.gd"
const GeneratedCanvas = preload("res://tools/watergen/generated_preview_canvas.gd")
const Cache = preload("res://scripts/watergen/water_visual_cache.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const SEEDS := [42, 731, 2649, 713284]
var profile: Dictionary
var cache := Cache.new()
var seed_index := 0
var current: Dictionary = {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--wg-capture": capture_mode = true
		elif argument.begins_with("--wg-output="): output = argument.trim_prefix("--wg-output=").replace("\\", "/").simplify_path()
	if DisplayServer.get_name() == "headless":
		push_error("WG1 static preview requires a real renderer")
		get_tree().quit(2)
		return
	before = Adapter.authority_bytes()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	public_context = Adapter.build(source.source_commit)
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond.json"))
	var validation := Profile.validate(profile)
	if not validation.ok:
		push_error(validation.diagnostic)
		get_tree().quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	canvas = GeneratedCanvas.new()
	viewport.add_child(canvas)
	canvas.prepare_geometry(public_context)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(640, 360)
	add_child(display)
	if capture_mode:
		var allowed := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
		if not output.begins_with(allowed) or output == allowed:
			push_error("WG1 output must be under this worktree's artifacts/watergen")
			get_tree().quit(2)
			return
		call_deferred("capture")
	else: _select_seed()

func _select_seed() -> bool:
	current = cache.prepare(public_context, profile, SEEDS[seed_index])
	if not current.ok:
		push_error("WG1 generation failed: " + str(current))
		get_tree().quit(1)
		return false
	canvas.use_bundle(current.bundle)
	get_window().title = "WG-1 seed %d | [ ]: seed | 1-5: camera | arrows: pan | G: guides | H: geometry | Esc" % SEEDS[seed_index]
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_mode or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		seed_index = posmod(seed_index + (1 if event.keycode == KEY_BRACKETRIGHT else -1), SEEDS.size())
		_select_seed()
	else: super._unhandled_key_input(event)

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG1_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("WG1_NATIVE_FAIL | " + title)

func capture() -> void:
	var root_output := output
	var context_before := Contract.canonical(public_context)
	var profile_before := Contract.canonical(profile)
	var results: Array = []
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(root_output + "/isolated-user/"), "isolated engine user directory")
	for index in SEEDS.size():
		seed_index = index
		var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
		if not _select_seed(): return
		output = root_output.path_join("seed-" + str(SEEDS[index]))
		if DirAccess.make_dir_recursive_absolute(output) != OK:
			get_tree().quit(2)
			return
		var layers: Dictionary = {}
		for key in LAYERS:
			var image: Image = current.images[key].image
			check(image.get_size() == Vector2i(1280, 480), "layer dimensions " + key)
			layers[key] = current.images[key].rgba_sha256
			save_image(image, "layer-" + key)
		var captures: Array = []
		viewport.size = Vector2i(640, 360)
		canvas.show_geometry = true
		for position in CAMERAS:
			canvas.camera_offset = Vector2(position[0], position[1])
			var image := await render()
			check(image.get_size() == Vector2i(640, 360), "native viewport size")
			check(image.get_data() == (await render()).get_data(), "static frame repeated " + str(position))
			var name := "viewport-%d-%d" % [position[0], position[1]]
			save_image(image, name)
			captures.append({"path": name + ".png", "camera_offset_px": position, "rgba_sha256": rgba_digest(image)})
		canvas.camera_offset = Vector2.ZERO
		viewport.size = Vector2i(1280, 480)
		save_image(await render(), "world-with-geometry")
		canvas.show_geometry = false
		save_image(await render(), "world-environment")
		canvas.show_geometry = true
		canvas.show_guides = true
		save_image(await render(), "world-guides")
		canvas.show_guides = false
		save_text("scene-plan.json", Contract.canonical(current.plan))
		var count := cache.bake_count
		var warm := cache.prepare(public_context, profile, SEEDS[index])
		check(warm.ok and warm.cache_hit and cache.bake_count == count and warm.bundle == current.bundle, "warm cache reuses bundle without re-baking")
		check(cache.bundles.size() <= 2, "bounded bundle cache")
		check(before == Adapter.authority_bytes() and context_before == Contract.canonical(public_context) and profile_before == Contract.canonical(profile), "map/profile/targets unchanged")
		results.append({"visual_seed": SEEDS[index], "profile_digest": Profile.digest(profile), "plan_sha256": Contract.canonical(current.plan).sha256_text(), "layer_rgba_sha256": layers, "cache_key": current.bundle.cache_key, "timing_us": current.timing_us, "memory_static_before_bytes": memory_before, "memory_static_after_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "cache_entries": cache.bundles.size(), "screenshots": captures})
		current.images.clear()
	output = root_output
	save_text("public-map-context.json", Contract.canonical(public_context))
	save_text("visual-profile.json", Contract.canonical(profile))
	save_text("wg1-native-evidence.json", JSON.stringify({"engine_version": Engine.get_version_info(), "os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "processor": OS.get_processor_name(), "map_public_digest": public_context.map_public_digest, "profile_digest": Profile.digest(profile), "generator_version": Profile.VERSION, "results": results, "performance_note": "upload_api is CPU API elapsed, not GPU fence timing; static memory is engine process memory, not texture VRAM. No game p95 or WG2 leak test.", "human_acceptance": "NOT_RUN", "failed": failed}, "\t"))
	print("WG1_NATIVE | passed=", passed, " | failed=", failed)
	get_tree().quit(1 if failed else 0)
