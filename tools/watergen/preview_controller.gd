extends Node
const Adapter = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
const Contract = preload("res://scripts/watergen/public_map_context.gd")
const Canvas = preload("res://tools/watergen/legacy_preview_canvas.gd")
const LAYERS := ["water", "distance", "surface", "terrain", "floor", "foreground"]
const CAMERAS := [[0, 0], [320, 60], [640, 120], [0, 120], [640, 0]]
var canvas: Node2D
var viewport: SubViewport
var public_context: Dictionary
var before: PackedByteArray
var output := ""
var capture_mode := false
var passed := 0
var failed := 0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--wg-capture": capture_mode = true
		elif argument.begins_with("--wg-output="): output = argument.trim_prefix("--wg-output=").replace("\\", "/").simplify_path()
	if DisplayServer.get_name() == "headless":
		push_error("WG0 native preview requires a real renderer")
		get_tree().quit(2)
		return
	before = Adapter.authority_bytes()
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/source_baseline.json"))
	public_context = Adapter.build(baseline.source_commit)
	var validation := Contract.validate(public_context)
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
	canvas = Canvas.new()
	viewport.add_child(canvas)
	canvas.prepare(public_context)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(640, 360)
	add_child(display)
	get_window().title = "WG-0 | arrows: pan | 1-5: cameras | G: guides | H: geometry | Esc: exit"
	if capture_mode:
		var allowed := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
		if not output.begins_with(allowed) or output == allowed or output.is_empty():
			push_error("WG0 output must be a run directory under this worktree's artifacts/watergen")
			get_tree().quit(2)
			return
		if DirAccess.make_dir_recursive_absolute(output) != OK:
			get_tree().quit(2)
			return
		call_deferred("capture")

func _process(delta: float) -> void:
	if capture_mode or not is_instance_valid(canvas): return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if direction != Vector2.ZERO:
		canvas.camera_offset = (canvas.camera_offset + direction * maxf(1, roundf(240 * delta))).clamp(Vector2.ZERO, Vector2(640, 120))
		canvas.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if capture_mode or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: get_tree().quit()
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var position: Array = CAMERAS[event.keycode - KEY_1]
		canvas.camera_offset = Vector2(position[0], position[1])
	if event.keycode == KEY_G: canvas.show_guides = not canvas.show_guides
	if event.keycode == KEY_H: canvas.show_geometry = not canvas.show_geometry
	canvas.queue_redraw()

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("WG0_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("WG0_NATIVE_FAIL | " + title)

func render() -> Image:
	canvas.queue_redraw()
	for tick in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

static func rgba_digest(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func save_image(image: Image, name: String) -> void:
	var path := output.path_join(name + ".png")
	check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "write " + name)

func save_text(name: String, text: String) -> void:
	var path := output.path_join(name)
	if FileAccess.file_exists(path):
		check(false, "refuse overwrite " + name)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "open " + name)
		return
	file.store_string(text)
	file.flush()
	check(file.get_error() == OK, "write " + name)

func capture() -> void:
	var context_before := Contract.canonical(public_context)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/legacy_baseline.json"))
	check(Engine.get_version_info().hash == baseline.engine_hash, "fixed engine compatibility")
	check(public_context.map_public_digest == baseline.map_public_digest, "frozen public geometry digest")
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(output + "/isolated-user/"), "engine user directory is isolated inside this run")
	var layers: Dictionary = {}
	for key in LAYERS:
		var image: Image = canvas.water_layers[key].get_image()
		check(image.get_size() == Vector2i(1280, 480) and image.get_format() == Image.FORMAT_RGBA8, "legacy layer " + key)
		layers[key] = {"rgba_sha256": rgba_digest(image), "size_px": [image.get_width(), image.get_height()], "format": "RGBA8"}
		check(layers[key].rgba_sha256 == baseline.layers[key].rgba_sha256, "frozen legacy RGBA " + key)
		save_image(image, "layer-" + key)
	var screenshots: Array = []
	for position in CAMERAS:
		canvas.camera_offset = Vector2(position[0], position[1])
		var image := await render()
		var repeat := await render()
		check(image.get_size() == Vector2i(640, 360), "native viewport size")
		check(image.get_data() == repeat.get_data(), "repeat camera " + str(position))
		var name := "viewport-%d-%d" % [position[0], position[1]]
		save_image(image, name)
		screenshots.append({"path": name + ".png", "camera_offset_px": position, "rgba_sha256": rgba_digest(image)})
	canvas.camera_offset = Vector2(320, 60)
	canvas.show_geometry = false
	save_image(await render(), "environment-only-center")
	canvas.show_geometry = true
	canvas.show_guides = true
	save_image(await render(), "guides-center")
	canvas.show_guides = false
	canvas.camera_offset = Vector2.ZERO
	viewport.size = Vector2i(1280, 480)
	save_image(await render(), "world-static")
	check(before == Adapter.authority_bytes(), "Layout arrays and runtime interaction targets unchanged after drawing")
	check(context_before == Contract.canonical(public_context), "public context unchanged after preparation and drawing")
	check(Contract.validate(public_context).ok, "public contract still valid")
	save_text("public-map-context.json", Contract.canonical(public_context))
	var summary := {
		"mode": "legacy-wg0", "engine_version": Engine.get_version_info(), "user_data_dir": OS.get_user_data_dir(),
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "os": OS.get_name(), "processor": OS.get_processor_name(),
		"visual_seed": null, "profile_id": null, "visual_time_seconds": 0,
		"map_public_digest": public_context.map_public_digest, "layers": layers, "screenshots": screenshots,
		"preparation_combined_us": canvas.preparation_us,
		"performance_note": "Single legacy Water.layers() CPU bake + texture creation sample; not separate GPU timing, p95, or game performance.",
		"omissions": ["dynamic motes/current cues", "mobile tackle surface", "nest art/status", "fish/bait/line/net/HUD", "game authority"],
		"passed_before_summary_write": passed, "failed": failed}
	save_text("native-evidence.json", JSON.stringify(summary, "\t"))
	print("WG0_NATIVE | passed=", passed, " | failed=", failed)
	get_tree().quit(1 if failed else 0)
