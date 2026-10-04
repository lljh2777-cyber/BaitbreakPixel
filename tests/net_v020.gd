extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Net=preload("res://scripts/net_simulation.gd")
const Rules=preload("res://scripts/game_rules.gd")
const Session=preload("res://scripts/network_session.gd")
const InputSource=preload("res://scripts/local_input.gd")
var passed:=0
var failed:=0
var w: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("NET20_PASS | ",title)
	else: failed+=1; push_error("NET20_FAIL | "+title)
func fresh(extra: Dictionary={}) -> void:
	var values := {"water_strength":0.0,"net_reach":620.0,"net_sight":680.0,"timer_enabled":false}
	values.merge(extra,true)
	w.reset_world({"ruleset":"duel","challenge":true,"rules":values})
	w.fish=Vector2(480,130); w.fish_before=w.fish
func events(items: Array) -> void: w.advance_tick({}, {"net_events":items})
func plan(a: Vector2, b: Vector2) -> void:
	events([{"kind":"toggle"},{"kind":"point","point":a},{"kind":"point","point":b}])
func advance(count: int, fish_input: Dictionary={}, angler_input: Dictionary={}) -> void:
	for i in count: w.advance_tick(fish_input,angler_input)
func fixture(fish: Vector2) -> void:
	fresh(); w.fish=fish; w.fish_before=fish
	plan(Vector2(210,140),Vector2(310,140))
