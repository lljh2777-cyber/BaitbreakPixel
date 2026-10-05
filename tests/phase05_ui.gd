extends SceneTree
const Main=preload("res://scenes/main.tscn")
var passed:=0
var failed:=0
var game:Node2D
var output:="res://artifacts/p5-ui"
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATED_UI_FAIL | "+label)
func _initialize()->void: call_deferred("run")
func button_named(label:String)->Button:
	for button in game.menu.find_children("*","Button",true,false):
		if button.text==label: return button
	return null
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	game=Main.instantiate(); root.add_child(game); game.capture_mode="p5-ui"
	game.set_physics_process(false); game.set_process(false)
	game.save_path="user://phase05-map-ui-test.cfg"
	check(game.selected_map_source.kind=="built_in","classic initial selection")
	var before:Dictionary=game.capture_snapshot()
	for invalid:String in ["","-1","2147483648","1.5","hello","9999999999999999999999"]:
		check(not game.select_pond("generated",invalid) and game.capture_snapshot()==before,"invalid seed rejected "+invalid)
	game.menu.open("map")
	var mode:OptionButton=game.menu.find_child("MapMode",true,false)
	var seed:LineEdit=game.menu.find_child("MapSeed",true,false)
	check(mode!=null and seed!=null and not seed.editable,"classic mode clearly disables seed")
	mode.select(1); mode.item_selected.emit(1); seed.text="123456789"
	check(seed.editable,"generated mode enables manual seed")
	if DisplayServer.get_name()!="headless":
		for tick in 3: await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join("map-choice.png"))==OK,"map chooser screenshot")
	button_named("使用这张地图").pressed.emit()
	check(game.menu.screen=="title" and game.map_context.map_source.map_seed==123456789,"actual apply button installs manually entered map")
	check(game.network.host_game("fish",26010,game.network_settings())==OK,"generated selection opens real host lobby")
	if DisplayServer.get_name()!="headless":
		for tick in 3: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("host-room.png"))==OK,"host lobby screenshot")
		for label in game.menu.find_children("*","Label",true,false):
			if label.text.begins_with("端口 "):
				check(label.get_global_rect().end.y<=game.menu.room_map.global_position.y,"host port and selected seed do not overlap")
	game.return_to_title()
	var original:Dictionary=game.map_context.map_ref
	game.menu.close()
	var key:=InputEventKey.new(); key.physical_keycode=KEY_R; key.pressed=true
	game._unhandled_input(key)
	check(game.map_context.map_ref==original and game.selected_map_source.map_seed==123456789,"R restarts the same map")
	game.menu.open("pause")
	check(button_named("同 Seed 重开 · R")!=null and button_named("新地图")!=null,"restart and new-map actions are distinct")
	button_named("新地图").pressed.emit()
	check(game.map_context.map_ref!=original and game.selected_map_source.map_seed!=123456789,"new map selects a different seed")
	var chosen:Dictionary=game.selected_map_source.duplicate(true)
	game.selected_map_source=game.MapResolver.classic(); game._load_profile()
	check(game.selected_map_source==chosen,"local seed preference persists")
	check(game.network_settings().map_source==chosen,"host settings carry selected recipe")
	game.shared_session=true
	check(not game.select_pond("classic") and game.selected_map_source==chosen,"connected client cannot change map locally")
	game.shared_session=false
	check(game.select_pond("classic"),"classic can be selected again")
	game.return_to_title()
	check(game.map_context.id=="pond_v2","classic returns to existing pond")
	game.free()
	print("PHASE05_UI | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
