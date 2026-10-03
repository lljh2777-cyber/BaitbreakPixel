extends SceneTree

const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const Snapshot=preload("res://scripts/world_snapshot.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
const FoodProfile=preload("res://scripts/food_profile.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("BAIT_NETWORK_PASS | ",label)
	else: failed+=1; push_error("BAIT_NETWORK_FAIL | "+label)

func no_private(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["bait_type","profile","hook","hook_id","tackle","rng_seed","rng_state","future_secret","suction_efficiency","bite_efficiency","satiety_scale","fragmentation"]: return false
			if not no_private(value[key]): return false
	elif value is Array:
		for item in value:
			if not no_private(item): return false
	return true

func populate(world: Node2D) -> void:
	world.fish=Vector2(60,200); world.fish_before=world.fish
	for index in 3:
		world.baits[index]=world._assign_bait_identity(world._make_bait(index,0,FoodProfile.TYPES[index]),index%2)
		var bait: Dictionary=world.baits[index]
		bait.active=true; bait.pos=Vector2(250+index*40,200)
		for grain: Dictionary in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
	world.baits[3].active=false

func reject_public(world: Node2D, value: Dictionary, label: String) -> void:
	var before: Dictionary=world.capture_snapshot()
	check(not Public.apply(world,value) and world.capture_snapshot()==before,label)

func reject_authority(world: Node2D, value: Dictionary, label: String) -> void:
	var before: Dictionary=world.capture_snapshot()
	check(not world.restore_snapshot(value) and world.capture_snapshot()==before,label)

func _initialize() -> void: call_deferred("run")

func pure_checks() -> void:
	var world:=World.new(); world.reset_world({"seed":2222,"ruleset":"duel"})
	populate(world)
	var replay:=World.new(); replay.reset_world({"seed":8})
	var saved: Dictionary=world.capture_snapshot()
	check(saved.schema==14 and Snapshot.SCHEMA==14 and saved.bait_profile_version==3,"authority preserves schema 14 with a mandatory bait-profile extension guard")
	check(replay.restore_snapshot(saved) and replay.capture_snapshot()==saved,"all bait and fragment kinds survive exact authority roundtrip")
	for tick in 50:
		world.advance_tick({"move":Vector2.UP},{})
		replay.advance_tick({"move":Vector2.UP},{})
	check(world.capture_snapshot()==replay.capture_snapshot(),"profile-bearing authority replay remains deterministic")
	check(world.restore_snapshot(saved),"source resets to profile test fixture")
	var public:=Public.capture(world)
	check(public.bait_profile_version==1 and Public.valid(replay,public) and no_private(public),"fish schema requires profile guard and leaks no authority profile data")
	check(Protocol.unpack_state(Protocol.pack_state(public))==public,"compressed transport retains public cues exactly")
	for index in 3:
		var bait: Dictionary=public.state.baits[index]
		var profile:=FoodProfile.get_profile(FoodProfile.TYPES[index])
		check(bait.visual_kind==FoodProfile.TYPES[index] and bait.shape_hint==profile.shape_hint and bait.smell_hint==profile.smell_hint,"public projection carries legal "+FoodProfile.TYPES[index]+" cues")
	check(public.state.baits[3].visual_kind=="" and public.state.baits[3].shape_hint=="" and public.state.baits[3].smell_hint=="","invisible reserve has empty type, shape and scent cues")
	check(Public.apply(replay,public) and Observation.build(replay)==Observation.build(world),"sanitized fish world reconstructs identical type-aware observations")
	for bait: Dictionary in world.baits:
		bait.hook=not bait.hook; bait.hook_id+=10000; bait.bait_type="worm"
		bait.future_secret={"profile":{"bite_efficiency":999.0}}
		for grain: Dictionary in bait.grains: grain.future_secret=3
	check(Public.capture(world)==public,"changing hook truth, hidden authority type or future fields leaves public payload identical")
	check(world.restore_snapshot(saved),"restore valid authority after deliberate private-field contamination")
	for value in ["secret","",7,&"worm",{},null]:
		var bad:=saved.duplicate(true); bad.state.baits[0].bait_type=value
		reject_authority(world,bad,"authority rejects invalid bait_type "+str(value))
		bad=saved.duplicate(true); bad.state.baits[0].grains[0].visual_kind=value
		reject_authority(world,bad,"authority rejects invalid grain kind "+str(value))
		bad=public.duplicate(true); bad.state.baits[0].visual_kind=value
		reject_public(replay,bad,"public rejects invalid bait kind "+str(value))
		bad=public.duplicate(true); bad.state.baits[0].grains[0].visual_kind=value
		reject_public(replay,bad,"public rejects invalid fragment kind "+str(value))
	for key in ["bait_type","profile","hook","suction_efficiency","future_secret"]:
		var bad:=public.duplicate(true); bad.state.baits[0][key]=1
		reject_public(replay,bad,"public bait allowlist rejects "+key)
		bad=public.duplicate(true); bad.state.baits[0].grains[0][key]=1
		reject_public(replay,bad,"public fragment allowlist rejects "+key)
	for key in ["shape_hint","smell_hint"]:
		var bad:=public.duplicate(true); bad.state.baits[0][key]="secret"
		reject_public(replay,bad,"public rejects unknown "+key)
		bad=public.duplicate(true); bad.state.baits[3][key]="grain"
		reject_public(replay,bad,"invisible reserve cannot carry "+key)
	var bad:=public.duplicate(true); bad.state.baits[3].visual_kind="cluster"
	reject_public(replay,bad,"invisible reserve cannot carry a valid-looking type")
	bad=public.duplicate(true); bad.state.baits[0].grains[1].visual_kind="worm"
	reject_public(replay,bad,"attached public fragments must match the visible bait kind")
	bad=public.duplicate(true); bad.state.baits[1].grains[0].id=bad.state.baits[0].grains[0].id
	reject_public(replay,bad,"public rejects duplicate stable grain IDs across baits")
	bad=saved.duplicate(true); bad.state.baits[0].profile={}
	reject_authority(world,bad,"authority bait records reject unknown profile dictionaries")
	bad=saved.duplicate(true); bad.state.baits[0].grains[0].future_secret=1
	reject_authority(world,bad,"authority fragments reject unknown keys")
	bad=saved.duplicate(true); bad.state.baits[0].grains[0].visual_kind="worm"
	reject_authority(world,bad,"attached fragment kind must match its authority bait type")
	bad=saved.duplicate(true); bad.state.baits[1].grains[0].id=bad.state.baits[0].grains[0].id
	reject_authority(world,bad,"authority rejects duplicate stable grain IDs across baits")
	var mixed:=saved.duplicate(true)
	mixed.state.baits[0].grains[0].free=true; mixed.state.baits[0].grains[0].visual_kind="worm"
	check(world.restore_snapshot(mixed),"valid older loose fragment may differ from the current attached bait type")
	check(world.restore_snapshot(saved),"mixed-fragment fixture resets to original authority")
	for value in [0,4,1.0,"1",null]:
		bad=saved.duplicate(true); bad.bait_profile_version=value
		reject_authority(world,bad,"authority rejects incompatible profile guard "+str(value))
		bad=public.duplicate(true); bad.bait_profile_version=value
		reject_public(replay,bad,"fish rejects incompatible profile guard "+str(value))
	bad=saved.duplicate(true); bad.bait_profile_version=1
	reject_authority(world,bad,"P2.2 neutral-profile snapshots cannot replay under P2.3 tuning")
	bad=saved.duplicate(true); bad.bait_profile_version=2
	reject_authority(world,bad,"P2.3 uniform transport cannot replay under distance-gradient physics")
	bad=saved.duplicate(true); bad.erase("bait_profile_version")
	reject_authority(world,bad,"pre-profile schema 14 snapshot is explicitly rejected")
	bad=public.duplicate(true); bad.erase("bait_profile_version")
	reject_public(replay,bad,"pre-profile fish snapshot is explicitly rejected")
	var view:=Presentation.new()
	check(view.accept(public,1.0,"fish") and no_private(view.sample(1.0).baits),"render-only fish world consumes only legal public cues")
	view.dispose(); world.free(); replay.free()

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
		game.capture_mode="phase02-bait-network"; game.set_process(false); game.set_physics_process(false)
		game.save_path="user://phase02-bait-network-"+str(game.get_instance_id())+".cfg"
	check(host.network.host_game("angler",24785,{"seed":2222,"rules":{"timer_enabled":false,"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0}})==OK and client.network.join_game("127.0.0.1",24785)==OK,"real ENet profile fish peer connects")
	if not await phase("waiting"): check(false,"profile ENet handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"profile ENet start/countdown completes"); return
	populate(host); host.network._send_state(true)
	for tick in 8: await frame()
	check(client.network.local_role=="fish" and no_private(client.baits),"real ENet fish receives no hidden authority profile fields")
	for index in 3:
		check(client.baits[index].visual_kind==FoodProfile.TYPES[index] and client.baits[index].grains[0].visual_kind==FoodProfile.TYPES[index],"real ENet carries "+FoodProfile.TYPES[index]+" bait and fragment kinds")
	check(client.baits[3].visual_kind=="" and client.baits[3].smell_hint=="","real ENet keeps the invisible reserve type hidden")
	# Preserve actual old fragments through the real rehang lifecycle. Choose a
	# deterministic RNG seed yielding a different replacement, without changing its
	# authoritative result or relabelling old food after refill.
	var retained: Array[Dictionary]=[]
	for index in 2:
		var grain: Dictionary=host.baits[1].grains[index]
		grain.free=true; grain.pos=Vector2(160+index*3,200)
		retained.append(grain)
	var fixture_rng:=RandomNumberGenerator.new()
	var seed_value:=722
	fixture_rng.seed=seed_value
	while FoodProfile.roll(fixture_rng)=="worm":
		seed_value+=1; fixture_rng.seed=seed_value
	host.rng.seed=seed_value
	host.refill_hook_bait(1)
	var replacement_kind: String=host.baits[1].bait_type
	check(replacement_kind!="worm" and host.baits[1].grains[-1].visual_kind=="worm","real rehang replaces the attached type while preserving old worm fragments")
	host.network._send_state(true)
	for tick in 6: await frame()
	check(not client.baits[1].active and client.baits[1].grains.size()==2 and client.baits[1].visual_kind=="worm","real ENet hidden replacement exposes only its old visible worm fragments")
	var saved_mixed: Dictionary=host.capture_snapshot()
	var mixed_replay:=World.new()
	check(mixed_replay.restore_snapshot(saved_mixed) and mixed_replay.baits[1].bait_type==replacement_kind and mixed_replay.baits[1].grains[-1].visual_kind=="worm","rehang snapshot preserves both replacement and old fragment types")
	mixed_replay.free()
	host.baits[1].active=true; host.baits[1].pos=Vector2(290,200)
	for grain: Dictionary in host.baits[1].grains:
		if not grain.free: grain.pos=host.baits[1].pos+Vector2(grain.offset)
	host.network._send_state(true)
	for tick in 6: await frame()
	check(client.baits[1].visual_kind==replacement_kind and client.baits[1].grains[-1].visual_kind=="worm","real ENet deployed replacement and old fragments retain different types")
	# Hide the new attached food again and automatically eat only the two old
	# fragments; no authority-only profile field is needed by the fish client.
	host.baits[1].active=false; host.fish=Vector2(140,200); host.fish_before=host.fish
	host.aim=Vector2.RIGHT; host.velocity=Vector2.ZERO; host.bite_cooldown=0.0; host.satiety=50.0
	var expected_points:=0.0
	for index in retained.size():
		retained[index].pos=host.mouth()+Vector2(index+1,0)
		expected_points+=float(retained[index].points)
	var score_before: float=host.score
	host.network._send_state(true)
	for tick in 8: await frame()
	check(retained[0].eaten and retained[1].eaten and is_equal_approx(host.score-score_before,expected_points),"real ENet automatic Bite consumes old typed fragments with unchanged point values")
	check(is_equal_approx(client.score,host.score) and is_equal_approx(client.satiety,host.satiety) and client.baits[1].grains.is_empty() and client.baits[1].visual_kind=="","real ENet consumption removes old public type cues and synchronizes rewards")
	var previous_session: String=host.network.session_id
	host.network.close(); client.network.close()
	check(client.network.presentation.current.is_empty() and client.network.presentation.previous.is_empty(),"disconnect clears type-bearing presentation history")
	check(host.network.host_game("angler",24785,{"rules":{"timer_enabled":false}})==OK and client.network.join_game("127.0.0.1",24785)==OK,"real ENet fresh room rejoin connects")
	if not await phase("waiting"): check(false,"fresh room rejoin handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"fresh room rejoin starts a new round"); return
	check(host.network.session_id!=previous_session and client.network.presentation.current.bait_profile_version==1 and no_private(client.baits),"fresh rejoin receives a guarded new public world without old authority types")
	for index in client.baits.size():
		var actual: Dictionary=client.baits[index]
		var expected: Dictionary=Public.capture(host).state.baits[index]
		check(actual.visual_kind==expected.visual_kind and actual.shape_hint==expected.shape_hint and actual.smell_hint==expected.smell_hint,"fresh rejoin profile cues match authority slot "+str(index))

func run() -> void:
	pure_checks()
	await live_checks()
	if is_instance_valid(host): host.network.close(); host.queue_free()
	if is_instance_valid(client): client.network.close(); client.queue_free()
	await process_frame
	print("PHASE02_BAIT_NETWORK_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
