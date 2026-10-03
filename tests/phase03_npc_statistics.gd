extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Session=preload("res://scripts/network_session.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const WARMUP_TICKS:=240
const MEASURED_TICKS:=1200
const SEED_VALUE:=83149
const OUTPUT:="res://artifacts/phase03-npc-statistics.json"
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_STATISTICS_FAIL | "+label)

func summary(values: Array) -> Dictionary:
	var sorted:=values.duplicate(); sorted.sort()
	var total:=0.0
	for value in values: total+=float(value)
	return {"samples":values.size(),"min":sorted[0],"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.95)-1)],"max":sorted[-1],"mean":total/values.size()}

func commands(role: String, tick: int) -> Array:
	var direction:=Vector2.RIGHT.rotated(tick*0.008)
	if role=="fish": return [{"move":direction,"aim":direction,"suck":tick%120<35,"dash":tick%180<15},{"target":Vector2(700,250)}]
	return [{},{"walk":float((tick/120)%3-1),"reel":tick%240<80,"release":tick%240>=160,"deploy":tick==0,"target":Vector2(600+sin(tick*0.01)*100,210)}]

func wire_metrics(world: Node2D, session: Node) -> Dictionary:
	# Use the production role adapter, compression and state-packet envelope.
	var packet: Dictionary=session._state_packet("state")
	packet.v=Protocol.VERSION
	var encoded:=Protocol.encode(packet)
	var unpacked:=Protocol.unpack_state(packet.snapshot)
	check(not encoded.is_empty() and not unpacked.is_empty(),"production role payload round-trips within protocol limits")
	check(unpacked.state.npc_fishes.size()==world.npc_fishes.size(),"measured payload includes requested NPC count")
	var chunks:=ceili(encoded.size()/800.0)
	var datagram_bytes:=0
	for part in chunks:
		var envelope: Dictionary={"kind":"chunk","session":session.session_id,"round":session.round_id,"seq":session.state_seq,"part":part,"count":chunks,"size":encoded.size(),"data":encoded.slice(part*800,(part+1)*800),"v":Protocol.VERSION}
		datagram_bytes+=Protocol.encode(envelope).size()
	return {"tick":world.simulation_tick,"authority_snapshot_bytes":var_to_bytes(world.capture_snapshot()).size(),
		"role_snapshot_bytes":int(packet.snapshot.size),"compressed_state_bytes":packet.snapshot.data.size(),
		"encoded_state_packet_bytes":encoded.size(),"chunked_application_payload_bytes":datagram_bytes,"chunk_count":chunks}

func measure(role: String, count: int) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":SEED_VALUE,"npc_count":count,"ruleset":"duel","rules":{"timer_enabled":false,"hunger_enabled":false}})
	var session:=Session.new()
	session.game=world; session.remote_role=role; session.local_role="angler" if role=="fish" else "fish"
	session.session_id="phase03-measurement"; session.round_id=1; session.status="playing"
	for tick in WARMUP_TICKS:
		var input:=commands(role,tick)
		world.advance_tick(input[0],input[1])
	var timings: Array=[]; var payload_samples: Array=[]
	for tick in MEASURED_TICKS:
		var input:=commands(role,tick+WARMUP_TICKS)
		var start:=Time.get_ticks_usec()
		world.advance_tick(input[0],input[1])
		timings.append(Time.get_ticks_usec()-start)
		if tick%60==59: payload_samples.append(wire_metrics(world,session))
	check(not world.match_over and world.simulation_tick==WARMUP_TICKS+MEASURED_TICKS,"timing measures live simulation ticks, never frozen/ended state")
	var metrics: Dictionary={}
	for key: String in ["authority_snapshot_bytes","role_snapshot_bytes","compressed_state_bytes","encoded_state_packet_bytes","chunked_application_payload_bytes","chunk_count"]:
		var samples: Array=[]
		for payload: Dictionary in payload_samples: samples.append(payload[key])
		metrics[key]=summary(samples)
	var result: Dictionary={"role":role,"npc_count":count,"seed":SEED_VALUE,"warmup_ticks":WARMUP_TICKS,"measured_ticks":MEASURED_TICKS,
		"simulation_tick_us":summary(timings),"payloads":metrics,"payload_samples":payload_samples,"simulation_tick_us_samples":timings}
	check(result.simulation_tick_us.mean>0 and result.simulation_tick_us.samples==MEASURED_TICKS,"measured tick timings are nonempty and real")
	print("NPC_PERFORMANCE | role=%s | npc_count=%d | tick_mean_us=%.3f | tick_p95_us=%d | authority_bytes_mean=%.1f | role_bytes_mean=%.1f | deflate_bytes_mean=%.1f | packet_bytes_mean=%.1f | chunked_bytes_mean=%.1f" % [role,count,result.simulation_tick_us.mean,result.simulation_tick_us.p95,metrics.authority_snapshot_bytes.mean,metrics.role_snapshot_bytes.mean,metrics.compressed_state_bytes.mean,metrics.encoded_state_packet_bytes.mean,metrics.chunked_application_payload_bytes.mean])
	session.presentation.dispose(); session.free(); world.free()
	return result

func stats_checks() -> void:
	var zero:=World.new(); var six:=World.new()
	for world in [zero,six]:
		world.reset_world({"seed":2518,"npc_count":0 if world==zero else 6,"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
		world.fish=Vector2(650,200); world.fish_before=world.fish; world.aim=Vector2.RIGHT
		for bait: Dictionary in world.baits:
			bait.active=false; bait.hook=false
			for grain: Dictionary in bait.grains: grain.eaten=true
		for index in 8:
			var grain: Dictionary=world.baits[0].grains[index]
			grain.eaten=false; grain.free=true; grain.pos=world.mouth()+Vector2(index+1,0); grain.points=1.0
	for tick in 120:
		for world in [zero,six]: world.advance_tick({"suck":tick>=70 and tick<95},{})
		check(zero.round_stats==six.round_stats,"all existing statistics are exactly NPC-count independent tick="+str(tick))
	check(zero.score==8 and zero.round_stats.food_consumed==8 and zero.round_stats.bite_successes>0,"stats equivalence includes actual automatic food intake")
	check(zero.round_stats.feeding_attempts>0 and zero.round_stats.feeding_aborts>0,"stats equivalence covers held-suck attempts and aborts")
	check(zero.Stats.valid(zero.round_stats) and six.Stats.valid(six.round_stats),"statistics schema remains unchanged and valid")
	zero.free(); six.free()

func _initialize() -> void:
	stats_checks()
	var runs: Array=[]
	for role: String in ["fish","angler"]:
		for count: int in [0,3,6]: runs.append(measure(role,count))
	for index in [0,3]:
		check(runs[index].payloads.authority_snapshot_bytes.mean<runs[index+1].payloads.authority_snapshot_bytes.mean and runs[index+1].payloads.authority_snapshot_bytes.mean<runs[index+2].payloads.authority_snapshot_bytes.mean,"authority snapshot measurements capture 0/3/6 incremental NPC cost")
		check(runs[index].payloads.role_snapshot_bytes.mean<runs[index+1].payloads.role_snapshot_bytes.mean and runs[index+1].payloads.role_snapshot_bytes.mean<runs[index+2].payloads.role_snapshot_bytes.mean,"role wire measurements capture 0/3/6 public NPC cost")
	var report: Dictionary={"format":"phase03-npc-performance-v1","timestamp_utc":Time.get_datetime_string_from_system(true),
		"engine":Engine.get_version_info().string,"os":OS.get_name(),"processor":OS.get_processor_name(),"processor_count":OS.get_processor_count(),
		"authority_schema":World.Snapshot.SCHEMA,"protocol_build":Protocol.BUILD,"fixed_timestep_seconds":World.TICK_SECONDS,
		"method":"Single-threaded headless live authority; per configuration 240 warmup + 1200 timed ticks; commands prepared before timer; serialization excluded from tick timing; production role state packet sampled every 60 measured ticks. Packet bytes include protocol envelope; chunked bytes include 800-byte fragmentation envelopes but exclude ENet/IP/UDP headers. Wall-time samples are machine-specific, not a comparative performance guarantee.",
		"frame_time":"Measured separately by renderer/native suite; not claimed by this headless suite.","runs":runs}
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	check(file!=null,"performance artifact is writable")
	if file!=null: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("NPC_PERFORMANCE_ARTIFACT | "+OUTPUT)
	print("PHASE03_NPC_STATISTICS_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
