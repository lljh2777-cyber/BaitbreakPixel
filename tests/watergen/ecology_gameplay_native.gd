extends SceneTree
const Main = preload("res://scenes/main.tscn")
const ReviewView = preload("res://tools/watergen/ecology_gameplay_view.gd")
const Resolver = preload("res://scripts/maps/map_resolver.gd")
var game: Node2D
var output := ""
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG62_GAMEPLAY_PASS | ", label)
	else: failed += 1; push_error("WG62_GAMEPLAY_FAIL | " + label)
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func render(name: String) -> Image:
	var before: Dictionary = game.capture_snapshot()
	game.view.queue_redraw()
	for tick in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(640, 360), "real logical game viewport")
	check(game.capture_snapshot() == before, "flora rendering does not change simulation or RNG")
	var path := output.path_join(name + ".png")
	check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "save " + name)
	return image

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=").replace("\\", "/").simplify_path()
	var prefix := ProjectSettings.globalize_path("res://artifacts/watergen/").replace("\\", "/").simplify_path() + "/"
	if DisplayServer.get_name() == "headless" or not output.begins_with(prefix): push_error("WG62 native output/renderer required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game = Main.instantiate(); root.add_child(game); game.capture_mode = "wg62-native"
	game.menu.close(); freeze(game)
	var previous: Node2D = game.view
	var view := ReviewView.new()
	view.game = game; game.view = view
	previous.hide(); previous.queue_free()
	game.add_child(view); freeze(view)
	for seed: int in [42, 1346]:
		check(game.reset_world({"map_source": Resolver.generated(seed), "seed": 64317, "challenge": false}), "true generated gameplay reset")
		game.player_role = "fish"; game.fish = Vector2(600, 365); game.fish_before = game.fish; game.elapsed = 2.0
		view.flora_visible = false
		var before := await render("game-%d-before" % seed)
		var state: Dictionary = game.capture_snapshot()
		view.flora_visible = true
		var after := await render("game-%d-after" % seed)
		check(before.get_data() != after.get_data() and game.capture_snapshot() == state, "flora changes pixels only with real fish/NPC/food")
		var uploads: int = view.flora.upload_count
		check(after.get_data() == (await render("game-%d-repeat" % seed)).get_data() and view.flora.upload_count == uploads, "frozen gameplay frame repeats without uploads")
		game.satiety = 15
		await render("game-%d-low-satiety" % seed)
		game.player_role = "angler"
		var shore := await render("game-%d-shore" % seed)
		view.flora_visible = false
		check(shore.get_data() == (await render("game-%d-shore-off" % seed)).get_data(), "shore view unchanged by local underwater flora")
	check(game.reset_world(), "classic map reset")
	game.player_role = "fish"; view.flora_visible = true
	await render("game-classic")
	check(not view.flora.enabled, "classic map keeps existing presentation")
	game.free()
	print("WG62_GAMEPLAY_NATIVE | passed=%d | failed=%d" % [passed, failed])
	quit(1 if failed else 0)
