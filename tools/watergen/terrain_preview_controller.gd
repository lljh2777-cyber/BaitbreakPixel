extends "res://tools/watergen/preview_controller.gd"
## WG-6.1 independent viewer. No Main, World, player store or game session.
const DynamicCanvas = preload("res://tools/watergen/dynamic_preview_canvas.gd")
const TerrainCache = preload("res://tools/watergen/terrain_preview_cache.gd")
const Materials = preload("res://scripts/watergen/water_cover_materials.gd")
const LegacyCanvas = preload("res://tools/watergen/terrain_legacy_canvas.gd")
const Clock = preload("res://scripts/watergen/water_visual_frame.gd")
const PRESETS := ["fern", "ribbon", "lily", "root"]
const SEEDS := [713284, 2649, 42, 731]
const LABELS := ["蕨叶庭 · 中央浅沟", "长叶湾 · 单侧缓坡", "浮叶荫 · 沉积低洼", "垂根岸 · 石质高岸"]
const MODES := ["full", "terrain", "before", "legacy"]
const MODE_LABELS := ["WG-6 地势 + 现有环境", "只看地势", "现有生成水域", "Legacy 原版"]
var cache := TerrainCache.new()
var clock := Clock.new()
var profiles: Dictionary
var visual_profile: Dictionary
var current: Dictionary = {}
var legacy: Node2D
var status_label: Label
var seed_index := 0
var mode_index := 0
var material_ready := false
var source_props: Array[Dictionary] = []
var source_plants: Array[Dictionary] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--wg-capture": capture_mode = true
		elif argument == "--wg-legacy": mode_index = 3
		elif argument.begins_with("--wg-output="): output = argument.trim_prefix("--wg-output=").replace("\\", "/").simplify_path()
	if DisplayServer.get_name() == "headless":
		push_error("WG6 preview needs a native renderer")
		get_tree().quit(2); return
	before = Adapter.authority_bytes()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	public_context = Adapter.build(source.source_commit)
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/terrain_profiles.json"))
	visual_profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	canvas = DynamicCanvas.new()
	viewport.add_child(canvas)
	canvas.prepare_geometry(public_context)
	source_props = canvas.props.duplicate(true)
	source_plants = canvas.plants.duplicate(true)
	legacy = LegacyCanvas.new()
	viewport.add_child(legacy)
	legacy.hide()
	legacy.context = public_context.duplicate(true)
	legacy.props = source_props
	legacy.plants = source_plants
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(640, 360)
	add_child(display)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.09, 0.11, 0.92)
	panel.size = Vector2(640, 36)
	add_child(panel)
	status_label = Label.new()
	status_label.position = Vector2(8, 2)
	status_label.add_theme_font_size_override("font_size", 11)
	add_child(status_label)
	get_window().title = "WG-6.1 independent terrain preview | [ ] preset | Tab mode | 1-5 camera | arrows pan | Space pause | F samples | Esc"
	canvas.camera_offset = Vector2(320, 60)
	clock.paused = true
	if capture_mode:
		var allowed := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
		if not output.begins_with(allowed) or output == allowed:
			push_error("WG6 capture output must be inside artifacts/watergen")
			get_tree().quit(2); return
		call_deferred("capture")
	else: select_view()

func prepare_materials() -> void:
	if material_ready: return
	for index in canvas.props.size():
		var prop: Dictionary = canvas.props[index]
		var kind: String = public_context.static_cover_records[prop.targets[0]].kind
		prop.texture = ImageTexture.create_from_image(Materials.finish(source_props[index].texture.get_image(), kind, prop.position, prop.targets[0]))
	for index in canvas.plants.size():
		var plant: Dictionary = canvas.plants[index]
		plant.texture = ImageTexture.create_from_image(Materials.finish(source_plants[index].texture.get_image(), "plant", plant.position, index))
	material_ready = true

