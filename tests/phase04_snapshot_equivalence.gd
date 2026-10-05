extends SceneTree

# P4.3 schema-aware deterministic compatibility probe. The external Python driver
# runs this identical harness against the frozen P4.2 Git source and current P4.3.
# Input/setup/intervention tape is byte-locked to the historical P4.0 harness.
# Only explicitly validated envelope schema and map identity are excluded from
# cross-version hashes. State/rig/RNG and both public wires remain exact bytes.
# Full capture/restore and second-half replay compare UNMODIFIED snapshots.
# This is not renderer, ecology balance, real ENet, or human acceptance.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Snapshot=preload("res://scripts/world_snapshot.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("SNAPSHOT_EQUIVALENCE_FAIL | "+label)

func digest(value: Variant) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func registry_ref() -> Dictionary:
	var refs: Array=Registry.available_refs()
	check(refs.size()==1,"closed built-in registry contains exactly one map")
	return refs[0].duplicate(true) if refs.size()==1 else {}

func envelope_valid(value: Dictionary, kind: String) -> bool:
	var modern: bool=Snapshot.SCHEMA>=16
	if Snapshot.SCHEMA not in [15,16,17]: return false
	var expected: Array=["schema","bait_profile_version","map_ref" if modern else "map_id","state","rig","rng_seed","rng_state"]
	var schema: int=Snapshot.SCHEMA
	var bait_version: int=3
	if kind=="fish":
		expected=["format","schema","bait_profile_version","npc_profile_version","map_ref" if modern else "map_id","role","state","rig"]
		schema=3 if Snapshot.SCHEMA==17 else 2 if modern else 1
		bait_version=1
		if value.get("format")!="fish-presentation" or value.get("role")!="fish" or value.get("npc_profile_version")!=2: return false
	elif kind=="angler":
		expected.append_array(["format","role","npc_profile_version"])
		if value.get("format")!="angler-presentation" or value.get("role")!="angler" or value.get("npc_profile_version")!=4: return false
	elif kind!="authority": return false
	if Snapshot.SCHEMA==17:
		expected.append("map_source")
		if value.get("map_source")!={"kind":"built_in","id":"pond_v2","revision":1}: return false
	if value.size()!=expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	if not value.schema is int or value.schema!=schema: return false
	if not value.bait_profile_version is int or value.bait_profile_version!=bait_version: return false
	if not value.state is Dictionary or not value.rig is Dictionary: return false
	var refs: Array=Registry.available_refs()
	if refs.size()!=1: return false
	var reference: Dictionary=refs[0]
	if reference.keys()!=["id","revision","contract_version","content_hash"]: return false
	if reference.id!="pond_v2" or reference.revision!=1 or reference.contract_version!=1: return false
	if modern:
		if not value.map_ref is Dictionary: return false
		if var_to_bytes(value.map_ref)!=var_to_bytes(reference): return false
	else:
		if not value.map_id is String or value.map_id!=reference.id: return false
	return true

func gameplay_payload(value: Dictionary, kind: String) -> Dictionary:
	# No recursive pruning, rounding, sorting, schema coercion or value replacement.
	# Invalid envelopes are errors even though the caller still produces diagnostics.
	check(envelope_valid(value,kind),kind+" exact envelope and registry identity before metadata exclusion")
	var result: Dictionary=value.duplicate(true)
	result.erase("schema")
	result.erase("map_source")
	result.erase("map_ref" if Snapshot.SCHEMA>=16 else "map_id")
	return result

func envelope_metadata(value: Dictionary) -> Dictionary:
	return {"schema":value.schema,"map":value.get("map_ref",value.get("map_id"))}

func scenarios() -> Array[Dictionary]:
	return [
		{"name":"ambient_survival","seed":17401,"mode":"survival","count":2,"challenge":true,"ticks":240},
		{"name":"ambient_duel","seed":17402,"mode":"duel","count":4,"challenge":false,"ticks":240},
		{"name":"feeding_refill","seed":17403,"mode":"duel","count":3,"challenge":false,"ticks":180},
		{"name":"player_entry","seed":64317,"mode":"survival","count":0,"challenge":true,"ticks":180},
		{"name":"player_wrap","seed":64317,"mode":"survival","count":0,"challenge":true,"ticks":120},
		{"name":"npc_capture_respawn","seed":64317,"mode":"duel","count":3,"challenge":false,"ticks":900},
		{"name":"net_player","seed":75401,"mode":"duel","count":3,"challenge":true,"ticks":120},
		{"name":"net_npc_only","seed":75401,"mode":"duel","count":3,"challenge":true,"ticks":120},
	]

