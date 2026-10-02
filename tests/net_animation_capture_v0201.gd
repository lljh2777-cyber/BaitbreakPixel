extends SceneTree
var capture_failed := false

const Main=preload("res://scenes/main.tscn")
var game: Node2D
var output:="res://artifacts/net-animation-v0201"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func frame(path: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) != OK:
		capture_failed = true
		push_error("CAPTURE_OUTPUT_FAIL | cannot save "+path)

func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	var ignore:=FileAccess.open(output.path_join(".gdignore"),FileAccess.WRITE)
	if ignore == null:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create .gdignore in %s: %s" % [output, error_string(FileAccess.get_open_error())])
		quit(2)
		return
	ignore.close()
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="net-animation"; game.set_process(false); game.set_physics_process(false)
	for i in 4: await process_frame
	for scenario in ["empty","catch","blocked"]:
		game.reset(false,"angler"); game.set_physics_process(false); game.menu.close()
		game.rules.water_strength=0; game.rules.net_reach=620; game.rules.net_sight=680
		game.fish=Vector2(260,140) if scenario=="catch" else Vector2(480,130)
		game.fish_before=game.fish
		var a:=Vector2(230,210) if scenario=="blocked" else Vector2(210,140)
		var b:=Vector2(420,210) if scenario=="blocked" else Vector2(310,140)
		game.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":a},{"kind":"point","point":b}]})
		var index:=0
		while game.net_active() and index<240:
			game.advance_tick({},{})
			if index%2==0:
				for role in ["angler","fish"]:
					game.player_role=role
					await frame(output.path_join("%s-%s-%03d.png" % [scenario,role,index/2]))
			index+=1
		print("NET_ANIMATION_CAPTURE | ",scenario," | ticks=",index," | state=",game.net_state)
	print("NET_ANIMATION_CAPTURE_COMPLETE")
	quit(1 if capture_failed else 0)

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