func select_view() -> bool:
	var is_legacy := mode_index == 3
	canvas.visible = not is_legacy
	legacy.visible = is_legacy
	if is_legacy:
		# Cold legacy never calls WG6 generation, bake, materials or uploads.
		if legacy.water_layers.is_empty(): legacy.water_layers = legacy.Water.layers()
		legacy.camera_offset = canvas.camera_offset
		legacy.queue_redraw()
	else:
		prepare_materials()
		cache.mode = MODES[mode_index]
		cache.terrain_profile = profiles[PRESETS[seed_index]]
		current = cache.prepare(public_context, visual_profile, SEEDS[seed_index])
		if not current.ok:
			push_error("WG6 preparation failed: " + str(current))
			get_tree().quit(1); return false
		canvas.use_bundle(current.bundle)
		canvas.show_geometry = mode_index != 1
		current.images.clear()
	update_label()
	return true

func update_label() -> void:
	status_label.text = "%s %d  |  %s\n[ ] 构图 · Tab 对照 · 1–5 镜头 · 方向键移动 · 空格播放 · F 样本 · Esc 退出" % [LABELS[seed_index], SEEDS[seed_index], MODE_LABELS[mode_index]]

func _process(delta: float) -> void:
	if capture_mode or not is_instance_valid(canvas): return
	super._process(delta)
	clock.advance(delta)
	canvas.visual_time = clock.visual_time
	canvas.queue_redraw()
	legacy.camera_offset = canvas.camera_offset
	legacy.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_mode or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_TAB:
			mode_index = posmod(mode_index + 1, MODES.size())
			select_view()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			seed_index = posmod(seed_index + (1 if event.keycode == KEY_BRACKETRIGHT else -1), PRESETS.size())
			select_view()
		KEY_SPACE: clock.paused = not clock.paused
		KEY_R: clock.seek(0)
		KEY_F:
			if canvas.fixtures == null: canvas.fixtures = DynamicCanvas.Fixtures.new()
			canvas.show_fixtures = not canvas.show_fixtures
		_: super._unhandled_key_input(event)

func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("WG6_NATIVE_PASS | ", title)
	else: failed += 1; push_error("WG6_NATIVE_FAIL | " + title)

func counts() -> Array:
	return [cache.plan_count, cache.bake_count, cache.upload_count, cache.texture_count]

func same_mask(first: Image, second: Image) -> bool:
	if first.get_size() != second.get_size(): return false
	var a := first.get_data()
	var b := second.get_data()
	for index in range(3, a.size(), 4):
		if a[index] != b[index]: return false
	return true

func frame(camera: Array, time := 0.0) -> void:
	canvas.camera_offset = Vector2(camera[0], camera[1])
	canvas.visual_time = time
	legacy.camera_offset = canvas.camera_offset
	canvas.queue_redraw()
	legacy.queue_redraw()

