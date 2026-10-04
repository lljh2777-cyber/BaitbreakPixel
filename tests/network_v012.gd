extends SceneTree

const Main=preload("res://scenes/main.tscn")
const Protocol=preload("res://scripts/network_protocol.gd")
var host: Node2D
var client: Node2D
var passed := 0
var failed := 0
var tick_count := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("NET12_PASS | ",description)
	else: failed+=1; push_error("NET12_FAIL | "+description)

func frame(h: Dictionary = {}, c: Dictionary = {}) -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60,h); client.network.tick(1.0/60,c)
	tick_count+=1
	await create_timer(0.017).timeout

func until_phase(phase: String, limit: int = 360) -> bool:
	for index in limit:
		await frame()
		if host.network.status==phase and client.network.status==phase: return true
		if host.network.status=="failed" or client.network.status=="failed": break
	print("PHASE_WAIT | host=",host.network.status," ",host.network.message," | client=",client.network.status," ",client.network.message)
	return false

func run() -> void:
	host=Main.instantiate(); client=Main.instantiate()
	root.add_child(host); root.add_child(client)
	for game in [host,client]:
		game.capture_mode="network-test"
		game.set_physics_process(false); game.set_process(false)
		game.save_path="user://network-v012-"+str(game.get_instance_id())+".cfg"
	var settings: Dictionary={"mouth_window":0.5,"slack_hold":0.7,"break_hold":4.0,"water_strength":0.0}
	check(host.network.host_game("angler",24752,settings)==OK,"host binds a real ENet UDP socket")
	check(client.network.join_game("127.0.0.1",24752)==OK,"client opens a separate ENet connection")
	var joined := await until_phase("waiting")
	check(joined and client.network.local_role=="fish","handshake assigns the complementary fish role")
	if not joined: await cleanup(); return
	check(client.network.config.rules.qte_entry_window==0.5,"host timing rules arrive in the room handshake")
	client.saved_rules=client.Rules.normalize({"slack_hold":1.2,"qte_entry_window":0.9,"qte_slack_window":0.9,"break_hold":8})
	host.network.set_ready(true)
	for index in 5: await frame()
	check(host.simulation_tick==0 and client.network.remote_ready,"one ready player cannot start the match")
	client.network.set_ready(true)
	var running := await until_phase("playing")
	check(running,"both ready players load the same world and finish a countdown")
	if not running: await cleanup(); return
	check(host.shared_session and client.shared_session and host.player_role=="angler" and client.player_role=="fish","both apps enter complementary live shared views")
	check(host.ruleset=="duel" and client.ruleset=="duel" and client.mouth_window_seconds==0.5,"same duel rules apply on both peers")
	client.save_profile()
	var saved_preferences:=ConfigFile.new(); saved_preferences.load(client.save_path)
	check(saved_preferences.get_value("rules","values").qte_entry_window==0.9,"online results and settings do not overwrite the client's offline timing preferences")
	var start_fish: Vector2=host.fish
	var start_angler: float=host.angler.x
	for index in 35: await frame({"walk":1,"deploy":index==0},{"move":Vector2.RIGHT,"power":0.7})
	check(host.fish.x>start_fish.x+20 and host.angler.x>start_angler+30,"remote fish and local angler act in the same authority simulation")
	check(absf(host.power-0.7)<0.01 and not host.angler.auto_reel,"remote suction input does not enable AI or replace manual human controls")
	check(client.fish.distance_to(host.fish)<5 and client.network.applied_input_seq>0,"snapshots and input acknowledgements follow authoritative motion")
	check(client.network.bytes_received>0 and host.network.bytes_received>0,"world states and commands crossed real UDP sockets")
	var sample: Dictionary=host.capture_snapshot()
	var packed: Dictionary=Protocol.pack_state(sample)
	check(Protocol.unpack_state(packed)==sample and packed.data.size()<var_to_bytes(sample).size(),"compressed snapshots round-trip while reducing traffic")
	check(Protocol.unpack_state({"size":Protocol.MAX_STATE+1,"data":PackedByteArray()}).is_empty(),"decompression rejects an oversized declared state")
	check(not Protocol.safe_values({"node":host}),"packet schema excludes object references")
	var clean := Protocol.input("angler",{"auto_reel":true,"auto_net":true,"walk":99,"target":Vector2(9999,9999)},host.map_context)
	check(not clean.auto_reel and not clean.auto_net and clean.walk==1 and clean.target==Vector2(640,360),"remote players cannot enable AI or bypass input bounds")
	var rejected: int=host.network.rejected_inputs
	host.network.receive_input({"session":host.network.session_id,"round":host.network.round_id-1,"seq":999})
	host.network.receive_input({"session":host.network.session_id,"round":host.network.round_id,"seq":host.network.received_input_seq})
	check(host.network.rejected_inputs==rejected+2,"old rounds and repeated input sequences are discarded")
	var tick_before: int=host.simulation_tick
	client.menu.open("help")
	for index in 5: await frame()
	check(host.simulation_tick>tick_before and not host.match_paused,"client help does not pause the authority")
	client.menu.close()
	# A real QTE is shown remotely, then judged using the tick the client saw.
	host.fish=Vector2(232,180); host.baits[0].active=true; host._enter_hook(0)
	host.qte_zone=0.4; host.qte_width=0.25
	host.network._remember_qte(); host.network._send_state(true)
	var pressed := false
	for index in 145:
		var view: Node2D=client.network.display_world()
		var command: Dictionary={}
		if not pressed and view.qte=="entry" and view.qte_progress()>0.48:
			command.qte=true; pressed=true
		await frame({},command)
		if pressed and host.hooked==host.HookState.FREE: break
	check(pressed and host.hooked==host.HookState.FREE and host.network.qte_accepted==1,"remote QTE is judged by host history and succeeds once")
	# End and replay a fresh round, then reverse which peer controls the net.
	host.finish(false,"net")
	host.network._phase("finished"); host.network._send_state(true)
	for index in 5: await frame()
	check(host.won and client.lost and host.winner_role==client.winner_role,"one authoritative result presents opposite local outcomes")
	check(host.round_stats==client.round_stats and client.round_stats.fish_good==1,"both result screens receive the same authoritative QTE statistics")
	var old_round: int=host.network.round_id
	host.network.set_ready(true); client.network.set_ready(true)
	check(await until_phase("playing"),"both players can ready again after a result")
	check(host.network.round_id==old_round+1 and host.score==0 and client.score==0,"rematch resets state and advances the round identifier")
	client.network.close(true)
	for index in 15:
		host.network.poll()
		await create_timer(0.02).timeout
	check(host.network.status=="failed" and host.match_paused,"leaving a room freezes the match without awarding a win")
	check(not host.match_over,"disconnect is not a fabricated game result")
	await test_remote_angler(settings)
	await cleanup()

