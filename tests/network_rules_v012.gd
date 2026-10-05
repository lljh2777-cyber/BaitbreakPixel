extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Session=preload("res://scripts/network_session.gd")
const AnglerPublic=preload("res://scripts/angler_network_observation.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var game: Node2D
var session: Node
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("NET_RULE_PASS | ",description)
	else: failed+=1; push_error("NET_RULE_FAIL | "+description)

func fresh() -> void:
	game.reset_world({"ruleset":"duel","challenge":true,"qte_grace":0.25,"water_strength":0})
	game.fish=Vector2(232,180); game.baits[0].active=true; game._enter_hook(0)
	game.qte_zone=0.40; game.qte_width=0.12
	session.qte_history.clear()
	session.remote_queue.clear()
	session.remote_held.clear()
	session.received_input_seq=0
	session.remote_role="fish"
	session.session_id="rules-test"
	session.round_id=1
	# Queue tests begin after a verified map handshake; adversarial pre-handshake gates have their own suite.
	session._select_map(); session.map_validated=true; session.is_host=true; session.status="playing"

func input_packet(sequence: int, tick_id: int, qte_id: int) -> Dictionary:
	return {"session":session.session_id,"round":1,"seq":sequence,"command":{"qte":true,"qte_at_age":0.0},"seen_tick":tick_id,"qte_id":qte_id,"events":[],"gesture":0}

func chunks(packet: Dictionary) -> Array[Dictionary]:
	var bytes := Protocol.encode(packet)
	var count := ceili(bytes.size()/800.0)
	var result: Array[Dictionary]=[]
	for index in count: result.append({"session":session.session_id,"round":1,"seq":packet.seq,"part":index,"count":count,"size":bytes.size(),"data":bytes.slice(index*800,(index+1)*800)})
	return result

func run() -> void:
	game=World.new(); session=Session.new(); session.game=game; root.add_child(session)
	fresh()
	game.qte_age=1.3; game.simulation_tick=70; session._remember_qte()
	game.qte_age=1.5; game.simulation_tick=82
	session.receive_input(input_packet(1,70,game.qte_id))
	var accepted: Dictionary=session._take_remote()
	check(accepted.qte and absf(accepted.qte_at_age-1.3)<0.001,"200 ms late input uses the host's recorded age, not client timing")
	game.advance_tick(accepted,{})
	check(game.hooked==game.HookState.FREE,"valid historical QTE succeeds even after the current pointer left green")
	check(absf(game.qte_result_progress-0.45)<0.001,"result animation freezes at the actually judged position")
	var consumed: Dictionary=session._take_remote()
	check(not consumed.qte,"held input never repeats a one-shot judgment")
	fresh(); game.qte_age=1.3; game.simulation_tick=70; session._remember_qte(); game.simulation_tick=86
	session.receive_input(input_packet(1,70,game.qte_id))
	check(not session._take_remote().qte,"timing older than the 250 ms history is rejected")
	fresh(); game.simulation_tick=70; session._remember_qte()
	session.receive_input(input_packet(1,71,game.qte_id))
	check(not session._take_remote().qte,"future tick claims are rejected")
	session.receive_input(input_packet(2,70,game.qte_id+1))
	check(not session._take_remote().qte,"QTE identifiers cannot target another check")
	fresh(); game.qte_zone=0.88; game.qte_width=0.10
	game.qte_age=2.2; game.simulation_tick=132; session._remember_qte()
	game.simulation_tick=145; game.qte_age=2.42
	session.receive_input(input_packet(1,132,game.qte_id))
	game.advance_tick(session._take_remote(),{})
	check(game.hooked==game.HookState.FREE,"grace keeps an outstanding QTE available for an in-range late judgment")
	fresh(); game.qte_age=2.41; game._step_qte(0,false)
	check(game.qte=="entry","online expiry allows a short delivery grace")
	game._step_qte(0.25,false)
	check(game.hooked==game.HookState.HOOKED,"unanswered online QTE still fails after grace")
	game.reset_world({}); game._enter_hook(0); game.qte_age=2.41; game._step_qte(0,false)
	check(game.hooked==game.HookState.HOOKED,"offline QTE retains its original timeout")
	fresh(); game._attach_hook(); game.rope_length=0; game._open_qte("slack"); game.qte_age=1.3
	game.simulation_tick=70; game.tension=0.1; session._remember_qte()
	session.receive_input(input_packet(1,70,game.qte_id)); game.advance_tick(session._take_remote(),{})
	check(game.hooked==game.HookState.HOOKED and game.qte=="","historical green does not bypass current high line tension")
	game.reset_world({"ruleset":"duel","challenge":true})
	var original: Dictionary=game.capture_snapshot()
	var invalid: Dictionary=game.capture_snapshot(); invalid.state.baits[0].grains[0].pos="bad"
	check(not game.restore_snapshot(invalid) and game.capture_snapshot()==original,"malformed nested food records cannot partially change the world")
	invalid=game.capture_snapshot(); invalid.state.qte="unknown"
	check(not game.restore_snapshot(invalid),"unknown state machine values are rejected")
	# Fragment transport uses the actual role wire contract; authority restore
	# validation above deliberately keeps the separate full replay snapshots.
	session.local_role="angler"; session.is_host=false
	var projected:=AnglerPublic.capture(game)
	var original_bytes:=var_to_bytes(original); var projected_bytes:=var_to_bytes(projected)
	var packet := {"kind":"state","v":Protocol.VERSION,"session":session.session_id,"round":1,"seq":10,"phase":"playing","countdown":0.0,"ack":5,"build":Protocol.BUILD,"map_source":session.map_source.duplicate(true),"map_ref":session.map_ref.duplicate(true),"snapshot":Protocol.pack_state(projected)}
	var pieces := chunks(packet)
	session.received_state_seq=-1
	for index in range(pieces.size()-1,0,-1): session._receive_chunk(pieces[index]); session._receive_chunk(pieces[index])
	check(session.received_state_seq==-1 and game.capture_snapshot()==original,"incomplete and duplicate fragments do not apply partial snapshots")
	session._receive_chunk(pieces[0])
	check(session.received_state_seq==10 and AnglerPublic.capture(game)==projected,"out-of-order fragments assemble one complete angler presentation state")
	for piece in pieces: session._receive_chunk(piece)
	check(session.received_state_seq==10,"a completed old snapshot cannot replay")
	packet.seq=11; packet.snapshot=Protocol.pack_state(projected)
	pieces=chunks(packet)
	for piece in pieces: session._receive_chunk(piece)
	check(session.received_state_seq==11,"a later full snapshot recovers without retransmitting earlier losses")
	var displayed: Node2D=session.display_world()
	var before: Dictionary=game.capture_snapshot()
	displayed.fish+=Vector2(15,0)
	check(game.capture_snapshot()==before,"presentation interpolation cannot mutate authority state")
	check(var_to_bytes(original)==original_bytes and var_to_bytes(projected)==projected_bytes,"fragment assembly and render sampling leave original authority and wire input snapshots byte-identical")
	check(Protocol.decode(PackedByteArray([1,2])).is_empty(),"truncated packet is rejected before Variant decoding")
	var too_deep: Variant=0
	for index in 14: too_deep=[too_deep]
	check(not Protocol.safe_values(too_deep),"nested packet depth is bounded")
	session.close()
	check(session.host_game("fish",80,{})==ERR_INVALID_PARAMETER and session.status=="failed","invalid room port fails cleanly before opening a socket")
	check(session.join_game("",24754)==ERR_INVALID_PARAMETER and session.status=="failed","empty server address gets a visible connection error")
	session.join_game("127.0.0.1",24754)
	session.started_at=session.now()-8001
	session.poll()
	check(session.status=="failed" and not session.active(),"connection timeout releases its socket and returns an actionable error")
	session.join_game("127.0.0.1",24754)
	session.peer.close()
	session.poll()
	check(not session.active() and game.match_paused,"transport failure stops the world and leaves no active connection")
	session.queue_free(); game.free(); await process_frame
	print("NETWORK_RULES_V012_TESTS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
