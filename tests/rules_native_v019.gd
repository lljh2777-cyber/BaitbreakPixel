extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("RULE_UI_PASS | ",message)
	else: failed+=1; push_error("RULE_UI_FAIL | "+message)
func frame() -> void:
	for count in 3: await process_frame
func capture(name: String) -> void:
	await frame()
	await RenderingServer.frame_post_draw
	var directory := "res://artifacts"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): directory=argument.trim_prefix("--capture-output-directory=")
	var error := get_root().get_texture().get_image().save_png(directory.path_join("rules-"+name+"-v019.png"))
	if error!=OK: failed+=1; push_error("RULE_UI_FAIL | capture could not be saved")
func click(point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await frame()
func run() -> void:
	game=Main.instantiate(); root.add_child(game); game.capture_mode="rules-native"; game.set_process(false); game.set_physics_process(false); game.save_path="user://rules-native-v019.cfg"
	game.reset(false); game.menu.open("rules"); await frame()
	var editor: Control=game.menu.rules_editor
	check(editor.rows.get_child_count()==10,"stamina category shows all ten numeric options")
	await capture("stamina")
	var input: LineEdit=editor.controls.stamina_max.get_line_edit()
	input.grab_focus(); input.text="250"
	# Use the actual button signal path after editing numeric text.
	for child in editor.get_children():
		if child is Button and child.text=="保存，下局使用": child.pressed.emit()
	await frame()
	check(game.saved_rules.stamina_max==250 and game.stamina==100,"typed numeric value saves without changing active round")
	editor.search.text="QTE"; editor.search.text_changed.emit("QTE"); await frame()
	check(editor.rows.get_child_count()>=30,"search finds QTE settings across all categories")
	editor.search.text=""
	for index in editor.category_picker.item_count:
		if editor.category_picker.get_item_text(index)=="QTE·入口吐钩": editor.category_picker.select(index); editor.category_picker.item_selected.emit(index)
	await frame()
	editor.controls.qte_entry_random.button_pressed=false; await frame()
	check(editor.controls.qte_entry_zone.editable,"fixed-position input becomes enabled when random zone is disabled")
	editor.controls.qte_entry_sweep.value=4.0; await frame()
	await capture("qte")
	editor._presets(); await frame(); editor.preset_name.text="native-regression"
	for child in editor.overlay.get_children():
		if child is Button and child.text=="保存方案": child.pressed.emit()
	check(editor.preset_picker.item_count>0,"named preset is selectable after saving")
	editor.json_text.text="invalid json"
	for child in editor.overlay.get_children():
		if child is Button and child.text=="导入草稿": child.pressed.emit()
	check(editor.preset_status.text.contains("格式"),"bad JSON produces a visible error")
	await capture("presets")
	editor.overlay.queue_free(); editor.overlay=null; await frame()
	editor._save(true); await frame()
	check(not game.menu.visible and game.stamina==250 and game.rule("qte_entry_sweep")==4,"save and restart uses edited gameplay values")
	game.set_physics_process(false); game._enter_hook(0); game.qte_age=2.0
	await capture("custom-qte")
	game.start_shared_session("angler",{"ruleset":"duel","rules":{"stamina_max":500,"qte_entry_sweep":5.0}})
	game.menu.open("rules"); await frame()
	check(game.menu.rules_editor.read_only,"network settings remain read-only")
	await capture("locked")
	print("RULES_NATIVE_V019 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
