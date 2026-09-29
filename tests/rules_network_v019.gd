extends SceneTree
const Main=preload("res://scenes/main.tscn")
var host: Node2D
var client: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("RULE_UDP_PASS | ",message)
	else: failed+=1; push_error("RULE_UDP_FAIL | "+message)
func frame(input: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60,{}); client.network.tick(1.0/60,input)
	await create_timer(0.017).timeout
func phase(wanted: String) -> bool:
	for i in 330:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false
func run() -> void:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game in [host,client]: game.capture_mode="custom-rules-net"; game.set_process(false); game.set_physics_process(false); game.save_path="user://rules-network-v019-"+str(game.get_instance_id())+".cfg"
	host.saved_rules=host.Rules.normalize({"stamina_max":300,"net_scale":1.25,"qte_entry_lead":0.6,"qte_entry_sweep":5.0,"qte_entry_window":0.35,"qte_entry_random":false,"qte_entry_zone":0.65})
	client.saved_rules=client.Rules.normalize({"stamina_max":200})
	check(host.network.host_game("angler",24761,host.network_settings())==OK and client.network.join_game("127.0.0.1",24761)==OK,"custom-rule peers connect over ENet")
	if not await phase("waiting"): check(false,"handshake"); await finish(); return
	check(client.network.config.rules==host.saved_rules,"all host rules arrive before ready")
	client.menu.open("rules")
	check(client.menu.rules_editor.read_only and client.menu.rules_editor.draft.stamina_max==300,"joining player can inspect locked host values in lobby")
	client.menu.open("room"); host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"start"); await finish(); return
	check(host.stamina==300 and client.stamina==300 and host.rules==client.rules,"both sides start with custom stamina and identical rule schema")
	check(client.network.display_world().net_rim()==host.net_rim(),"render world receives custom net scale")
	host.fish=Vector2(250,170); host.baits[0].active=true; host._enter_hook(0)
	host.network._remember_qte(); host.network._send_state(true)
	var judged:=false; var at:=0.0
	for i in 340:
		var world: Node2D=client.network.display_world()
		var press: bool=not judged and world.qte=="entry" and world.qte_progress()>=world.qte_zone+world.qte_width*0.4
		if press: judged=true; at=world.qte_age
		await frame({"qte":press})
		if judged and host.hooked==host.HookState.FREE: break
	check(judged and at>3.5 and host.hooked==host.HookState.FREE and host.round_stats.fish_good==1,"remote long QTE succeeds using historical age beyond old timeout")
	for i in 8: await frame()
	check(client.hooked==client.HookState.FREE and host.network.qte_accepted==1,"one remote result is authoritative and synchronized")
	client.save_profile(); var cfg:=ConfigFile.new(); cfg.load(client.save_path)
	check(cfg.get_value("rules","values").stamina_max==200,"network profile save keeps client's offline preferences")
	client.return_to_title()
	check(client.rule("stamina_max")==200,"offline rules return after leaving custom room")
	await finish()
func finish() -> void:
	host.network.close(); client.network.close(); host.queue_free(); client.queue_free(); await process_frame
	print("RULES_NETWORK_V019 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
