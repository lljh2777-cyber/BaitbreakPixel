extends Node2D
## Round-one art studies only. No World, MapContext, collision or observation.
## The single images are concept plates, not layered production environments.
const Art = preload("res://scripts/pixel_art.gd")
const FILES := ["A-trough-log.png", "B-stone-bay.png", "C-root-channel.png"]
const TITLES := ["A · 偏心沟谷与低位倒木", "B · 单侧石坡与开阔沙湾", "C · 斜向浅沟与沉木根盘"]
const CAMERAS := [Vector2(0, 120), Vector2(320, 120), Vector2(640, 120)]
const INK := Color("142e39")
const CREAM := Color("fff0cd")
var plates: Array[Texture2D] = []
var fish: Texture2D
var font: SystemFont
var selection := 0
var camera := Vector2(320, 120)
var overview := true
var probes := false
var guides := false
var capture := false
var output := ""
var passed := 0
var failed := 0

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().title = "Watergen | terrain direction studies | round 1"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fish = Art.fish()
	for file: String in FILES:
		var image := Image.load_from_file("res://docs/watergen/terrain-round1/" + file)
		if image == null or image.is_empty() or image.get_size() != Vector2i(2048, 768):
			push_error("Terrain study missing or wrong dimensions: " + file)
			get_tree().quit(2); return
		plates.append(ImageTexture.create_from_image(image))
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture": capture = true
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=").replace("\\", "/").simplify_path()
	if capture: call_deferred("capture_all")
	queue_redraw()

func _process(delta: float) -> void:
	if capture or overview: return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		camera = (camera + direction * delta * 180).clamp(Vector2.ZERO, Vector2(640, 120))
		queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_1, KEY_2, KEY_3: selection = event.keycode - KEY_1
		KEY_TAB: overview = not overview
		KEY_P: probes = not probes
		KEY_G: guides = not guides
		KEY_HOME: camera = Vector2(320, 120)
		KEY_ESCAPE: get_tree().quit()
	queue_redraw()

func label(p: Vector2, text: String, size := 11, color := CREAM) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if plates.size() != 3: return
	draw_rect(Rect2(0, 0, 640, 360), INK)
	if overview: draw_set_transform(Vector2(0, 55), 0, Vector2(0.5, 0.5))
	else: draw_set_transform(-camera.round())
	draw_texture_rect(plates[selection], Rect2(0, 0, 1280, 480), false)
	if guides:
		draw_rect(Rect2(320, 77, 679, 230), Color(0.55, 0.9, 0.76, 0.55), false, 1)
		# This rectangle is a composition guide, never an Authority boundary.
	if probes: draw_world_probes()
	draw_set_transform(Vector2.ZERO)
	if probes and not overview: draw_ui_probes()
	draw_rect(Rect2(0, 0, 640, 32), INK)
	label(Vector2(10, 14), TITLES[selection], 12, Color("a9d0bf"))
	label(Vector2(310, 14), "构图稿 · 全景" if overview else "构图稿 · 640×360 镜头", 11)
	label(Vector2(10, 28), "1 / 2 / 3 方案   Tab 全景/镜头   方向键平移   P 识别样本   G 留白区   Home 居中   Esc", 10)
	draw_rect(Rect2(0, 335, 640, 25), INK)
	label(Vector2(10, 351), "第一轮：地势与大构图。样本为静态视觉检查；此画面没有运行玩法模拟。", 10)

func draw_world_probes() -> void:
	# Real player sprite; other samples deliberately use fixed public visual values.
	for point in [Vector2(310, 245), Vector2(638, 235), Vector2(920, 290)]:
		draw_texture(fish, point - Vector2(12, 6))
	# A visible line sample only: no hooks, private truth or game-state inputs.
	draw_polyline(PackedVector2Array([Vector2(610, 45), Vector2(605, 180), Vector2(624, 300), Vector2(705, 347), Vector2(788, 401)]), Color(0.7, 0.69, 0.42, 0.8), 1)
	for kind in 3:
		var root := Vector2(535 + kind * 85, 291)
		for index in 16:
			var point := root + Vector2((index % 4) * 2 - 4, floori(index / 4.0) * 2 - 4)
			if kind == 1: point.y += (index % 4) - 2
			var color := Color("a26c3f").lerp(Color("f1d798"), 0.35 + (index % 3) * 0.18)
			var size := Vector2(3, 2) if kind == 2 else Vector2(2, 1) if kind == 1 else Vector2(2, 2)
			draw_rect(Rect2(point, size), color.darkened(0.18))
			draw_rect(Rect2(point, Vector2.ONE), color)
	for point in [Vector2(580, 336), Vector2(713, 381), Vector2(726, 388)]:
		draw_rect(Rect2(point, Vector2(2, 2)), Color("d6b375"))

func draw_ui_probes() -> void:
	# A panel mockup, not the production QTE logic or a gameplay acceptance test.
	draw_rect(Rect2(10, 48, 195, 53), INK)
	label(Vector2(18, 64), "可读性样本 · 低饱食 HUD", 11)
	draw_rect(Rect2(18, 77, 170, 5), Color("335762"))
	draw_rect(Rect2(18, 77, 24, 5), Color("f58375"))
	draw_rect(Rect2(10, 124, 168, 62), INK)
	label(Vector2(18, 140), "QTE 面板样本 · 空格", 11)
	draw_rect(Rect2(18, 154, 149, 8), Color("335762"))
	draw_rect(Rect2(80, 152, 29, 12), Color("8de0bd"), false, 1)
	draw_line(Vector2(93, 150), Vector2(93, 166), CREAM)
	label(Vector2(18, 180), "仅检查对比与视觉干扰", 10)

func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("TERRAIN_R1_PASS | ", message)
	else: failed += 1; push_error("TERRAIN_R1_FAIL | " + message)

func save_frame(name: String) -> Image:
	queue_redraw()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.get_size() == Vector2i(640, 360), "native logical viewport " + name)
	var path := output.path_join(name + ".png")
	check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "saved " + name)
	return image

func capture_all() -> void:
	var prefix := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
	if DisplayServer.get_name() == "headless" or not output.begins_with(prefix):
		push_error("Native renderer and artifact run directory required"); get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	check(plates.size() == 3, "three independently generated direction plates loaded")
	var previous := PackedByteArray()
	for index in 3:
		selection = index; overview = true; probes = false
		var image := await save_frame("%s-overview" % char(65 + index))
		check(previous != image.get_data(), "different composition " + str(index))
		previous = image.get_data()
		overview = false
		for location in CAMERAS:
			camera = location; probes = false
			var clean := await save_frame("%s-%d-clean" % [char(65 + index), int(location.x)])
			probes = true
			var sample := await save_frame("%s-%d-probes" % [char(65 + index), int(location.x)])
			check(clean.get_data() != sample.get_data(), "probes visible without altering plate")
		# Redrawing a static frame must be identical, including panel and line samples.
		var repeat := await save_frame("%s-repeat" % char(65 + index))
		queue_redraw()
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(repeat.get_data() == get_viewport().get_texture().get_image().get_data(), "repeat frame stable")
	check(plates.size() == 3, "three textures retained; draw never prepares new textures")
	var record := {"passed": passed, "failed": failed, "scope": "Round-one static art direction and readability samples only", "production_integration": false, "human_review": "PENDING", "engine": Engine.get_version_info().string}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n"); file.close()
	print("TERRAIN_R1 | passed=%d | failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
