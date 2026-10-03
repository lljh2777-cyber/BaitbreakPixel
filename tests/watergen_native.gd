extends SceneTree
const Main = preload("res://scenes/main.tscn")
const World = preload("res://scripts/world_simulation.gd")
const Layout = preload("res://scripts/pond_layout.gd")
class TimedView extends "res://scripts/pond_view.gd":
	var draw_cpu_us := 0
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		draw_cpu_us = Time.get_ticks_usec() - started
var game: Node2D
var passed := 0
var failed := 0
var output := "res://artifacts/watergen/wg3-native"
var metrics: Array = []

func _initialize() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG3_NATIVE_PASS | ", label)
	else: failed += 1; push_error("WG3_NATIVE_FAIL | " + label)

func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(label := "") -> Image:
	game.view.queue_redraw()
	for index in 2: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not label.is_empty(): check(image.save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	return image

func setup(role := "fish", mode := "survival") -> void:
	game.reset(false, role)
	game.reset_world({"seed":8231, "ruleset":mode, "rules":{"timer_enabled":false, "hunger_enabled":false, "water_strength":0.35}})
	game.menu.close(); game.fish = Vector2(700,210); game.fish_before = game.fish
	game.aim = Vector2.RIGHT; game.elapsed = 4; game.notice_age = 0
	freeze(game)

func replay(mode: String) -> void:
	setup("fish", mode)
	var reference := World.new()
	check(reference.restore_snapshot(game.capture_snapshot()), "restore identical authority for " + mode)
	game.view.set_water_appearance(true)
	var equal := true
	var draws_neutral := true
	var hook_seen := false
	var qte_seen := false
	for tick in 240:
		if tick % 60 == 0:
			game.view.set_water_preset(game.view.WaterAppearance.PRESETS[tick / 60].id)
		for w in [game, reference]:
			if tick == 20: w._enter_hook(0)
			if tick == 35 and w.hooked != w.HookState.HOOKED: w._attach_hook()
			if tick == 70: w._open_qte("slack")
			if tick == 100: w._release_hook(false)
			if tick == 130: w.refill_hook_bait(0)
		var direction := Vector2.RIGHT.rotated(tick * 0.023)
		var fish := {"move":direction, "aim":direction, "suck":tick % 60 < 25, "dash":tick % 80 < 8, "qte":tick in [45,85,150]}
		var angler := {"walk":0.0, "target":Vector2(700,210), "reel":tick % 90 < 35, "release":tick % 90 > 65}
		game.advance_tick(fish, angler); reference.advance_tick(fish, angler)
		var state: PackedByteArray = var_to_bytes(reference.capture_snapshot())
		if state != var_to_bytes(game.capture_snapshot()):
			equal = false; print("WG3_FIRST_DIVERGENCE | ", mode, " | tick=", tick); break
		game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
		draws_neutral = draws_neutral and state == var_to_bytes(game.capture_snapshot())
		hook_seen = hook_seen or game.round_stats.hook_events > 0
		qte_seen = qte_seen or game.qte_id > 0
	check(equal and draws_neutral, "%s: 240 rendered ticks preserve every authority field and RNG" % mode)
	check(hook_seen and qte_seen and game.next_bait_id > 5, "trace reaches attachment, QTE and refill " + mode)
	reference.free()

func frame_costs() -> void:
	setup()
	game.view.set_water_preset("fern")
	for enabled in [false, true]:
		game.view.set_water_appearance(enabled)
		for warm in 60: game.view.queue_redraw(); await process_frame
		var samples: Array = []
		var cpu: Array = []
		var before: PackedByteArray = var_to_bytes(game.capture_snapshot())
		for index in 180:
			var started := Time.get_ticks_usec()
			game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			samples.append(Time.get_ticks_usec() - started)
			cpu.append(game.view.draw_cpu_us)
		check(before == var_to_bytes(game.capture_snapshot()), "performance sampling preserves authority")
		metrics.append({"generated":enabled, "frame_interval_us":samples, "draw_cpu_us":cpu})

func interaction_replays() -> void:
	for scenario in ["feeding", "wrapping", "net"]:
		setup("fish", "duel" if scenario != "feeding" else "survival")
		game.view.set_water_preset({"feeding":"lily", "wrapping":"ribbon", "net":"root"}[scenario])
		if scenario == "feeding":
			game.hook_cooldown = 1000
			for bait in game.baits:
				bait.hook = false; bait.active = false; bait.bait_type = "cluster"
				for grain in bait.grains: grain.eaten = true; grain.visual_kind = "cluster"
			for index in 4:
				var grain: Dictionary = game.baits[0].grains[index]
				grain.eaten = false; grain.free = true; grain.pos = game.mouth() + Vector2(3+index,0); grain.points = 1.0
		elif scenario == "wrapping":
			game.fish = Vector2(332,245); game.fish_before = game.fish
			game.baits[0].active = true; game._enter_hook(0); game._attach_hook()
			game._update_contacts(0); game._begin_wrap(); game._commit_wrap()
			check(not game.wraps.is_empty(), "fixture reaches committed wood wrap")
			game.wraps[0].progress = 1.0; game.untangle_cooldown = 0
			game.fish = Vector2(382,245); game.fish_before = game.fish; game.qte = ""
			game.fish_line_length = game.mouth().distance_to(game.wraps[0].entry) - (0.4-0.18)*32
			game.tension = 0.4; game._rebuild_rope()
		else:
			game.fish = Vector2(260,140); game.fish_before = game.fish
			game.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}]})
		var reference := World.new()
		check(reference.restore_snapshot(game.capture_snapshot()), "restore interaction " + scenario)
		game.view.set_water_appearance(true)
		var equal := true
		var untangle_seen := false
		for tick in 160:
			if scenario == "feeding" and tick == 1:
				for w in [game, reference]:
					w.bite_cooldown = 0
					for index in 4: w.baits[0].grains[index].eaten = false
			var fish := {"suck":scenario == "feeding"}
			var angler := {}
			if scenario == "wrapping":
				angler = {"untangle":tick == 5,"reel":game.tension < 0.39,"release":game.tension > 0.51}
				var state: Dictionary = game.effort_checks.angler
				angler["qte"] = state.active and game.Effort.progress(state) >= state.zone + state.width * 0.35
			game.advance_tick(fish, angler); reference.advance_tick(fish, angler)
			if scenario == "feeding" and tick == 1: check(game.score == 4,"Bite/Suck cannot double-award reoffered grain identities")
			var authority: PackedByteArray = var_to_bytes(reference.capture_snapshot())
			game.view.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			if authority != var_to_bytes(game.capture_snapshot()): equal = false; print("WG3_FIRST_DIVERGENCE | ",scenario," | ",tick); break
			untangle_seen = untangle_seen or game.untangle_phase in ["check", "unwind"]
			if tick in [0,30,80,159]: await render(scenario + "-" + str(tick))
		check(equal, "%s: 160 rendered ticks keep full authority/RNG equal" % scenario)
		if scenario == "wrapping": check(untangle_seen, "trace enters real untangle check")
		if scenario == "net": check(game.net_catches == 1, "trace reaches actual net capture")
		reference.free()

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game = Main.instantiate(); root.add_child(game); game.capture_mode = "wg3-native"
	# Preserve the production sibling order: the menu must remain above the view.
	var view_index: int = game.view.get_index()
	game.view.free(); game.view = TimedView.new(); game.view.game = game; game.add_child(game.view)
	game.move_child(game.view, view_index)
	setup()
	check(not game.view.water_appearance.enabled, "ordinary entry defaults to legacy")
	var before: PackedByteArray = var_to_bytes(game.capture_snapshot())
	game.menu.open("settings")
	var toggle: CheckButton = game.menu.find_child("GeneratedWater", true, false)
	check(is_instance_valid(toggle) and not toggle.button_pressed, "settings exposes explicit opt-in")
	var picker: OptionButton = game.menu.find_child("WaterPreset", true, false)
	check(is_instance_valid(picker) and picker.item_count == 4 and picker.selected == 0, "settings offers four named presets with fern selected")
	toggle.button_pressed = true
	var cold_preparation: Dictionary = game.view.water_appearance.preparation.duplicate()
	check(game.view.water_appearance.enabled and before == var_to_bytes(game.capture_snapshot()), "settings toggle prepares without touching authority")
	var preset_pixels: Array[PackedByteArray] = []
	var preset_times: Dictionary = {}
	for index in picker.item_count:
		picker.select(index); picker.item_selected.emit(index)
		var preset: Dictionary = game.view.WaterAppearance.PRESETS[index]
		check(game.view.water_appearance.enabled and game.view.water_appearance.visual_seed() == preset.seed and before == var_to_bytes(game.capture_snapshot()), "UI preset " + preset.id + " changes appearance without changing authority")
		preset_times[preset.id] = game.view.water_appearance.preparation.duplicate()
		game.menu.hide()
		var picture := await render("preset-" + preset.id)
		check(not preset_pixels.has(picture.get_data()), "preset " + preset.id + " has a distinct production picture")
		preset_pixels.append(picture.get_data())
		game.menu.show()
	picker.select(0); picker.item_selected.emit(0)
	await render("settings-generated")
	game.menu.close()
	var cache = game.view.water_appearance.cache
	var counts := [cache.plan_count, cache.bake_count, cache.upload_count, cache.texture_count]
	for point in [Vector2(66,100),Vector2(640,240),Vector2(1250,450),Vector2(66,450),Vector2(1250,100)]:
		game.fish = point; game.fish_before = point
		game.view.set_water_appearance(false)
		var legacy := await render("legacy-" + str(int(point.x)) + "-" + str(int(point.y)))
		game.view.set_water_appearance(true)
		var generated := await render("generated-" + str(int(point.x)) + "-" + str(int(point.y)))
		check(legacy.get_data() != generated.get_data(), "environment visibly changes at " + str(point))
		# Production fish footer begins at y=333; y=327..332 is water, not HUD.
		check(legacy.get_region(Rect2i(0,0,640,49)).get_data() == generated.get_region(Rect2i(0,0,640,49)).get_data() and legacy.get_region(Rect2i(0,333,640,27)).get_data() == generated.get_region(Rect2i(0,333,640,27)).get_data(), "HUD pixels remain exact at " + str(point))
		var pixel := Vector2(412,192)
		check(game.view.Camera.to_screen(game.screen_to_game(pixel), game, "fish") == pixel, "pointer coordinates unchanged")
	setup()
	var exact := await render("generated-free")
	for bait in game.baits: bait.hook = not bait.hook; bait.hook_id += 700
	check(exact.get_data() == (await render()).get_data(), "hidden hook truth leaves final production pixels unchanged")
	game.paused = true
	var paused_time: float = game.elapsed
	game.step(1.0/60,Vector2.RIGHT,true,false)
	check(game.elapsed == paused_time and exact.get_data() == (await render()).get_data(), "actual local pause freezes water time and pixels")
	for role in ["angler", "fish"]:
		setup(role, "duel")
		if role == "fish": game.shared_session = true
		if role == "fish":
			game.menu.open("settings")
			check(game.menu.find_child("GeneratedWater", true, false).disabled and game.menu.find_child("WaterPreset", true, false).disabled, "shared session disables both appearance controls")
			game.menu.close()
		game.view.set_water_appearance(false); var legacy := await render(role + "-legacy")
		game.view.set_water_appearance(true); var selected := await render(role + "-selected")
		check(not game.view.generated_water_active and legacy.get_data() == selected.get_data(), "ineligible " + role + " remains exact legacy")
		if role == "angler":
			game.net_action.observing = true
			game.view.set_water_appearance(false); legacy = await render("observation-legacy")
			game.view.set_water_appearance(true); selected = await render("observation-selected")
			check(legacy.get_data() == selected.get_data(), "net observation remains exact legacy")
	setup()
	game.view.set_water_appearance(false); var fallback := await render()
	game.view.set_water_appearance(true)
	check(not game.view.set_water_appearance(true, {"broken":true}), "invalid profile reports failure")
	check(fallback.get_data() == (await render("fallback")).get_data(), "failure restores full legacy image")
	game.view.set_water_appearance(true)
	for index in 20: game.restart_round(); game.view.set_water_appearance(false); game.view.set_water_appearance(true)
	check(cache.bake_count == counts[1] and cache.upload_count == counts[2] and cache.texture_count == counts[3], "twenty restarts/toggles never rebuild textures")
	await replay("survival"); await replay("duel")
	await interaction_replays()
	await frame_costs()
	var report := {"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"measurement":"Frame intervals include pacing/scheduling. draw_cpu_us times inherited production _draw command submission, not GPU execution.", "preparation_us":cold_preparation, "frame_costs":metrics, "cache_counts":[cache.plan_count,cache.bake_count,cache.upload_count,cache.texture_count]}
	report["preset_preparation_us"] = preset_times
	report["resident_bundles"] = cache.bundles.size()
	var file := FileAccess.open(output.path_join("wg3-evidence.json"),FileAccess.WRITE)
	check(file != null,"evidence writable")
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	game.queue_free(); await process_frame
	print("WG3_NATIVE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output = argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | empty capture directory")
		return false
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create capture directory")
		return false
	return true
