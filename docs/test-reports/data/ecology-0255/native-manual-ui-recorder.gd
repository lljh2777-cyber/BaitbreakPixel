extends SceneTree
# Evidence-only observer: ordinary main scene, unchanged controls and processing.
# F12 records current viewport and state; no state placement or synthetic input.
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var output: String=""
var capture_number:=0
var pressed_before:=false
var recording:=false
func _initialize() -> void:
	if DisplayServer.get_name()=="headless": push_error("MANUAL_UI_FAIL needs renderer"); quit(2); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-record-output="): output=argument.trim_prefix("--ui-record-output=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("MANUAL_UI_FAIL writable output required"); quit(2); return
	call_deferred("run")
func run() -> void:
	game=Main.instantiate(); root.add_child(game)
	print("MANUAL_UI_READY | F12 records; all game controls unchanged")
func _process(_delta: float) -> bool:
	var pressed:=Input.is_physical_key_pressed(KEY_F12)
	if pressed and not pressed_before and not recording and is_instance_valid(game):
		recording=true; call_deferred("capture")
	pressed_before=pressed
	return false
func capture() -> void:
	await RenderingServer.frame_post_draw
	capture_number+=1
	var label:="ui-%02d" % capture_number
	var picture:=root.get_texture().get_image()
	var error:=picture.save_png(output.path_join(label+".png"))
	var npcs: Array=[]
	for npc: Dictionary in game.npc_fishes:
		npcs.append({"fish_id":npc.fish_id,"active":npc.active,"position":[npc.position.x,npc.position.y],"behavior":npc.behavior_state})
	var record:={"capture":label,"png_error":error,"engine_ticks_ms":Time.get_ticks_msec(),"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"size":[picture.get_width(),picture.get_height()],"menu_visible":game.menu.visible,"menu_screen":game.menu.screen,"role":game.player_role,"paused":game.paused,"challenge":game.challenge,"simulation_elapsed":game.elapsed,"fish_position":[game.fish.x,game.fish.y],"score":game.score,"npc_food_consumed":game.round_stats.npc_food_consumed,"hook_target_fish_id":game.hook_target_fish_id,"hooked":game.hooked,"match_over":game.match_over,"observing":game.net_action.observing,"npc_fishes":npcs}
	var file:=FileAccess.open(output.path_join(label+".json"),FileAccess.WRITE)
	if file==null or error!=OK: push_error("MANUAL_UI_FAIL capture"); quit(2); return
	file.store_string(JSON.stringify(record,"\t")+"\n"); file.close()
	print("MANUAL_UI_CAPTURE | ",JSON.stringify(record)); recording=false
