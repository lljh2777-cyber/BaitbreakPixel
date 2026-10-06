extends SceneTree
const Peer=preload("res://tests/helpers/map_network_peer.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("WOODLAND_NETWORK_FAIL | "+label)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60.0,{"move":Vector2.RIGHT,"walk":0.2})
	client.network.tick(1.0/60.0,{"move":Vector2.RIGHT,"walk":0.2})
	await create_timer(0.001).timeout
func until_phase(phase: String) -> bool:
	for tick in 600:
		await frame()
		if host.network.status==phase and client.network.status==phase: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false
func run() -> void:
	var port:=26140
	for role: String in ["fish","angler"]:
		host=Peer.new(); client=Peer.new(); root.add_child(host); root.add_child(client)
		check(host.network.host_game(role,port,{"map_source":Resolver.woodland(),"rules":{"timer_enabled":false,"hunger_enabled":false}})==OK,"host fixed scene as "+role)
		check(client.network.join_game("127.0.0.1",port)==OK,"join from classic default")
		check(await until_phase("waiting"),"fixed scene negotiated before ready")
		check(client.network.map_source==Resolver.woodland() and client.network.map_ref==host.network.map_ref,"identical authored map identity")
		host.network.set_ready(); client.network.set_ready()
		check(await until_phase("playing"),"both roles start")
		for tick in 50: await frame()
		check(host.rounds_started==1 and client.rounds_started==1 and client.map_context.id=="woodland_pond","runtime installs fixed map")
		check(host.targets==client.targets and host.map_net_blockers==client.map_net_blockers and host.map_context.floor_profile==client.map_context.floor_profile,"floor and contacts match across peers")
		check(client.network.received_state_seq>1 and client.npc_fishes.size()==host.npc_fishes.size(),"live public states synchronize")
		var wrong: Dictionary=host.network._state_packet("state")
		wrong.map_source=Resolver.classic(); wrong.v=host.network.Protocol.VERSION
		var previous: Vector2=client.fish
		client.network._handle(wrong)
		check(client.network.status=="failed" and client.rounds_started==1 and client.fish==previous,"map substitution rejected before state mutation")
		host.free(); client.free(); await process_frame; port+=1
	print("WOODLAND_NETWORK | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