func test_remote_angler(settings: Dictionary) -> void:
	host.return_to_title(); client.return_to_title()
	check(client.mouth_window_seconds==0.9,"leaving restores the client's own singleplayer rules")
	host.network.host_game("fish",24752,settings)
	client.network.join_game("127.0.0.1",24752)
	if not await until_phase("waiting"): check(false,"reverse roles connect"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await until_phase("playing"): check(false,"reverse roles start"); return
	check(client.player_role=="angler","room owner can also play fish while the client angles")
	host.fish=Vector2(60,270)
	var route := [Vector2(425,110),Vector2(540,110),Vector2(540,200),Vector2(425,200),Vector2(425,110)]
	var events: Array=[]
	for point in route: events.append({"kind":"point","point":point})
	await frame({}, {"net_hold":true,"drag":true,"target":route[-1],"net_events":events})
	for index in 6: await frame({}, {"net_hold":true,"drag":true,"target":route[-1]})
	check(host.manual_net and host.net_route==PackedVector2Array(route),"remote same-frame loop retains the exact ordered corners")
	for index in 85: await frame({}, {"net_hold":true,"drag":true,"target":route[-1]})
	check(host.net_state=="sweep","remote E and mouse hold advance the net into sweep")
	await frame({}, {"net_events":[{"kind":"cancel"}],"target":route[-1]})
	for index in 4: await frame()
	check(host.net_state=="withdraw" and host.net_catches==0,"remote release cancels the sweep and capture")
	var saved: PackedVector2Array=host.net_route.duplicate()
	var next_seq: int=host.network.received_input_seq+1
	host.network.receive_input({"session":host.network.session_id,"round":host.network.round_id,"seq":next_seq,
		"seen_tick":host.simulation_tick,"qte_id":host.qte_id,"gesture":1,
		"command":{"net_hold":true,"drag":true,"target":Vector2(590,120)},"events":[{"kind":"point","point":Vector2(590,120),"gesture":1}]})
	host.network.tick(1.0/60,{})
	check(host.net_route==saved and not host.angler.dragging,"a closed gesture cannot be reopened by a late point")
	host.network.remote_held={"walk":1,"reel":true,"net_hold":true,"drag":true}
	host.network.last_input_rx=host.network.now()-300
	var neutral: Dictionary=host.network._take_remote()
	check(not neutral.get("reel",false) and neutral.get("walk",0)==0 and neutral.net_events[0].kind=="suspend","expired inputs stop held controls and suspend the net")
	# Regression: incoming W/S must change fish reach and tension, not only a speed field.
	host.cancel_manual_net(); host.net_state="rest"; host.net_recovery=10
	host.fish=Vector2(240,205); host.aim=Vector2.RIGHT; host.stamina=100
	host.baits[0].active=true; host._enter_hook(0); host._attach_hook()
	# The stale-input probe above used a synthetic sequence; restore the next live sequence.
	host.network.received_input_seq=client.network.input_seq
	for index in 120: await frame({"move":Vector2.DOWN,"dash":true},{"reel":true})
	check(host.hooked==host.HookState.HOOKED and host.fish.y<170,"remote W reels a sprinting host fish physically closer")
	for index in 65: await frame({"move":Vector2.DOWN,"dash":true},{"release":true})
	check(host.hooked==host.HookState.HOOKED and host.tension<0.9 and host.high_age==0,"remote S relieves red tension before line break")
	check(client.hooked==host.hooked and absf(client.tension-host.tension)<0.1 and client.fish.distance_to(host.fish)<8,"corrected reel result is synchronized back to the angler client")
	# A remote net must expose the new escape window on both clients.
	host._clear_hook(); host._finish_net_recovery(); host.net_state="wait"; host.angler.net_cooldown=0
	host.angler.needs_neutral=false; host.fish=Vector2(460,160); host.fish_before=host.fish; host.velocity=Vector2.ZERO
	host.stamina=100; host.hook_cooldown=10; host.baits[0].active=false
	var net_input := {"net_hold":true,"drag":true,"target":Vector2(460,160)}
	await frame({}, {"net_hold":true,"drag":true,"target":Vector2(460,160),"net_events":[{"kind":"point","point":Vector2(460,160)}]})
	for index in 120:
		await frame({},net_input)
		if host.net_capture>=0.4: break
	check(host.net_state=="sweep" and client.net_state=="sweep" and client.net_capture>0 and not host.movement_locked(),"partial remote net closure is visible on both sides while fish can still move")
	await frame({}, {"net_events":[{"kind":"cancel"}]})
	for index in 8: await frame()
	check(host.net_capture==0 and client.net_capture==0 and host.net_catches==0,"remote release clears partial closure without a capture")
	for index in 80:
		await frame()
		if host.net_state=="rest": break
	host.angler.net_cooldown=0; host.stamina=10; host.stamina_delay=4
	await frame({}, {"net_hold":true,"drag":true,"target":Vector2(460,160),"net_events":[{"kind":"point","point":Vector2(460,160)}]})
	for index in 140:
		await frame({},net_input)
		if host.net_state=="caught" and client.net_state=="caught": break
	check(host.net_catches==1 and client.net_catches==1 and host.net_state=="caught" and client.net_state=="caught","sustained remote net contact captures once and synchronizes the lift")

func cleanup() -> void:
	host.queue_free(); client.queue_free()
	await process_frame
	print("NETWORK_V012_TESTS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
