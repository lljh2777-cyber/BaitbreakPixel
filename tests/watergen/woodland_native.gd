extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
class Overview:
	extends "res://scripts/pond_view.gd"
	var full:=true
	var guides:=false
	func _draw() -> void:
		if not full: super._draw(); return
		if not is_instance_valid(game): return
		world=game; prepare_map(world.map_context)
		line_frame=line_motion.sample(world); net_frame=net_motion.sample(world)
		fish_observation=FishObservation.build(world); camera_offset=Vector2.ZERO
		draw_set_transform(Vector2.ZERO)
		_world(world.elapsed); _baits(world.elapsed); _angler(world.elapsed); _line(); _net_back(world.elapsed); _player(world.elapsed); _net(world.elapsed)
		if guides:
			draw_polyline(world.map_context.floor_profile,Color("ff6786"),1)
			for target: Dictionary in world.targets:
				var outline: PackedVector2Array=target.polygon.duplicate(); outline.append(outline[0])
				draw_polyline(outline,Color("ffdd88"),1)
var game: Node2D
var output:="res://artifacts/woodland-native"
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("WOODLAND_NATIVE_FAIL | "+label)
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func capture(name: String, full: bool=true) -> Image:
	var size:=Vector2i(1280,480) if full else Vector2i(640,360)
	root.size=size; root.content_scale_size=size; game.view.full=full
	var before:=var_to_bytes(game.capture_snapshot()); game.view.queue_redraw()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image.get_size()==size and image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	check(before==var_to_bytes(game.capture_snapshot()),"render leaves authority untouched")
	return image
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.menu.close(); freeze(game)
	check(game.map_context.id=="woodland_pond","fresh main boots the new fixed scene")
	var old: Node=game.view; game.remove_child(old); old.free()
	game.view=Overview.new(); game.view.game=game; game.add_child(game.view); freeze(game.view)
	game.view.prepare_map(Resolver.resolve(Resolver.classic()).context)
	game.view.prepare_map(game.map_context)
	check(game.view.woodland.active and game.view.plant_frames.size()==2,"classic round trip does not empty fixed-map cached plants")
	game.elapsed=8.0; game.view.woodland.visual_time=8.0
	var full:=await capture("world")
	game.view.guides=true; await capture("geometry"); game.view.guides=false
	var original:=await capture("game",false)
	for bait in game.baits: bait.hook=not bait.hook
	var secret:=await capture("hidden-hook",false)
	check(original.get_data()==secret.get_data(),"hidden hook truth cannot change any fish-view pixel")
	for bait in game.baits: bait.hook=not bait.hook
	for i in 7: game.target_opacity[i]=0.08
	var faded:=await capture("wood-fade")
	check(full.get_region(Rect2i(480,312,200,80)).get_data()!=faded.get_region(Rect2i(480,312,200,80)).get_data(),"real wood target opacity changes host art")
	game.target_opacity.fill(1.0)
	for p in [Vector2(200,215),Vector2(1080,250),game.map_context.home]:
		game.fish=p; game.fish_before=p
		await capture("camera-%d" % int(p.x),false)
	game.target_opacity[10]=0.08; game.target_opacity[11]=0.08
	await capture("grass-fade")
	game.target_opacity.fill(1.0)
	game.fish=Vector2(115,220); game.fish_before=game.fish
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
	var coil: Dictionary=game.MapGeometry.coil_at(game.targets[10],Vector2(105,215)); coil.target=10
	game.wraps.assign([coil]); game.wraps[0].progress=0.8; game._update_contacts(1.0)
	await capture("grass-binding",false)
	game.wraps.clear(); game.target_opacity.fill(1.0)
	game.fish=Vector2(600,270); game.fish_before=game.fish
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook(); game.qte="entry"; game.qte_age=1.3
	await capture("qte",false)
	game.player_role="angler"; game.net_action.observing=true
	await capture("net-observation",false)
	game.free()
	print("WOODLAND_NATIVE | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
