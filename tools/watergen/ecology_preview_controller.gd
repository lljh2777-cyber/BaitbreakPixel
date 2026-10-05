extends Node
const Canvas = preload("res://tools/watergen/ecology_preview_canvas.gd")
const Resolver = preload("res://scripts/maps/map_resolver.gd")
const Clock = preload("res://scripts/watergen/water_visual_frame.gd")
const MAP_SEEDS := [42, 2166, 1346, 296]
const CAMERAS := [[0, 0], [320, 120], [640, 120], [0, 120], [640, 0]]
const MODES := ["full", "before", "plants", "geometry"]
const LABELS := ["完整环境 + 群落", "开发基线 · 无新增群落", "真实地形 + 群落", "真实地形"]
var canvas: Node2D
var viewport: SubViewport
var map_box: LineEdit
var label: Label
var context: RefCounted
var clock := Clock.new()
var map_seed := 42
var visual_seed := 713284
var density := "medium"
var mode_index := 0
var output := ""
var capture_mode := false
var passed := 0
var failed := 0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture": capture_mode = true
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=").replace("\\", "/").simplify_path()
	if DisplayServer.get_name() == "headless": push_error("WG62 native preview requires a renderer"); get_tree().quit(2); return
	get_window().size = Vector2i(1280, 840)
	get_window().content_scale_size = Vector2i(640, 420)
	get_window().title = "WG-6.2 | generated geometry + decorative plant communities"
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	canvas = Canvas.new()
	viewport.add_child(canvas)
	var display := TextureRect.new()
	display.position = Vector2(0, 40)
	display.size = Vector2(640, 360)
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture = viewport.get_texture()
	add_child(display)
	map_box = LineEdit.new()
	map_box.position = Vector2(8, 5); map_box.size = Vector2(120, 29)
	map_box.text = "42"; map_box.placeholder_text = "地图种子"
	map_box.text_submitted.connect(func(_value: String): apply_seed())
	add_child(map_box)
	var button := Button.new()
	button.position = Vector2(134, 5); button.size = Vector2(60, 29); button.text = "生成"
	button.pressed.connect(apply_seed); add_child(button)
	label = Label.new(); label.position = Vector2(201, 5); label.add_theme_font_size_override("font_size", 10); add_child(label)
	var help := Label.new(); help.position = Vector2(8, 402); help.add_theme_font_size_override("font_size", 10)
	help.text = "[ ] 地图 · V 视觉种子 · D 密度 · Tab 对照 · 1–5 镜头 · 方向键 · 空格暂停 · G 挂点 · Esc"
	add_child(help)
	clock.paused = true
	if capture_mode:
		var prefix := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
		if not output.begins_with(prefix) or output == prefix: push_error("Capture path must be a run directory inside artifacts/watergen"); get_tree().quit(2); return
		call_deferred("capture")
	else: select_map(42)

func select_map(seed: int) -> bool:
	var result := Resolver.resolve(Resolver.generated(seed))
	if not result.valid:
		label.text = "地图种子无效，保留当前画面"; return false
	if not canvas.prepare(result.context, visual_seed, density):
		label.text = "群落准备失败，详情见运行日志"; return false
	context = result.context; map_seed = seed; map_box.text = str(seed)
	update_label(); return true

func apply_seed() -> void:
	var value := map_box.text.strip_edges()
	if value.length() > 10 or not value.is_valid_int() or str(value.to_int()) != value or value.to_int() < 0 or value.to_int() > 2147483647:
		label.text = "请输入 0–2147483647 的整数地图种子"; return
	select_map(value.to_int())
	map_box.release_focus()

func update_label() -> void:
	label.text = "%s\n视觉 %d · 密度 %s · 地图 %d" % [LABELS[mode_index], visual_seed, density, map_seed]

func _process(delta: float) -> void:
	if capture_mode or context == null: return
	if not map_box.has_focus():
		var direction := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
		canvas.camera_offset = (canvas.camera_offset + direction * roundf(delta * 180)).clamp(Vector2.ZERO, Vector2(640, 120))
	clock.advance(delta); canvas.visual_time = clock.visual_time; canvas.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_mode or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			select_map(MAP_SEEDS[posmod(MAP_SEEDS.find(map_seed) + (1 if event.keycode == KEY_BRACKETRIGHT else -1), MAP_SEEDS.size())])
		KEY_V:
			visual_seed = 42 if visual_seed == 713284 else 713284; select_map(map_seed)
		KEY_D:
			density = ["low", "medium", "high"][posmod(["low", "medium", "high"].find(density) + 1, 3)]; select_map(map_seed)
		KEY_TAB: mode_index = (mode_index + 1) % MODES.size(); canvas.mode = MODES[mode_index]; update_label()
		KEY_SPACE: clock.paused = not clock.paused
		KEY_G: canvas.guides = not canvas.guides
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var p: Array = CAMERAS[event.keycode - KEY_1]; canvas.camera_offset = Vector2(p[0], p[1])
	canvas.queue_redraw()

func check(ok: bool, text: String) -> void:
	if ok: passed += 1; print("WG62_NATIVE_PASS | ", text)
	else: failed += 1; push_error("WG62_NATIVE_FAIL | " + text)

func render() -> Image:
	canvas.queue_redraw()
	for tick in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func save(image: Image, name: String) -> void:
	var path := output.path_join(name + ".png")
	check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "save " + name)

