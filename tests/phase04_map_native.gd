extends SceneTree

# Real Main scene renderer gate for authored test-only geometry. This map is never
# registered, selectable or exported. Exact pond restoration complements the
# frozen-build pixel pair run and catches stale view caches across round changes.
const Main=preload("res://scenes/main.tscn")
const Fixture=preload("res://tests/fixtures/phase04/fixture_rect_small.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
const Camera=preload("res://scripts/pond_camera.gd")
const Shore=preload("res://scripts/shore_view.gd")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/phase04-map-native"

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2); return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("MAP_NATIVE_PASS | ",label)
	else: failed+=1; push_error("MAP_NATIVE_FAIL | "+label)

func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func setup_map(definition: Variant=null) -> void:
	check(game.reset_world({"seed":4964,"ruleset":"duel","npc_count":3,
		"rules":{"water_strength":0.0,"hunger_enabled":false,"timer_enabled":false,"instinct_max_strength":0.0}},definition),"map installs before actors")
	game.player_role="fish"; game.menu.close(); game.notice_age=0.0
	game.elapsed=2.0; game.aim=Vector2.RIGHT; game.power=0.35
	freeze(game)

func render(name: String) -> Image:
	# The pointer is outside world interaction; cursor normalization changes no
	# authority state and no pixels are cropped or hidden for comparisons.
	Input.warp_mouse(Vector2(4,4)*Vector2(root.size)/Vector2(640,360))
	await process_frame
	var before:=var_to_bytes(game.capture_snapshot())
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	check(before==var_to_bytes(game.capture_snapshot()),name+" drawing preserves complete authority and RNG")
	check(picture.get_size()==Vector2i(640,360),name+" keeps logical viewport separate from map extent")
	if picture.save_png(output.path_join(name+".png"))!=OK:
		failed+=1; push_error("CAPTURE_OUTPUT_FAIL | cannot save "+name)
	return picture

func run() -> void:
	if not prepare_capture_output():
		quit(2); return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="map_fixture"
	setup_map()
	var pond:=await render("pond-before")
	var pond_layers: Dictionary=game.view.water_layers.duplicate()
	setup_map()
	var repeated:=await render("pond-equivalent-reset")
	check(pond.get_data()==repeated.get_data(),"equivalent pond round reset preserves every pixel")
	check(pond_layers==game.view.water_layers,"equivalent context reuses prepared texture objects")
	setup_map(Fixture.create())
	var small:=await render("fixture-fish-spawn")
	check(game.view.map_presentation.context==game.map_context,"display world provides the live render context")
	check(game.view.props.size()==2 and game.view.plant_frames.size()==1,"fixture has its own authored wood stone and plant")
	for texture in game.view.water_layers.values(): check(texture.get_size()==Fixture.SIZE,"fixture water/depth layers use800x360")
	check(small.get_data()!=pond.get_data(),"different authored map is actually visible")
	check(Camera.offset(game,"fish").y==0.0,"360-high map cannot inherit pond vertical scrolling")
	game.fish=Fixture.HOME; game.fish_before=game.fish
	await render("fixture-fish-home")
	check(Camera.offset(game,"fish").x==160.0,"right-side fixture home uses its own camera extent")
	game.player_role="angler";game.angler.x=Fixture.HOME.x-30.0
	await render("fixture-shore")
	for point: Vector2 in [Fixture.SPAWN,Fixture.HOME,Fixture.SITES[0],Fixture.SITES[-1]]:
		check(Shore.to_world(Shore.to_screen(point,game),game).distance_to(point)<0.001,"fixture shore projection roundtrip")
	game.advance_tick({}, {"auto_net":false,"net_events":[{"kind":"toggle"}]})
	await render("fixture-observation")
	check(game.net_action.observing,"fixture uses real observation entry")
	var a:=Vector2(620,180); var b:=Vector2(715,180)
	game.advance_tick({}, {"auto_net":false,"net_events":[{"kind":"point","point":a}]})
	game.advance_tick({}, {"auto_net":false,"net_events":[{"kind":"point","point":b}]})
	await render("fixture-net-warning")
	check(game.net_state=="warning" and game.net_from.distance_to(a)<0.001 and game.net_to.distance_to(b)<0.001,"fixture commits authored in-bounds route")
	for tick in 38: game.advance_tick({}, {"auto_net":false})
	await render("fixture-net-sweep")
	check(game.net_state in ["sweep","caught"],"fixture net route actually advances")
	setup_map()
	var restored:=await render("pond-after-fixture")
	check(restored.get_data()==pond.get_data(),"returning to pond removes stale fixture geometry and preserves every pixel")
	check(Registry.available_refs().size()==2 and Registry.available_refs()[0].id=="pond_v2" and Registry.available_refs()[1].id=="woodland_pond","fixture never becomes a player map")
	print("PHASE04_MAP_NATIVE | passed=%d | failed=%d"%[passed,failed])
	quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="):
			output=argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | choose a nonempty output directory")
		return false
	var error:=DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s" % [output,error_string(error)])
		return false
	return true
