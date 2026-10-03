extends SceneTree

const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const AnglerNetwork=preload("res://scripts/angler_network_observation.gd")
const FishNetwork=preload("res://scripts/fish_network_observation.gd")
const FishObservation=preload("res://scripts/fish_observation.gd")
const Session=preload("res://scripts/network_session.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PHASE01_NETWORK_PASS | ",label)
	else: failed+=1; push_error("PHASE01_NETWORK_FAIL | "+label)

func no_private(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["hook","hook_id","tackle","rng_seed","rng_state","seed","truth_events","suspicion_by_bait","caution_by_bait","risk_tolerance","supply_queue","next_hook_id","next_bait_id","bait_batch","counted","budget","drift_phase","flutter_amplitude","future_secret"]: return false
			if not no_private(value[key]): return false
	elif value is Array:
		for item in value:
			if not no_private(item): return false
	return true

func chunks(packet: Dictionary) -> Array[Dictionary]:
	var wire:=packet.duplicate(true)
	wire.v=Protocol.VERSION
	var bytes:=Protocol.encode(wire)
	var count:=ceili(bytes.size()/800.0)
	var result: Array[Dictionary]=[]
	for index in count: result.append({"session":packet.session,"round":packet.round,"seq":packet.seq,"part":index,"count":count,"size":bytes.size(),"data":bytes.slice(index*800,(index+1)*800)})
	return result

func reject_without_mutation(world: Node2D, bad: Dictionary, label: String) -> void:
	var before: Dictionary=world.capture_snapshot()
	check(not FishNetwork.apply(world,bad) and world.capture_snapshot()==before,label)

func pure_checks() -> void:
	var authority:=World.new()
	var receiver:=World.new()
	authority.reset_world({"seed":991847,"ruleset":"duel","challenge":true})
	authority.baits[0].active=true
	receiver.reset_world({"seed":40,"ruleset":"duel","challenge":true})
	var original: Dictionary=authority.capture_snapshot()
	var projected:=FishNetwork.capture(authority)
	check(FishNetwork.valid(receiver,projected),"explicit fish presentation schema validates")
	check(no_private(projected),"recursive fish payload excludes hooks, tackle tags, seeds, scores, and reserves")
	check(projected.state.effort_checks.angler.keys().size()==2 and not projected.state.effort_checks.angler.has("zone"),"opponent check timing and target are private; only realized force is public")
	check(not receiver.restore_snapshot(projected),"fish presentation cannot enter authoritative replay restore")
	check(FishNetwork.apply(receiver,projected),"validated fish data uses its separate presentation apply API")
	check(receiver.truth_events.is_empty() and receiver.suspicion_by_bait.is_empty() and receiver.supply_queue.is_empty() and no_private(receiver.baits),"fish game adapter retains only sanitized bait dictionaries")
	check(FishObservation.build(receiver)==FishObservation.build(authority),"sanitized world builds the same public fish perception as authority")
	var invisible: Dictionary=projected.state.baits[2]
	check(not invisible.active and invisible.grains.is_empty() and invisible.pos==Vector2.ZERO,"invisible reserves have no hidden home, future grains, or motion")
	# Change secret truth only, with identical legal physical facts.
	for bait in authority.baits:
		bait.hook=not bait.hook
		bait.hook_id+=100000
		bait.tackle=not bait.tackle
		bait.future_secret={"hook":true,"seed":42}
		for grain in bait.grains: grain.future_secret="classified"
	authority.rng.seed=7781
	authority.rng.state=98
	authority.next_hook_id=400000
	authority.next_bait_id=800000
	authority.supply_queue.reverse()
	authority.bait_batch=555
	authority.truth_events.append({"hook":true,"seed":55})
	authority.suspicion_by_bait={1:0.99}
	authority.caution_by_bait={1:"ALARMED"}
	authority.risk_tolerance=0.99
	authority.focus_bait_id=3
	authority.net_action.future_secret=1
	authority.effort_checks.fish.future_secret=2
	authority.effort_checks.angler.zone=0.74
	authority.effort_checks.angler.age=1.2
	authority.effort_checks.angler.id=200
	authority.effort_checks.angler.active=true
	authority.round_stats.future_secret=3
	check(FishNetwork.capture(authority)==projected,"hidden-only truth, opponent timing, and future fields cannot change fish payload")
	check(authority.restore_snapshot(original),"authoritative schema remains restorable after projection")
	var replay:=World.new()
	check(replay.restore_snapshot(original),"authority still restores full seeds and hidden hook truth")
	for tick in 24:
		authority.advance_tick({"move":Vector2.RIGHT},{})
		replay.advance_tick({"move":Vector2.RIGHT},{})
	check(authority.capture_snapshot()==replay.capture_snapshot(),"projection does not weaken deterministic authority replay")
	var bad:=projected.duplicate(true); bad.state.baits[0].hook=false
	reject_without_mutation(receiver,bad,"unexpected hidden bait fields are rejected without partial mutation")
	bad=projected.duplicate(true); bad.rng_seed=1
	reject_without_mutation(receiver,bad,"authority seeds cannot be smuggled into fish schema")
	bad=projected.duplicate(true); bad.state.net_action.future_secret={"hook_id":1}
	reject_without_mutation(receiver,bad,"future nested fields are rejected, not blindly copied")
	bad=projected.duplicate(true); bad.state.baits[0].grains[0].pos="invalid"
	reject_without_mutation(receiver,bad,"malformed visible grains are rejected atomically")
	bad=projected.duplicate(true); bad.state.baits[1].bait_id=bad.state.baits[0].bait_id
	reject_without_mutation(receiver,bad,"duplicate public bait identities are rejected")
	bad=projected.duplicate(true); bad.state.qte_timing.sweep=0.0
	reject_without_mutation(receiver,bad,"invalid timing denominator is rejected")
	bad=projected.duplicate(true); bad.state.effort_checks.fish.kind="unknown"
	reject_without_mutation(receiver,bad,"invalid nested check enum is rejected")
	bad=projected.duplicate(true); bad.state.caution_state="SECRET"
	reject_without_mutation(receiver,bad,"invalid caution enum is rejected")
	bad=projected.duplicate(true); bad.state.net_retract_duration=0.0
	reject_without_mutation(receiver,bad,"invalid physical interpolation duration is rejected")
	bad=projected.duplicate(true); bad.state.fish=Vector2(NAN,1)
	reject_without_mutation(receiver,bad,"nonfinite position is rejected")
	bad=projected.duplicate(true); bad.state.baits[0].grains.resize(2049)
	reject_without_mutation(receiver,bad,"oversized visible grain arrays are rejected")
	var present:=Presentation.new()
	check(present.accept(projected,1.0,"fish"),"render-only world accepts fish schema")
	var before:=present.current.duplicate(true)
	check(not present.accept(bad,2.0,"fish") and present.current==before,"malformed presentation cannot replace render history")
	var later:=projected.duplicate(true); later.state.simulation_tick=2; later.state.elapsed=2.0/60; later.state.fish+=Vector2(2,0)
	check(present.accept(later,1.04,"fish") and no_private(present.sample(1.06).baits),"fish interpolation never fabricates hook keys")
	check(FishNetwork.capture(receiver)==projected,"render interpolation cannot mutate latest public game state")
	var config:=FishNetwork.public_config({"seed":81234,"future_secret":1,"rules":authority.rules})
	check(FishNetwork.config_valid(config) and no_private(config),"fish room/start configuration has an explicit seed-free allowlist")
	config.seed=42
	check(not FishNetwork.config_valid(config),"seed-bearing configuration is rejected on fish receive")
	var sender:=Session.new(); sender.game=authority; sender.remote_role="fish"; sender.session_id="projection"; sender.round_id=1; sender.status="playing"
	var receiving:=Session.new(); receiving.game=receiver; receiving.local_role="fish"; receiving.session_id="projection"; receiving.round_id=1
	for kind in ["start","state"]:
		var packet: Dictionary=sender._state_packet(kind)
		check(no_private(Protocol.unpack_state(packet.snapshot)),kind+" packet uses fish projection before encoding")
	var state: Dictionary=sender._state_packet("state")
	receiving._receive_state(state)
	check(receiving.received_state_seq==state.seq and no_private(receiver.baits),"reliable state path applies only fish presentation")
	state=sender._state_packet("state")
	var pieces:=chunks(state)
	var prior: int=receiving.received_state_seq
	for index in range(pieces.size()-1,0,-1): receiving._receive_chunk(pieces[index]); receiving._receive_chunk(pieces[index])
	check(receiving.received_state_seq==prior,"incomplete duplicate chunks cannot partially apply fish state")
	receiving._receive_chunk(pieces[0])
	check(receiving.received_state_seq==state.seq and no_private(receiving.presentation.current),"out-of-order chunk path reconstructs only sanitized fish state")
	sender.remote_role="angler"
	var angler_wire:=Protocol.unpack_state(sender._state_packet("state").snapshot)
	check(angler_wire==AnglerNetwork.capture(authority),"angler peer uses its NPC-public role projection")
	check(AnglerNetwork.apply(receiver,angler_wire),"angler projection applies through the separate validated adapter")
	var original_angler: Dictionary=authority.capture_snapshot()
	var received_angler: Dictionary=receiver.capture_snapshot()
	for key: String in ["npc_fishes","next_fish_id","hook_target_fish_id","npc_foraging_enabled"]:
		original_angler.state.erase(key); received_angler.state.erase(key)
	for key: String in World.Stats.NPC_FIELDS:
		original_angler.state.round_stats.erase(key); received_angler.state.round_stats.erase(key)
	check(received_angler==original_angler,"angler adapter preserves every preexisting non-NPC authority field, rig and RNG value")
	receiving.presentation.dispose(); sender.presentation.dispose(); receiving.free(); sender.free(); present.dispose(); authority.free(); receiver.free(); replay.free()

func frame() -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60,{}); client.network.tick(1.0/60,{})
	await create_timer(0.017).timeout

