extends SceneTree
const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const Commands=preload("res://scripts/game_commands.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Session=preload("res://scripts/network_session.gd")
const Public=preload("res://scripts/fish_network_observation.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0
var host:Node2D
var client:Node2D
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("BITE_NETWORK_PASS | ",label)
	else: failed+=1; push_error("BITE_NETWORK_FAIL | "+label)
func fresh() -> Node2D:
	var w=World.new()
	w.reset_world({"seed":1976,"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	w.fish=Vector2(250,200); w.fish_before=w.fish; w.aim=Vector2.RIGHT; w.satiety=50
	for bait in w.baits:
		bait.bait_type="cluster"
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true; grain.visual_kind="cluster"
	for index in 8:
		var grain:Dictionary=w.baits[0].grains[index]
		grain.free=true; grain.eaten=false; grain.pos=w.mouth()+Vector2(index+1,0); grain.points=1.0
	return w
func packet(session: Node, seq: int, command: Dictionary) -> Dictionary:
	return {"session":session.session_id,"round":session.round_id,"seq":seq,"command":command,"events":[],"seen_tick":0,"qte_id":0,"gesture":0}
func _initialize() -> void: call_deferred("run")
func pure_checks() -> void:
	check(not Commands.fish({},Vector2.RIGHT,0.35).has("bite"),"fish command has no Bite action bit")
	for value in [true,false,"true",[],{},null,1,2,-1]:
		check(not Commands.fish({"bite":value},Vector2.RIGHT,0.35).has("bite"),"obsolete Bite field is discarded: "+str(value))
	var wire:=Protocol.decode(Protocol.encode({"bite":true,"suck":true}))
	var context: RefCounted=World.MapContext.load_map().context
	check(not Protocol.input("fish",wire,context).has("bite") and Protocol.input("fish",wire,context).suck,"wire sanitization discards obsolete Bite but preserves held Suck")
	check(not Protocol.input("angler",wire,context).has("bite"),"angler command cannot acquire Bite")
	var w=fresh(); var replay=World.new(); replay.reset_world()
	w.advance_tick({},{})
	var saved:Dictionary=w.capture_snapshot()
	check(saved.schema==17 and saved.state.bite_cooldown>0 and saved.state.bite_feedback_age>0,"schema17 captures in-flight automatic Bite from a neutral tick")
	check(replay.restore_snapshot(saved),"restore in-flight Bite snapshot")
	for tick in 70:
		var command={"suck":tick==32}
		w.advance_tick(command,{}); replay.advance_tick(Protocol.input("fish",Protocol.decode(Protocol.encode(command)),replay.map_context),{})
		check(w.capture_snapshot()==replay.capture_snapshot(),"wire/replay deterministic tick "+str(tick))
	check(w.score==8 and w.score==replay.score and w.satiety==replay.satiety,"schema17 replay repeats automatic intake and preserves exact rewards without Bite input")
	for key in ["bite_cooldown","bite_feedback_age"]:
		for value in [-0.1,NAN,INF,"0",999.0]:
			var bad=saved.duplicate(true); bad.state[key]=value
			var before:Dictionary=replay.capture_snapshot()
			check(not replay.restore_snapshot(bad) and replay.capture_snapshot()==before,"authority rejects malformed "+key+" atomically: "+str(value))
		var missing=saved.duplicate(true); missing.state.erase(key)
		check(not replay.restore_snapshot(missing),"authority requires "+key)
	var old=saved.duplicate(true); old.schema=13
	check(not replay.restore_snapshot(old),"old snapshot cannot masquerade as Bite schema")
	check(w.restore_snapshot(saved),"restore source for public projection")
	var projection:Dictionary=Public.capture(w)
	check(Public.valid(replay,projection),"public schema accepts Bite state")
	check(projection.state.bite_cooldown==w.bite_cooldown and projection.state.bite_feedback_age==w.bite_feedback_age,"public projection carries neutral Bite feedback")
	check(not projection.has("rng_state") and not projection.state.baits[0].has("hook"),"Bite feedback adds no hook/RNG leak")
	check(Public.apply(replay,projection) and replay.score==w.score and replay.satiety==w.satiety,"fish presentation reproduces score/satiety")
	var view=Presentation.new()
	check(view.accept(projection,1.0,"fish") and view.sample(1.0).bite_feedback_age==w.bite_feedback_age,"render-only fish world receives Bite feedback")
	for key in ["bite_cooldown","bite_feedback_age"]:
		for value in [-0.1,NAN,"0",999.0]:
			var bad=projection.duplicate(true); bad.state[key]=value
			var before:Dictionary=replay.capture_snapshot()
			check(not Public.apply(replay,bad) and replay.capture_snapshot()==before,"public rejects malformed "+key+" atomically: "+str(value))
	var extra=projection.duplicate(true); extra.state.bite_hook_roll=0.5
	check(not Public.valid(replay,extra),"public Bite fields remain a strict allowlist")
	view.dispose(); w.free(); replay.free()
	# Guard3 snapshots carry explicit rules; changing defaults must not migrate replay.
	for defaults in [[14.0,0.4],[12.0,0.6]]:
		w=fresh(); replay=World.new(); replay.reset_world()
		w.rules.bite_range=defaults[0]; w.rules.bite_cooldown=defaults[1]
		w.advance_tick({}, {})
		var old_defaults: Dictionary=w.capture_snapshot()
		check(old_defaults.bait_profile_version==3 and replay.restore_snapshot(old_defaults) and replay.rule("bite_range")==defaults[0] and replay.rule("bite_cooldown")==defaults[1],"guard3 restores old explicit defaults without personal-profile migration: "+str(defaults))
		for tick in 60:
			w.advance_tick({}, {}); replay.advance_tick({}, {})
		check(w.capture_snapshot()==replay.capture_snapshot() and replay.score==8,"old-default guard3 snapshot preserves deterministic repeated-intake replay: "+str(defaults))
		w.free(); replay.free()
	queue_checks()
func queue_checks() -> void:
	var w=fresh(); var session=Session.new()
	session.game=w; session.remote_role="fish"; session.session_id="bite-test"; session.round_id=1
	# This isolated queue unit starts after handshake; ENet below still verifies real peers.
	session._select_map(); session.map_validated=true; session.is_host=true; session.status="playing"
	session.receive_input(packet(session,1,{"bite":true}))
	session.receive_input(packet(session,2,{"bite":false,"move":Vector2.RIGHT,"suck":true}))
	var first:Dictionary=session._take_remote()
	check(not first.has("bite") and first.move==Vector2.RIGHT and first.suck,"remote queue strips obsolete Bite and preserves latest held movement/Suck")
	var held:Dictionary=session._take_remote()
	check(not held.has("bite") and held.move==Vector2.RIGHT and held.suck,"held remote state has no Bite edge to replay")
	session.receive_input(packet(session,2,{"bite":true}))
	check(not session._take_remote().has("bite") and session.rejected_inputs==1,"duplicate sequence stays rejected without introducing Bite")
	session.receive_input(packet(session,3,{}))
	var neutral:Dictionary=session._take_remote()
	w.advance_tick(neutral,{})
	check(not neutral.has("bite") and w.score==4,"neutral sequenced remote input automatically eats nearby food on authority")
	for seq in range(4,14): session.receive_input(packet(session,seq,{"bite":true,"suck":seq==13}))
	var bounded:Dictionary=session._take_remote()
	check(not bounded.has("bite") and not bounded.suck and session.remote_queue.size()==2,"eight-command bounded drain never recreates an obsolete Bite field")
	check(session._take_remote().suck and not session._take_remote().has("bite"),"deferred held Suck survives bounded queue drain")
	session.receive_input(packet(session,14,{"bite":true,"suck":true}))
	session.last_input_rx=session.now()-session.INPUT_LEASE_MS-1
	var expired:Dictionary=session._take_remote()
	check(not expired.has("bite") and not expired.get("suck",false) and session.remote_queue.is_empty(),"expired input lease clears stale held input and has no Bite bit")
	session.presentation.dispose(); session.free(); w.free()

func frame(command: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	client.network.tick(1.0/60,command); host.network.tick(1.0/60,{})
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
		game.capture_mode="phase02-bite-network"; game.set_process(false); game.set_physics_process(false)
		game.save_path="user://phase02-bite-network-"+str(game.get_instance_id())+".cfg"
	var config={"seed":3184,"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}}
	check(host.network.host_game("angler",24784,config)==OK and client.network.join_game("127.0.0.1",24784)==OK,"real ENet fish peer connects")
	if not await phase("waiting"): check(false,"ENet handshake completes"); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"ENet start/countdown completes"); return
	host.fish=Vector2(250,200); host.fish_before=host.fish; host.aim=Vector2.RIGHT; host.velocity=Vector2.ZERO; host.satiety=50
	for bait in host.baits:
		bait.bait_type="cluster"
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true; grain.visual_kind="cluster"
	host.network._send_state(true)
	for tick in 5: await frame()
	check(client.network.local_role=="fish" and client.satiety==50 and client.score==0,"fish receives prepared empty public world")
	check(host.bite_cooldown==0 and host.bite_feedback_age==0 and client.bite_feedback_age==0,"real ENet neutral empty ticks produce no Bite feedback")
	for index in 8:
		var grain:Dictionary=host.baits[1].grains[index]
		grain.eaten=false; grain.free=true; grain.pos=host.mouth()+Vector2(index+1,0); grain.points=1.0
	for tick in 6: await frame()
	check(host.score==4 and host.satiety>50,"real ENet authority automatically takes four nearby grains without a key command")
	check(client.score==host.score and client.satiety==host.satiety,"actual ENet public result carries automatic score and satiety")
	check(client.bite_cooldown>0 and client.bite_feedback_age>0,"actual ENet state carries successful automatic Bite countdown and snap")
	check(not client.baits[1].has("hook") and not client.network.presentation.current.has("rng_seed"),"real automatic Bite result remains hook-private")
	for tick in 47: await frame()
	check(host.score==8 and client.score==8,"neutral remote ticks automatically repeat after cooldown and take the remaining four grains")
	for tick in 54: await frame()
	check(host.score==8 and client.score==8 and host.bite_cooldown==0 and client.bite_cooldown==0 and client.bite_feedback_age==0,"empty authority and remote view settle quietly after the repeated intake")
	# Use the unchanged physical contact route and observe its public result.
	var bait:Dictionary=host.baits[1]
	bait.active=true; bait.hook=true; bait.pos=host.mouth()+Vector2(1,-1); bait.home=bait.pos; bait.angle=0; bait.tip_before=bait.pos+Vector2(2,1)
	var contact_food:Dictionary=bait.grains[8]
	contact_food.eaten=false; contact_food.free=true; contact_food.pos=host.mouth()+Vector2(1,0); contact_food.points=1.0
	host.bite_cooldown=0
	for tick in 6: await frame()
	check(host.hooked==host.HookState.MOUTH and client.hooked==client.HookState.MOUTH,"real physical hook contact reaches remote fish mouth QTE with neutral input")
	check(not contact_food.eaten and host.score==8 and client.score==8 and not client.baits[1].has("hook"),"physical contact preempts automatic food reward and exposes no hidden hook field")
	check(host.bite_feedback_age==0 and client.bite_feedback_age==0,"real contact result cannot pretend an automatic intake succeeded")
func run() -> void:
	pure_checks()
	await live_checks()
	if is_instance_valid(host): host.network.close(); host.queue_free()
	if is_instance_valid(client): client.network.close(); client.queue_free()
	await process_frame
	print("BITE_NETWORK | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
