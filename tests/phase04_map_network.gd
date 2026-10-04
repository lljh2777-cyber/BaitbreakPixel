extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Peer=preload("res://tests/helpers/map_network_peer.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Fish=preload("res://scripts/fish_network_observation.gd")
const Angler=preload("res://scripts/angler_network_observation.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
const Fixture=preload("res://tests/fixtures/phase04/authority_fixture.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D
var next_port:=24920

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("MAP_NETWORK_PASS | ",label)
	else: failed+=1; push_error("MAP_NETWORK_FAIL | "+label)

func ref() -> Dictionary:
	return Registry.available_refs()[0]

func bad_refs() -> Array[Dictionary]:
	var cases: Array[Dictionary]=[]
	for key: String in ["id","revision","contract_version","content_hash"]:
		var missing:=ref(); missing.erase(key)
		cases.append({"label":"missing "+key,"value":missing})
		var wrong:=ref(); wrong[key]=[]
		cases.append({"label":"nested "+key,"value":wrong})
	for value in [null,[],"pond_v2",1]: cases.append({"label":"non-record "+str(value),"value":value})
	for entry: Dictionary in [{"id":"unknown"},{"revision":2},{"revision":1.0},{"contract_version":2},{"contract_version":1.0},{"content_hash":"0".repeat(64)},{"content_hash":"A".repeat(64)},{"id":&"pond_v2"},{"content_hash":&"bad"}]:
		var bad:=ref(); bad.merge(entry,true)
		cases.append({"label":"mismatch "+str(entry),"value":bad})
	var extra:=ref(); extra.geometry=PackedVector2Array([Vector2.ZERO])
	cases.append({"label":"extra geometry","value":extra})
	var named: Dictionary={}
	for key: String in ref(): named[StringName(key)]=ref()[key]
	cases.append({"label":"StringName keys","value":named})
	return cases

func projection(role: String, world: Node2D) -> Dictionary:
	return Fish.capture(world) if role=="fish" else Angler.capture(world)

func apply(role: String, world: Node2D, snapshot: Dictionary) -> bool:
	return Fish.apply(world,snapshot) if role=="fish" else Angler.apply(world,snapshot)

func map_fields_absent(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["map_id","map_definition","interaction_features","visual_features","bait_sites","SOLIDS","PLANTS","BAIT_SITES"]: return false
			if not map_fields_absent(value[key]): return false
	elif value is Array:
		for item in value:
			if not map_fields_absent(item): return false
	return true

func same_world_without_pause(before: Dictionary, world: Node2D) -> bool:
	var after: Dictionary=world.capture_snapshot()
	after.state.match_paused=before.state.match_paused
	return before==after

func pure_checks() -> void:
	check(Protocol.BUILD=="0.26.4" and Fish.SCHEMA==2 and World.Snapshot.SCHEMA==16,"exact build, public fish schema2 and authority schema16 remain distinct")
	var authority:=World.new(); authority.reset_world({"seed":4262,"ruleset":"duel"})
	var receiver:=World.new(); receiver.reset_world({"seed":9})
	for role: String in ["fish","angler"]:
		var source:=projection(role,authority)
		check(source.map_ref==ref() and not source.has("map_id") and map_fields_absent(source),role+" wire carries exactly MapRef and no map geometry arrays")
		check(apply(role,receiver,source) and receiver.map_context.map_ref==ref() and receiver.targets==authority.targets and receiver.map_net_blockers==authority.map_net_blockers,role+" resolves identical public geometry through local registry")
		check(receiver.npc_fishes==NPCPublic.capture(authority.npc_fishes) and NPCPublic.valid(receiver.npc_fishes,1,receiver.map_context.water),role+" NPC positions remain public and valid in resolved water")
		for case: Dictionary in bad_refs():
			var invalid:=source.duplicate(true); invalid.map_ref=case.value
			var before: Dictionary=receiver.capture_snapshot(); var before_context: RefCounted=receiver.map_context
			check(not apply(role,receiver,invalid) and before==receiver.capture_snapshot() and receiver.map_context==before_context,role+" rejects "+case.label+" before world/context mutation")
		var legacy:=source.duplicate(true); legacy.map_id="pond_v2"; legacy.erase("map_ref")
		check(not apply(role,receiver,legacy),role+" rejects legacy map_id without fallback")
		var missing:=source.duplicate(true); missing.erase("map_ref")
		check(not apply(role,receiver,missing),role+" requires map_ref")
		if role=="fish":
			var malformed:=source.duplicate(true); malformed.state.net_action.age=0
			check(not apply(role,receiver,malformed),role+" preserves existing strict public float guard")
		var wrong_array: Array[Vector2]=[]
		var malformed:=source.duplicate(true); malformed.state.wraps=wrong_array
		check(not apply(role,receiver,malformed),role+" rejects wrong typed-array property before mutation")
		check(receiver.reset_world({"seed":9},Fixture.create()) and receiver.targets.size()==5,role+" starts from a valid unregistered five-target fixture")
		var fixture_before: Dictionary=receiver.capture_snapshot()
		var false_geometry:=source.duplicate(true); false_geometry.state.target_opacity.resize(5)
		check(not apply(role,receiver,false_geometry) and receiver.capture_snapshot()==fixture_before,role+" validates target cardinality against resolved pond, not existing fixture")
		check(apply(role,receiver,source) and receiver.map_context.map_ref==ref() and receiver.targets==authority.targets and receiver.map_net_blockers==authority.map_net_blockers and receiver.angler._map_context==receiver.map_context,role+" atomically replaces fixture with locally resolved pond geometry and rig caches")
		var source_before:=source.duplicate(true)
		var detached_ref: Dictionary=receiver.map_context.map_ref; detached_ref.id="tampered"
		var detached_targets: Array=receiver.map_context.interaction_targets; detached_targets[0].polygon[0]=Vector2.ZERO
		check(source==source_before and receiver.map_context.map_ref==ref() and receiver.targets==authority.targets,role+" public map exports cannot mutate source/ref or installed geometry")
	var object_array: Array[Object]=[]
	var object_values: Dictionary[String,Object]={}
	check(not Protocol.safe_values(object_array) and not Protocol.safe_values(object_values),"wire rejects even empty Object-typed container metadata")
	check(NPCPublic.landing_bounds(authority.map_context.water).position.y==39.0,"map-aware NPC landing validator preserves exact legacy lower edge")
	authority.free(); receiver.free()
	# A connected socket or known session string is not a completed map handshake.
	for kind: String in ["ready","start","start_ack","input","state","chunk","effects"]:
		var game:=Peer.new(); root.add_child(game)
		game.network._select_map(); game.network.session_id="guessed"; game.network.status="waiting"
		game.network.is_host=kind in ["ready","start_ack","input"]
		var before: Dictionary=game.capture_snapshot()
		game.network._handle({"v":Protocol.VERSION,"kind":kind,"session":"guessed","round":0,"value":true})
		check(game.network.status=="failed" and not game.network.map_validated and not game.network.remote_ready and game.rounds_started==0 and same_world_without_pause(before,game),"forged "+kind+" cannot bypass map handshake")
		game.free()
	var game:=Peer.new(); root.add_child(game)
	game.network._select_map(); game.network.is_host=true; game.network.status="playing"; game.network.session_id="test"
	game.network.receive_input({"session":"test","round":0,"seq":1,"command":{},"events":[],"seen_tick":0,"qte_id":0,"gesture":0})
	check(game.network.remote_queue.is_empty() and game.network.received_input_seq==0,"direct receive_input cannot bypass unvalidated map")
	game.free()

func envelope_checks() -> void:
	var authority:=World.new(); authority.reset_world({"seed":71,"ruleset":"duel"})
	authority.fish=Vector2(777,220)
	var cases: Array[Dictionary]=[]
	for value in [{},Vector2.ZERO,false,-1,1.0,null]: cases.append({"key":"ack","value":value})
	for value in [{},Vector2.ZERO,false,NAN,INF,-0.01,3.01,null]: cases.append({"key":"countdown","value":value})
	for role: String in ["fish","angler"]:
		for case: Dictionary in cases:
			var game:=Peer.new(); root.add_child(game); game.reset_world({"seed":13})
			game.network._select_map(); game.network.map_validated=true; game.network.local_role=role
			game.network.session_id="envelope"; game.network.status="playing"
			var packet: Dictionary={"session":"envelope","round":0,"seq":1,"build":Protocol.BUILD,"map_ref":ref(),"phase":"playing","snapshot":Protocol.pack_state(projection(role,authority)),"ack":0,"countdown":0.0}
			packet[case.key]=case.value
			var before: Dictionary=game.capture_snapshot()
			game.network._receive_state(packet)
			check(game.network.status=="failed" and game.network.received_state_seq==-1 and game.network.applied_input_seq==0 and game.network.presentation.current.is_empty() and same_world_without_pause(before,game),role+" rejects malformed envelope "+case.key+"="+str(case.value)+" before world/sequence/render mutation")
			game.free()
		for value in [0,0.0,3,3.0]:
			var game:=Peer.new(); root.add_child(game); game.reset_world({"seed":13})
			game.network._select_map(); game.network.map_validated=true; game.network.local_role=role
			game.network.session_id="envelope"; game.network.status="playing"
			game.network._receive_state({"session":"envelope","round":0,"seq":1,"build":Protocol.BUILD,"map_ref":ref(),"phase":"playing","snapshot":Protocol.pack_state(projection(role,authority)),"ack":0,"countdown":value})
			check(game.network.status=="playing" and game.network.received_state_seq==1 and game.fish==authority.fish and game.network.countdown==float(value),role+" preserves valid numeric countdown "+str(value))
			game.free()
	authority.free()

func frame(h: Dictionary={}, c: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60.0,h); client.network.tick(1.0/60.0,c)
	await create_timer(0.001).timeout

func until_phase(wanted: String, limit: int=480) -> bool:
	for tick in limit:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false

func setup(host_role: String) -> bool:
	host=Peer.new(); client=Peer.new(); root.add_child(host); root.add_child(client)
	var port:=next_port; next_port+=1
	return host.network.host_game(host_role,port,{"rules":{"timer_enabled":false,"water_strength":0.0,"satiety_decay":0.0}})==OK and client.network.join_game("127.0.0.1",port)==OK

func cleanup() -> void:
	host.network.close(); client.network.close(); host.free(); client.free()
	await process_frame

func live_checks(host_role: String) -> void:
	var role: String="fish" if host_role=="angler" else "angler"
	check(await setup(host_role),"ENet "+role+" opens real UDP host/client")
	check(await until_phase("waiting"),"ENet "+role+" same-build same-map handshake accepted")
	check(host.network.map_validated and client.network.map_validated and host.network.map_ref==ref() and client.network.map_ref==ref(),"ENet "+role+" both peers validate full MapRef before ready")
	host.network.set_ready(); client.network.set_ready()
	var started:=await until_phase("playing")
	check(started,"ENet "+role+" validated start reaches playing")
	if not started: await cleanup(); return
	for tick in 24: await frame({"move":Vector2.RIGHT,"walk":1},{"move":Vector2.RIGHT,"walk":1})
	host.match_paused=true; host.network._send_state(true)
	for tick in 12: await frame()
	check(client.rounds_started==1 and host.rounds_started==1 and client.network.local_role==role,"ENet "+role+" initializes exactly one complementary round")
	check(client.map_context.map_ref==ref() and client.targets==host.targets and client.network.presentation.world.targets==host.targets,"ENet "+role+" client/render world resolve local map geometry")
	check(client.npc_fishes==NPCPublic.capture(host.npc_fishes) and NPCPublic.valid(client.npc_fishes,1,client.map_context.water),"ENet "+role+" real NPC authority movement synchronizes inside map bounds")
	check(host.network.received_input_seq>0 and client.network.received_state_seq>0,"ENet "+role+" inputs/states flow after validated round")
	for side: Node2D in [host,client]:
		for packet: Dictionary in side.network.sent:
			if packet.kind in ["hello","welcome","start","start_ack"]:
				check(packet.build==Protocol.BUILD and packet.map_ref==ref(),"ENet "+role+" "+packet.kind+" has exact build and four-field identity")
	var wire:=Protocol.unpack_state(host.network._state_packet("state").snapshot)
	check(wire.map_ref==ref() and map_fields_absent(wire) and not wire.state.npc_fishes[0].has("brain_seed"),"ENet "+role+" wire contains no map arrays or private NPC authority")
	var before: Dictionary=client.capture_snapshot(); var sequence: int=client.network.received_state_seq
	var forged: Dictionary=host.network._state_packet("state"); forged.map_ref.content_hash="0".repeat(64)
	host.network._send(forged,true,2)
	for tick in 8: await frame()
	check(client.network.status=="failed" and not client.network.map_validated and client.network.received_state_seq==sequence and same_world_without_pause(before,client),"ENet "+role+" mismatched later state fails closed before mutation")
	await cleanup()

func mismatch_checks(host_role: String, stage: String, mutation: String) -> void:
	var role: String="fish" if host_role=="angler" else "angler"
	check(await setup(host_role),"ENet "+role+" "+stage+" "+mutation+" sockets open")
	var attacker: Node=client.network if stage=="hello" else host.network
	attacker.transform_packet=func(packet: Dictionary) -> Dictionary:
		if packet.kind!=stage: return packet
		match mutation:
			"build": packet.build="0.26.1"
			"missing": packet.erase("map_ref")
			"unknown": packet.map_ref.id="unknown"
			"revision": packet.map_ref.revision=2
			"contract": packet.map_ref.contract_version=2
			"hash": packet.map_ref.content_hash="0".repeat(64)
			"malformed": packet.map_ref.revision=1.0
			"snapshot":
				var state:=Protocol.unpack_state(packet.snapshot)
				state.map_ref.content_hash="0".repeat(64)
				packet.snapshot=Protocol.pack_state(state)
		return packet
	if stage=="start":
		check(await until_phase("waiting"),"ENet "+role+" valid handshake before forged start")
		host.network.set_ready(); client.network.set_ready()
	for tick in 90:
		await frame()
		if stage=="hello":
			if host.network.status=="failed" and client.network.status=="failed": break
		elif host.network.status=="failed" or client.network.status=="failed": break
	if stage=="hello":
		check(host.network.message.contains("地图") and host.network.message.contains("版本") and client.network.status=="failed" and client.network.message.contains("地图") and client.network.message.contains("版本"),"ENet "+role+" bad hello "+mutation+" delivers explicit map/version refusal to both captions")
	var receiver: Node=host.network if stage=="hello" else client.network
	check(receiver.status=="failed" and not receiver.map_validated and client.rounds_started==0 and client.simulation_tick==0 and client.network.remote_queue.is_empty(),"ENet "+role+" rejects "+stage+" "+mutation+" before client round/authority mutation")
	await cleanup()

func rejection_drain_checks() -> void:
	check(await setup("angler"),"ENet rejection drain sockets open")
	client.network.transform_packet=func(packet: Dictionary) -> Dictionary:
		if packet.kind=="hello": packet.map_ref.content_hash="0".repeat(64)
		return packet
	for tick in 90:
		client.network.poll(); host.network.poll()
		if host.network.rejection_deadline>0: break
		await create_timer(0.001).timeout
	check(host.network.status=="failed" and host.network.rejection_deadline>0 and not host.network.map_validated and client.network.active() and client.network.status=="connecting","ENet refusal immediately disables gameplay while unserviced client transport drains")
	var caption: String=host.network.message
	var tick_before: int=host.simulation_tick
	host.network._handle({"v":Protocol.VERSION,"kind":"hello","build":Protocol.BUILD,"map_ref":ref()})
	host.network.set_ready(); host.network._start_round(); host.network.tick(1.0/60.0,{"move":Vector2.RIGHT})
	check(not host.network.local_ready and not host.network.map_validated and host.rounds_started==0 and host.simulation_tick==tick_before and host.network.message==caption,"ENet draining refusal cannot be revived by valid hello, ready, start or input")
	# Stop servicing the rejected client. The host must close on its bounded
	# monotonic deadline even when the other side neither acknowledges nor leaves.
	var deadline: int=host.network.rejection_deadline
	while Time.get_ticks_msec()<=deadline+50:
		host.network.poll()
		await create_timer(0.01).timeout
	check(not host.network.active() and host.network.status=="failed" and host.network.message==caption and host.network.rejection_deadline==0,"ENet rejection closes by deadline without losing the refusal caption")
	await cleanup()

func readiness_checks(host_role: String) -> void:
	var role: String="fish" if host_role=="angler" else "angler"
	check(await setup(host_role) and await until_phase("waiting"),"ENet "+role+" completes identity before readiness bypass attempt")
	var before: Dictionary=client.capture_snapshot()
	var forged: Dictionary=host.network._state_packet("start")
	forged.round=1; forged.role=host.network.remote_role; forged.config=host.network._peer_config()
	host.network._send(forged,true,2)
	for tick in 12: await frame()
	check(client.network.status=="failed" and client.rounds_started==0 and client.network.round_id==0 and same_world_without_pause(before,client),"ENet "+role+" correct identity cannot bypass both-ready gate with forged start")
	await cleanup()

func bypass_checks() -> void:
	for kind: String in ["ready","start","input","state"]:
		check(await setup("angler"),"ENet bypass "+kind+" sockets open")
		client.network.transform_packet=func(packet: Dictionary) -> Dictionary:
			if packet.kind=="hello":
				return {"kind":kind,"session":host.network.session_id,"round":0,"value":true,"build":Protocol.BUILD,"map_ref":ref()}
			return packet
		for tick in 90:
			await frame()
			if host.network.status=="failed": break
		check(host.network.status=="failed" and not host.network.map_validated and host.rounds_started==0 and host.simulation_tick==0,"ENet guessed session + valid map_ref cannot replace hello with "+kind)
		await cleanup()

func run() -> void:
	pure_checks()
	envelope_checks()
	for role: String in ["angler","fish"]:
		await live_checks(role)
		for stage: String in ["hello","welcome","start"]:
			for mutation: String in ["build","missing","unknown","revision","contract","hash","malformed"]:
				await mismatch_checks(role,stage,mutation)
		await mismatch_checks(role,"start","snapshot")
		await readiness_checks(role)
	await bypass_checks()
	await rejection_drain_checks()
	print("PHASE04_MAP_NETWORK_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
