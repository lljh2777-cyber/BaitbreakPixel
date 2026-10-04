extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Brain=preload("res://scripts/angler_brain.gd")
const Session=preload("res://scripts/network_session.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Presentation=preload("res://scripts/network_presentation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("UNTANGLE_PASS | ",label)
	else: failed+=1; push_error("UNTANGLE_FAIL | "+label)
func fresh() -> Node2D:
	var w=World.new()
	w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0,"line_force":0,"seed":2649})
	w.fish=Vector2(332,245); w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	w._update_contacts(0); w._begin_wrap(); w._commit_wrap()
	for frame in 90: w.advance_tick({}, {})
	w.fish+=Vector2(48,0)
	set_tension(w,0.4)
	return w
func set_tension(w:Node2D, value:float) -> void:
	var distance:float=(Vector2(w.wraps[-1].entry) if not w.wraps.is_empty() else w.line_anchor(w.bound_bait)).distance_to(w.mouth())
	if w.wraps.is_empty(): w.rope_length=distance-(value-0.5)*w.LINE_ELASTIC_PIXELS
	else: w.fish_line_length=distance-(value-0.18)*w.LINE_ELASTIC_PIXELS
	w.tension=value; w.low_age=0; w.high_age=0; w.qte=""
func green(w:Node2D) -> void:
	var s:Dictionary=w.effort_checks.angler
	s.age=0.4+(s.zone+s.width*0.5)*2-w.TICK_SECONDS
