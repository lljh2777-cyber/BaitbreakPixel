extends SceneTree
const Peer=preload("res://tests/helpers/map_network_peer.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
var passed:=0
var failed:=0
var next_port:=25980
var generator_version:=1
var host:Node2D
var client:Node2D
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATED_NETWORK_FAIL | "+label)
func _initialize()->void: call_deferred("run")
func frame()->void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60.0,{"move":Vector2.RIGHT,"walk":0.2})
	client.network.tick(1.0/60.0,{"move":Vector2.RIGHT,"walk":0.2})
	await create_timer(0.001).timeout
func until_phase(phase:String)->bool:
	for tick in 600:
		await frame()
		if host.network.status==phase and client.network.status==phase: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false
func setup(seed:int,role:String)->void:
	host=Peer.new(); client=Peer.new(); root.add_child(host); root.add_child(client)
	check(host.network.host_game(role,next_port,{"map_source":Resolver.generated(seed,generator_version),"rules":{"timer_enabled":false,"hunger_enabled":false}})==OK,"host creates generated lobby")
	check(client.network.join_game("127.0.0.1",next_port)==OK,"client connects from classic default")
	next_port+=1
func cleanup()->void:
	host.free(); client.free(); await process_frame
func run()->void:
	for role:String in ["fish","angler"]:
		for seed:int in [42,1346,2147483647]:
			await setup(seed,role)
			check(await until_phase("waiting"),"generated recipe negotiated")
			check(client.network.map_source==Resolver.generated(seed,generator_version) and client.network.map_ref==host.network.map_ref,"client reconstructs same map before ready")
			host.network.set_ready(); client.network.set_ready()
			check(await until_phase("playing"),"both roles start generated round")
			for tick in 50: await frame()
			check(host.rounds_started==1 and client.rounds_started==1 and client.map_context.map_ref==host.map_context.map_ref,"runtime map installed on both peers")
			check(host.targets==client.targets and host.map_net_blockers==client.map_net_blockers,"geometry reconstructed locally matches")
			check(client.network.received_state_seq>1 and client.npc_fishes.size()==host.npc_fishes.size(),"live public NPC states synchronize")
			var starts:int=client.rounds_started
			var wrong:Dictionary=host.network._state_packet("state"); wrong.map_source.map_seed=1
			wrong.v=host.network.Protocol.VERSION
			var previous:Vector2=client.fish
			client.network._handle(wrong)
			check(client.network.status=="failed" and client.rounds_started==starts and client.fish==previous,"mid-round recipe substitution rejected before state mutation")
			await cleanup()
	for mutation:String in ["generator","version","profile","hash","missing-source","source-seed"]:
		await setup(42,"angler")
		host.network.transform_packet=func(packet:Dictionary)->Dictionary:
			if packet.get("kind")=="welcome":
				match mutation:
					"generator": packet.map_source.generator_id="other"
					"version": packet.map_source.generator_version=99
					"profile": packet.map_source.gameplay_profile="other"
					"hash": packet.map_ref.content_hash="0".repeat(64)
					"missing-source": packet.erase("map_source")
					"source-seed": packet.map_source.map_seed=1
			return packet
		for tick in 200:
			await frame()
			if client.network.status=="failed": break
		client.network.set_ready()
		check(client.network.status=="failed" and not client.network.map_validated and not client.network.local_ready and client.rounds_started==0,"untrusted lobby rejects "+mutation)
		await cleanup()
	print("PHASE05_NETWORK | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