func phase(wanted: String) -> bool:
	for tick in 340:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false

func live_checks() -> void:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game in [host,client]:
		game.capture_mode="phase01-network"; game.set_process(false); game.set_physics_process(false); game.save_path="user://phase01-network-"+str(game.get_instance_id())+".cfg"
	check(host.network.host_game("angler",24767,{})==OK and client.network.join_game("127.0.0.1",24767)==OK,"real ENet fish peer connects")
	if not await phase("waiting"): check(false,"fish handshake completes"); return
	check(client.network.local_role=="fish" and no_private(client.network.config),"actual welcome config is seed-free")
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"sanitized start and countdown complete"); return
	check(no_private(client.network.config) and no_private(client.baits) and no_private(client.network.presentation.current),"actual fish start/game/render worlds contain no hidden hooks or seeds")
	host.angler.deploy(host)
	for tick in 65: await frame()
	check(client.baits[0].active and no_private(client.baits),"public deployed food motion remains synchronized through chunks")
	host.fish=Vector2(250,180); host._enter_hook(0); host._attach_hook(); host.network._send_state(true)
	for tick in 8: await frame()
	check(client.hooked==host.HookState.HOOKED and client.bound_bait==0 and no_private(client.baits),"observed attachment remains playable without receiving hook truth")
	check(client.network.display_world().rope_path.size()>=2,"sanitized presentation still draws the attached public line")
	host.finish(false,"net"); host.network._phase("finished"); host.network._send_state(true)
	for tick in 5: await frame()
	check(client.match_over and client.winner_role==host.winner_role and client.menu.screen=="result","sanitized reliable result reaches fish result screen")

func run() -> void:
	pure_checks()
	await live_checks()
	if is_instance_valid(host): host.network.close(); host.queue_free()
	if is_instance_valid(client): client.network.close(); client.queue_free()
	await process_frame
	print("PHASE01_NETWORK_TESTS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
