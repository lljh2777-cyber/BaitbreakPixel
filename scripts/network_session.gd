extends Node

signal changed
const Rules=preload("res://scripts/game_rules.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const AnglerNetworkObservation=preload("res://scripts/angler_network_observation.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
const FishNetworkObservation=preload("res://scripts/fish_network_observation.gd")
const QTE_HISTORY_TICKS := 15
const INPUT_LEASE_MS := 250
const SILENCE_MS := 5000
var game: Node2D
var peer: ENetMultiplayerPeer
var presentation := Presentation.new()
var status := "idle"
var message := ""
var is_host := false
var local_role := "fish"
var remote_role := "angler"
var remote_id := 0
var port := Protocol.DEFAULT_PORT
var address := "127.0.0.1"
var session_id := ""
var round_id := 0
var config: Dictionary={}
var local_ready := false
var remote_ready := false
var countdown := 0.0
var rtt_ms := 0
var input_seq := 0
var received_input_seq := 0
var applied_input_seq := 0
var state_seq := 0
var received_state_seq := -1
var bytes_sent := 0
var bytes_received := 0
var rejected_inputs := 0
var qte_accepted := 0
var remote_queue: Array[Dictionary]=[]
var remote_held: Dictionary={}
var qte_history: Dictionary={}
var effort_history: Dictionary={"fish":{},"angler":{}}
var last_rx := 0
var last_input_rx := 0
var started_at := 0
var last_ping := 0
var ping_tokens: Dictionary={}
var last_snapshot_tick := -1
var last_snapshot_ms := 0
var result_round := -1
var cues: Array[String]=[]
var effect_seq := 0
var received_effect_seq := 0
var gesture_id := 0
var gesture_open := false
var remote_gesture := 0
var closed_gesture := 0
var local_power := 0.35
var fragments: Dictionary={}

func now() -> int: return Time.get_ticks_msec()
func active() -> bool: return peer!=null
func other_role(role: String) -> String: return "angler" if role=="fish" else "fish"
func _phase(value: String, detail: String = "") -> void:
	print("NETWORK_PHASE | host=",is_host," | ",value," | ",detail)
	status=value
	message=detail
	changed.emit()

func host_game(role: String, requested_port: int, settings: Dictionary) -> Error:
	close()
	is_host=true
	local_role="angler" if role=="angler" else "fish"
	remote_role=other_role(local_role)
	port=requested_port
	if port<1024 or port>65535: _phase("failed","端口应为 1024—65535"); return ERR_INVALID_PARAMETER
	config={"rules":Rules.legacy(settings)}
	config.ruleset="duel"
	config.challenge=true
	config.qte_grace=0.25
	session_id=Crypto.new().generate_random_bytes(16).hex_encode()
	peer=ENetMultiplayerPeer.new()
	# Godot 4.7's explicit max_channels path also sets a tiny inbound bandwidth.
	# Leave channel negotiation at its default; our channels 0, 1 and 2 still exist.
	var error := peer.create_server(port,1)
	if error!=OK: peer=null; _phase("failed","无法创建房间，端口可能已被占用"); return error
	_bind_peer()
	_phase("waiting","房间已创建，等待另一位玩家")
	return OK

func join_game(host_address: String, requested_port: int) -> Error:
	close()
	is_host=false
	address=host_address.strip_edges()
	port=requested_port
	if address.is_empty() or address.length()>253 or port<1024 or port>65535:
		_phase("failed","请填写房主 IP 和有效端口"); return ERR_INVALID_PARAMETER
	peer=ENetMultiplayerPeer.new()
	var error := peer.create_client(address,port)
	if error!=OK: peer=null; _phase("failed","无法连接这个地址"); return error
	_bind_peer()
	_phase("connecting","正在连接房主…")
	return OK

func _bind_peer() -> void:
	started_at=now()
	last_rx=started_at
	last_ping=started_at
	peer.peer_connected.connect(_connected)
	peer.peer_disconnected.connect(_disconnected)

func _connected(id: int) -> void:
	last_rx=now()
	if is_host:
		if remote_id!=0: peer.disconnect_peer(id); return
		remote_id=id
	else:
		if id!=1: return
		remote_id=1
		_send({"kind":"hello","build":Protocol.BUILD},true,2)

func _disconnected(id: int) -> void:
	if id==remote_id: _finish_disconnect.call_deferred(peer)

func _finish_disconnect(disconnected_peer: ENetMultiplayerPeer) -> void:
	if peer==disconnected_peer: fail("另一位玩家已离开，本局已停止")

func close(notify_peer: bool = false) -> void:
	if peer!=null:
		if notify_peer and remote_id!=0 and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
			_send({"kind":"leave","session":session_id},true,2)
			peer.host.flush()
		peer.close()
	peer=null
	remote_id=0
	status="idle"
	message=""
	session_id=""
	round_id=0
	local_ready=false
	remote_ready=false
	remote_queue.clear()
	remote_held.clear()
	qte_history.clear()
	effort_history={"fish":{},"angler":{}}
	ping_tokens.clear()
	fragments.clear()
	presentation.clear()
	gesture_id=0
	gesture_open=false
	remote_gesture=0
	closed_gesture=0
	result_round=-1

func fail(detail: String) -> void:
	print("NETWORK_STOP | host=",is_host," | ",detail)
	if peer!=null: peer.close(); peer=null
	remote_queue.clear()
	remote_held.clear()
	if is_instance_valid(game): game.match_paused=true
	_phase("failed",detail)

func poll() -> void:
	if peer==null: return
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		fail("连接已关闭，请确认房主和地址后重新加入"); return
	peer.poll()
	if peer==null: return
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		fail("连接已关闭，请确认房主和地址后重新加入"); return
	for packet_index in 128:
		if peer==null or peer.get_available_packet_count()==0: break
		var sender := peer.get_packet_peer()
		var data := peer.get_packet()
		bytes_received+=data.size()
		if sender!=remote_id: continue
		var packet := Protocol.decode(data)
		if packet.is_empty(): continue
		_handle(packet)
	if peer==null: return
	if not is_host and status=="connecting" and now()-started_at>8000:
		fail("连接超时：确认房主已开房、IP 和端口相同"); return
	if remote_id!=0 and now()-last_rx>SILENCE_MS:
		fail("连接中断，本局已停止；返回标题后可重新连接"); return
	if remote_id!=0 and now()-last_ping>=1000:
		last_ping=now()
		ping_tokens[last_ping]=true
		for token in ping_tokens.keys():
			if now()-int(token)>SILENCE_MS: ping_tokens.erase(token)
		_send({"kind":"ping","token":last_ping},false,0)

func _send(packet: Dictionary, reliable: bool, channel: int) -> void:
	if peer==null or remote_id==0 or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	packet.v=Protocol.VERSION
	var data := Protocol.encode(packet)
	if data.is_empty(): fail("同步数据超出本版限制，本局已停止"); return
	peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.transfer_channel=channel
	peer.set_target_peer(remote_id)
	if peer.put_packet(data)==OK:
		bytes_sent+=data.size()

func _handle(packet: Dictionary) -> void:
	if packet.get("v")!=Protocol.VERSION:
		fail("联机协议不兼容，请双方使用 "+Protocol.BUILD+" 版"); return
	var kind: String=packet.get("kind","") if packet.get("kind","") is String else ""
	last_rx=now()
	if kind=="ping" and packet.get("token") is int:
		_send({"kind":"pong","token":packet.token},false,0); return
	if kind=="pong" and ping_tokens.has(packet.get("token")):
		rtt_ms=clampi(now()-int(packet.token),0,SILENCE_MS)
		ping_tokens.erase(packet.token); return
	if kind=="hello" and is_host and status=="waiting":
		if packet.get("build")!=Protocol.BUILD:
			_send({"kind":"reject","reason":"版本不同，请双方使用 "+Protocol.BUILD+" 版"},true,2); return
		_send({"kind":"welcome","session":session_id,"role":remote_role,"config":_peer_config(),"build":Protocol.BUILD,"ready":local_ready},true,2)
		message="玩家已连接，双方准备后开始"
		changed.emit(); return
	if kind=="reject" and not is_host: fail("版本不同，请双方使用 "+Protocol.BUILD+" 版"); return
	if kind=="welcome" and not is_host and status=="connecting":
		if packet.get("build")!=Protocol.BUILD or not packet.get("role") in ["fish","angler"] or not packet.get("config") is Dictionary or not packet.get("session") is String: fail("房间信息无效"); return
		session_id=packet.session
		if not Rules.valid(packet.config.get("rules")) or (packet.role=="fish" and not FishNetworkObservation.config_valid(packet.config)): fail("房主玩法规则无效"); return
		config=packet.config
		local_role=packet.role
		remote_role=other_role(local_role)
		remote_ready=packet.get("ready",false)==true
		_phase("waiting","已进入房间，双方准备后开始"); return
	if packet.get("session")!=session_id or session_id.is_empty(): return
	match kind:
		"chunk":
			if not is_host: _receive_chunk(packet)
		"leave": fail("另一位玩家已离开，本局已停止")
		"ready":
			if not status in ["waiting","finished"] or packet.get("round")!=round_id or not packet.get("value") is bool: return
			remote_ready=packet.value
			changed.emit()
			if is_host and local_ready and remote_ready: _start_round()
		"start":
			if not is_host: _receive_start(packet)
		"start_ack":
			if is_host and status=="starting" and packet.get("round")==round_id:
				countdown=3.0
				_phase("countdown")
				_send_state(true)
		"input":
			if is_host and status=="playing": receive_input(packet)
		"state":
			if not is_host: _receive_state(packet)
		"effects":
			if is_host or packet.get("round")!=round_id or not packet.get("seq") is int or packet.seq<=received_effect_seq: return
			received_effect_seq=packet.seq
			if packet.get("cues") is Array and packet.cues.size()<=16:
				for cue in packet.cues:
					if cue in ["bite","eat","warn","splash","success","fail","break","tap","qte_fish","qte_angler","effort_good_fish","effort_bad_fish","effort_good_angler","effort_bad_angler"]: game.play_feedback(cue)

func set_ready(value: bool = true) -> void:
	if not active() or remote_id==0 or not status in ["waiting","finished"]: return
	local_ready=value
	_send({"kind":"ready","session":session_id,"round":round_id,"value":value},true,2)
	changed.emit()
	if is_host and local_ready and remote_ready: _start_round()

func _reset_round() -> void:
	local_ready=false
	remote_ready=false
	input_seq=0
	received_input_seq=0
	applied_input_seq=0
	state_seq=0
	received_state_seq=-1
	remote_queue.clear()
	remote_held.clear()
	qte_history.clear()
	effort_history={"fish":{},"angler":{}}
	cues.clear()
	effect_seq=0
	received_effect_seq=0
	gesture_id=0
	gesture_open=false
	remote_gesture=0
	closed_gesture=0
	local_power=float(config.get("rules",Rules.defaults()).suction_initial)
	last_input_rx=now()
	last_snapshot_tick=-1
	presentation.clear()
	fragments.clear()

func _start_round() -> void:
	round_id+=1
	_reset_round()
	config.seed=Time.get_ticks_usec()
	game.start_shared_session(local_role,config)
	_phase("starting","等待对方载入池塘…")
	var packet := _state_packet("start")
	packet.config=_peer_config()
	packet.role=remote_role
	_send(packet,true,2)

func _receive_start(packet: Dictionary) -> void:
	if not packet.get("round") is int or packet.round<=round_id or not packet.get("seq") is int or packet.seq<0 or not packet.get("config") is Dictionary or packet.get("role")!=local_role: return
	if not packet.get("snapshot") is Dictionary: return
	if not Rules.valid(packet.config.get("rules")) or (local_role=="fish" and not FishNetworkObservation.config_valid(packet.config)): fail("开局规则无效"); return
	var snapshot := Protocol.unpack_state(packet.snapshot)
	if snapshot.is_empty() or not (FishNetworkObservation.valid(game,snapshot) if local_role=="fish" else AnglerNetworkObservation.valid(game,snapshot)): fail("初始世界数据无效"); return
	round_id=packet.round
	_reset_round()
	config=packet.config
	game.start_shared_session(local_role,config)
	if not _apply_remote_state(snapshot): fail("无法恢复初始世界"); return
	presentation.accept(snapshot,now()/1000.0,local_role)
	received_state_seq=packet.seq
	countdown=3.0
	_phase("starting","等待房主开始…")
	_send({"kind":"start_ack","session":session_id,"round":round_id},true,2)

func tick(delta: float, local_command: Dictionary) -> void:
	if peer==null: return
	if status in ["starting","countdown"]:
		if is_host and status=="countdown":
			countdown=maxf(0,countdown-delta)
			if countdown<=0: _phase("playing"); _remember_qte(); _send_state(true)
			elif now()-last_snapshot_ms>=100: _send_state(false)
		return
	if status!="playing": return
	var local := Protocol.input(local_role,local_command)
	if is_host:
		var before := _check_identity()
		var remote := _take_remote()
		game.advance_tick(local if local_role=="fish" else remote,local if local_role=="angler" else remote)
		_remember_qte()
		if not cues.is_empty():
			effect_seq+=1
			_send({"kind":"effects","session":session_id,"round":round_id,"seq":effect_seq,"cues":cues.duplicate()},true,2)
			cues.clear()
		if game.match_over:
			_phase("finished")
			_send_state(true)
		elif before!=_check_identity(): _send_state(true)
		elif not game.qte.is_empty() or game.qte_result_age>0 or game.effort_checks.fish.active or game.effort_checks.angler.active or game.effort_checks.fish.effect_age>0 or game.effort_checks.angler.effect_age>0 or not game.untangle_phase.is_empty() or game.net_state in ["prepare","warning","sweep","caught"]:
			# A missing fragment must not hide a short skill window. While a check
			# is active, send complete reliable states at 10 Hz, with interpolation.
			if game.simulation_tick-last_snapshot_tick>=6: _send_state(true)
		elif game.simulation_tick-last_snapshot_tick>=2: _send_state(false)
	else:
		input_seq+=1
		var displayed := presentation.sample(now()/1000.0)
		var check: Dictionary=displayed.skill_check(local_role)
		var events := _tag_events(local)
		local.net_events=[]
		_send({"kind":"input","session":session_id,"round":round_id,"seq":input_seq,"command":local,
			"seen_tick":displayed.simulation_tick,"qte_id":check.id if check.kind in ["effort","untangle"] and check.active else displayed.qte_id,"check_kind":"effort" if check.kind in ["effort","untangle"] and check.active else "regular","events":events,"gesture":gesture_id},true,1)

func _check_identity() -> Array:
	return [game.bite_feedback_age>0,game.qte_id,game.qte,game.qte_result_age>0,game.effort_checks.fish.id,game.effort_checks.fish.active,game.effort_checks.fish.effect_age>0,game.effort_checks.angler.id,game.effort_checks.angler.active,game.effort_checks.angler.effect_age>0,game.net_state,game.net_action.observing,game.net_action.has_a,game.net_capture>0,game.untangle_phase,game.wraps.size()]

func _tag_events(command: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if local_role!="angler": return result
	for event in command.net_events:
		# Reliable, sequenced discrete actions. A click release is not a cancellation.
		gesture_id+=1
		var tagged: Dictionary=event.duplicate(true)
		tagged.gesture=gesture_id
		result.append(tagged)
	return result

func receive_input(packet: Dictionary) -> void:
	if packet.get("session")!=session_id or packet.get("round")!=round_id or not packet.get("seq") is int or packet.seq<=received_input_seq:
		rejected_inputs+=1; return
	if not packet.get("command") is Dictionary or not packet.get("events") is Array or packet.events.size()>Protocol.MAX_EVENTS or not packet.get("seen_tick") is int or not packet.get("qte_id") is int or not packet.get("gesture") is int: return
	if remote_queue.size()>=120: fail("输入积压过多，请检查连接后重新开局"); return
	var command := Protocol.input(remote_role,packet.command)
	command.net_events=[]
	if remote_role=="angler":
		for event in packet.events:
			if not event is Dictionary or not event.get("gesture") is int: continue
			var gid: int=event.gesture
			if gid<=remote_gesture: continue
			if event.get("kind") in ["toggle","cancel","suspend"]:
				command.net_events.append({"kind":event.kind})
			elif event.get("kind")=="point" and event.get("point") is Vector2 and event.point.is_finite():
				command.net_events.append({"kind":"point","point":event.point.clamp(Vector2.ZERO,game.Layout.SIZE)})
			else: continue
			remote_gesture=gid
	received_input_seq=packet.seq
	last_input_rx=now()
	remote_queue.append({"command":command,"seq":packet.seq,"seen_tick":packet.seen_tick,"qte_id":packet.qte_id,"check_kind":packet.get("check_kind","regular")})

func _take_remote() -> Dictionary:
	if now()-last_input_rx>INPUT_LEASE_MS:
		remote_queue.clear()
		remote_held=Protocol.neutral(remote_role,game)
		if remote_role=="angler": remote_held.net_events=[{"kind":"suspend"}]
		return remote_held
	var combined := remote_held.duplicate(true)
	combined.qte=false
	combined.qte_at_age=-1.0
	combined.home=false
	combined.deploy=false
	combined.untangle=false
	combined.qte_condition_valid=true
	combined.net_events=[]
	for index in mini(8,remote_queue.size()):
		var entry: Dictionary=remote_queue.pop_front()
		var cmd: Dictionary=entry.command
		var events: Array=combined.net_events
		events.append_array(cmd.get("net_events",[]))
		var pressed: bool=combined.qte
		var age: float=combined.qte_at_age
		var condition_valid: bool=combined.qte_condition_valid
		if cmd.get("qte",false) and _valid_qte(entry):
			var candidate_age: float=effort_history[remote_role][entry.seen_tick].age if entry.get("check_kind")=="effort" else (qte_history[entry.seen_tick].age if not game.qte.is_empty() else -1.0)
			var lead: float=game.effort_checks[remote_role].lead if entry.get("check_kind")=="effort" else game.qte_timing.lead
			# A consumed warning edge must not swallow a later visible press in
			# this transport batch. The first visible judgment still owns it.
			if not pressed or (age>=0 and age<lead and candidate_age>=lead):
				pressed=true
				age=candidate_age
				qte_accepted+=1
				if entry.get("check_kind")=="effort": condition_valid=effort_history[remote_role][entry.seen_tick].valid
		var home: bool=combined.home or cmd.get("home",false)
		var deploy: bool=combined.deploy or cmd.get("deploy",false)
		var untangle: bool=combined.untangle or cmd.get("untangle",false)
		combined=cmd.duplicate(true)
		combined.qte=pressed
		combined.qte_at_age=age
		combined.home=home
		combined.deploy=deploy
		combined.untangle=untangle
		combined.qte_condition_valid=condition_valid
		combined.net_events=events
		applied_input_seq=entry.seq
	remote_held=combined.duplicate(true)
	return combined

func _remember_qte() -> void:
	for role in ["fish","angler"]:
		var state: Dictionary=game.effort_checks[role]
		effort_history[role][game.simulation_tick]={"id":state.id,"kind":state.kind,"age":state.age,"active":state.active,"valid":state.kind!="untangle" or game.untangle_tension_valid()}
		for tick_id in effort_history[role].keys():
			if tick_id<game.simulation_tick-QTE_HISTORY_TICKS: effort_history[role].erase(tick_id)
	qte_history[game.simulation_tick]={"id":game.qte_id,"kind":game.qte,"age":game.qte_age,"valid":game.qte!="slack" or game.tension<game.rule("tension_low")}
	for tick_id in qte_history.keys():
		if tick_id<game.simulation_tick-QTE_HISTORY_TICKS: qte_history.erase(tick_id)

func _valid_qte(entry: Dictionary) -> bool:
	if entry.get("check_kind","regular")=="effort":
		var state: Dictionary=game.effort_checks[remote_role]
		if not state.active or entry.qte_id!=state.id or not effort_history[remote_role].has(entry.seen_tick): return false
		if remote_role=="fish" and not game.qte.is_empty(): return false
		if entry.seen_tick>game.simulation_tick or game.simulation_tick-entry.seen_tick>QTE_HISTORY_TICKS: return false
		var past: Dictionary=effort_history[remote_role][entry.seen_tick]
		return past.id==state.id and past.active and past.kind==state.kind
	if entry.get("check_kind","regular")!="regular" or remote_role!="fish": return false
	if entry.qte_id!=game.qte_id or not qte_history.has(entry.seen_tick): return false
	if entry.seen_tick>game.simulation_tick or game.simulation_tick-entry.seen_tick>QTE_HISTORY_TICKS: return false
	var past: Dictionary=qte_history[entry.seen_tick]
	return past.id==game.qte_id and past.kind==game.qte and past.valid

func _peer_config() -> Dictionary:
	return FishNetworkObservation.public_config(config) if remote_role=="fish" else config.duplicate(true)

func _apply_remote_state(snapshot: Dictionary) -> bool:
	return FishNetworkObservation.apply(game,snapshot) if local_role=="fish" else AnglerNetworkObservation.apply(game,snapshot)

func _state_packet(kind: String) -> Dictionary:
	state_seq+=1
	var snapshot: Dictionary=FishNetworkObservation.capture(game) if remote_role=="fish" else AnglerNetworkObservation.capture(game)
	return {"kind":kind,"session":session_id,"round":round_id,"seq":state_seq,"snapshot":Protocol.pack_state(snapshot),
		"phase":status,"countdown":countdown,"ack":applied_input_seq}

func _send_state(reliable: bool) -> void:
	last_snapshot_tick=game.simulation_tick
	last_snapshot_ms=now()
	var packet := _state_packet("state")
	if reliable:
		_send(packet,true,2)
		return
	packet.v=Protocol.VERSION
	var data := Protocol.encode(packet)
	var count := ceili(data.size()/800.0)
	for part in count:
		_send({"kind":"chunk","session":session_id,"round":round_id,"seq":state_seq,"part":part,"count":count,"size":data.size(),"data":data.slice(part*800,(part+1)*800)},false,0)
	if peer!=null: peer.host.flush()

func _receive_chunk(packet: Dictionary) -> void:
	if packet.get("round")!=round_id or not packet.get("seq") is int or packet.seq<=received_state_seq: return
	if not packet.get("part") is int or not packet.get("count") is int or not packet.get("size") is int or not packet.get("data") is PackedByteArray: return
	if packet.count<1 or packet.count>256 or packet.part<0 or packet.part>=packet.count or packet.size<1 or packet.size>Protocol.MAX_PACKET or packet.data.size()>800: return
	for sequence in fragments.keys():
		if sequence<=received_state_seq or now()-fragments[sequence].time>300: fragments.erase(sequence)
	if not fragments.has(packet.seq):
		if fragments.size()>=8: fragments.erase(fragments.keys()[0])
		var parts: Array=[]
		parts.resize(packet.count)
		fragments[packet.seq]={"parts":parts,"received":0,"time":now(),"size":packet.size}
	var fragment: Dictionary=fragments[packet.seq]
	if fragment.parts.size()!=packet.count or fragment.size!=packet.size: return
	if fragment.parts[packet.part]!=null: return
	fragment.parts[packet.part]=packet.data
	fragment.received+=1
	if fragment.received!=packet.count: return
	var full := PackedByteArray()
	for part in fragment.parts: full.append_array(part)
	fragments.erase(packet.seq)
	if full.size()!=packet.size: return
	var decoded := Protocol.decode(full)
	if decoded.get("kind")=="state": _handle(decoded)

func _receive_state(packet: Dictionary) -> void:
	if packet.get("round")!=round_id or not packet.get("seq") is int or packet.seq<=received_state_seq or not packet.get("snapshot") is Dictionary: return
	if not packet.get("phase") in ["countdown","playing","finished"]: return
	var snapshot := Protocol.unpack_state(packet.snapshot)
	if snapshot.is_empty() or not _apply_remote_state(snapshot): fail("收到的世界状态无效，本局已停止"); return
	received_state_seq=packet.seq
	applied_input_seq=int(packet.get("ack",0))
	countdown=clampf(float(packet.get("countdown",0)),0,3)
	presentation.accept(snapshot,now()/1000.0,local_role)
	if status!=packet.phase: _phase(packet.phase)
	if game.match_over and result_round!=round_id:
		result_round=round_id
		game._present_result(game.winner_role,game.reason)

func remember_feedback(cue: String) -> void:
	if active() and is_host and status=="playing" and cues.size()<16: cues.append(cue)

func display_world() -> Node2D:
	return presentation.sample(now()/1000.0) if not is_host and not presentation.current.is_empty() else game

func caption() -> String:
	if status=="failed": return message
	if status in ["starting","countdown"]: return "即将开始 %d" % ceili(countdown) if status=="countdown" else "双方载入中…"
	if status=="playing": return "%s · %d ms%s" % ["房主" if is_host else "联机",rtt_ms," · 连接不稳" if now()-last_rx>500 else ""]
	return message

func _exit_tree() -> void:
	close(true)
	presentation.dispose()
