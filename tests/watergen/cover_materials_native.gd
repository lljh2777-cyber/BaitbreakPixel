extends "res://tests/watergen_native.gd"
func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game = Main.instantiate(); root.add_child(game); game.capture_mode = "wg3-native"
	setup(); game.view.set_water_appearance(true)
	var material = game.view.cover_materials
	print("MATERIAL_PREPARE | us=",material.preparation_us," | textures=",material.texture_count," | rgba_bytes=",material.rgba_bytes)
	for entry in [["wood",Vector2(350,350)],["stone",Vector2(850,380)],["plants",Vector2(1090,400)],["center",Vector2(700,210)]]:
		game.fish=entry[1];game.fish_before=game.fish
		game.view.cover_materials=material
		await render(entry[0]+"-after")
		var original = game.view.CoverMaterials.new()
		original.props=game.view.props;original.plant_frames=game.view.plant_frames
		game.view.cover_materials=original
		await render(entry[0]+"-before")
	game.view.cover_materials=material
	game.queue_free(); await process_frame
	print("WG5_CAPTURE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
