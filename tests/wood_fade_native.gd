extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Layout=preload("res://scripts/pond_layout.gd")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/wood-fade-v0224-native"
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("WOOD_FADE_NATIVE_PASS | ",title)
	else: failed+=1; push_error("WOOD_FADE_NATIVE_FAIL | "+title)
func render(label: String="") -> Image:
	game.view.queue_redraw()
	for tick in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if not label.is_empty() and image.save_png(output.path_join(label+".png")) != OK:
		failed += 1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [label, output])
	return image
func set_opacity(group: int, opacity: float) -> void:
	for index in Layout.SOLIDS.size():
		if Layout.solid_fade_group(index)==group: game.target_opacity[index]=opacity
func blend_matches(opaque: Image, faded: Image, hidden: Image, probe: Vector2, alpha: float) -> bool:
	var p:=Vector2i(game.view.Camera.to_screen(probe,game,"fish"))
	var a:=opaque.get_pixelv(p); var b:=hidden.get_pixelv(p); var actual:=faded.get_pixelv(p)
	var expected:=b.lerp(a,alpha)
	var contrast:=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	return contrast>0.035 and absf(expected.r-actual.r)<0.018 and absf(expected.g-actual.g)<0.018 and absf(expected.b-actual.b)<0.018
func run() -> void:
	if not prepare_capture_output():
		quit(2)
		return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="wood-fade-test"
	game.set_process(false); game.set_physics_process(false)
	# Probe both solitary branch pixels and pixels shared with their parent.
	for sample: Array in [["trunk",0,Vector2(350,350),[Vector2(336,236),Vector2(285,263),Vector2(402,230),Vector2(337,307)]],["log",6,Vector2(542,399),[Vector2(590,386),Vector2(586,330),Vector2(610,377)]],["fork",16,Vector2(1220,380),[Vector2(1223,369),Vector2(1188,381),Vector2(1213,397)]]]:
		game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
		game.reset_world({"ruleset":"survival","seed":42,"rules":{"cover_opacity":0.5,"water_strength":0,"timer_enabled":false}})
		game.fish=sample[2]; game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.elapsed=2; game.notice_age=0
		var group: int=sample[1]; var label: String=sample[0]
		game._update_contacts(0.25)
		set_opacity(group,0); var hidden:=await render()
		set_opacity(group,1); var opaque:=await render(label+"-opaque")
		for tick in 12: game._update_contacts(1.0/60)
		var state:=var_to_bytes(game.capture_snapshot())
		var faded:=await render(label+"-inside")
		for probe: Vector2 in sample[3]:
			check(blend_matches(opaque,faded,hidden,probe,0.5),label+": branch/junction pixel %s receives exactly one shared alpha blend" % probe)
		check(var_to_bytes(game.capture_snapshot())==state and faded.get_data()==(await render()).get_data(),label+": repeated native drawing leaves the world and faded pixels unchanged")
		game.fish=Vector2(460,120)
		for tick in 12: game._update_contacts(1.0/60)
		var restored:=true
		for index in Layout.SOLIDS.size():
			if Layout.solid_fade_group(index)==group: restored=restored and game.target_opacity[index]==1
		check(restored,label+": exiting restores trunk and every connected branch")
	game.reset(false,"fish"); game.menu.close(); game.set_physics_process(false)
	game.reset_world({"ruleset":"survival","seed":42,"rules":{"water_strength":0,"timer_enabled":false}})
	game.fish=Vector2(350,350); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.elapsed=2; game.notice_age=0
	game._update_contacts(0.3)
	await render("trunk-default-inside")
	var default_fade:=true
	for index in Layout.SOLIDS.size():
		if Layout.solid_fade_group(index)==0: default_fade=default_fade and absf(game.target_opacity[index]-game.rule("cover_opacity"))<0.00001
	check(default_fade,"normal rule defaults also fade the entire tree uniformly")
	print("WOOD_FADE_NATIVE | passed=",passed," | failed=",failed)
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