func capture() -> void:
	var root_output := output
	var immutable := Contract.canonical(public_context) + Contract.canonical(profiles) + Contract.canonical(visual_profile)
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(root_output + "/isolated-user/"), "isolated user directory")
	mode_index = 3
	select_view()
	check(counts() == [0, 0, 0, 0] and not material_ready, "cold legacy creates no terrain or WG5 resources")
	var results: Array = []
	for index in PRESETS.size():
		seed_index = index
		output = root_output.path_join(PRESETS[index])
		if DirAccess.make_dir_recursive_absolute(output) != OK: get_tree().quit(2); return
		var row := {"preset": PRESETS[index], "seed": SEEDS[index], "captures": [], "preparation_us": {}}
		for mode in MODES.size():
			mode_index = mode
			if not select_view(): return
			if mode != 3: row.preparation_us[MODES[mode]] = current.timing_us.duplicate()
			if mode == 0: save_text("terrain-plan.json", Contract.canonical(current.plan.visual_terrain))
			var frozen_counts := counts()
			viewport.size = Vector2i(1280, 480)
			frame([0, 0])
			save_image(await render(), MODES[mode] + "-world")
			viewport.size = Vector2i(640, 360)
			for camera in CAMERAS:
				frame(camera)
				var image := await render()
				var name := "%s-%d-%d" % [MODES[mode], camera[0], camera[1]]
				save_image(image, name)
				check(image.get_data() == (await render()).get_data(), "repeat frame " + name)
				check(image.get_pixel(0, 359).a == 1 and image.get_pixel(639, 359).a == 1, "camera borders opaque " + name)
				row.captures.append({"path": name + ".png", "camera": camera, "rgba_sha256": rgba_digest(image)})
			check(frozen_counts == counts(), "no camera-triggered generation or upload " + MODES[mode])
		results.append(row)
	output = root_output
	mode_index = 0
	seed_index = 0
	select_view()
	var geometry_preserved := true
	for index in canvas.props.size():
		var prop: Dictionary = canvas.props[index]
		geometry_preserved = geometry_preserved and prop.position == source_props[index].position and prop.targets == source_props[index].targets and same_mask(prop.texture.get_image(), source_props[index].texture.get_image())
	for index in canvas.plants.size():
		var plant: Dictionary = canvas.plants[index]
		geometry_preserved = geometry_preserved and plant.position == source_plants[index].position and plant.back == source_plants[index].back and same_mask(plant.texture.get_image(), source_plants[index].texture.get_image())
	check(geometry_preserved, "WG5 reference sprites retain every alpha pixel, position and target")
	frame([320, 60])
	canvas.fixtures = DynamicCanvas.Fixtures.new()
	canvas.show_fixtures = true
	save_image(await render(), "fern-readability-fixtures")
	canvas.show_fixtures = false
	var warm_counts := counts()
	var reference: Texture2D = current.bundle.layers.floor.texture
	select_view()
	check(current.cache_hit and reference == current.bundle.layers.floor.texture and warm_counts.slice(1) == counts().slice(1), "warm cache reuses texture identity without bake or upload")
	reference = null
	var eviction_refs: Array = []
	for index in 8:
		eviction_refs.append(weakref(current.bundle.layers.floor.texture))
		seed_index = (index + 1) % 4
		select_view()
		check(cache.bundles.size() <= 2, "two-bundle limit switch " + str(index))
	var released := true
	for ref in eviction_refs.slice(0, 6): released = released and ref.get_ref() == null
	check(released, "evicted terrain textures released")
	var fixed_counts := counts()
	var draw_cost: Array = []
	for index in 240:
		frame([roundi(640.0 * index / 239), roundi(120.0 * index / 239)], index / 60.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		draw_cost.append(canvas.last_draw_us)
	check(fixed_counts == counts(), "240 moving frames without generation or uploads")
	frame([320, 60], 0)
	var at_zero := await render()
	frame([320, 60], 3)
	check(at_zero.get_data() != (await render()).get_data(), "existing foliage still animates")
	frame([320, 60], 0)
	check(at_zero.get_data() == (await render()).get_data(), "time seek restores pixels")
	check(before == Adapter.authority_bytes() and immutable == Contract.canonical(public_context) + Contract.canonical(profiles) + Contract.canonical(visual_profile), "map targets/order and all inputs untouched")
	draw_cost.sort()
	save_text("wg6-native-evidence.json", JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "results": results, "cache_counts": counts(), "cache_entries": cache.bundles.size(), "eviction_verified": released, "moving_frames": 240, "draw_cpu_us_median": draw_cost[120], "draw_cpu_us_p95": draw_cost[228], "performance_note": "Native preview draw submission only, not GPU/FPS or full-game frame time. Cold preparation includes terrain and existing environment; upload_api is not a GPU fence.", "map_public_digest": public_context.map_public_digest, "human_acceptance": "NOT_RUN", "omissions": ["live NPC/food/rope/net/HUD/QTE sessions", "WG6 plants", "animals", "production integration"], "passed": passed, "failed": failed}, "\t"))
	print("WG6_NATIVE | passed=", passed, " | failed=", failed)
	get_tree().quit(1 if failed else 0)
