extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Session=preload("res://scripts/network_session.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const WARMUP_TICKS:=240
const MEASURED_TICKS:=1200
const SEED_VALUE:=83149
const NPC_STAT_FIELDS: Array[String]=["npc_food_consumed","npc_food_by_type","npc_feeding_events","player_npc_food_contests","npc_target_switches"]
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
	check(not unpacked.state.has("npc_foraging_enabled"),"private foraging configuration is absent from measured role payload")
	for key: String in NPC_STAT_FIELDS:
		check(not unpacked.state.round_stats.has(key),"role payload omits private NPC aggregate: "+key)
	var chunks:=ceili(encoded.size()/800.0)
	var datagram_bytes:=0
	for part in chunks:
		var envelope: Dictionary={"kind":"chunk","session":session.session_id,"round":session.round_id,"seq":session.state_seq,"part":part,"count":chunks,"size":encoded.size(),"data":encoded.slice(part*800,(part+1)*800),"v":Protocol.VERSION}
		datagram_bytes+=Protocol.encode(envelope).size()
	return {"tick":world.simulation_tick,"authority_snapshot_bytes":var_to_bytes(world.capture_snapshot()).size(),
		"role_snapshot_bytes":int(packet.snapshot.size),"compressed_state_bytes":packet.snapshot.data.size(),
		"encoded_state_packet_bytes":encoded.size(),"chunked_application_payload_bytes":datagram_bytes,"chunk_count":chunks}

func measure(role: String, count: int, foraging_enabled: bool=true) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":SEED_VALUE,"npc_count":count,"npc_foraging_enabled":foraging_enabled,"ruleset":"duel","rules":{"timer_enabled":false,"hunger_enabled":false}})
	var session:=Session.new()
	session.game=world; session.remote_role=role; session.local_role="angler" if role=="fish" else "fish"
	session.session_id="phase03-measurement"; session.round_id=1; session.status="playing"
	session._select_map(); session.map_validated=true; session.is_host=true # Measure the complete current packet identity.
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
		"npc_foraging_enabled":world.npc_foraging_enabled,"npc_food_consumed":world.round_stats.npc_food_consumed,"npc_feeding_events":world.round_stats.npc_feeding_events,
		"simulation_tick_us":summary(timings),"payloads":metrics,"payload_samples":payload_samples,"simulation_tick_us_samples":timings}
	check(result.simulation_tick_us.mean>0 and result.simulation_tick_us.samples==MEASURED_TICKS,"measured tick timings are nonempty and real")
	print("NPC_PERFORMANCE | role=%s | npc_count=%d | foraging=%s | tick_mean_us=%.3f | tick_p95_us=%d | authority_bytes_mean=%.1f | role_bytes_mean=%.1f | deflate_bytes_mean=%.1f | packet_bytes_mean=%.1f | chunked_bytes_mean=%.1f" % [role,count,str(foraging_enabled),result.simulation_tick_us.mean,result.simulation_tick_us.p95,metrics.authority_snapshot_bytes.mean,metrics.role_snapshot_bytes.mean,metrics.compressed_state_bytes.mean,metrics.encoded_state_packet_bytes.mean,metrics.chunked_application_payload_bytes.mean])
	session.presentation.dispose(); session.free(); world.free()
	return result

