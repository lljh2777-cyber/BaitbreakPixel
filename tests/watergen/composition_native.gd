extends SceneTree
const Main=preload("res://scenes/main.tscn")
const View=preload("res://tools/watergen/composition_view.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
var game: Node2D
var output:="res://artifacts/watergen/composition-round1"
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("COMPOSITION_FAIL | "+message)
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(name: String, overview: bool) -> Image:
	var size:=Vector2i(1280,480) if overview else Vector2i(640,360)
	root.content_scale_size=size; root.size=size
	game.view.overview=overview
	var snapshot:=var_to_bytes(game.capture_snapshot())
	game.view.queue_redraw()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image.get_size()==size,"native viewport size")
	check(snapshot==var_to_bytes(game.capture_snapshot()),"render leaves complete authority and RNG unchanged")
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	return image

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game=Main.instantiate(); root.add_child(game); game.capture_mode="composition-round1"
	game.menu.close(); freeze(game)
	var previous: Node=game.view; game.remove_child(previous); previous.free()
	game.view=View.new(); game.view.game=game; game.add_child(game.view); freeze(game.view)
	for seed: int in [42,1346]:
		check(game.reset_world({"map_source":Resolver.generated(seed,3),"seed":64317,"challenge":false}),"current v3 map")
		game.fish=Vector2(620,286); game.fish_before=game.fish; game.elapsed=2.0; game.player_role="fish"
		game.view.show_baseline=true
		await render("seed-%d-baseline-wide" % seed,true)
		var original:=await render("seed-%d-baseline-game" % seed,false)
		game.view.show_baseline=false
		for choice in ["A","B","C"]:
			game.view.choice=choice
			await render("seed-%d-%s-wide" % [seed,choice],true)
			var image:=await render("seed-%d-%s-game" % [seed,choice],false)
			check(image.get_data()!=original.get_data() and game.view.generated_water.study.plan.variant==choice,"selected study changes pixels")
			check(image.get_region(Rect2i(0,0,640,49)).get_data()==original.get_region(Rect2i(0,0,640,49)).get_data(),"HUD pixels unchanged")
			check(image.get_region(Rect2i(0,333,640,27)).get_data()==original.get_region(Rect2i(0,333,640,27)).get_data(),"hint pixels unchanged")
			var uploads: int=game.view.generated_water.bake_count
			var repeated:=await render("seed-%d-%s-repeat" % [seed,choice],false)
			check(image.get_data()==repeated.get_data() and game.view.generated_water.bake_count==uploads,"stable pixels and cached scenery")
			for bait in game.baits: bait.hook=not bait.hook
			var secret:=await render("seed-%d-%s-hidden-hook" % [seed,choice],false)
			check(image.get_data()==secret.get_data(),"hidden hook truth cannot change scenery or free-fish pixels")
			for bait in game.baits: bait.hook=not bait.hook
		# Existing QTE and line are rendered over all three choices, never underneath.
		game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
		game.fish=Vector2(620,260); game.fish_before=game.fish
		game.qte="entry"; game.qte_age=1.3
		game.view.show_baseline=true
		var qte:=await render("seed-%d-qte-baseline" % seed,false)
		game.view.show_baseline=false
		for choice in ["A","B","C"]:
			game.view.choice=choice
			var image:=await render("seed-%d-%s-qte" % [seed,choice],false)
			check(image.get_region(Rect2i(12,124,172,195)).get_data()==qte.get_region(Rect2i(12,124,172,195)).get_data(),"QTE interior pixels unchanged")
	game.free()
	print("COMPOSITION_NATIVE | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
