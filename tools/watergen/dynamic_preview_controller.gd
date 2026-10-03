extends "res://tools/watergen/preview_controller.gd"
const DynamicCanvas = preload("res://tools/watergen/dynamic_preview_canvas.gd")
const Cache = preload("res://scripts/watergen/water_dynamic_cache.gd")
const Generator = preload("res://scripts/watergen/water_dynamic_generator.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const SEEDS := [42, 731, 2649, 713284]
var profile: Dictionary
var cache := Cache.new()
var clock := Frame.new()
var seed_index := 3
var current: Dictionary = {}
var status_label: Label
var timed_seconds := 60.0
var baseline_mode := false
var capture_clip := false

func load_profile() -> void:
	var path := "res://data/watergen/forest_pond_dynamic.json" if baseline_mode else "res://data/watergen/forest_pond_atmosphere.json"
	profile = JSON.parse_string(FileAccess.get_file_as_string(path))

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--wg-capture": capture_mode = true
		elif argument == "--wg-baseline": baseline_mode = true
		elif argument == "--wg-clip": capture_clip = true
		elif argument.begins_with("--wg-output="): output = argument.trim_prefix("--wg-output=").replace("\\", "/").simplify_path()
		elif argument.begins_with("--wg-test-seconds="): timed_seconds = float(argument.trim_prefix("--wg-test-seconds="))
	if DisplayServer.get_name() == "headless" or timed_seconds < 1 or timed_seconds > 120:
		push_error("WG2 requires a real renderer and bounded test duration")
		get_tree().quit(2)
		return
	before = Adapter.authority_bytes()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	public_context = Adapter.build(source.source_commit)
	load_profile()
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	canvas = DynamicCanvas.new()
	viewport.add_child(canvas)
	canvas.prepare_geometry(public_context)
	canvas.fixtures = DynamicCanvas.Fixtures.new()
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(640, 360)
	add_child(display)
	status_label = Label.new()
	status_label.position = Vector2(8, 4)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_shadow_color", Color("102b30"))
	add_child(status_label)
	get_window().title = "WG-2 atmosphere | V before/after | Space pause | , . step | R reset | F samples | [ ] seed | 1-5 camera | arrows | G H | Esc"
	if capture_mode:
		var allowed := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
		if not output.begins_with(allowed) or output == allowed:
			push_error("WG2 output must be under this worktree's artifacts/watergen")
			get_tree().quit(2)
			return
		call_deferred("capture")
	else:
		canvas.camera_offset = Vector2(0, 120)
		_select_seed()

func _select_seed() -> bool:
	current = cache.prepare(public_context, profile, SEEDS[seed_index])
	if not current.ok:
		push_error("WG2 preparation failed: " + str(current))
		get_tree().quit(1)
		return false
	canvas.use_bundle(current.bundle)
	if not capture_mode: current.images.clear()
	return true

func _frame(camera: Vector2, time: float) -> bool:
	return canvas.set_frame({"role": "preview", "camera_offset_px": [camera.x, camera.y], "viewport_size_px": [viewport.size.x, viewport.size.y], "visual_time_seconds": time})

func _process(delta: float) -> void:
	if capture_mode or not is_instance_valid(canvas): return
	super._process(delta)
	clock.advance(delta)
	_frame(canvas.camera_offset, clock.visual_time)
	var label: String = current.get("plan", {}).get("atmosphere", {}).get("label", "原版")
	status_label.text = "%s · %s · %d  %.2fs %s | V: 对照 F: 样本 [ ]: 种子" % [profile.generator_version, label, SEEDS[seed_index], clock.visual_time, "暂停" if clock.paused else "播放"]

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_mode or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: clock.paused = not clock.paused
		KEY_R: clock.seek(0)
		KEY_COMMA: clock.paused = true; clock.seek(maxf(0, clock.visual_time - 0.25))
		KEY_PERIOD: clock.paused = true; clock.seek(clock.visual_time + 0.25)
		KEY_F: canvas.show_fixtures = not canvas.show_fixtures
		KEY_V:
			clock.paused = true
			baseline_mode = not baseline_mode
			load_profile()
			_select_seed()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			seed_index = posmod(seed_index + (1 if event.keycode == KEY_BRACKETRIGHT else -1), SEEDS.size())
			_select_seed()
		_: super._unhandled_key_input(event)

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG2_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("WG2_NATIVE_FAIL | " + title)

func counts() -> Array:
	return [cache.plan_count, cache.bake_count, cache.upload_count, cache.texture_count]

func resources() -> Dictionary:
	return {"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "cache_entries": cache.bundles.size()}

func _edges(image: Image) -> bool:
	for x in image.get_width():
		for y in [0, image.get_height() - 1]:
			var color := image.get_pixel(x, y)
			if color.a < 1 or color == Color.BLACK: return false
	for y in image.get_height():
		for x in [0, image.get_width() - 1]:
			var color := image.get_pixel(x, y)
			if color.a < 1 or color == Color.BLACK: return false
	return true

func renderer_probe() -> void:
	var saved_bundle: Dictionary = canvas.bundle
	var saved_geometry: bool = canvas.show_geometry
	canvas.show_geometry = false
	canvas.show_fixtures = false
	var empty := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty.fill(Color.TRANSPARENT)
	var blank := ImageTexture.create_from_image(empty)
	for name in ["distance", "foreground"]:
		var source: Dictionary = saved_bundle.layers[name]
		var marker := Image.create(source.texture.get_width(), source.texture.get_height(), false, Image.FORMAT_RGBA8)
		marker.fill(Color.TRANSPARENT)
		marker.set_pixel(800 - source.origin_px[0], 200 - source.origin_px[1], Color.MAGENTA)
		var probe := {"layers": {}, "animations": [], "parallax_compensation": saved_bundle.parallax_compensation}
		for layer in LAYERS: probe.layers[layer] = {"texture": blank, "origin_px": [0, 0]}
		probe.layers.water = saved_bundle.layers.water
		probe.layers[name] = {"texture": ImageTexture.create_from_image(marker), "origin_px": source.origin_px}
		canvas.use_bundle(probe)
		for camera in [Vector2(320, 60), Vector2(640, 120)]:
			_frame(camera, 0)
			var image := await render()
			var k: Array = probe.parallax_compensation[name]
			# Independent explicit expectation; do not reuse renderer's offset helper.
			var expected := Vector2i(800 - int(camera.x) + roundi(camera.x * k[0]), 200 - int(camera.y) + roundi(camera.y * k[1]))
			check(image.get_pixelv(expected) == Color.MAGENTA, "native origin/camera probe " + name + " " + str(camera))
			var markers := 0
			for y in 360:
				for x in 640:
					if image.get_pixel(x, y) == Color.MAGENTA: markers += 1
			check(markers == 1, "marker appears exactly once " + name)
	canvas.show_geometry = saved_geometry
	canvas.use_bundle(saved_bundle)
	await render()

func comparison_capture() -> void:
	var selected_profile := profile.duplicate(true)
	seed_index = 3
	if not _select_seed(): return
	current.images.clear()
	_frame(Vector2(0, 120), 4)
	canvas.show_fixtures = false
	var after := await render()
	save_image(after, "comparison-after")
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_dynamic.json"))
	if not _select_seed(): return
	current.images.clear()
	check(canvas.camera_offset == Vector2(0, 120) and canvas.visual_time == 4, "comparison preserves camera and explicit time")
	var before_image := await render()
	save_image(before_image, "comparison-before")
	check(after.get_data() != before_image.get_data(), "same seed has a visible atmosphere revision")
	profile = selected_profile
	if not _select_seed(): return
	check(current.cache_hit and after.get_data() == (await render()).get_data(), "switching back restores exact new frame from cache")

func capture() -> void:
	var root_output := output
	var immutable := Contract.canonical(public_context) + Contract.canonical(profile)
	var results: Array = []
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(root_output + "/isolated-user/"), "isolated user directory")
	for index in SEEDS.size():
		seed_index = index
		if not _select_seed(): return
		output = root_output.path_join("seed-" + str(SEEDS[index]))
		if DirAccess.make_dir_recursive_absolute(output) != OK: get_tree().quit(2); return
		var layers: Dictionary = {}
		for name in LAYERS:
			var data: Dictionary = current.images[name]
			layers[name] = {"rgba_sha256": data.rgba_sha256, "origin_px": data.origin_px, "size_px": [data.image.get_width(), data.image.get_height()]}
			save_image(data.image, "layer-" + name)
		current.images.clear()
		var fixed_counts := counts()
		var captures: Array = []
		viewport.size = Vector2i(640, 360)
		for position in CAMERAS:
			_frame(Vector2(position[0], position[1]), 0)
			canvas.show_fixtures = false
			var image := await render()
			check(_edges(image), "opaque nonblack borders " + str(position))
			check(image.get_data() == (await render()).get_data(), "same time same frame")
			var name := "viewport-%d-%d" % [position[0], position[1]]
			save_image(image, name)
			captures.append({"path": name + ".png", "camera_offset_px": position, "visual_time": 0, "rgba_sha256": rgba_digest(image)})
			canvas.show_fixtures = true
			save_image(await render(), name + "-fixtures")
		canvas.show_fixtures = false
		viewport.size = Vector2i(1280, 480)
		_frame(Vector2.ZERO, 0)
		var first := await render()
		save_image(first, "world-time-0")
		_frame(Vector2.ZERO, 3)
		var moving := await render()
		save_image(moving, "world-time-3")
		check(first.get_data() != moving.get_data(), "decorative stems animate")
		_frame(Vector2.ZERO, 0)
		check(first.get_data() == (await render()).get_data(), "seek reproduces time zero")
		check(fixed_counts == counts(), "camera/time/fixtures cause no generation or upload")
		save_text("scene-plan.json", Contract.canonical(current.plan))
		results.append({"visual_seed": SEEDS[index], "plan_sha256": Contract.canonical(current.plan).sha256_text(), "layers": layers, "cache_key": current.bundle.cache_key, "atmosphere": current.plan.get("atmosphere", {}), "animation_count": current.bundle.animations.size(), "timing_us": current.timing_us, "resources": resources(), "screenshots": captures})
	output = root_output
	viewport.size = Vector2i(640, 360)
	if not baseline_mode: await comparison_capture()
	await renderer_probe()
	var switches: Array = []
	var eviction_refs: Array = []
	for index in 20:
		seed_index = index % 4
		eviction_refs.append(weakref(current.bundle.layers.water.texture))
		if not _select_seed(): return
		current.images.clear()
		_frame(Vector2(320, 60), 2)
		await render()
		var row := resources()
		row["index"] = index + 1
		row["seed"] = SEEDS[seed_index]
		row["timing_us"] = current.timing_us
		switches.append(row)
		check(cache.bundles.size() <= 2, "bounded cache switch " + str(index + 1))
	var released := true
	for reference in eviction_refs.slice(0, 17): released = released and reference.get_ref() == null
	check(released, "evicted texture objects actually released")
	var stable_resources := true
	for row in switches.slice(4): stable_resources = stable_resources and row.resource_count == switches[4].resource_count
	check(stable_resources, "resource count stable after cache warmup over 20 switches")
	var count_before_warm := counts()
	var warm := cache.prepare(public_context, profile, SEEDS[seed_index])
	check(warm.cache_hit and warm.bundle == current.bundle and counts().slice(1) == count_before_warm.slice(1), "warm cache avoids baking/upload")
	warm.clear()
	seed_index = 3
	if not _select_seed(): return
	current.images.clear()
	var steady_counts := counts()
	clock.seek(4)
	clock.paused = true
	_frame(Vector2(320, 60), clock.visual_time)
	var paused_image := await render()
	for index in 10: clock.advance(0.1)
	_frame(Vector2(320, 60), clock.visual_time)
	check(paused_image.get_data() == (await render()).get_data() and clock.visual_time == 4, "pause freezes exact pixels and time")
	clock.paused = false
	clock.advance(0.25)
	check(clock.visual_time == 4.25, "resume has no wall-clock jump")
	# Warm rendering before measured 60-second native loop.
	canvas.show_fixtures = true
	for index in 120:
		clock.advance(1.0 / 60)
		_frame(Vector2(320, 60), clock.visual_time)
		await get_tree().process_frame
	var draw_us: Array = []
	var frame_us: Array = []
	var timeline: Array = []
	var started := Time.get_ticks_usec()
	var previous := started
	var last_second := -1
	while Time.get_ticks_usec() - started < timed_seconds * 1000000:
		var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
		clock.paused = elapsed >= 20 and elapsed < 25
		clock.advance(get_process_delta_time())
		var phase := fposmod(elapsed / 20.0, 2.0)
		var x := roundf((phase if phase <= 1 else 2 - phase) * 640)
		_frame(Vector2(x, roundf(60 + sin(elapsed * 0.2) * 60)), clock.visual_time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		draw_us.append(canvas.last_draw_us)
		frame_us.append(now - previous)
		previous = now
		if int(elapsed) != last_second:
			last_second = int(elapsed)
			var row := resources()
			row.merge({"elapsed_s": elapsed, "visual_time": clock.visual_time, "paused": clock.paused, "camera": [canvas.camera_offset.x, canvas.camera_offset.y], "counts": counts()})
			timeline.append(row)
	var duration := (Time.get_ticks_usec() - started) / 1000000.0
	check(duration >= timed_seconds, "native timed duration")
	check(steady_counts == counts(), "timed preview does not regenerate/upload")
	check(before == Adapter.authority_bytes() and immutable == Contract.canonical(public_context) + Contract.canonical(profile), "map/profile/target order unchanged")
	_frame(Vector2(320, 60), 3)
	save_image(await render(), "selected-readability")
	canvas.show_fixtures = false
	save_image(await render(), "selected-environment")
	var clip: Dictionary = {}
	if capture_clip:
		output = root_output.path_join("clip-frames")
		if DirAccess.make_dir_recursive_absolute(output) != OK: get_tree().quit(2); return
		viewport.size = Vector2i(1280, 480)
		var clip_counts := counts()
		for index in 100:
			_frame(Vector2.ZERO, index / 10.0)
			save_image(await render(), "frame-%03d" % index)
		check(counts() == clip_counts, "animation clip has no static regeneration")
		output = root_output
		clip = {"directory": "clip-frames", "frames": 100, "fps": 10, "visual_time_start": 0, "visual_time_end": 9.9, "seed": SEEDS[seed_index], "size_px": [1280, 480]}
	save_text("visual-profile.json", Contract.canonical(profile))
	save_text("public-map-context.json", Contract.canonical(public_context))
	save_text("wg2-native-evidence.json", JSON.stringify({"engine_version": Engine.get_version_info(), "os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "processor": OS.get_processor_name(), "profile_digest": Profile.digest(profile), "map_public_digest": public_context.map_public_digest, "generator_version": profile.generator_version, "results": results, "clip": clip, "seed_switches": switches, "eviction_verified": released, "timed_preview": {"duration_s": duration, "required_duration_s": timed_seconds, "acceptance_60_seconds": duration >= 60, "warmup_frames": 120, "draw_cpu_us": draw_us, "frame_interval_us": frame_us, "timeline": timeline, "counts_before": steady_counts, "counts_after": counts()}, "performance_note": "draw_cpu_us measures command submission only; frame intervals include pacing, not GPU or simulation cost. upload_api is not GPU fence timing. Static memory is engine heap, not VRAM. No full-game legacy/generated performance claim.", "human_acceptance": "NOT_RUN", "failed": failed}, "\t"))
	print("WG2_NATIVE | passed=", passed, " | failed=", failed)
	get_tree().quit(1 if failed else 0)
