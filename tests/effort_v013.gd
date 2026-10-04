extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Session=preload("res://scripts/network_session.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var game: Node2D
var cues: Array[String]=[]
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("EFFORT_PASS | ",description)
	else: failed+=1; push_error("EFFORT_FAIL | "+description)
func fresh() -> void:
	game.reset_world({"ruleset":"duel","challenge":true,"water_strength":0,"seed":913,"break_hold":10,"slack_hold":3})
	game.fish=Vector2(250,220); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook(); cues.clear()
func tick(seconds: float, fish: Dictionary={}, angler: Dictionary={}) -> void:
	for frame in roundi(seconds*60): game.advance_tick(fish,angler)
func judge(role: String, good: bool) -> void:
	var state: Dictionary=game.effort_checks[role]
	state.age=0.4+(state.zone+state.width*0.5)*2-1.0/60 if good else float(state.lead)+0.02
	game.advance_tick({"qte":true} if role=="fish" else {},{"qte":true} if role=="angler" else {})
func run() -> void:
	game=World.new(); game.feedback_requested.connect(func(cue: String): cues.append(cue))
	fresh()
	var zones: Array[float]=[]
	for index in 80:
		game._open_qte("entry"); zones.append(game.qte_zone)
	check(is_equal_approx(game.qte_width,0.12) and zones.min()<0.25 and zones.max()>0.65,"default 0.24s success zone is short and varies across the track")
	check(cues.count("qte_fish")==80,"each check sends exactly one cue before its 0.4s lead-in")
	game._open_qte("wrap"); check(is_equal_approx(game.qte_width,0.12),"wrapping window is also shortened")
	game._open_qte("slack"); check(cues[-1]=="qte_fish","low-tension escape also warns before the ring")
	fresh(); game.effort_checks.fish.wait=0.0; game.effort_checks.angler.wait=0.0
	tick(0.5,{}, {"release":true})
	check(not game.effort_checks.fish.active and not game.effort_checks.angler.active,"idling and paying out do not generate exertion checks")
	game.tension=0.5; game.rope_length=game.line_anchor(0).distance_to(game.mouth())
	game.advance_tick({"move":Vector2.DOWN},{"reel":true})
	check(game.effort_checks.fish.active and game.effort_checks.angler.active,"both resisting fish and reeling angler can independently receive checks")
	check(game.effort_checks.fish.age==0 and cues.count("qte_fish")==1 and cues.count("qte_angler")==1,"role-specific warnings precede each new effort sweep")
	var before: Vector2=game.fish
	tick(0.2,{"move":Vector2(0.7,0.7)},{"walk":1,"reel":true})
	check(game.fish.distance_to(before)>2 and game.angler.x>206 and not game.movement_locked(),"movement, bank walking and line pull continue during checks")
	judge("angler",true); judge("fish",false)
	check(game.effort_multiplier("angler")==1.35 and game.effort_checks.angler.effect_age>1.9,"angler success grants a short 35 percent strength bonus")
	check(game.effort_multiplier("fish")==0.6 and game.qte.is_empty() and game.wraps.is_empty(),"fish failure weakens it without letting the same Space start wrapping")
	var frozen: Dictionary=game.effort_checks.duplicate(true)
	game.match_paused=true; tick(0.5,{"move":Vector2.DOWN},{"reel":true})
	check(game.effort_checks==frozen,"offline pause freezes effect durations and trigger timers")
	game.match_paused=false
	var snapshot: Dictionary=game.capture_snapshot()
	var restored=World.new()
	check(restored.restore_snapshot(snapshot) and restored.effort_checks==game.effort_checks,"both checks and temporary powers survive a snapshot round trip")
	var bad: Dictionary=snapshot.duplicate(true); bad.state.effort_checks.angler.multiplier=99.0
	check(not restored.restore_snapshot(bad) and restored.effort_checks==game.effort_checks,"invalid effect data is rejected without partial state mutation")
	restored.free()
	tick(2.1)
	check(game.effort_multiplier("fish")==1 and game.effort_multiplier("angler")==1,"boost and weakness expire automatically")
	fresh(); game.Effort.open(game.effort_checks.fish,game.rng)
	game._open_qte("wrap")
	check(not game.effort_checks.fish.active and game.effort_multiplier("fish")==1,"ordinary fish QTE preempts effort without a failure penalty")
	fresh(); game.Effort.open(game.effort_checks.angler,game.rng)
	tick(2.5)
	check(not game.effort_checks.angler.active and game.effort_multiplier("angler")==0.6,"ignoring an effort check causes brief weakness")
	game._release_hook(false)
	check(game.effort_multiplier("angler")==1 and game.effort_checks.angler.effect_age==0,"unhooking clears all outstanding effects")
	game.effort_checks.angler.wait=0.0; tick(0.2,{}, {"reel":true})
	check(not game.effort_checks.angler.active,"a free hook cannot trigger exertion checks")
	for role in ["fish","angler"]:
		var distances: Array[float]=[]
		for gain in [0.6,1.0,1.35]:
			fresh(); game.effort_checks[role].multiplier=gain; game.effort_checks[role].effect_age=2.0
			before=game.fish
			tick(0.8,{"move":Vector2.DOWN},{"reel":true})
			distances.append(game.fish.y-before.y)
		check(distances[0]>distances[2]+3 if role=="angler" else distances[2]>distances[0]+3,role+" power changes real tug motion, not only the HUD")
	# A held effort continues to offer new checks after the temporary effect and cooldown.
	fresh(); var starts:=0; var previous:=0
	for frame in 2400:
		game.break_hold_seconds=10; game.high_age=0
		game.fish=Vector2(250,220); game.stamina=100
		game.rope_length=game.line_anchor(0).distance_to(game.mouth())
		var input: Dictionary={"reel":true,"qte":game.effort_ai_press("angler")}
		game.advance_tick({"move":Vector2.DOWN,"qte":game.effort_ai_press("fish")},input)
		if game.effort_checks.angler.id>previous: starts+=1; previous=game.effort_checks.angler.id
	check(starts>=3 and starts<10,"sustained exertion repeatedly offers bounded, random-timed checks")
	await network_checks()
	print("EFFORT_V013_TESTS | passed=",passed," | failed=",failed)
	game.free(); quit(1 if failed else 0)

func network_checks() -> void:
	var net=Session.new(); net.game=game; root.add_child(net)
	# Isolated timing unit starts at the verified/playing host boundary.
	net._select_map(); net.map_validated=true; net.is_host=true; net.status="playing"
	for role in ["fish","angler"]:
		fresh(); game.qte_grace_seconds=0.25
		var state: Dictionary=game.effort_checks[role]
		game.Effort.open(state,game.rng); state.zone=0.4; state.age=1.3
		game.simulation_tick=100
		net.remote_role=role; net.session_id="effort"; net.round_id=1; net.received_input_seq=0; net.remote_queue.clear(); net.remote_held.clear()
		net._remember_qte(); game.simulation_tick=112; state.age=1.5
		var packet: Dictionary={"session":"effort","round":1,"seq":1,"command":{"qte":true,"qte_at_age":0.0},"seen_tick":100,"qte_id":state.id,"check_kind":"effort","events":[],"gesture":0}
		net.receive_input(packet); var accepted: Dictionary=net._take_remote()
		check(accepted.qte and is_equal_approx(accepted.qte_at_age,1.3),role+" effort uses authority timing rather than client claims")
		game.advance_tick(accepted if role=="fish" else {},accepted if role=="angler" else {})
		check(state.good and state.effect_age>1.9,role+" delayed green hit grants exactly one authoritative boost")
		check(not net._take_remote().qte,role+" held network input does not repeat a judgment")
		packet.seq=2; net.receive_input(packet)
		check(not net._take_remote().qte,role+" resolved effort rejects replayed judgments")
		check(Protocol.input(role,{"qte_at_age":1.3}).qte_at_age<0,role+" cannot supply a trusted timestamp directly")
	net.queue_free(); await process_frame
