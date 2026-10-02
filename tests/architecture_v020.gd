extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Main=preload("res://scenes/main.tscn")
const Commands=preload("res://scripts/game_commands.gd")
const FishBrain=preload("res://scripts/fish_brain.gd")
const AnglerBrain=preload("res://scripts/angler_brain.gd")
const Snapshot=preload("res://scripts/world_snapshot.gd")
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("ARCH_PASS | ",message)
	else: failed+=1; push_error("ARCH_FAIL | "+message)

func config() -> Dictionary:
	return {"ruleset":"duel","challenge":true,"seed":8675309,"slack_hold":0.7,"mouth_window":0.6,"break_hold":4.0,"water_strength":1.0}

func same(a: Node2D, b: Node2D) -> bool:
	return var_to_bytes(a.capture_snapshot())==var_to_bytes(b.capture_snapshot())

func replay_pair(a: Node2D, b: Node2D, count: int) -> bool:
	for frame in count:
		var fish: Dictionary={"move":Vector2(cos(frame*0.07),sin(frame*0.05)),"aim":Vector2.RIGHT,"power":0.8,"suck":frame%6<3,"dash":frame%71<9,"qte":frame%139==113}
		var angler: Dictionary={"walk":sin(frame*0.03),"reel":frame%90<30,"release":frame%90>65}
		if a.manual_net: angler.merge({"net_hold":true,"drag":true,"target":a.net_aim})
		a.advance_tick(fish,angler)
		b.advance_tick(fish,angler)
		if not same(a,b):
			print("DIVERGED | tick=",a.simulation_tick)
			return false
	return true

func roundtrip(a: Node2D, b: Node2D, label: String, frames: int=90) -> void:
	var payload: Dictionary=bytes_to_var(var_to_bytes(a.capture_snapshot()))
	var restored: bool=b.restore_snapshot(payload)
	check(restored and same(a,b),label+" restores every simulation field")
	check(replay_pair(a,b,frames),label+" resumes identically under the same commands")

