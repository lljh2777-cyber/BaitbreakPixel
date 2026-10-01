extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var hosting := false
var checks := 0
var failures := 0
var ready_sent := false
var playing_since := 0
var result_at := 0
var actions: Dictionary={}
var quitting := false
var test_started := 0
var prefix := "client"
var output := "res://artifacts"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: checks+=1; print("PEER_PASS | ",prefix," | ",description)
	else: failures+=1; push_error("PEER_FAIL | "+prefix+" | "+description)

func button(title: String) -> bool:
	for item in game.menu.content.find_children("*","Button",true,false):
		if item.text.begins_with(title): item.pressed.emit(); return true
	return false

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*point; event.global_position=event.position
	Input.parse_input_event(event); Input.flush_buffered_events()

func mouse(pressed: bool, point: Vector2) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	event.position=root.get_final_transform()*point; event.global_position=event.position
	Input.parse_input_event(event); Input.flush_buffered_events()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.view.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/network-"+label+"-"+prefix+"-v012.png")==OK,"capture "+label)

func once(name: String, when: bool) -> bool:
	if not when or actions.has(name): return false
	actions[name]=true
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	hosting="--peer-host" in OS.get_cmdline_user_args()
	prefix="host" if hosting else "client"
	test_started=Time.get_ticks_msec()
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="peer-network"
	game.set_process(false)
	game.save_path="user://peer-v012-"+prefix+".cfg"
	game.water_strength=0
	check(button("双人联机"),"title opens the real connection menu")
	game.menu.net_role="angler"
	game.menu.net_port="24753"
	var role_control: OptionButton=game.menu.content.find_child("HostRole",true,false)
	var port_control: LineEdit=game.menu.content.find_child("HostPort",true,false)
	role_control.selected=1; role_control.item_selected.emit(1)
	port_control.text="24753"; port_control.text_changed.emit("24753")
	await capture("setup")
	check(button("创建房间" if hosting else "加入房间"),"connection button creates the correct session")

func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or quitting: return false
	game.view.queue_redraw()
	var net: Node=game.network
	if net.status=="failed" and result_at==0:
		check(false,"session stopped: "+net.message); finish(); return false
	if Time.get_ticks_msec()-test_started>30000:
		check(false,"peer run timed out"); finish(); return false
	if not ready_sent and net.status=="waiting" and net.remote_id!=0:
		ready_sent=true
		check(game.menu.screen=="room","room screen is visible after connecting")
		capture("room")
		net.set_ready(true)
	if net.status=="playing":
		if playing_since==0:
			playing_since=Time.get_ticks_msec()
			check(game.player_role==("angler" if hosting else "fish"),"assigned role reaches the actual gameplay view")
		var age := (Time.get_ticks_msec()-playing_since)/1000.0
		if once("start",age>0.1):
			if hosting: key(KEY_Q,true)
			else: key(KEY_D,true)
		if once("release-q",age>0.2) and hosting: key(KEY_Q,false)
		if once("stop-fish",age>1.6) and not hosting: key(KEY_D,false)
		if once("begin-net",age>2.0) and hosting:
			key(KEY_E,true); mouse(true,Vector2(425,110))
			motion(Vector2(540,110)); motion(Vector2(540,200)); motion(Vector2(425,200))
		if once("live",age>3.0):
			check(game.fish.x>130,"physical client D moves the fish on both processes")
			check(game.baits[0].active,"host Q deployment reaches both processes")
			check(game.manual_net and game.net_route.size()>=4,"real host mouse corners appear in both worlds")
			capture("live")
		if once("cancel",age>4.0) and hosting: key(KEY_E,false); mouse(false,Vector2(425,200))
		if once("settle",age>4.5):
			check(game.net_state=="withdraw","native E release cancels in both processes")
		if once("end",age>5.0) and hosting: game.clock=game.TIME_LIMIT-0.01
	if game.match_over and result_at==0:
		result_at=Time.get_ticks_msec()
		check(game.winner_role=="fish" and game.won!=hosting,"timeout result is consistent with each role")
		check(game.menu.screen=="result","result reaches the visible menu")
		capture("result")
	if result_at>0 and Time.get_ticks_msec()-result_at>1200: finish()
	return false

func finish() -> void:
	if quitting: return
	quitting=true
	key(KEY_D,false); key(KEY_Q,false); key(KEY_E,false); mouse(false,Vector2(425,200))
	print("NETWORK_PEER_V012 | ",prefix," | passed=",checks," | failed=",failures," | tx=",game.network.bytes_sent," | rx=",game.network.bytes_received)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