func run() -> void:
	w=World.new()
	fresh(); events([{"kind":"toggle"}])
	check(w.net_action.observing and w.net_state=="wait","E opens observation without spawning a net")
	var before: Vector2=w.fish
	advance(15,{"move":Vector2.RIGHT})
	check(w.fish.x>before.x+2 and w.net_action.age>0.2,"fish and observation timer continue simultaneously")
	events([{"kind":"point","point":Vector2(210,140)}])
	check(w.net_action.has_a and w.net_action.observing,"first click selects A without sweeping")
	advance(2)
	check(w.net_action.has_a,"button release / neutral input does not cancel A")
	events([{"kind":"point","point":Vector2(310,140)}])
	check(w.net_state=="warning" and not w.net_action.observing and w.angler.net_cooldown>5,"B commits a two-point route and starts cooldown")
	var end: Vector2=w.net_to
	events([{"kind":"point","point":Vector2(390,210)},{"kind":"cancel"}])
	check(w.net_to==end and w.net_state=="warning","extra clicks and releases cannot steer or cancel committed net")
	advance(28)
	check(w.net_state=="sweep" and w.net_count==1,"sweep begins after configured warning")
	advance(42)
	check(w.net_state in ["miss","withdraw"],"net stops at B without lingering for old drag timer")
	fresh(); events([{"kind":"toggle"},{"kind":"toggle"}])
	check(not w.net_action.observing and w.angler.net_cooldown>5,"cancelling observation consumes cooldown")
	events([{"kind":"toggle"}]); check(not w.net_action.observing,"cooldown prevents repeated sonar observations")
	fresh({"net_observe_time":0.8}); events([{"kind":"toggle"}]); advance(49)
	check(not w.net_action.observing and w.angler.net_cooldown>5,"timeout closes observation and consumes cooldown")
	fresh(); events([{"kind":"toggle"},{"kind":"point","point":Vector2(337,200)}])
	check(not w.net_action.has_a,"solid wood cannot be used as a net spawn point")
	events([{"kind":"point","point":Vector2(210,210)},{"kind":"point","point":Vector2(212,210)}])
	check(w.net_action.observing and w.net_action.has_a,"near-zero-length sweeps remain uncommitted")
	test_obstacle()
	fresh({"net_reach":180}); events([{"kind":"toggle"},{"kind":"point","point":Vector2(550,140)}])
	check(not w.net_action.has_a,"out-of-reach clicks cannot spawn a remote net")
	fresh({"net_max_path":50}); events([{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)}])
	var preview: Dictionary=Net.preview(w,Vector2(450,140))
	events([{"kind":"point","point":Vector2(450,140)}])
	check(w.net_to==preview.b and is_equal_approx(w.net_from.distance_to(w.net_to),50),"preview and commit use same clamped maximum route")
	fixture(Vector2(260,140)); advance(75)
	check(w.net_state=="caught" and w.net_catches==1,"unhooked stationary fish crossing front opening is captured")
	check(w.hooked==w.HookState.FREE,"net capture does not fake a hooked state")
	var copy:=World.new()
	check(copy.restore_snapshot(w.capture_snapshot()),"capture/lift state restores in snapshot")
	advance(240)
	check(w.match_over and w.winner_role=="angler" and w.reason=="net","captured free fish completes net win")
	fixture(Vector2(210,140)); advance(45)
	check(w.net_catches==0,"spawning directly on a fish does not count as entering mouth")
	fixture(Vector2(260,168)); advance(52)
	check(w.net_catches==0 and w.net_action.rim_hit and w.net_action.slow_age>0,"side contact pushes/slows without capturing")
	var hit_y: float=w.fish.y
	advance(10,{"move":Vector2.RIGHT})
	check(w.fish.y>hit_y and w.velocity.x>0,"rim push is physical while fish retains movement control")
	advance(50)
	check(w.net_action.slow_age==0 and w.net_action.impulse.length()==0,"push and slow recover without persistent lock")
	fixture(Vector2(260,140)); advance(55,{"move":Vector2.UP,"dash":true})
	check(w.net_catches==0,"full-speed fish can dodge a committed warning lane")
	fresh(); w.net_angle=0; w.net_pos=Vector2(260,140); w.net_state="sweep"
	Net.contact(w,Vector2(240,140),Vector2(270,140),w.net_pos,w.net_pos)
	check(w.net_catches==0 and w.net_action.rim_hit,"back-to-front crossing only contacts the bag")
	fresh(); w.net_angle=0; w.net_pos=Vector2(260,140); w.net_state="sweep"
	Net.contact(w,Vector2(300,140),Vector2(240,140),w.net_pos,w.net_pos)
	check(w.net_catches==1,"fast relative crossing cannot tunnel through the opening")
	test_tackle()
	fresh(); events([{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)}])
	check(copy.restore_snapshot(w.capture_snapshot()) and copy.net_action==w.net_action,"observation phase and selected A are replicated")
	var identical:=true
	for i in 120:
		var command: Dictionary={"net_events":[{"kind":"point","point":Vector2(310,140)}]} if i==0 else {}
		w.advance_tick({},command); copy.advance_tick({},command)
		if var_to_bytes(w.capture_snapshot())!=var_to_bytes(copy.capture_snapshot()): identical=false
	check(identical,"snapshot resumes observation, commitment and sweep deterministically")
	var corrupt: Dictionary=w.capture_snapshot(); corrupt.state.net_action.impulse=Vector2(2000,0)
	check(not copy.restore_snapshot(corrupt),"invalid net impulses rejected before restore")
	check(Rules.parse_document({"format":"baitbreak-rules","version":1,"values":{"stamina_max":250,"net_capture_base":0.8,"net_prepare":1.0}}).values.stamina_max==250,"old presets migrate without keeping retired capture knobs")
	check(not Rules.defaults().has("net_capture_base") and Rules.defaults().has("net_observe_time"),"settings expose only active net rules")
	fresh(); w.fish=Vector2(337,220)
	check(Net.visibility(w,w.fish)==0,"fish inside wood is hidden from observation/AI")
	w.rules.net_sight=180
	check(Net.visibility(w,Vector2(550,250))==0,"fish outside sight range gives no silhouette")
	test_input_and_network()
	fresh(); w.fish=Vector2(280,170); w.request_net(); advance(100)
	check(w.net_count==1,"practice N schedules the same two-point action without holding E")
	copy.free(); w.free()
	print("NET_V020 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func test_obstacle() -> void:
	fresh(); plan(Vector2(230,210),Vector2(420,210))
	check(w.net_blocked and w.net_to.x<305,"preview clips at first inflated wood contact")
	var clear:=true
	for i in 240:
		w.advance_tick({},{})
		if w.net_state in ["sweep","miss","withdraw"] and Net.manual_net_blocked(w,w.net_pos): clear=false
	check(clear,"sweep and retreat remain outside wood/stone")

func test_tackle() -> void:
	fresh(); w.baits[0].active=true
	events([{"kind":"toggle"}]); advance(20,{}, {"reel":true})
	check(w.angler.spool<0 and w.angler.free_reel_speed<0,"W still reels during observation before bite")
	events([{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}])
	advance(20,{}, {"reel":true})
	check(w.angler.spool==0 and w.angler.reel_hand_amount==0,"committed net owns left hand and blocks active winding")
	# Test the original exclusion explicitly: a live net must no longer disable hook entry.
	w.hook_cooldown=0; w.fish=Vector2(480,160); w.aim=Vector2.RIGHT
	var bait: Dictionary=w.baits[0]; bait.pos=w.mouth()+Vector2(1,-1); bait.home=bait.pos; bait.tip_before=w._tip(0)
	w.angler.hook_velocity=Vector2.ZERO; w.angler.free_line_length=600
	w._step_bait(0,0.001,false,w.mouth())
	check(w.hooked==w.HookState.MOUTH,"fish may enter hook during active net sweep")
	fresh(); w.baits[0].active=true; w.fish=Vector2(270,170); w._enter_hook(0); w._attach_hook()
	w.rope_length=w.angler.anchor().distance_to(w.mouth())-5
	plan(Vector2(390,130),Vector2(490,130))
	advance(5,{}, {"reel":true})
	check(w.hooked==w.HookState.HOOKED and w.rope_path.size()>=2 and w.line_pull_velocity().length()>0,"hooked fish retains rope and pull during net action")

func test_input_and_network() -> void:
	if not InputMap.has_action("use"):
		InputMap.add_action("use")
		var mapping:=InputEventKey.new(); mapping.physical_keycode=KEY_E; InputMap.action_add_event("use",mapping)
	var source:=InputSource.new()
	var key:=InputEventKey.new(); key.physical_keycode=KEY_E; key.pressed=true
	source.handle(key,"angler",Vector2.ZERO)
	var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false
	source.handle(release,"angler",Vector2(210,140))
	check(source.net_events.size()==1 and source.net_events[0].kind=="toggle","E is a discrete action and left release sends no cancel")
	var session:=Session.new(); session.game=w; root.add_child(session)
	session.session_id="net20"; session.round_id=1; session.remote_role="angler"
	# Shared current wrapper exercises net events after map verification.
	session._select_map(); session.map_validated=true; session.is_host=true; session.status="playing"
	var packet := {"session":"net20","round":1,"seq":1,"command":{},"events":[{"kind":"toggle","gesture":1},{"kind":"point","point":Vector2(210,140),"gesture":2}],"seen_tick":0,"qte_id":0,"gesture":2}
	session.receive_input(packet)
	var command: Dictionary=session._take_remote()
	check(command.net_events.size()==2,"remote E and A survive one command batch in order")
	packet.seq=2; packet.events=[{"kind":"point","point":Vector2(210,140),"gesture":2}]
	session.receive_input(packet); command=session._take_remote()
	check(command.net_events.is_empty(),"replayed click cannot accidentally commit B")
	session.close(); session.queue_free()