func run() -> void:
	var w=fresh()
	check(w.wraps.size()==1 and not w.winding() and w.can_untangle(),"real fish wrap QTE creates an eligible persistent coil")
	var cues:Array[String]=[]
	w.feedback_requested.connect(func(cue:String): cues.append(cue))
	w.advance_tick({}, {"untangle":true})
	check(w.untangle_phase=="check" and w.skill_check("angler").kind=="untangle" and "qte_angler" in cues,"F opens the angler hook QTE with a warning sound")
	check(is_equal_approx(w.effort_multiplier("angler"),0.55) and not w.movement_locked(),"counter sacrifices pull while leaving fish movement unlocked")
	var id:int=w.effort_checks.angler.id
	var zone:float=w.effort_checks.angler.zone
	w.advance_tick({}, {"untangle":true})
	check(w.effort_checks.angler.id==id and w.effort_checks.angler.zone==zone,"repeated F cannot restart the timer or reroll its green zone")
	var before:Vector2=w.fish
	w.advance_tick({"move":Vector2.LEFT,"dash":true},{})
	check(w.fish.distance_to(before)>0 and w.stamina<100,"fish can sprint and spend stamina during human judgment")
	set_tension(w,0.4); green(w); w.velocity=Vector2.ZERO
	w.advance_tick({}, {"qte":true})
	check(w.untangle_phase=="unwind" and w.wraps.size()==1 and w.effort_checks.angler.good,"valid green and valid tension begin a reverse animation without deleting the coil immediately")
	w.advance_tick({}, {})
	check(w.wraps[0].progress<1 and not w.winding(),"reverse progress cannot be mistaken for forward winding")
	var previous:float=w.wraps[0].progress
	for frame in 12: w.advance_tick({}, {})
	check(w.wraps[0].progress<previous and w.wraps[0].progress>0,"visible coil shrinks progressively")
	var clone=World.new(); check(clone.restore_snapshot(w.capture_snapshot()),"in-progress reverse animation restores through the network schema")
	var identical:=true
	for frame in 50:
		w.advance_tick({}, {}); clone.advance_tick({}, {})
		identical=identical and var_to_bytes(w.capture_snapshot())==var_to_bytes(clone.capture_snapshot())
	check(identical,"snapshot resumes deterministically through coil removal")
	check(w.wraps.is_empty() and not w.latched and w.round_stats.unwrap_good==1 and w.hooked==w.HookState.HOOKED,"one successful check removes one coil and keeps fish hooked")
	check(absf(w.tension-0.4)<0.001 and w.fish.distance_to(clone.fish)<0.001,"removing last attachment preserves line tension")
	check(not w._begin_untangle(),"cannot unwrap a line with no coils")
	clone.free(); w.free()
	for value in [0.10,0.85]:
		w=fresh(); w.advance_tick({}, {"untangle":true}); set_tension(w,value); green(w)
		w.advance_tick({}, {"qte":true})
		check(w.untangle_phase=="recover" and not w.effort_checks.angler.good and w.wraps.size()==1,"green with tension %.0f%% fails and preserves the coil" % (value*100))
		check(is_equal_approx(w.effort_multiplier("angler"),0.6) and not w.can_untangle(),"failed counter has recovery and cooldown")
		for frame in 50: w.advance_tick({}, {})
		check(w.untangle_phase.is_empty() and w.untangle_cooldown>0 and not w.effort_checks.angler.active,"recovery ends but cooldown prevents spam")
		w.free()
	w=fresh(); w.advance_tick({}, {"untangle":true}); w.advance_tick({}, {"qte":true})
	check(w.untangle_phase=="check" and w.effort_checks.angler.active and w.round_stats.angler_total==0,"warning press is consumed without judging a hidden target")
	w.effort_checks.angler.age=float(w.effort_checks.angler.lead)+0.02
	w.advance_tick({}, {"qte":true})
	check(w.untangle_phase=="recover" and not w.effort_checks.angler.good,"visible off-zone press fails and retains the coil")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true})
	for frame in 150: w.advance_tick({}, {})
	check(w.untangle_phase=="recover" and w.wraps.size()==1,"unanswered check times out and leaves coil")
	w.free(); w=fresh(); w.Effort.open(w.effort_checks.angler,w.rng)
	id=w.effort_checks.angler.id; w.advance_tick({}, {"untangle":true})
	check(w.effort_checks.angler.id==id and w.effort_checks.angler.kind=="effort" and w.untangle_phase.is_empty(),"F cannot replace an existing effort check")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true}); set_tension(w,0.1)
	w._open_qte("slack"); w.qte_age=0.4+(w.qte_zone+w.qte_width*0.5)*2-w.TICK_SECONDS; green(w)
	w.advance_tick({"qte":true},{"qte":true})
	check(w.hooked==w.HookState.FREE and w.untangle_phase.is_empty() and w.round_stats.unwrap_good==0,"fish escape wins simultaneous judgments and cancels counter")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true}); green(w); w.advance_tick({}, {"qte":true})
	set_tension(w,0.1)
	for frame in 32: w.advance_tick({}, {})
	check(w.qte=="slack" and w.untangle_phase=="unwind","reverse animation does not suppress fish slack QTE")
	w.qte_age=0.4+(w.qte_zone+w.qte_width*0.5)*2-w.TICK_SECONDS
	w.advance_tick({"qte":true},{})
	check(w.hooked==w.HookState.FREE and w.round_stats.unwrap_good==0,"fish can escape while the coil is visibly unwinding")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true}); set_tension(w,1); w.high_age=w.break_hold_seconds-0.001
	w.advance_tick({}, {})
	check(w.hooked==w.HookState.FREE and w.untangle_phase.is_empty() and w.round_stats.breaks==1,"line break cancels the human action without shielding fish")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true}); green(w); w.advance_tick({}, {"qte":true}); w.advance_tick({}, {})
	w.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}]})
	check(w.untangle_phase.is_empty() and w.wraps[0].progress==1 and w.round_stats.unwrap_good==0,"switching to the net cancels reverse motion and retains the complete coil")
	w.free(); w=fresh()
	var coil:Dictionary=w.Layout.coil_at(w.targets[3],Vector2(262,270)); coil.target=3; coil.progress=1.0; w.wraps.append(coil); set_tension(w,0.4)
	w.advance_tick({}, {"untangle":true}); green(w); w.advance_tick({}, {"qte":true})
	for frame in 45: w.advance_tick({}, {})
	check(w.wraps.size()==1 and w.wraps[0].target==0 and w.latched and absf(w.tension-0.4)<0.001,"multiple coils unwind last-first, exactly one, with preserved tension")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true})
	coil=w.Layout.coil_at(w.targets[3],Vector2(262,270)); coil.target=3; coil.progress=0.0; w.wraps.append(coil)
	w.advance_tick({}, {})
	check(w.untangle_phase=="recover" and w.wraps.size()==2,"a new fish wrap interrupts an ongoing attempt without deleting either coil")
	w.free(); w=fresh(); w.advance_tick({}, {"untangle":true}); green(w); w.advance_tick({}, {"qte":true})
	for frame in 12: w.advance_tick({}, {})
	coil=w.Layout.coil_at(w.targets[3],Vector2(262,270)); coil.target=3; coil.progress=0.0; w.wraps.append(coil)
	w.advance_tick({}, {})
	check(w.untangle_phase.is_empty() and w.wraps.size()==2 and w.wraps[0].progress==1 and w.round_stats.unwrap_good==0,"a pending fish wrap completing during reverse restores the interrupted coil completely")
	w.reset_world({}); check(w.untangle_phase.is_empty() and w.untangle_cooldown==0 and w.untangle_target==-1,"new round clears all counter state")
	w.free(); w=fresh(); w.practice_line_force=1; w.advance_tick({}, {"untangle":true})
	var reel_before:float=w.fish_line_length
	for frame in 8: w.advance_tick({}, {"release":true})
	check(w.fish_line_length>reel_before and w.reel_speed>0,"S operates the real line while the human QTE runs")
	for frame in 12: w.advance_tick({}, {"reel":true})
	check(w.reel_speed<0 and w.untangle_phase=="check","W reverses the spool during the same QTE")
	w.free(); w=fresh(); var ai=Brain.new(); w.practice_line_force=1
	for frame in 1200:
		w.advance_tick({},ai.command(w,1.0/60))
		if w.round_stats.unwrap_good>0: break
	check(w.round_stats.unwrap_good>0 and w.round_stats.angler_total>0,"single-player AI uses timing and the shared spool to undo a real coil")
	w.free(); w=fresh(); w.ruleset="survival"; w.practice_line_force=1
	for frame in 1200:
		w.advance_tick({},ai.command(w,1.0/60))
		if w.round_stats.unwrap_good>0: break
	check(w.round_stats.unwrap_good>0,"survival AI also counters with the fixed-bank tackle")
	w.free()
	await network_checks()
	print("UNTANGLE_V020 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
func network_checks() -> void:
	var w=fresh(); var session=Session.new(); root.add_child(session); session.game=w
	session.remote_role="angler"; session.session_id="untangle-test"; session.round_id=1
	# Shared current wrapper exercises queue timing after map verification.
	session._select_map(); session.map_validated=true; session.is_host=true; session.status="playing"
	w.advance_tick({}, {"untangle":true}); green(w); w.effort_checks.angler.age+=w.TICK_SECONDS
	w.simulation_tick=100; session._remember_qte(); w.simulation_tick=112; w.effort_checks.angler.age+=0.2
	var packet:Dictionary={"session":session.session_id,"round":1,"seq":1,"command":{"qte":true},"seen_tick":100,"qte_id":w.effort_checks.angler.id,"check_kind":"effort","events":[],"gesture":0}
	session.receive_input(packet); var command:Dictionary=session._take_remote()
	w.advance_tick({},command)
	check(w.untangle_phase=="unwind","late online input uses authoritative historical green timing")
	check(not session._take_remote().qte,"network judgment remains one-shot")
	w.free(); w=fresh(); session.game=w; session.remote_queue.clear(); session.remote_held.clear(); session.effort_history.angler.clear()
	w.advance_tick({}, {"untangle":true}); green(w); w.effort_checks.angler.age+=w.TICK_SECONDS; set_tension(w,0.9)
	w.simulation_tick=100; session._remember_qte(); set_tension(w,0.4); w.simulation_tick=110
	packet.seq=2; packet.qte_id=w.effort_checks.angler.id; packet.command.qte_condition_valid=true
	session.receive_input(packet); command=session._take_remote(); w.advance_tick({},command)
	check(w.untangle_phase=="recover" and not w.effort_checks.angler.good,"historically invalid tension fails even when current tension recovered; client cannot forge eligibility")
	w.free(); w=fresh(); session.game=w; session.remote_queue.clear(); session.remote_held.clear(); session.effort_history.angler.clear()
	w.advance_tick({}, {"untangle":true}); green(w); w.effort_checks.angler.age+=w.TICK_SECONDS
	w.simulation_tick=100; session._remember_qte(); set_tension(w,0.9); w.simulation_tick=110
	packet.seq=3; packet.qte_id=w.effort_checks.angler.id
	session.receive_input(packet); w.advance_tick({},session._take_remote())
	check(w.untangle_phase=="recover","historical success cannot bypass current high tension")
	packet.seq=4; packet.command={"untangle":true}; session.receive_input(packet)
	check(session._take_remote().untangle and not session._take_remote().untangle,"remote F is a one-shot command, not a held retry")
	var original:Dictionary=w.capture_snapshot(); var bad:Dictionary=original.duplicate(true); bad.state.untangle_phase="unknown"
	check(not w.restore_snapshot(bad) and w.capture_snapshot()==original,"bad counter states are rejected atomically")
	bad=original.duplicate(true); bad.state.wraps[0].progress=-0.1
	check(not w.restore_snapshot(bad),"invalid reverse progress cannot enter presentation")
	var a:Dictionary=original.duplicate(true); var b:Dictionary=original.duplicate(true)
	a.state.simulation_tick=100; b.state.simulation_tick=102; a.state.wraps[0].progress=1.0; b.state.wraps[0].progress=0.8
	var presentation=Presentation.new(); presentation.accept(a,0); presentation.accept(b,0.1)
	check(absf(presentation.sample(0.1+1.0/60).wraps[0].progress-0.9)<0.001,"remote coil reverse progress interpolates smoothly")
	presentation.dispose(); session.close(); session.queue_free(); w.free(); await process_frame
