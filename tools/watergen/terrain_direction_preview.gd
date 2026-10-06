extends Node2D
## Art studies only. No World, MapContext, collision or observation.
## The single images are concept plates, not layered production environments.
const Art = preload("res://scripts/pixel_art.gd")
const Fauna = preload("res://tools/watergen/decorative_fauna_layer.gd")
const STUDIES := {
	"terrain": {
		"files": ["res://docs/watergen/terrain-round1/A-trough-log.png", "res://docs/watergen/terrain-round1/B-stone-bay.png", "res://docs/watergen/terrain-round1/C-root-channel.png"],
		"titles": ["A · 偏心沟谷与低位倒木", "B · 单侧石坡与开阔沙湾", "C · 斜向浅沟与沉木根盘"],
		"ids": ["A", "B", "C"], "tag": "TERRAIN_R1", "initial": 0,
		"help": "1 / 2 / 3 方案   Tab 全景/镜头   方向键平移   P 识别样本   G 留白区   Home 居中   Esc",
		"footer": "第一轮：地势与大构图。样本为静态视觉检查；此画面没有运行玩法模拟。",
		"cameras": [Vector2(0, 120), Vector2(320, 120), Vector2(640, 120)]},
	"plants": {
		"files": ["res://docs/watergen/terrain-round1/A-trough-log.png", "res://docs/watergen/plants-round2/A-plant-communities.png"],
		"titles": ["A · 第一轮地势", "A · 第二轮植物群落"],
		"ids": ["BASE", "PLANTS"], "tag": "PLANTS_R2", "initial": 1,
		"help": "1 地势 / 2 植物   Tab 全景/镜头   方向键平移   P 识别样本   G 留白区   Home 居中   Esc",
		"footer": "第二轮：植物群落。静态构图预览；未运行玩法模拟，尚未添加装饰动物。",
		"cameras": [Vector2(0, 120), Vector2(320, 120), Vector2(640, 120), Vector2(0, 0), Vector2(640, 0)]},
	"fauna": {
		"files": ["res://docs/watergen/plants-round2/A-plant-communities.png", "res://docs/watergen/plants-round2/A-plant-communities.png"],
		"titles": ["A · 第二轮植物", "A · 第三轮装饰生态"],
		"ids": ["PLANTS", "FAUNA"], "tag": "FAUNA_R3", "initial": 1,
		"help": "1 植物 / 2 生态   Tab 全景/镜头   方向键   P 样本   G 标记   空格暂停   R 归零   Esc",
		"footer": "第三轮：3 虾 / 2 蜗牛 / 2 组远景鱼。纯视觉叠加；不运行玩法模拟。",
		"cameras": [Vector2(0, 120), Vector2(320, 120), Vector2(640, 120), Vector2(0, 0), Vector2(640, 0)]}
}
@export_enum("terrain", "plants", "fauna") var study := "terrain"
var settings: Dictionary = {}
var fauna: RefCounted
var visual_time := 0.0
var paused := false
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
	if not STUDIES.has(study): push_error("Unknown visual study"); get_tree().quit(2); return
	settings = STUDIES[study]
	selection = settings.initial
	get_window().size = Vector2i(1280, 720)
	get_window().title = "Watergen | " + settings.tag + " | visual study"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fish = Art.fish()
	if study == "fauna": fauna = Fauna.new()
	var loaded: Dictionary = {}
	for file: String in settings.files:
		if loaded.has(file): plates.append(loaded[file]); continue
		var image := Image.load_from_file(file)
		if image == null or image.is_empty() or image.get_size() != Vector2i(2048, 768):
			push_error("Terrain study missing or wrong dimensions: " + file)
			get_tree().quit(2); return
		var plate := ImageTexture.create_from_image(image)
		loaded[file] = plate
		plates.append(plate)
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture": capture = true
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=").replace("\\", "/").simplify_path()
	if capture: call_deferred("capture_all")
	queue_redraw()

func _process(delta: float) -> void:
	if capture: return
	advance_visual_time(delta)
	if overview: return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		camera = (camera + direction * delta * 180).clamp(Vector2.ZERO, Vector2(640, 120))
		queue_redraw()

func advance_visual_time(delta: float) -> void:
	if study != "fauna" or paused or not is_finite(delta) or delta < 0 or delta > 60: return
	visual_time = fmod(visual_time + delta, 86400.0)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			if event.keycode - KEY_1 < plates.size(): selection = event.keycode - KEY_1
		KEY_TAB: overview = not overview
		KEY_P: probes = not probes
		KEY_G: guides = not guides
		KEY_HOME: camera = Vector2(320, 120)
		KEY_SPACE: paused = not paused
		KEY_R: visual_time = 0.0
		KEY_ESCAPE: get_tree().quit()
	queue_redraw()