func stats_checks() -> void:
	var zero:=World.new(); var six:=World.new()
	for world in [zero,six]:
		world.reset_world({"npc_foraging_enabled":false,"seed":2518,"npc_count":0 if world==zero else 6,"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
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
	check(zero.Stats.valid(zero.round_stats) and six.Stats.valid(six.round_stats),"extended statistics schema preserves valid legacy counters")
	zero.free(); six.free()

func foraging_stats_checks() -> void:
	for kind: String in ["cluster","worm","chunk"]:
		var world:=World.new()
		world.reset_world({"seed":816,"npc_count":1,"ruleset":"duel","rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0}})
		world.fish=Vector2(930,300); world.fish_before=world.fish
		var npc: Dictionary=world.npc_fishes[0]
		npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
		npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0
		for bait: Dictionary in world.baits:
			bait.active=false
			for grain: Dictionary in bait.grains: grain.eaten=true
		var food: Dictionary=world.baits[0].grains[0]
		food.eaten=false; food.free=true; food.pos=npc.position+Vector2(12,0); food.points=1.0; food.visual_kind=kind
		check(world.round_stats.npc_food_consumed==0.0 and world.round_stats.npc_feeding_events==0 and world.round_stats.npc_target_switches==0,"fresh NPC counters are zero: "+kind)
		for tick in 120:
			world.advance_tick({}, {})
			if food.eaten: break
		check(food.eaten and world.round_stats.npc_food_consumed==1.0,"NPC intake records real consumed food exactly once: "+kind)
		check(world.round_stats.npc_food_by_type[kind]==1.0 and world.round_stats.npc_feeding_events==1,"NPC archetype amount and feeding event reflect real intake: "+kind)
		for other: String in world.Stats.type_totals():
			if other!=kind: check(world.round_stats.npc_food_by_type[other]==0.0,"NPC intake cannot credit a different archetype")
		check(world.round_stats.npc_target_switches>=1 and world.round_stats.player_npc_food_contests==0,"target acquisition is counted without inventing a player contest")
		check(world.score==0 and world.round_stats.food_consumed==0 and world.round_stats.bite_successes==0 and world.round_stats.suck_successes==0 and world.hook_count==0,"NPC intake does not increment player nutrition, bite, suction or hook statistics")
		var credited: float=world.round_stats.npc_food_consumed
		for tick in 30: world.advance_tick({}, {})
		check(world.round_stats.npc_food_consumed==credited and world.round_stats.npc_feeding_events==1,"already consumed grain cannot be credited a second time")
		check(world.Stats.valid(world.round_stats),"live NPC statistics retain strict schema validity")
		world.free()
	var reference: Dictionary=World.Stats.fresh()
	for key: String in NPC_STAT_FIELDS:
		var missing:=reference.duplicate(true); missing.erase(key)
		check(not World.Stats.valid(missing),"authority statistics require private aggregate: "+key)
	for key: String in ["npc_food_consumed","npc_feeding_events","player_npc_food_contests","npc_target_switches"]:
		for invalid in [-1,NAN,INF,"0",null]:
			var changed:=reference.duplicate(true); changed[key]=invalid
			check(not World.Stats.valid(changed),"reject malformed private aggregate "+key+"="+str(invalid))
	for invalid in [{},{"cluster":-1.0,"worm":0.0,"chunk":0.0},{"cluster":NAN,"worm":0.0,"chunk":0.0},{"cluster":0,"worm":0.0,"chunk":0.0},[]]:
		var changed:=reference.duplicate(true); changed.npc_food_by_type=invalid
		check(not World.Stats.valid(changed),"reject malformed NPC archetype totals")

func _initialize() -> void:
	stats_checks(); foraging_stats_checks()
	var runs: Array=[]; var passive_runs: Array=[]
	for role: String in ["fish","angler"]:
		for count: int in [0,3,6]: passive_runs.append(measure(role,count,false))
		for count: int in [0,3,6]: runs.append(measure(role,count))
	for index in [0,3]:
		check(passive_runs[index].payloads.authority_snapshot_bytes.mean<passive_runs[index+1].payloads.authority_snapshot_bytes.mean and passive_runs[index+1].payloads.authority_snapshot_bytes.mean<passive_runs[index+2].payloads.authority_snapshot_bytes.mean,"passive-control authority measurements preserve 0/3/6 incremental NPC cost")
		check(passive_runs[index].payloads.role_snapshot_bytes.mean<passive_runs[index+1].payloads.role_snapshot_bytes.mean and passive_runs[index+1].payloads.role_snapshot_bytes.mean<passive_runs[index+2].payloads.role_snapshot_bytes.mean,"passive-control role measurements preserve 0/3/6 public NPC cost")
	for result: Dictionary in runs:
		check(result.npc_foraging_enabled and (result.npc_food_consumed>0 if result.npc_count>0 else result.npc_food_consumed==0),"live-foraging performance measurement includes real intake for "+result.role+" count="+str(result.npc_count))
	for result: Dictionary in passive_runs:
		check(not result.npc_foraging_enabled and result.npc_food_consumed==0 and result.npc_feeding_events==0,"passive performance controls preserve no-food-interaction baseline")
	var report: Dictionary={"format":"phase03-npc-performance-v2","timestamp_utc":Time.get_datetime_string_from_system(true),
		"engine":Engine.get_version_info().string,"os":OS.get_name(),"processor":OS.get_processor_name(),"processor_count":OS.get_processor_count(),
		"authority_schema":World.Snapshot.SCHEMA,"protocol_build":Protocol.BUILD,"fixed_timestep_seconds":World.TICK_SECONDS,
		"method":"Single-threaded headless live authority with default foraging enabled plus explicit passive controls; per configuration 240 warmup + 1200 timed ticks; commands prepared before timer; serialization excluded from tick timing; production role state packet sampled every 60 measured ticks. Packet bytes include protocol envelope; chunked bytes include 800-byte fragmentation envelopes but exclude ENet/IP/UDP headers. Wall-time samples are machine-specific, not a comparative performance guarantee. Live fish-view payloads need not grow monotonically with NPC count because eaten grains leave the visible-food projection; passive controls isolate public NPC record cost.",
		"frame_time":"Measured separately by renderer/native suite; not claimed by this headless suite.","runs":runs,"passive_control_runs":passive_runs}
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	check(file!=null,"performance artifact is writable")
	if file!=null: file.store_string(JSON.stringify(report,"  ")); file.close()
	print("NPC_PERFORMANCE_ARTIFACT | "+OUTPUT)
	print("PHASE03_NPC_STATISTICS_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
