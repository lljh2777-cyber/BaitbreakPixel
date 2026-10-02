extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Node2D
var passed := 0
var failed := 0
var output := "res://artifacts/phase01-native"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PHASE01_NATIVE_PASS | ", title)
	else:
		failed += 1
		push_error("PHASE01_NATIVE_FAIL | " + title)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(name: String = "") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if not name.is_empty() and picture.save_png(output.path_join(name + ".png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [name, output])
	return picture

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game = Main.instantiate()
	root.add_child(game)
	game.capture_mode = "phase01"
	game.reset(false, "fish")
	game.menu.close()
	game.reset_world({"ruleset":"survival", "seed":42, "rules":{"water_strength":0, "timer_enabled":false}})
	freeze(game)
	game.fish = Vector2(700,210)
	game.fish_before = game.fish
	game.aim = Vector2.RIGHT
	game.velocity = Vector2.ZERO
	game.elapsed = 2.0
	game.power = 0.35
	game.feeding = false
	game.notice_age = 0
	game.hook_cooldown = 1000
	game.satiety = 100.0
	game.instinct_drive = 0.0
	game.caution_state = "CALM"
	for bait in game.baits: bait.active = false
	var focus: Dictionary = game.baits[0]
	focus.active = true
	focus.pos = game.mouth() + Vector2(38,0)
	focus.home = focus.pos
	focus.angle = 0.0
	for grain in focus.grains: grain.pos = focus.pos + Vector2(grain.offset)
	var pictures: Array[Image] = []
	for state in ["CALM", "UNEASY", "ALARMED"]:
		game.caution_state = state
		var before: Dictionary = game.capture_snapshot()
		var picture := await render("caution-" + state.to_lower())
		pictures.append(picture)
		check(game.capture_snapshot() == before, state + ": rendering does not mutate simulation")
		var repeat := await render()
		check(picture.get_data() == repeat.get_data(), state + ": fixed-tick rendering is deterministic")
	for pair in [[0,1], [1,2], [0,2]]:
		check(pictures[pair[0]].get_region(Rect2i(285,160,70,60)).get_data() != pictures[pair[1]].get_region(Rect2i(285,160,70,60)).get_data(), "caution states %s visibly differ beside fish" % [pair])
		check(pictures[pair[0]].get_region(Rect2i(360,26,78,9)).get_data() != pictures[pair[1]].get_region(Rect2i(360,26,78,9)).get_data(), "caution states %s visibly differ in HUD" % [pair])
	game.caution_state = "UNEASY"
	for bait in game.baits:
		bait.hook = true
		bait.hook_id = int(bait.bait_id) + 1000
	var hooked := await render("bait-hooked")
	for bait in game.baits:
		bait.hook = false
		bait.hook_id = 0
	var safe := await render("bait-safe")
	check(hooked.get_data() == safe.get_data(), "flipping only hidden hook flags/IDs cannot reveal hooked versus safe bait")
	var satiety_pictures: Array[Image] = []
	for value in [100.0, 50.0, 20.0, 5.0]:
		game.satiety = value
		satiety_pictures.append(await render("satiety-" + game.satiety_band().to_lower()))
	for index in range(1, satiety_pictures.size()):
		check(satiety_pictures[index-1].get_region(Rect2i(440,3,70,20)).get_data() != satiety_pictures[index].get_region(Rect2i(440,3,70,20)).get_data(), "adjacent satiety bands have visibly distinct HUD labels %d" % index)
	print("PHASE01_NATIVE | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="):
			output = argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | --capture-output-directory must not be empty")
		return false
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s; choose a writable --capture-output-directory" % [output, error_string(error)])
		return false
	return true