func label(p: Vector2, text: String, size := 11, color := CREAM) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if settings.is_empty() or plates.size() != settings.files.size(): return
	draw_rect(Rect2(0, 0, 640, 360), INK)
	if overview: draw_set_transform(Vector2(0, 55), 0, Vector2(0.5, 0.5))
	else: draw_set_transform(-camera.round())
	draw_texture_rect(plates[selection], Rect2(0, 0, 1280, 480), false)
	if study == "fauna" and selection == 1: fauna.draw(self, visual_time)
	if guides:
		draw_rect(Rect2(320, 77, 679, 230), Color(0.55, 0.9, 0.76, 0.55), false, 1)
		# This rectangle is a composition guide, never an Authority boundary.
		if study == "fauna" and selection == 1: fauna.debug_draw(self, visual_time)
	if probes: draw_world_probes()
	draw_set_transform(Vector2.ZERO)
	if probes and not overview: draw_ui_probes()
	draw_rect(Rect2(0, 0, 640, 32), INK)
	label(Vector2(10, 14), settings.titles[selection], 12, Color("a9d0bf"))
	label(Vector2(310, 14), "构图稿 · 全景" if overview else "构图稿 · 640×360 镜头", 11)
	if study == "fauna": label(Vector2(488, 14), "%s %.1fs" % ["暂停" if paused else "播放", visual_time], 10)
	label(Vector2(10, 28), settings.help, 10)
	draw_rect(Rect2(0, 335, 640, 25), INK)
	label(Vector2(10, 351), settings.footer, 10)

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
	if condition: passed += 1; print(settings.tag, "_PASS | ", message)
	else: failed += 1; push_error(settings.tag + "_FAIL | " + message)

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
	check(plates.size() == settings.files.size(), "requested study plates loaded")
	var previous := PackedByteArray()
	for index in plates.size():
		var id: String = settings.ids[index]
		selection = index; overview = true; probes = false
		var image := await save_frame(id + "-overview")
		check(previous != image.get_data(), "different composition " + str(index))
		previous = image.get_data()
		overview = false
		for location: Vector2 in settings.cameras:
			camera = location; probes = false
			var name := "%s-%d" % [id, int(location.x)]
			if study != "terrain": name += "-%d" % int(location.y)
			var clean := await save_frame(name + "-clean")
			probes = true
			var sample := await save_frame(name + "-probes")
			check(clean.get_data() != sample.get_data(), "probes visible without altering plate")
		# Redrawing a static frame must be identical, including panel and line samples.
		var repeat := await save_frame(id + "-repeat")
		queue_redraw()
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(repeat.get_data() == get_viewport().get_texture().get_image().get_data(), "repeat frame stable")
	check(plates.size() == settings.files.size(), "study textures retained; draw never prepares new textures")
	if study == "fauna": await capture_fauna()
	var record := {"passed": passed, "failed": failed, "study": study, "scope": "Visual study and fixed readability samples; no gameplay simulation", "production_integration": false, "human_review": "PENDING", "engine": Engine.get_version_info().string}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n"); file.close()
	print("%s | passed=%d | failed=%d" % [settings.tag, passed, failed])
	get_tree().quit(1 if failed else 0)

func capture_fauna() -> void:
	check(plates[0] == plates[1], "before/after share the unchanged plant texture")
	check(fauna.texture.get_size() == Vector2(96, 8) and fauna.upload_count == 1, "one small fauna atlas")
	var anchors: Array = [fauna.residents.duplicate(true), fauna.schools.duplicate(true)]
	var repeat: Array = fauna.sample(8)
	check(repeat == fauna.sample(8), "explicit time repeats exactly")
	check(repeat != fauna.sample(0), "visual time animates the decoration")
	check(repeat != fauna.sample(8, 42), "local visual seed changes only phases")
	check(fauna.sample(-1).is_empty() and fauna.sample(NAN).is_empty(), "invalid time rejected")
	var clear := true
	var bounded := true
	var count_ok := true
	var small_fish := true
	for tick in 181:
		var frame: Array = fauna.sample(float(tick))
		count_ok = count_ok and frame.size() == 15
		for animal: Dictionary in frame:
			var box := Rect2(animal.position, animal.region.size)
			clear = clear and not Fauna.CLEAR_ZONE.intersects(box)
			bounded = bounded and Rect2(0, 0, 1280, 480).encloses(box)
			if animal.kind == "distant_fish": small_fish = small_fish and box.size == Vector2(8, 3) and animal.opacity < 0.5
	check(clear, "all motion avoids the central activity rectangle for 181 samples")
	check(bounded and count_ok, "three shrimp, two snails, ten distant fish stay bounded")
	check(small_fish, "distant fish remain smaller and dimmer than player/NPC sprites")
	check(anchors == [fauna.residents, fauna.schools] and fauna.upload_count == 1, "sampling does not mutate habitats or upload textures")
	visual_time = 8; paused = true; advance_visual_time(0.5)
	check(visual_time == 8, "pause freezes the explicit preview clock")
	paused = false; advance_visual_time(0.5)
	check(visual_time == 8.5, "resume advances only local visual time")
	overview = false; camera = Vector2(320, 120); selection = 1; probes = false
	visual_time = 0
	var zero := await save_frame("FAUNA-time-0")
	visual_time = 8
	var later := await save_frame("FAUNA-time-8")
	check(zero.get_data() != later.get_data(), "native animal animation changes pixels")
	visual_time = 0
	check(zero.get_data() == (await save_frame("FAUNA-seek-0")).get_data(), "native seek repeats original frame")
	await save_world("PLANTS-world", 0, false)
	await save_world("FAUNA-world", 0, true)
	await save_world("FAUNA-world-8", 8, true)
	await save_world("detail-shrimp", 8, true, Vector2i(384, 216), Vector2(174, 337), 3.0)
	await save_world("detail-snail", 8, true, Vector2i(384, 216), Vector2(435, 312), 3.0)
	await save_world("detail-school", 8, true, Vector2i(384, 216), Vector2(248, 149), 3.0)
	check(fauna.upload_count == 1, "captures and camera changes keep one atlas")

func save_world(name: String, time: float, animals: bool, size := Vector2i(1280, 480), center := Vector2.ZERO, zoom := 1.0) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	canvas.draw.connect(func():
		if zoom != 1.0: canvas.draw_set_transform(Vector2(size) * 0.5 - center * zoom, 0, Vector2.ONE * zoom)
		canvas.draw_texture_rect(plates[0], Rect2(0, 0, 1280, 480), false)
		if animals: fauna.draw(canvas, time))
	canvas.queue_redraw()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image.get_size() == size, "world/detail canvas " + name)
	var path := output.path_join(name + ".png")
	check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "save world " + name)
	viewport.free()