func counts() -> Array:
	return [canvas.ecology.prepare_count, canvas.ecology.bake_count, canvas.ecology.upload_count, canvas.generated_water.cache.bake_count]

func capture() -> void:
	var base_output := output
	var records: Array = []
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(output + "/isolated-user/"), "isolated user directory")
	for seed: int in MAP_SEEDS:
		check(select_map(seed), "load true generated map " + str(seed))
		var targets: Array = context.interaction_targets
		var blockers: Array = context.net_blockers
		var before_counts := counts()
		output = base_output.path_join("map-" + str(seed))
		DirAccess.make_dir_recursive_absolute(output)
		var plan: Dictionary = canvas.ecology.bundle.plan
		var file := FileAccess.open(output.path_join("communities.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(plan, "\t")); file.close()
		records.append({"map_seed": seed, "visual_seed": visual_seed, "patch_count": plan.patches.size(), "community_count": plan.communities.size(), "preparation_us": canvas.ecology.last_timing_us.duplicate(), "atlas_size": [canvas.ecology.bundle.texture.get_width(), canvas.ecology.bundle.texture.get_height()]})
		var pictures: Dictionary = {}
		for mode in MODES:
			canvas.mode = mode
			viewport.size = Vector2i(1280, 480); canvas.camera_offset = Vector2.ZERO
			save(await render(), mode + "-world")
			viewport.size = Vector2i(640, 360)
			for camera in CAMERAS:
				canvas.camera_offset = Vector2(camera[0], camera[1])
				var picture := await render()
				var name := "%s-%d-%d" % [mode, camera[0], camera[1]]
				save(picture, name)
				check(picture.get_data() == (await render()).get_data(), "paused repeat " + name)
				if camera == [320, 120]: pictures[mode] = picture.get_data()
		check(pictures.full != pictures.before and pictures.plants != pictures.geometry, "flora changes the actual scene pixels " + str(seed))
		check(counts() == before_counts, "cameras and modes do not regenerate/upload")
		check(context.interaction_targets == targets and context.net_blockers == blockers, "geometry, blockers and target order unchanged")
	output = base_output
	select_map(42); canvas.mode = "plants"; canvas.camera_offset = Vector2(320, 120)
	var unchanged := counts()
	var texture: Texture2D = canvas.ecology.bundle.texture
	check(select_map(42) and counts() == unchanged and canvas.ecology.bundle.texture == texture, "same context restart reuses exact atlas")
	texture = null
	var at_zero := await render()
	canvas.visual_time = 4
	check(at_zero.get_data() != (await render()).get_data(), "bounded foliage movement")
	canvas.visual_time = 0
	check(at_zero.get_data() == (await render()).get_data(), "seek reproduces exact pixels")
	var costs: Array = []
	for tick in 180:
		canvas.camera_offset = Vector2(roundf(tick * 640.0 / 179), 120)
		canvas.visual_time = tick / 60.0; canvas.queue_redraw()
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		costs.append(canvas.last_draw_us)
	check(counts() == unchanged, "180 moving frames do not bake/upload")
	canvas.visual_time = 0; canvas.camera_offset = Vector2(320, 120)
	canvas.cover_opacity = 0.22
	save(await render(), "attached-cover-fade")
	var all_patches: Array = canvas.ecology.bundle.patches
	canvas.ecology.bundle.patches = all_patches.filter(func(p: Dictionary): return p.anchor_target >= 0)
	canvas.cover_opacity = 0; canvas.mode = "full"
	var invisible := await render()
	canvas.mode = "before"
	check(invisible.get_data() == (await render()).get_data(), "fully faded cover leaves no floating epiphytes")
	canvas.cover_opacity = 1.0; canvas.mode = "full"
	var attached := await render()
	canvas.mode = "before"
	check(attached.get_data() != (await render()).get_data(), "attached plants are visible on solid reference surfaces")
	canvas.ecology.bundle.patches = all_patches
	canvas.mode = "plants"
	canvas.cover_opacity = 1.0; canvas.guides = true
	save(await render(), "public-anchors")
	canvas.guides = false
	var old: WeakRef = weakref(canvas.ecology.bundle.texture)
	for seed: int in [2166, 1346, 296]:
		select_map(seed)
		check(canvas.ecology.entries.size() == 2, "two ecology atlases maximum")
	check(old.get_ref() == null, "evicted ecology atlas released")
	# Same real map, another visual seed: geometry and placement must stay decoupled.
	var original: Array = context.interaction_targets
	var first_plan: Dictionary = canvas.ecology.bundle.plan.duplicate(true)
	visual_seed = 42; select_map(map_seed)
	check(canvas.ecology.bundle.plan.patches != first_plan.patches and context.interaction_targets == original, "visual variation does not regenerate authority terrain")
	costs.sort()
	var evidence := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "records": records, "draw_cpu_median_us": costs[90], "draw_cpu_p95_us": costs[171], "moving_frames": 180, "performance_scope": "Standalone public-geometry preview; draw-command CPU time, not full-game FPS", "human_review": "PENDING", "passed": passed, "failed": failed}
	var report := FileAccess.open(output.path_join("native-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(evidence, "\t")); report.close()
	print("WG62_NATIVE | passed=%d | failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
