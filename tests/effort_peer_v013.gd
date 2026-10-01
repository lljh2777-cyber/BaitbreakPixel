extends SceneTree
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var hosting:=false
var ready_sent:=false
var started:=false
var quitting:=false
var began:=0
var checks:=0
var failures:=0
var pressed_id:=-1
var release_at:=0
var completed_at:=0
var observed: Dictionary={"fish":false,"angler":false}
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: checks+=1; print("EFFORT_PEER_PASS | ",hosting," | ",description)
	else: failures+=1; push_error("EFFORT_PEER_FAIL | "+description)
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	hosting="--peer-host" in OS.get_cmdline_user_args(); began=Time.get_ticks_msec()
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="effort-peer"; game.set_process(false)
	game.save_path="user://effort-peer-v013-"+str(hosting)+".cfg"
	var result: Error=game.network.host_game("fish",24755,{"water_strength":0.0,"break_hold":10.0,"slack_hold":3.0}) if hosting else game.network.join_game("127.0.0.1",24755)
	check(result==OK,"start real peer")
func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or quitting: return false
	game.view.queue_redraw()
	var now:=Time.get_ticks_msec()
	if completed_at>0 and now-completed_at>700: finish(); return false
	if game.network.status=="failed":
		if completed_at==0: check(false,game.network.message)
		finish(); return false
	if now-began>18000: check(false,"peer check timed out"); finish(); return false
	if game.network.status=="waiting" and game.network.remote_id!=0 and not ready_sent:
		ready_sent=true; game.network.set_ready(true)
	if game.network.status!="playing": return false
	if not started:
		started=true
		check(game.player_role==("fish" if hosting else "angler"),"correct native input role")
		if hosting:
			game.fish=Vector2(250,220); game.aim=Vector2.RIGHT; game.baits[0].active=true
			game._enter_hook(0); game._attach_hook()
			game.effort_checks.fish.wait=0.0; game.effort_checks.angler.wait=0.0
		key(KEY_S if hosting else KEY_W,true)
	if release_at>0 and now>=release_at: key(KEY_SPACE,false); release_at=0
	var view: Node2D=game.network.display_world()
	var state: Dictionary=view.effort_checks[game.player_role]
	if state.active and state.id!=pressed_id and view.Effort.progress(state)>=state.zone+state.width*0.40:
		pressed_id=state.id; key(KEY_SPACE,true); release_at=now+80
		check(view.Effort.progress(state)<=state.zone+state.width,"physical Space is pressed in the displayed local green zone")
	for role in observed:
		var authoritative: Dictionary=game.effort_checks[role]
		if authoritative.good and authoritative.effect_age>0: observed[role]=true
	if observed.fish and observed.angler and completed_at==0:
		completed_at=now
		check(game.hooked==game.HookState.HOOKED,"both native judgments preserve the tug instead of unhooking")
		check(game.effort_checks.fish.id==1 and game.effort_checks.angler.id==1,"each role resolves its own first check once")
		check(game.effort_multiplier("fish")>1 and game.effort_multiplier("angler")>1,"both authoritative power boosts are synchronized")
		capture()
	return false
func capture() -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/effort-peer-"+("host" if hosting else "client")+"-v013.png")==OK,"capture live dual QTE")
func finish() -> void:
	if quitting: return
	quitting=true; key(KEY_S,false); key(KEY_W,false); key(KEY_SPACE,false)
	print("EFFORT_PEER_V013 | ","host" if hosting else "client"," | passed=",checks," | failed=",failures)
	game.queue_free(); await process_frame; quit(1 if failures else 0)