func run() -> void:
	var a:=World.new()
	var b:=World.new()
	a.reset_world(config()); b.reset_world(config())
	var transient: Array[String]=[]
	for field in a.get_script().get_script_property_list():
		if not field.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
		if not field.name in ["targets","angler","rng"] and not field.name in World.Rules.LEGACY_PROPERTIES and not field.name in Snapshot.WORLD_FIELDS: transient.append(field.name)
	for field in a.angler.get_script().get_script_property_list():
		if field.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not field.name in Snapshot.RIG_FIELDS: transient.append(field.name)
	check(transient.is_empty(),"snapshot schema covers every mutable world and rig field: "+str(transient))
	a.set_escape_timing(2,0.9,9); a.set_practice_line_tuning(2,2); a.water_strength=2
	a.angler.cast_from=Vector2(90,100); a.result_good=true
	a.reset_world(config()); b.reset_world(config())
	check(same(a,b),"new match config fully resets prior rules, rig and effect state")
	check(a.get_child_count()==0 and not a.is_inside_tree(),"world runs without scene tree, UI, audio or input nodes")
	var ticks: int=a.simulation_tick
	var pos: Vector2=a.fish
	a.advance_tick({"move":Vector2.RIGHT,"power":0.9},{"deploy":true,"walk":1})
	check(a.simulation_tick==ticks+1 and a.fish.x>pos.x and a.angler.casting and a.angler.x>206,"one tick applies independent fish and angler commands together")
	check(a.power==0.9,"external fish suction power is not overwritten by AI defaults")
	check(a.get("player_role")==null,"world has no local player role")
	var initial: Dictionary=a.capture_snapshot()
	check(not initial.state.has("volume") and not initial.state.has("save_path") and not initial.state.has("player_role"),"snapshot excludes local settings, profile paths and viewing role")
	check(Snapshot.plain(initial),"snapshot contains only serializable values and stable identifiers")
	initial.state.baits[0].grains[0].eaten=true
	initial.state.net_route.append(Vector2(123,123))
	check(not a.baits[0].grains[0].eaten and a.net_route.is_empty(),"snapshot nested food data and packed route arrays are detached from the live world")
	roundtrip(a,b,"partially deployed inertial rig",120)
	a.reset_world(config()); a.fish=Vector2(70,95)
	a.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(210,110)},{"kind":"point","point":Vector2(310,110)}]})
	check(a.net_from==Vector2(210,110) and a.net_route.size()==2,"command batch commits exactly two route endpoints")
	roundtrip(a,b,"queued net route",100)
	a.reset_world(config()); a.fish=Vector2(232,180); a.baits[0].active=true; a._enter_hook(0)
	check(a.qte_id==1,"each new QTE receives a stable sequence number")
	roundtrip(a,b,"entry QTE with random success zone",160)
	a.reset_world(config()); a.fish=Vector2(332,245); a.baits[0].active=true; a._enter_hook(0); a._attach_hook()
	a._update_contacts(0)
	check(a._begin_wrap(),"wrap fixture contacts actual cover")
	a.qte_age=0.4+(a.qte_zone+a.qte_width*0.5)*2; a._step_qte(0,true)
	check(a.wraps.size()==1,"wrap QTE commits a real coil before snapshot")
	roundtrip(a,b,"hooked fish and animated wrap",100)
	a.reset_world(config()); a.fish=Vector2(260,140); a.fish_before=a.fish
	a.Net.begin_observation(a); a.begin_manual_net(Vector2(210,140)); a.record_manual_net_point(Vector2(310,140))
	# Entry, warning and sustained contact now precede the actual capture.
	for frame in 300:
		a._step_net(1.0/120)
		if a.net_state=="caught": break
	check(a.net_state=="caught","capture fixture enters real net lifting")
	roundtrip(a,b,"net capture and lift",180)
	a.reset_world(config()); a.baits[1].grains[0].free=true; a.baits[1].grains[1].eaten=true; a.score=3.5; a.counted[a.baits[1].grains[1].id]=true
	roundtrip(a,b,"detached food and score ownership",90)
	var valid: Dictionary=a.capture_snapshot()
	# net_aim remains part of the schema-13 wire contract even when the current
	# two-point net action no longer consumes the old drag target.
	check(Snapshot.SCHEMA==13 and valid.state.has("net_aim"),"schema 13 retains legacy net_aim for same-build snapshot compatibility")
	var legacy_aim: Dictionary=valid.duplicate(true)
	legacy_aim.state.net_aim=Vector2(418,173)
	check(b.restore_snapshot(legacy_aim) and b.capture_snapshot().state.net_aim==Vector2(418,173),"schema 13 roundtrips nondefault legacy net_aim without silently dropping it")
	b.restore_snapshot(valid)
	var broken: Dictionary=valid.duplicate(true); broken.schema=999
	check(not b.restore_snapshot(broken) and same(a,b),"unknown snapshot schema is rejected without partial changes")
	broken=valid.duplicate(true); broken.state.erase("tension")
	check(not b.restore_snapshot(broken) and same(a,b),"incomplete snapshots cannot partially overwrite the world")
	broken=valid.duplicate(true); broken.state.fish=Vector2(NAN,1)
	check(not b.restore_snapshot(broken) and same(a,b),"non-finite snapshot values are rejected")
	var emissions: Array[String]=[]
	b.feedback_requested.connect(func(cue: String): emissions.append(cue))
	b.match_ended.connect(func(_winner: String,_reason: String): emissions.append("result"))
	check(b.restore_snapshot(valid) and emissions.is_empty(),"restoring state produces no sound, result or profile side effects")
	valid.state.baits[0].grains[0].eaten=not valid.state.baits[0].grains[0].eaten
	check(same(a,b),"restored world does not retain references to the supplied snapshot")
	a.reset_world(config()); a._open_qte("entry"); var seed_snapshot: Dictionary=a.capture_snapshot(); a._open_qte("slack")
	b.restore_snapshot(seed_snapshot); b._open_qte("slack")
	check(a.qte_zone==b.qte_zone and a.qte_id==b.qte_id,"RNG state and QTE numbering survive snapshot restoration")
	var fish_bad:=Commands.fish({"move":Vector2(INF,0),"power":NAN,"aim":Vector2(NAN,0)},Vector2.RIGHT,0.6)
	var angler_bad:=Commands.angler({"walk":5,"target":Vector2(INF,0),"net_events":[{}, {"kind":"point","point":"wrong"}]},Vector2(200,100))
	check(fish_bad.move==Vector2.ZERO and fish_bad.power==0.6 and fish_bad.aim==Vector2.RIGHT and angler_bad.walk==1 and angler_bad.net_events.is_empty(),"all command sources share finite-value and movement-limit normalization")
	a.reset_world({"ruleset":"survival","challenge":true,"seed":10}); a.fish=Vector2(200,170)
	var fish_ai:=FishBrain.new(); fish_ai.reset(12)
	var angler_ai:=AnglerBrain.new()
	a.advance_tick(fish_ai.command(a,World.TICK_SECONDS),angler_ai.command(a,World.TICK_SECONDS))
	check(a.simulation_tick==1 and a.angler.auto_reel and a.angler.auto_net,"both AI command providers use the same tick entry as external commands")
	a.reset_world(config()); a.match_paused=true; ticks=a.simulation_tick; pos=a.fish
	a.advance_tick({"move":Vector2.RIGHT},{"walk":1})
	check(a.simulation_tick==ticks and a.fish==pos and a.angler.x==206,"explicit match pause freezes both sides atomically")
	var source:=FileAccess.get_file_as_string("res://scripts/world_simulation.gd")
	check(not "Input." in source and not "menu." in source and not "save_profile" in source and not "player_role" in source,"simulation module remains independent of local UI, input and profile operations")
	await test_view_roles()
	a.free(); b.free()
	print("ARCHITECTURE_V020_TESTS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func test_view_roles() -> void:
	var fish_view: Node2D=Main.instantiate()
	var human_view: Node2D=Main.instantiate()
	root.add_child(fish_view); root.add_child(human_view)
	for view in [fish_view,human_view]:
		view.capture_mode="architecture"
		view.set_physics_process(false); view.set_process(false)
		view.save_path="user://architecture-v011-"+str(view.get_instance_id())+".cfg"
	fish_view.start_shared_session("fish",config()); human_view.start_shared_session("angler",config())
	check(same(fish_view,human_view),"opposite viewing roles create exactly the same configured world")
	var before: Dictionary=fish_view.capture_snapshot()
	fish_view.menu.open("help")
	check(fish_view.capture_snapshot()==before and not fish_view.match_paused,"opening local help does not mutate or pause a shared world")
	fish_view.menu.open("timing")
	check(fish_view.menu.screen=="help","shared session does not allow local timing sliders to change match rules")
	check(replay_pair(fish_view,human_view,90),"same two-sided commands evolve identically even while one view has a menu open")
	var tick: int=fish_view.simulation_tick
	fish_view.restart_round()
	check(fish_view.simulation_tick==tick,"local restart cannot reset a shared match")
	fish_view.menu.close()
	fish_view.finish(false,"net"); human_view.finish(false,"net")
	check(fish_view.winner_role=="angler" and human_view.winner_role=="angler" and fish_view.lost and human_view.won,"one canonical winner gives opposite, correct local results")
	var wins: int=human_view.angler_wins
	human_view.finish(false,"net")
	check(human_view.angler_wins==wins,"repeated finish does not duplicate local win records")
	fish_view.start_shared_session("fish",config()); human_view.start_shared_session("angler",config())
	for view in [fish_view,human_view]:
		view.clock=view.TIME_LIMIT-0.001
		view.advance_tick({}, {})
	check(fish_view.winner_role=="fish" and human_view.winner_role=="fish" and fish_view.won and human_view.lost,"duel timeout winner depends on match rules, not local role")
	fish_view.queue_free(); human_view.queue_free()
	await process_frame
