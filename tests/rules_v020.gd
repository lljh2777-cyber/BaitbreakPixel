extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Rules=preload("res://scripts/game_rules.gd")
const Store=preload("res://scripts/rules_store.gd")
const Session=preload("res://scripts/network_session.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Commands=preload("res://scripts/game_commands.gd")
const Main=preload("res://scenes/main.tscn")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("RULE_PASS | ",message)
	else: failed+=1; push_error("RULE_FAIL | "+message)
func fresh(world: Node2D, values: Dictionary={}) -> void:
	world.reset_world({"ruleset":"duel","challenge":true,"rules":values})
func hook(world: Node2D) -> void:
	world.fish=Vector2(250,220); world.baits[0].active=true; world._enter_hook(0); world._attach_hook()
func run() -> void:
	feeding_default_migration()
	check(Rules.defaults()==Rules.normalize({}) and Rules.changed(Rules.normalize({})).is_empty(),"default normalization keeps exact defaults and zero false modifications")
	var ids := {}
	for item in Rules.Catalog.ITEMS: ids[item.id]=true
	check(ids.size()==Rules.Catalog.ITEMS.size(),"catalog keys are unique")
	var a:=World.new(); var b:=World.new()
	for edge in ["min","max"]:
		var extreme := {}
		for item in Rules.Catalog.ITEMS: extreme[item.id]=not item.value if item.value is bool else item[edge]
		var normalized := Rules.normalize(extreme)
		check(Rules.valid(normalized),"all "+edge+" settings remain valid after cross-field constraints")
		fresh(a,normalized); fresh(b)
		for tick in 60: a.advance_tick({"move":Vector2.RIGHT,"dash":true},{"deploy":tick==0,"walk":0.4})
		check(b.restore_snapshot(a.capture_snapshot()),"all "+edge+" settings simulate and restore without invalid values")
	# Every option must survive canonical JSON/profile/snapshot serialization, including nondefault boundaries.
	for item in Rules.Catalog.ITEMS:
		var values := {item.id:not item.value if item.value is bool else item.max}
		fresh(a,values); fresh(b)
		var restored: bool=b.restore_snapshot(a.capture_snapshot())
		var document: Dictionary=Rules.parse_document(JSON.parse_string(JSON.stringify(Rules.document(a.rules))))
		check(restored and a.rules==b.rules and not document.has("error") and Rules.valid(document.values),"roundtrip "+item.id)
	var invalid := Rules.normalize({"stamina_max":NAN,"sprint_speed":"bad","tension_low":0.8,"tension_high":0.1,"untangle_min":0.85,"untangle_max":0.1,"bait_points":5,"food_goal":120,"qte_entry_sweep":0.5,"qte_entry_window":2.0})
	check(invalid.stamina_max==100 and invalid.sprint_speed==140 and invalid.tension_high>=0.85 and invalid.untangle_max>=0.9 and invalid.food_goal==20 and invalid.qte_entry_window<=0.4,"invalid values fall back and dependent thresholds, food and QTE windows stay feasible")
	fresh(a,{"stamina_max":250,"stamina_initial":0.4,"sprint_drain":50,"water_strength":0})
	check(a.stamina==100 and is_equal_approx(a.stamina_ratio(),0.4),"stamina capacity and initial percentage are distinct")
	for tick in 60: a.advance_tick({"move":Vector2.RIGHT,"dash":true},{})
	check(absf(a.stamina-50)<0.001,"custom stamina drain is real points per second")
	a.stamina=0; var tired: float=a.fatigue_factor(); a.stamina=250
	check(a.fatigue_factor()>tired+0.29,"fatigue uses configured capacity")
	fresh(a,{"stamina_max":250,"stamina_initial":0.2,"stamina_recovery":40,"stamina_delay":0})
	for tick in 60: a.advance_tick({}, {})
	check(absf(a.stamina-90)<0.001,"custom recovery restores real points")
	fresh(a,{"swim_speed":40,"water_strength":0}); fresh(b,{"swim_speed":100,"water_strength":0})
	a.fish=Vector2(300,130); b.fish=a.fish
	for tick in 30: a.advance_tick({"move":Vector2.RIGHT},{}); b.advance_tick({"move":Vector2.RIGHT},{})
	check(b.fish.x>a.fish.x+15,"swim speed changes displacement")
	fresh(a,{"suction_range":20,"suction_spread":0.1}); fresh(b)
	check(a.strength(a.mouth()+Vector2(30,0))==0 and b.strength(b.mouth()+Vector2(30,0))>0,"suction range changes real feeding volume")
	fresh(a,{"bait_points":50}); var total:=0.0
	for grain in a.baits[0].grains: total+=grain.points
	check(absf(total-50)<0.001,"bait yield scales every layer without changing particle geometry")
	fresh(a,{"reel_speed":72}); fresh(b)
	for world in [a,b]: world.angler.spool=-1
	check(a.angler.manual_spool_speed(0,2,1,a.rules)==-72 and b.angler.manual_spool_speed(0,2,1,b.rules)==-36,"manual reel settings control physical actuator")
	fresh(a,{"reel_speed":72,"water_strength":0}); fresh(b,{"water_strength":0})
	for world in [a,b]: world.angler.deploy(world)
	for tick in 60: a.advance_tick({},{}); b.advance_tick({},{})
	for tick in 36: a.advance_tick({},{"reel":true}); b.advance_tick({},{"reel":true})
	check(a.angler.free_line_length<b.angler.free_line_length-10,"custom reeling affects unhooked line length")
	fresh(a,{"line_force":2,"line_response":2})
	check(a.line_tuning()==Vector2(2,2),"challenge honors configured reeling instead of silently overriding with defaults")
	fresh(a,{"qte_entry_lead":0.8,"qte_entry_sweep":5,"qte_entry_window":0.4,"qte_entry_random":false,"qte_entry_zone":0.5})
	a._enter_hook(0)
	check(is_equal_approx(a.qte_width,0.08) and a.qte_zone==0.5,"green fraction comes from window seconds divided by custom sweep")
	a.rules.qte_entry_sweep=2.0
	check(a.qte_timing.sweep==5,"active QTE holds its captured timing")
	a.qte_age=3.45
	check(b.restore_snapshot(a.capture_snapshot()),"active long QTE snapshot restores independently of future rules")
	b._step_qte(0,true)
	check(b.hooked==World.HookState.FREE,"long sweep still accepts correct input after old 2.4 second limit")
	check(Commands.fish({"qte_at_age":5.1},Vector2.RIGHT,0.5).qte_at_age==5.1,"command validation supports allowed long QTE ages")
	for kind in ["entry","slack","wrap"]:
		fresh(a,{"qte_"+kind+"_sweep":4,"qte_"+kind+"_random":false,"qte_"+kind+"_zone":0.3})
		a._open_qte(kind); check(a.qte_timing.sweep==4 and a.qte_zone==0.3,"independent regular QTE: "+kind)
	for role in ["fish","angler"]:
		fresh(a,{"qte_"+role+"_effort_sweep":6,role+"_effort_boost":2.0,role+"_effort_boost_seconds":4})
		hook(a); var state: Dictionary=a.effort_checks[role]
		a.Effort.open(state,a.rng,a.effort_tuning(role)); state.age=state.lead+(state.zone+state.width*0.5)*state.sweep
		check(a.Effort.finish(state,true,-1,a.rng) and state.multiplier==2 and state.effect_age==4 and b.restore_snapshot(a.capture_snapshot()),"independent "+role+" effort speed and strength persist in state")
	fresh(a,{"tension_low":0.4,"slack_hold":0.2}); hook(a); a.rope_length+=8
	a._step_line(0.21,false)
	check(a.qte=="slack","custom low threshold and wait trigger slack QTE")
	fresh(a,{"tension_high":0.7,"break_hold":0.4}); hook(a); a.rope_length=0
	a._step_line(0.21,false); check(a.hooked==World.HookState.HOOKED,"custom break timer does not fire early")
	a._step_line(0.21,false); check(a.hooked==World.HookState.FREE and a.round_stats.breaks==1,"continuous high tension uses custom break time")
	fresh(a,{"untangle_min":0.4,"untangle_max":0.7}); a.tension=0.6
	check(a.untangle_tension_valid(),"untangle interval follows independent configured bounds")
	fresh(a,{"unwind_seconds":2.0}); hook(a); a.fish=Vector2(332,245); a._update_contacts(0); a._begin_wrap(); a._commit_wrap()
	a.untangle_phase="unwind"; a.untangle_age=1.0; a.wraps[-1].progress=0.5
	check(is_equal_approx(Motion.action(a).progress,0.5),"custom unwind duration also drives rod and line presentation phase")
	fresh(a,{"net_scale":1.5,"net_manual_speed":80}); fresh(b)
	check(a.net_rim()==b.net_rim()*1.5 and a.net_catch()==b.net_catch()*1.5,"net collision and warning radii scale together")
	a.Net.begin_observation(a); a.begin_manual_net(Vector2(210,140)); a.record_manual_net_point(Vector2(310,140))
	b.Net.begin_observation(b); b.begin_manual_net(Vector2(210,140)); b.record_manual_net_point(Vector2(310,140))
	check(a.net_warning_outline()!=b.net_warning_outline(),"net route warning uses custom capture size")
	fresh(a,{"timer_enabled":false,"time_limit":30}); a.clock=30; a.advance_tick({},{})
	check(not a.match_over,"unlimited-time rounds never trigger timeout")
	fresh(a,{"food_goal":20,"home_hold":0.5}); a.fish=a.HOME; a.score=20; a.returning=true; a._simulate_fish(0.51,Vector2.ZERO,false,false)
	check(a.match_over and a.winner_role=="fish","custom food goal and return duration settle the round")
	var cfg:=ConfigFile.new(); cfg.set_value("practice","line_force",1.7); cfg.set_value("timing","mouth_window",0.4); cfg.set_value("timing","qte_revision",1)
	var migrated:=Store.load_profile(cfg)
	check(is_equal_approx(migrated.line_force,1.7) and migrated.qte_entry_window==0.4 and migrated.qte_slack_window==0.4,"old profile timings and practice values migrate")
	Store.save_profile(cfg,migrated); check(Store.load_profile(cfg)==migrated,"new profile schema has a stable roundtrip")
	var missing_presets := "user://rules-presets-missing-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	check(Store.preset_names(missing_presets).is_empty() and not DirAccess.dir_exists_absolute(missing_presets),"first-use missing preset directory lists no presets without errors or filesystem changes")
	check(Store.save_preset("user://rules-presets-test","rules-regression",migrated)==OK and Store.load_preset("user://rules-presets-test","rules-regression").values==migrated,"named preset saves and reloads JSON")
	check(Store.save_preset("user://rules-presets-test","../unsafe",migrated)!=OK,"preset name cannot escape its directory")
	check(Rules.parse_document({"format":"baitbreak-rules","version":999,"values":{}}).has("error") and Rules.parse_document({"format":"baitbreak-rules","version":1,"values":{"unknown":4}}).has("error"),"unsupported and unknown import values are rejected")
	fresh(a); var baseline: Dictionary=a.capture_snapshot(); var broken: Dictionary=baseline.duplicate(true); broken.state.rules.stamina_max=-10
	check(not a.restore_snapshot(broken) and a.capture_snapshot()==baseline,"invalid rule snapshot cannot partially overwrite world")
	await application_checks()
	a.free(); b.free()
	print("RULES_V020 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func application_checks() -> void:
	var app: Node2D=Main.instantiate(); root.add_child(app); app.capture_mode="rules-test"; app.set_physics_process(false); app.set_process(false); app.save_path="user://rules-v019-test.cfg"
	app.reset(false); app.menu.open("title"); app.menu.open("settings"); app.menu.open("rules")
	app.menu.rules_editor.closed.emit()
	check(app.menu.screen=="settings" and app.menu.previous=="title","returning from rules preserves the settings back destination")
	app.menu.open("rules")
	var editor: Control=app.menu.rules_editor
	check(editor.controls.has("stamina_max"),"settings category builds real editable controls from catalog")
	editor.controls.stamina_max.value=250
	var before: Dictionary=app.capture_snapshot()
	editor._save(false)
	check(app.saved_rules.stamina_max==250 and app.rules.stamina_max==100 and app.capture_snapshot()==before,"saving settings leaves current world and QTE unchanged")
	app.reset(true)
	check(app.stamina==250 and app.rules.stamina_max==250,"next challenge applies saved rules")
	var offline: Dictionary=app.saved_rules.duplicate(true)
	app.start_shared_session("fish",{"ruleset":"duel","rules":{"stamina_max":500}})
	app.menu.open("rules")
	check(app.rules.stamina_max==500 and app.menu.rules_editor.read_only and not app.menu.rules_editor.controls.stamina_max.editable,"client shows host rules as read-only")
	app.save_profile(); var saved:=ConfigFile.new(); saved.load(app.save_path)
	check(Store.load_profile(saved)==offline,"host rules never overwrite offline preferences when saving audio/profile")
	app.reset(false)
	check(app.rules==offline,"leaving room restores local saved rules")
	app.queue_free(); await process_frame

func feeding_default_migration() -> void:
	var file:=ConfigFile.new()
	file.set_value("rules","version",Rules.VERSION)
	for revision in [0,1]:
		file.set_value("rules","feeding_defaults_version",revision)
		for old_range in ([18.0,14.0] if revision==0 else [14.0]):
			file.set_value("rules","values",{"bite_range":old_range,"bite_cooldown":0.4,"water_strength":0.0})
			var values:=Store.load_profile(file)
			check(values.bite_range==12.0 and values.bite_cooldown==0.6 and values.water_strength==0.0,"old feeding defaults migrate sequentially without resetting preferences: "+str(revision)+"/"+str(old_range))
		file.set_value("rules","values",{"bite_range":20.0,"bite_cooldown":0.5,"water_strength":0.0})
		var custom:=Store.load_profile(file)
		check(custom.bite_range==20.0 and custom.bite_cooldown==0.5 and custom.water_strength==0.0,"custom legacy range/cadence remain unchanged: "+str(revision))
		file.set_value("rules","values",{"bite_range":20.0,"bite_cooldown":0.4})
		check(Store.load_profile(file).bite_range==20.0 and Store.load_profile(file).bite_cooldown==0.6,"cadence migrates independently of custom range")
		file.set_value("rules","values",{"bite_range":14.0,"bite_cooldown":0.5})
		check(Store.load_profile(file).bite_range==12.0 and Store.load_profile(file).bite_cooldown==0.5,"range migrates independently of custom cadence")
	file.set_value("rules","feeding_defaults_version",1)
	file.set_value("rules","values",{"bite_range":18.0,"bite_cooldown":0.5})
	check(Store.load_profile(file).bite_range==18.0,"revision1 explicit18 is not treated as unstamped legacy default")
	for old_range in [14.0,18.0]:
		var explicit:=Rules.normalize({"bite_range":old_range,"bite_cooldown":0.4})
		Store.save_profile(file,explicit)
		check(file.get_value("rules","feeding_defaults_version")==2 and Store.load_profile(file)==explicit,"new explicit old values survive stamped save/load: "+str(old_range))
	var preset:=Rules.parse_document(Rules.document({"bite_range":14.0,"bite_cooldown":0.4}))
	check(not preset.has("error") and preset.values.bite_range==14.0 and preset.values.bite_cooldown==0.4,"named/imported rules retain explicit old defaults")