func fresh(spec: Dictionary) -> Node2D:
	var world:=World.new()
	var rules: Dictionary={"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}
	if spec.name in ["player_entry","player_wrap"]: rules.line_force=0.0
	world.reset_world({"seed":spec.seed,"ruleset":spec.mode,"npc_count":spec.count,"challenge":spec.challenge,"rules":rules})
	world.angler.auto_net=false
	if str(spec.name).begins_with("ambient_"): return world
	for bait: Dictionary in world.baits:
		bait.active=false; bait.removed=false; bait.hook=false; bait.tackle=false; bait.suction_offset=Vector2.ZERO
		for grain: Dictionary in bait.grains: grain.eaten=true
	match spec.name:
		"feeding_refill":
			world.fish=Vector2(300,200); world.fish_before=world.fish; world.aim=Vector2.RIGHT
			var npc: Dictionary=world.npc_fishes[0]
			npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
			npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0
			for index in 4:
				for slot in [0,1]:
					var grain: Dictionary=world.baits[slot].grains[index]
					grain.eaten=false; grain.free=true; grain.points=1.0
					grain.pos=(world.mouth() if slot==0 else world.FishFeeding.mouth(npc.position,npc.aim))+Vector2(index+1,0)
		"player_entry":
			world.fish=Vector2(250,200); world.fish_before=world.fish; world.aim=Vector2.RIGHT
			place_hook(world,world.mouth()+Vector2(3,0),0)
		"player_wrap":
			world.fish=Vector2(100,380); world.fish_before=world.fish; world.aim=Vector2.RIGHT
			world.baits[0].home.x=100.0
			# White-box setup, same as the existing player_hook_entry fixture.
			world._enter_hook(0); world._attach_hook()
		"npc_capture_respawn":
			world.fish=Vector2(1050,280); world.fish_before=world.fish
			world.angler.x=614.0; world.angler.previous_anchor=world.angler.anchor()
			var npc: Dictionary=world.npc_fishes[0]
			npc.position=Vector2(640,220); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
			npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO
			place_hook(world,world.FishFeeding.mouth(npc.position,npc.aim)+Vector2(3,0),1)
			world._step_bait(1,0.0,false,world.mouth())
		"net_player","net_npc_only":
			world.angler.x=234.0; world.angler.previous_anchor=world.angler.anchor()
			world.fish=Vector2(260,140) if spec.name=="net_player" else Vector2(1000,320)
			world.fish_before=world.fish
			var npc: Dictionary=world.npc_fishes[0]
			npc.position=Vector2(260,140); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
			npc.intent_aim=Vector2.RIGHT; npc.wander_heading=Vector2.RIGHT; npc.steering=Vector2.ZERO
	return world

func place_hook(world: Node2D, point: Vector2, slot: int) -> void:
	var bait: Dictionary=world.baits[slot]
	bait.active=true; bait.hook=true; bait.angle=0.0
	bait.pos=point-Vector2(2,1); bait.home=bait.pos; bait.tip_before=point

func commands(spec: Dictionary, tick: int) -> Dictionary:
	var fish: Dictionary={}
	var angler: Dictionary={"auto_net":false}
	if str(spec.name).begins_with("ambient_"):
		var direction:=Vector2.RIGHT.rotated(float(tick)*0.023)
		fish={"move":direction,"aim":direction,"suck":tick%70<23,"dash":tick%90<11}
		angler={"walk":float((tick/80)%3-1),"reel":tick%135<45,"release":tick%135>=90,
			"deploy":spec.mode=="duel" and tick%120==0,"auto_net":false,"target":Vector2(650+sin(tick*0.01)*100,250)}
	elif spec.name=="feeding_refill":
		fish={"suck":tick%60<20}
	elif spec.name=="player_entry":
		fish={"qte":tick<12}
	elif spec.name=="player_wrap":
		fish={"qte":tick in [0,1,2,3]}
	elif spec.name=="npc_capture_respawn":
		angler={"reel":true,"auto_net":false}
	elif str(spec.name).begins_with("net_") and tick in [0,1,2]:
		# UI-realistic observation and two clicks on separate authority ticks.
		var event: Dictionary={"kind":"toggle"} if tick==0 else {"kind":"point","point":Vector2(210 if tick==1 else 310,140)}
		angler={"auto_net":false,"net_events":[event]}
	return {"fish":fish,"angler":angler}

func intervention(world: Node2D, spec: Dictionary, tick: int) -> Dictionary:
	var applied: Dictionary={}
	if spec.name=="feeding_refill" and tick==120:
		world.refill_hook_bait(0); applied.refill_slot=0
	if spec.name=="player_wrap" and tick==3:
		world.qte_age=world.qte_timing.lead+world.qte_timing.sweep*(world.qte_zone+world.qte_width*0.5)-World.TICK_SECONDS
		applied.wrap_green_age=world.qte_age
	return applied

func checkpoint(world: Node2D, label: String, input_tick: int) -> Dictionary:
	var snapshot: Dictionary=world.capture_snapshot()
	var fish_wire: Dictionary=FishWire.capture(world)
	var angler_wire: Dictionary=AnglerWire.capture(world)
	check(envelope_valid(snapshot,"authority"),label+" strict authority envelope")
	check(world.Stats.valid(world.round_stats),label+" valid statistics")
	var verifier:=World.new(); verifier.reset_world({"seed":1})
	check(verifier.restore_snapshot(snapshot),label+" accepts complete authority checkpoint")
	check(var_to_bytes(snapshot)==var_to_bytes(verifier.capture_snapshot()),label+" exact snapshot restore")
	var fish_wire_valid: bool=FishWire.valid(verifier,fish_wire)
	var angler_wire_valid: bool=AnglerWire.valid(verifier,angler_wire)
	check(angler_wire_valid,label+" angler projection remains valid")
	check(fish_wire_valid,label+" fish projection remains valid")
	check(var_to_bytes(Protocol.unpack_state(Protocol.pack_state(snapshot)))==var_to_bytes(snapshot),label+" compressed wire preserves snapshot")
	var npc_observations: Array=[]
	for npc: Dictionary in world.npc_fishes:
		npc_observations.append(Observation.build_social_for(world,State.observer(npc,world.rules),false))
	var hooks: Dictionary={"hooked":world.hooked,"target":world.hook_target_fish_id,"npc_hook":world.npc_hook,
		"qte":world.qte,"qte_id":world.qte_id,"qte_age":world.qte_age,"zone":world.qte_zone,"timing":world.qte_timing,
		"wraps":world.wraps,"effort":world.effort_checks,"rope":world.rope_path,"tension":world.tension}
	var net: Dictionary={"state":world.net_state,"motion":world.net_motion,"route":world.net_route,
		"action":world.net_action,"position":world.net_pos,"captures":world.net_catches,"capture":world.net_capture}
	var result: Dictionary={"input_tick":input_tick,"simulation_tick":world.simulation_tick,
		"fish_wire_valid":fish_wire_valid,"angler_wire_valid":angler_wire_valid,
		"rng_seed":str(world.rng.seed),"rng_state":str(world.rng.state),
		"snapshot_sha256":digest(gameplay_payload(snapshot,"authority")),"snapshot_bytes":var_to_bytes(gameplay_payload(snapshot,"authority")).size(),
		"raw_snapshot_sha256":digest(snapshot),"raw_snapshot_bytes":var_to_bytes(snapshot).size(),
		"authority_metadata":envelope_metadata(snapshot),"fish_metadata":envelope_metadata(fish_wire),"angler_metadata":envelope_metadata(angler_wire),
		"fish_observation_sha256":digest(Observation.build(world,true)),
		"fish_decision_observation_sha256":digest(Observation.build(world,false)),
		"npc_observations_sha256":digest(npc_observations),"npcs_sha256":digest(world.npc_fishes),
		"bait_sha256":digest(world.baits),"hook_qte_wrap_sha256":digest(hooks),"net_sha256":digest(net),
		"stats_sha256":digest(world.round_stats),"fish_wire_sha256":digest(gameplay_payload(fish_wire,"fish")),"angler_wire_sha256":digest(gameplay_payload(angler_wire,"angler")),
		"raw_fish_wire_sha256":digest(fish_wire),"raw_angler_wire_sha256":digest(angler_wire),
		"packed_authority_sha256":digest(Protocol.pack_state(gameplay_payload(snapshot,"authority")))}
	verifier.free()
	return result

func run_case(spec: Dictionary) -> Dictionary:
	var world:=fresh(spec)
	var records: Array=[checkpoint(world,spec.name+" initial",-1)]
	var trace:=HashingContext.new(); trace.start(HashingContext.HASH_SHA256)
	var inputs:=HashingContext.new(); inputs.start(HashingContext.HASH_SHA256)
	var replay:=World.new(); replay.reset_world({"seed":2})
	var replaying:=false
	var saw: Dictionary={"entry":false,"attached":false,"qte":false,"wrap":false,"net_warning":false,"net_sweep":false,
		"npc_hooked":world.hook_target_fish_id>1,"npc_landing":false,"npc_replaced":false,"refill":false}
	var replay_ok:=true
	for tick in int(spec.ticks):
		if tick==int(spec.ticks)/2:
			var frozen:=var_to_bytes(world.capture_snapshot())
			world.match_paused=true
			var paused:=var_to_bytes(world.capture_snapshot())
			for ignored in 3: world.advance_tick({"suck":true,"qte":true},{"deploy":true,"reel":true})
			check(paused==var_to_bytes(world.capture_snapshot()),spec.name+" pause freezes complete state")
			world.match_paused=false
			check(frozen==var_to_bytes(world.capture_snapshot()),spec.name+" pause leaves no input residue")
			replaying=replay.restore_snapshot(world.capture_snapshot())
			check(replaying,spec.name+" restores midpoint for future replay")
		var applied:=intervention(world,spec,tick)
		if replaying: check(intervention(replay,spec,tick)==applied,spec.name+" identical replay intervention")
		var input:=commands(spec,tick)
		inputs.update(var_to_bytes({"tick":tick,"commands":input,"intervention":applied}))
		world.advance_tick(input.fish,input.angler)
		var snapshot: Dictionary=world.capture_snapshot()
		trace.update(var_to_bytes(gameplay_payload(snapshot,"authority")))
		if replaying:
			replay.advance_tick(input.fish,input.angler)
			replay_ok=replay_ok and var_to_bytes(snapshot)==var_to_bytes(replay.capture_snapshot())
		saw.entry=saw.entry or world.hooked==World.HookState.MOUTH
		saw.attached=saw.attached or world.hooked==World.HookState.HOOKED
		saw.qte=saw.qte or not world.qte.is_empty()
		saw.wrap=saw.wrap or not world.wraps.is_empty()
		saw.net_warning=saw.net_warning or world.net_state=="warning"
		saw.net_sweep=saw.net_sweep or world.net_state=="sweep"
		saw.npc_landing=saw.npc_landing or world.npc_hook.phase=="landing"
		saw.npc_replaced=saw.npc_replaced or (spec.name=="npc_capture_respawn" and world.npc_by_id(2).is_empty())
		saw.refill=saw.refill or applied.has("refill_slot")
		if tick%30==0 or tick==int(spec.ticks)-1: records.append(checkpoint(world,spec.name+" tick="+str(tick),tick))
	check(replay_ok and replaying,spec.name+" full second-half authority replay is byte-identical")
	match spec.name:
		"feeding_refill": check(world.score>0 and world.round_stats.npc_food_consumed>0 and saw.refill,spec.name+" actual player/NPC intake plus new bait RNG witness")
		"player_entry": check(saw.entry and saw.attached and saw.qte and world.round_stats.fish_total>0,spec.name+" physical entry, ignored lead inputs, real timeout attachment")
		"player_wrap": check(saw.attached and saw.qte and saw.wrap and world.round_stats.wrap_good>0,spec.name+" actual QTE and physical coil witness")
		"npc_capture_respawn": check(saw.npc_hooked and saw.npc_landing and saw.npc_replaced and world.round_stats.wrong_catches>0,spec.name+" real contact/retrieval/landing/capture/delayed fresh ID")
		"net_player": check(saw.net_warning and world.net_catches==1,spec.name+" real net warning and player capture")
		"net_npc_only": check(saw.net_warning and saw.net_sweep and world.net_catches==0 and world.npc_fishes[0].active,spec.name+" real sweep leaves NPC uncatchable")
	var result: Dictionary={"scenario":spec,"checkpoints":records,"input_trace_sha256":inputs.finish().hex_encode(),
		"every_tick_authority_sha256":trace.finish().hex_encode(),"witnesses":saw,
		"outcome":{"score":world.score,"npc_food":world.round_stats.npc_food_consumed,"next_bait_id":world.next_bait_id,
			"next_fish_id":world.next_fish_id,"wrong_catches":world.round_stats.wrong_catches,"net_catches":world.net_catches,
			"hook_events":world.round_stats.hook_events,"wrap_good":world.round_stats.wrap_good,"match_over":world.match_over,"reason":world.reason}}
	world.free(); replay.free()
	return result

func _initialize() -> void:
	var output:=""
	var repeat:=true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument=="--single-pass": repeat=false
	var records: Array=[]
	for spec: Dictionary in scenarios():
		var first:=run_case(spec)
		if repeat: check(first==run_case(spec),spec.name+" independent identical-seed/input reset repeats exactly")
		records.append(first)
	var report: Dictionary={"format":"phase04-snapshot-equivalence-v1","engine":Engine.get_version_info().string,"schema":Snapshot.SCHEMA,
		"probe":"bounded deterministic 60 Hz scenarios; exact Variant bytes after checked schema/map envelope exclusion",
		"registry_ref":registry_ref(),"metadata_exclusions":["schema","map_id" if Snapshot.SCHEMA==15 else "map_ref"],"scenarios":records,"passed":passed,"failed":failed}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		check(file!=null,"open comparison output")
		if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	print("PHASE04_SNAPSHOT_EQUIVALENCE_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
