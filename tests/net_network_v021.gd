extends SceneTree
const Main=preload("res://scenes/main.tscn")
var host: Node2D
var client: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed+=1; print("NET20_UDP_PASS | ",text)
	else: failed+=1; push_error("NET20_UDP_FAIL | "+text)
func frame(command: Dictionary={}, fish_command: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60,fish_command); client.network.tick(1.0/60,command)
	await create_timer(0.017).timeout
func wait_frames(count: int) -> void:
	for i in count: await frame()
func phase(wanted: String) -> bool:
	for i in 330:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false
func run() -> void:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game in [host,client]:
		game.capture_mode="net-network"; game.set_process(false); game.set_physics_process(false); game.save_path="user://net-v020-"+str(game.get_instance_id())+".cfg"
	host.saved_rules=host.Rules.normalize({"net_cooldown":2,"net_manual_speed":100,"water_strength":0,"net_manual_warning":0.8})
	check(host.network.host_game("fish",24762,host.network_settings())==OK and client.network.join_game("127.0.0.1",24762)==OK,"fish host and remote angler connect through ENet")
	if not await phase("waiting"): check(false,"handshake"); await finish(); return
	client.network.set_ready(true); host.network.set_ready(true)
	if not await phase("playing"): check(false,"start"); await finish(); return
	check(client.rules==host.rules and client.rule("net_manual_warning")==0.8,"host net rules synchronized before play")
	host.angler.x=1054; host.fish=Vector2(1120,180); host.fish_before=host.fish; host.network._send_state(true)
	await frame({"net_events":[{"kind":"toggle"}]}); await wait_frames(8)
	check(host.net_action.observing and client.net_action.observing and client.network.display_world().net_action.observing,"remote E opens authoritative and rendered observation")
	check(client.screen_to_game(client.View.Camera.to_screen(Vector2(1070,180),client.network.display_world(),"angler"))==Vector2(1070,180),"remote observer maps scrolled clicks to far-bank world coordinates")
	await frame({"net_events":[{"kind":"point","point":Vector2(1070,180)}]}); await wait_frames(6)
	check(host.net_action.has_a and client.net_action.a==Vector2(1070,180),"first remote click selects exact A")
	await frame({"net_events":[{"kind":"toggle"}]}); await wait_frames(8)
	check(not host.net_action.observing and host.angler.net_cooldown>1.5 and client.angler.net_cooldown>1.4,"remote cancellation closes view and consumes cooldown")
	await wait_frames(130)
	await frame({"net_events":[{"kind":"toggle"}]}); await wait_frames(6)
	await frame({"net_events":[{"kind":"point","point":Vector2(1070,180)},{"kind":"point","point":Vector2(1170,180)}]}); await wait_frames(8)
	check(host.net_state=="warning" and client.net_state=="warning" and not client.network.display_world().net_action.observing,"two clicks in one packet commit exactly once and exit observation")
	check(host.net_from==Vector2(1070,180) and host.net_to==Vector2(1170,180),"remote route retains exact world endpoints")
	await frame({"net_events":[{"kind":"point","point":Vector2(1240,280)},{"kind":"cancel"}]}); await wait_frames(5)
	check(host.net_to==Vector2(1170,180) and host.net_state=="warning","late drag/cancel input cannot mutate committed action")
	for i in 220:
		await frame()
		if host.net_state=="caught": break
	await wait_frames(6)
	check(host.net_state=="caught" and client.net_state=="caught" and host.net_catches==1,"directional free-fish capture occurs once on both peers")
	check(host.hooked==host.HookState.FREE,"free-fish capture never requires a hook")
	for i in 300:
		await frame()
		if host.network.status=="finished" and client.network.status=="finished": break
	check(host.winner_role=="angler" and client.winner_role=="angler" and client.reason=="net","both peers settle the same net victory after lift")
	check(host.network.received_input_seq>0 and client.network.received_state_seq>0,"live inputs and snapshots continued through the action")
	await finish()
func finish() -> void:
	host.network.close(); client.network.close(); host.queue_free(); client.queue_free(); await process_frame
	print("NET_NETWORK_V020 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
