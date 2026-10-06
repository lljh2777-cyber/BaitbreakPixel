extends SceneTree
# The former generated-map menu suite now verifies its fixed-map replacement.
const Main=preload("res://scenes/main.tscn")
var passed:=0
var failed:=0
var game: Node2D
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("FIXED_MAP_UI_FAIL | "+label)
func _initialize() -> void: call_deferred("run")
func button_named(label: String) -> Button:
	for button in game.menu.find_children("*","Button",true,false):
		if button.text==label: return button
	return null
func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	game.set_physics_process(false); game.set_process(false)
	game.save_path="user://woodland-map-ui-test.cfg"
	check(game.selected_map_source==game.MapResolver.woodland(),"fresh entry uses fixed woodland")
	for kind in ["generated","classic"]:
		var old:=ConfigFile.new(); old.set_value("map","kind",kind); old.set_value("map","seed",123)
		old.set_value("record","best",37); old.save(game.save_path)
		game.select_pond("classic"); game._load_profile()
		check(game.selected_map_source==game.MapResolver.woodland() and game.best_score==37,"migrate old "+kind+" preference, retain record")
	for selection in [1,0]:
		game.menu.open("map")
		var mode: OptionButton=game.menu.find_child("MapMode",true,false)
		check(mode!=null and mode.item_count==2 and game.menu.find_child("MapSeed",true,false)==null,"two fixed maps, no random seed controls")
		mode.select(selection); mode.item_selected.emit(selection)
		button_named("使用这张地图").pressed.emit()
		var expected: Dictionary=game.MapResolver.woodland() if selection==0 else game.MapResolver.classic()
		check(game.menu.screen=="title" and game.map_context.map_source==expected,"apply installs selected fixed map")
		game.selected_map_source=game.MapResolver.classic() if selection==0 else game.MapResolver.woodland()
		game._load_profile()
		check(game.selected_map_source==expected,"explicit fixed selection persists")
	var reference: Dictionary=game.map_context.map_ref
	game.menu.close()
	var key:=InputEventKey.new(); key.physical_keycode=KEY_R; key.pressed=true
	game._unhandled_input(key)
	check(game.map_context.map_ref==reference,"restart preserves authored layout")
	game.menu.open("pause")
	check(button_named("新地图")==null and button_named("同 Seed 重开 · R")==null,"pause does not offer random map generation")
	check(game.network_settings().map_source==game.MapResolver.woodland(),"host settings use fixed map")
	game.shared_session=true
	check(not game.select_pond("classic") and game.selected_map_source==game.MapResolver.woodland(),"connected peer cannot change map locally")
	game.shared_session=false
	game.free()
	print("FIXED_MAP_UI | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
