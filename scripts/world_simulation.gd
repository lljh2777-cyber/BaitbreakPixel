extends Node2D

const Rules = preload("res://scripts/game_rules.gd")
var rules := Rules.defaults()
var qte_timing := Rules.qte(Rules.defaults(),"entry")

const Effort = preload("res://scripts/effort_check.gd")
const Net = preload("res://scripts/net_simulation.gd")
var net_action := Net.fresh()

const Stats = preload("res://scripts/round_stats.gd")
const Rope = preload("res://scripts/rope.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const AnglerController = preload("res://scripts/angler_rig.gd")
enum HookState { FREE, MOUTH, HOOKED }
const HOME := Layout.HOME
const TARGET := 60.0
const TIME_LIMIT := 360.0
const SOLIDS: Array = Layout.SOLIDS
const HOOK_SCALE := 0.70
const BITE_RADIUS := 7.0
const NET_RIM := Vector2(8,24)
const NET_CATCH := Vector2(8,24)
const NET_PREPARE := 0.8
const NET_WARNING := 2.2
const NET_SWEEP := 1.6
const NET_WITHDRAW := 1.0
const NET_LIFT := 1.15
const NET_SETTLE := 0.32
const NET_MISS := 0.22
const LINE_ELASTIC_PIXELS := 32.0
const MAX_LINE_LENGTH := 720.0

var fish := Layout.SPAWN
var angler := AnglerController.new()
var net_aim := Vector2.ZERO
var manual_net := false
var net_trail := PackedVector2Array()
var net_return_path := PackedVector2Array()
var net_exit_path := PackedVector2Array()
var net_route := PackedVector2Array()
var net_route_next := 1
const MANUAL_NET_WARNING := 0.55
const MANUAL_NET_SECONDS := 5.0
const MANUAL_NET_SPEED := 160.0
var velocity := Vector2.ZERO
var aim := Vector2.RIGHT
var power := 0.35
var stamina := 100.0
var sprinting := false
var sprint_exhausted := false
var stamina_delay := 0.0
const SPRINT_SPEED := 140.0
const SPRINT_DRAIN := 28.0
var water_strength: float:
	get: return rule("water_strength")
	set(value): rules["water_strength"]=value
var fish_before := Vector2.ZERO
var hooked := HookState.FREE
var bound_bait := -1
var hook_cooldown := 0.0
var rope_path := PackedVector2Array()
var rope_length := 0.0
var tension := 0.0
var reel_speed := 0.0
var practice_line_sensitivity: float:
	get: return rule("line_response")
	set(value): rules["line_response"]=value
var practice_line_force: float:
	get: return rule("line_force")
	set(value): rules["line_force"]=value
var practice_effort_frequency: float:
	get: return rule("fish_effort_frequency")
	set(value): rules["fish_effort_frequency"]=value
var practice_effort_window: float:
	get: return rule("qte_fish_effort_window")
	set(value): rules["qte_fish_effort_window"]=value
var practice_effort_boost: float:
	get: return rule("fish_effort_boost")
	set(value): rules["fish_effort_boost"]=value
var practice_effort_weak: float:
	get: return rule("fish_effort_weak")
	set(value): rules["fish_effort_weak"]=value
var round_stats := Stats.fresh()
var net_capture := 0.0
var slack_hold_seconds: float:
	get: return rule("slack_hold")
	set(value): rules["slack_hold"]=value
var mouth_window_seconds: float:
	get: return rule("qte_entry_window")
	set(value): rules["qte_entry_window"]=value
var break_hold_seconds: float:
	get: return rule("break_hold")
	set(value): rules["break_hold"]=value
var qte_width := 0.2
var qte_result_width := 0.2
var bait_batch := 0
var latched := false
var high_age := 0.0
var low_age := 0.0
var retry_age := 0.0
var landing_age := 0.0
var landing := false
var landing_from := Vector2.ZERO
var resisting := false
var feeding := false
var line_catches := 0
var qte := ""
var qte_age := 0.0
var qte_zone := 0.60
var qte_origin := Vector2.ZERO
var qte_result := ""
var qte_result_kind := ""
var qte_result_zone := 0.0
var qte_result_progress := 0.0
var qte_result_age := 0.0
var qte_result_good := false
var targets: Array[Dictionary] = []
var target_opacity: Array[float] = []
var contact_target := -1
var wrap_target := -1
var wrap_retry := 0.0
var wraps: Array[Dictionary] = []
var fish_line_length := 0.0
var untangle_phase := ""
var untangle_target := -1
var untangle_age := 0.0
var untangle_cooldown := 0.0
const UNTANGLE_MIN := 0.25
const UNTANGLE_MAX := 0.55
const UNWIND_SECONDS := 0.7
const UNTANGLE_COOLDOWN := 3.0
const WIND_SECONDS := 0.85
var result_flash := 0.0
var result_good := false
var baits: Array[Dictionary] = []
var supply_queue: Array[int] = [2, 3]
var cycle_slot := -1
var cycle_age := 0.0
var cycle_phase := ""
var score := 0.0
var counted: Dictionary = {}
var clock := 0.0
var elapsed := 0.0
var started := false
var challenge := false
var returning := false
var home_age := 0.0
var reason := ""
var notice := ""
var notice_age := 0.0
var hook_count := 0
var escape_count := 0
var net_state := "wait"
var net_age := 0.0
var net_wait := 0.0
var net_recovery := 0.0
var net_queued := false
var net_count := 0
var net_from := Vector2.ZERO
var net_to := Vector2.ZERO
var net_pos := Vector2.ZERO
var net_pulse := 0.0
var net_kind := "sweep"
var net_blocked := false
var net_return_from := Vector2.ZERO
var net_catch_offset := Vector2.ZERO
var net_dodges := 0
var net_catches := 0
var net_angle := 0.0
var net_park := Vector2.ZERO
var net_retract_duration := 1.0
var net_splash := 0.0
var net_splash_at := Vector2.ZERO
var net_last_position := Vector2.ZERO
var net_motion := Vector2.ZERO
var net_warning_shape := PackedVector2Array()
var rng := RandomNumberGenerator.new()

signal feedback_requested(cue: String)
signal match_ended(winner: String, cause: String)
const Commands = preload("res://scripts/game_commands.gd")
const Snapshot = preload("res://scripts/world_snapshot.gd")
const TICK_SECONDS := 1.0/60.0
var ruleset := "survival"
var match_over := false
var winner_role := ""
var match_paused := false
var simulation_tick := 0
var qte_id := 0
var qte_grace_seconds := 0.0
var effort_checks := {"fish":Effort.fresh(),"angler":Effort.fresh()}

func _init() -> void:
	targets=Layout.interaction_targets()

# Compatibility properties above are aliases only; no duplicate tuning state.
func rule(key: String) -> float: return float(rules[key])
func stamina_ratio() -> float: return clampf(stamina/rule("stamina_max"),0,1)
func fatigue_factor() -> float: return lerpf(rule("fatigue_speed"),1.0,clampf(stamina_ratio()/rule("fatigue_threshold"),0,1))
func food_target() -> float: return rule("food_goal") if challenge else rule("practice_goal")
func net_rim() -> Vector2: return NET_RIM*rule("net_scale")
func net_catch() -> Vector2: return NET_CATCH*rule("net_scale")

func uses_mobile_tackle() -> bool: return ruleset=="duel"

func play_feedback(cue: String) -> void: feedback_requested.emit(cue)

func effort_multiplier(role: String) -> float:
	if role=="angler" and hooked==HookState.HOOKED and not landing and net_state!="caught":
		if untangle_phase in ["check","unwind"]: return rule("untangle_force")
		if untangle_phase=="recover": return 0.60
	return float(effort_checks[role].multiplier) if hooked==HookState.HOOKED and not landing and net_state!="caught" and effort_checks[role].effect_age>0 else 1.0

func _cancel_effort(role: String) -> void:
	var state: Dictionary=effort_checks[role]
	if state.active:
		state.active=false
		state.wait=maxf(state.wait,3.0)
		state.result_age=0.0

func _tick_efforts(delta: float, fish_input: Dictionary, angler_input: Dictionary) -> void:
	if hooked!=HookState.HOOKED or landing or net_state=="caught":
		for role in effort_checks: Effort.reset(effort_checks[role])
		return
	var target := line_anchor(bound_bait) if wraps.is_empty() else Vector2(wraps[-1].entry)
	var opposing: float=-Vector2(fish_input.move).dot((target-mouth()).normalized())
	var attempts := {"fish":opposing>0.25 and stamina>0,"angler":angler.spool<0 or (angler.auto_reel and not Net.busy(self) and reel_speed< -0.5)}
	for role in ["fish","angler"]:
		var state: Dictionary=effort_checks[role]
		state.effect_age=maxf(0,state.effect_age-delta)
		state.result_age=maxf(0,state.result_age-delta)
		if state.effect_age<=0: state.multiplier=1.0
		if role=="angler" and not untangle_phase.is_empty(): continue
		if role=="fish" and not qte.is_empty(): _cancel_effort(role); continue
		var command: Dictionary=fish_input if role=="fish" else angler_input
		if state.active:
			state.age+=delta
			var pressed: bool=command.qte
			command.qte=false # One Space judges one check; never also starts wrapping.
			if pressed or state.age>=float(state.lead)+float(state.sweep)+qte_grace_seconds:
				var good := Effort.finish(state,pressed,command.get("qte_at_age",-1.0),rng)
				Stats.record(round_stats,role,good)
				play_feedback(("effort_good_" if good else "effort_bad_")+role)
		elif state.effect_age<=0 and state.result_age<=0 and attempts[role] and not command.qte:
			state.wait=maxf(0,state.wait-delta*float(effort_tuning(role).frequency))
			if state.wait<=0:
				Effort.open(state,rng,effort_tuning(role))
				play_feedback("qte_"+role)

func effort_ai_press(role: String) -> bool:
	var state: Dictionary=effort_checks[role]
	if not state.active: return false
	var skilled: bool=posmod(state.id*37+int(rng.seed)%100+(19 if role=="angler" else 0),100)<rule("ai_effort_skill")*100
	var threshold: float=state.zone+state.width*0.5 if skilled else maxf(0.01,state.zone-0.06)
	return Effort.progress(state)>=threshold

func skill_check(role: String) -> Dictionary:
	var state: Dictionary=effort_checks[role]
	if role=="fish" and (not qte.is_empty() or (qte_result_age>0 and not state.active)):
		return {"active":not qte.is_empty(),"id":qte_id,"kind":qte if not qte.is_empty() else qte_result_kind,
			"age":qte_age,"lead":qte_timing.lead,"zone":qte_zone if not qte.is_empty() else qte_result_zone,"width":qte_width if not qte.is_empty() else qte_result_width,
			"progress":qte_progress() if not qte.is_empty() else qte_result_progress,"result_age":qte_result_age,"good":qte_result_good,"result":qte_result,"origin":qte_origin}
	return {"active":state.active,"id":state.id,"kind":state.kind,"age":state.age,"lead":state.lead,"zone":state.zone,"width":state.width,
		"progress":Effort.progress(state) if state.active else state.progress,"result_age":state.result_age,"good":state.good,
		"result":state.message if state.kind=="untangle" else ("发力成功" if state.good else "短暂脱力"),"origin":Vector2(452,83) if fish.x<320 else Vector2(12,83)}

func untangle_tension_valid() -> bool:
	return tension>=rule("untangle_min") and tension<=rule("untangle_max")

func can_untangle() -> bool:
	var state: Dictionary=effort_checks.angler
	return hooked==HookState.HOOKED and not landing and not match_over and not wraps.is_empty() and not winding() and untangle_phase.is_empty() and untangle_cooldown<=0 and not state.active and state.effect_age<=0 and state.result_age<=0 and net_state in ["wait","rest"] and not angler.net_held

func _begin_untangle() -> bool:
	if not can_untangle(): return false
	untangle_phase="check"
	untangle_target=wraps[-1].target
	untangle_age=0.0
	Effort.open(effort_checks.angler,rng,effort_tuning("angler","untangle"))
	effort_checks.angler.kind="untangle"
	play_feedback("qte_angler")
	return true

func _reset_untangle() -> void:
	# An interrupted animation has not earned a removed coil.
	if untangle_phase=="unwind":
		for coil in wraps:
			if coil.target==untangle_target: coil.progress=1.0
		_rebuild_rope()
	if effort_checks.angler.kind=="untangle": Effort.reset(effort_checks.angler)
	untangle_phase=""
	untangle_target=-1
	untangle_age=0.0

func _judge_untangle(pressed: bool, judged_age: float = -1.0, failure: String = "") -> void:
	var state: Dictionary=effort_checks.angler
	var good := Effort.finish(state,pressed,judged_age,rng)
	good=good and untangle_tension_valid() and failure.is_empty()
	state.good=good
	state.multiplier=1.0
	state.effect_age=0.0
	state.message="解开一圈" if good else (failure if not failure.is_empty() else "张力不合适" if pressed and not untangle_tension_valid() else "判定失败")
	Stats.record(round_stats,"angler",good)
	untangle_phase="unwind" if good else "recover"
	untangle_age=0.0
	untangle_cooldown=rule("untangle_cooldown")
	play_feedback(("effort_good_" if good else "effort_bad_")+"angler")

func _tick_untangle(delta: float, command: Dictionary) -> void:
	# Run after fish movement, line tension and fish QTE. Escape/capture wins a
	# simultaneous result; neither a stale input nor a saved success revives it.
	if hooked!=HookState.HOOKED or landing or match_over or net_state!="wait" and net_state!="rest" or angler.net_held:
		if not untangle_phase.is_empty():
			_reset_untangle()
			untangle_cooldown=maxf(untangle_cooldown,rule("untangle_cooldown"))
		return
	if untangle_phase.is_empty(): return
	untangle_age+=delta
	if untangle_phase=="recover":
		if untangle_age>=rule("untangle_recover"): _reset_untangle()
		return
	if wraps.is_empty() or wraps[-1].target!=untangle_target:
		if untangle_phase=="check": _judge_untangle(false,-1,"鱼再次缠线")
		else: _reset_untangle()
		return
	if untangle_phase=="check":
		var state: Dictionary=effort_checks.angler
		state.age+=delta
		if command.qte or state.age>=float(state.lead)+float(state.sweep)+qte_grace_seconds:
			_judge_untangle(command.qte,command.qte_at_age,"张力不合适" if not command.qte_condition_valid else "")
	elif untangle_phase=="unwind":
		wraps[-1].progress=maxf(0.0,1.0-untangle_age/rule("unwind_seconds"))
		if untangle_age>=rule("unwind_seconds"):
			# Preserve elastic extension, including excess slack. Changing the
			# attachment must never teleport the fish or introduce a force spike.
			var offset: float=fish_line_length-Vector2(wraps[-1].entry).distance_to(mouth())
			wraps.pop_back()
			latched=not wraps.is_empty()
			var target := Vector2(wraps[-1].entry) if latched else line_anchor(bound_bait)
			var available := clampf(target.distance_to(mouth())+offset+(0.0 if latched else 0.32*rule("line_elastic")),0,rule("line_max"))
			if latched: fish_line_length=available
			else: rope_length=available; fish_line_length=0.0
			round_stats.unwrap_good+=1
			untangle_phase=""
			untangle_target=-1
			untangle_age=0.0
		_rebuild_rope()

func advance_tick(fish_command: Dictionary, angler_command: Dictionary) -> void:
	simulate(TICK_SECONDS,fish_command,angler_command)

func simulate(delta: float, fish_command: Dictionary, angler_command: Dictionary) -> void:
	if match_paused or match_over or not is_finite(delta) or delta<=0: return
	var fish_input := Commands.fish(fish_command,aim,power)
	var angler_input := Commands.angler(angler_command,angler.cursor)
	angler.update(self,delta,angler_input)
	untangle_cooldown=maxf(0,untangle_cooldown-delta)
	if angler_input.untangle: _begin_untangle()
	_tick_efforts(delta,fish_input,angler_input)
	power=fish_input.power
	if not movement_locked() and fish_input.aim.length()>0.01: aim=fish_input.aim.normalized()
	_simulate_fish(delta,fish_input.move,fish_input.suck,fish_input.home,fish_input.dash,fish_input.slow,fish_input.qte,fish_input.qte_at_age)
	_tick_untangle(delta,angler_input)
	angler.step_tackle_feedback(self,delta)
	if net_state=="caught" or match_over:
		for role in effort_checks: Effort.reset(effort_checks[role])

func capture_snapshot() -> Dictionary: return Snapshot.capture(self)

func restore_snapshot(snapshot: Dictionary) -> bool: return Snapshot.restore(self,snapshot)

func set_escape_timing(slack: float, window: float, breaking: float) -> void:
	var changes := rules.duplicate()
	changes.merge({"slack_hold":slack,"qte_entry_window":window,"qte_slack_window":window,"break_hold":breaking},true)
	rules=Rules.normalize(changes)

func set_practice_line_tuning(sensitivity: float, force: float) -> void:
	var changes := rules.duplicate()
	changes.merge({"line_response":sensitivity,"line_force":force},true)
	rules=Rules.normalize(changes)
	reel_speed=0

func line_tuning() -> Vector2:
	return Vector2(rule("line_response"),rule("line_force"))

func set_practice_effort_tuning(frequency: float, window: float, boost: float, weak: float) -> void:
	var changes := rules.duplicate()
	for role in ["fish","angler"]:
		changes[role+"_effort_frequency"]=frequency
		changes["qte_"+role+"_effort_window"]=window
		changes[role+"_effort_boost"]=boost
		changes[role+"_effort_weak"]=weak
	rules=Rules.normalize(changes)

func effort_tuning(role: String = "fish", kind: String = "effort") -> Dictionary:
	var tuning := Rules.qte(rules,"untangle" if kind=="untangle" else role+"_effort")
	for field in ["frequency","boost","weak","boost_seconds","weak_seconds"]:
		tuning[field]=rule(role+"_effort_"+field)
	return tuning

func tug_status() -> String:
	if hooked!=HookState.HOOKED: return ""
	if tension<rule("tension_low"): return "松线机会"
	var target := line_anchor(bound_bait) if wraps.is_empty() else Vector2(wraps[-1].entry)
	var approach := (fish-fish_before).dot((target-fish).normalized())
	if approach>0.12: return "正在被收近"
	if approach< -0.12: return "小鱼正在拉开"
	return "拉扯僵持"

func reset_world(config: Dictionary = {}) -> void:
	rules=Rules.legacy(config)
	qte_timing=Rules.qte(rules,"entry")
	ruleset="duel" if config.get("ruleset","survival")=="duel" else "survival"
	rng.seed=int(config.get("seed",2649))
	angler.reset()
	angler.auto_reel=not uses_mobile_tackle()
	angler.auto_net=not uses_mobile_tackle()
	simulation_tick=0
	qte_id=0
	effort_checks={"fish":Effort.fresh(),"angler":Effort.fresh()}
	_reset_untangle()
	untangle_cooldown=0.0
	round_stats=Stats.fresh()
	net_capture=0.0
	net_action=Net.fresh()
	qte_grace_seconds=clampf(Commands.number(config.get("qte_grace"),0),0,0.25)
	match_over=false
	winner_role=""
	match_paused=false
	net_aim=Vector2.ZERO
	manual_net=false
	net_trail.clear()
	net_return_path.clear()
	net_exit_path.clear()
	net_route.clear()
	net_route_next=1
	bait_batch=0
	challenge = bool(config.get("challenge",false))
	fish = Layout.SPAWN
	power=rule("suction_initial")
	rope_length=0
	landing_from=Vector2.ZERO
	qte_width=0.2
	qte_result_width=0.2
	qte_zone=0.6
	qte_result_kind=""
	qte_result_zone=0
	qte_result_progress=0
	qte_result_good=false
	qte_origin=Vector2.ZERO
	net_from=Vector2.ZERO
	net_to=Vector2.ZERO
	net_pos=Vector2.ZERO
	net_last_position=Vector2.ZERO
	net_splash_at=Vector2.ZERO
	velocity = Vector2.ZERO
	aim = Vector2.RIGHT
	fish_before = fish
	stamina = rule("stamina_max")*rule("stamina_initial")
	sprinting = false
	sprint_exhausted = false
	stamina_delay = 0
	hooked = HookState.FREE
	bound_bait = -1
	hook_cooldown = 0
	qte = ""
	qte_age = 0
	qte_result_age = 0
	qte_result = ""
	wrap_target = -1
	wrap_retry = 0
	wraps.clear()
	fish_line_length = 0
	contact_target = -1
	target_opacity.clear()
	for target in targets: target_opacity.append(1.0)
	result_flash = 0
	result_good = false
	tension = 0
	reel_speed = 0
	latched = false
	high_age = 0
	low_age = 0
	retry_age = 0
	landing_age = 0
	landing = false
	resisting = false
	feeding = false
	line_catches = 0
	rope_path.clear()
	score = 0
	counted.clear()
	clock = 0
	elapsed = 0
	started = false
	reason = ""
	returning = false
	home_age = 0
	hook_count = 0
	escape_count = 0
	net_state = "wait"
	net_wait = 0
	net_age = 0
	net_recovery = 0
	net_count = 0
	net_queued = false
	net_pulse = 0
	net_kind = "sweep"
	net_blocked = false
	net_return_from = Vector2.ZERO
	net_catch_offset = Vector2.ZERO
	net_dodges = 0
	net_catches = 0
	net_angle = 0
	net_park = Vector2.ZERO
	net_retract_duration = 1
	net_splash = 0
	net_motion = Vector2.ZERO
	net_warning_shape.clear()
	cycle_phase = ""
	cycle_slot = -1
	cycle_age = 0
	supply_queue.assign([2])
	baits.clear()
	var sites: Array[Vector2]=Layout.BAIT_SITES.duplicate()
	for index in range(sites.size()-1,0,-1):
		var other:=rng.randi_range(0,index)
		var swap:=sites[index]; sites[index]=sites[other]; sites[other]=swap
	for index in range(4):
		_create_bait(index)
		baits[index].home=sites[index]
		baits[index].pos=sites[index]
		baits[index].tip_before=sites[index]+Vector2(2,1)
		for grain in baits[index].grains: grain.pos=sites[index]+Vector2(grain.offset)
	if uses_mobile_tackle():
		baits[0].active=false
		started=true
	notice = "寻找饵团 · 鼠标朝向，左键吸食 · 饵中可能藏有鱼钩"
	notice_age = 5
	if uses_mobile_tackle(): notice="Q 下钩 · W 收线 / S 放线 · E 观察 · 左键选择 A/B 抄网"

func line_anchor(index: int) -> Vector2:
	return angler.anchor() if uses_mobile_tackle() else Vector2(baits[index].home.x,53)

func _create_bait(index: int) -> void:
	baits.append(_make_bait(index))

func _make_bait(index: int, batch: int = 0) -> Dictionary:
	var hooked_bait := index % 2 == 0
	var home := Vector2(232, 153) if hooked_bait else Vector2(532, 216)
	var bait := {"id":index, "home":home, "pos":home, "angle":0.0, "hook":hooked_bait, "removed":false, "active":index != 2, "age":0.0, "budget":0.0, "grains":[], "tip_before":home + Vector2(2, 1)}
	var counts := [24, 14, 6]
	var radii := [7.0, 4.4, 1.9]
	var grain_rng := RandomNumberGenerator.new()
	# Share the same pellet silhouette; a stable slot-specific shape could identify hook bait.
	grain_rng.seed = 3901
	var serial := 0
	for layer in range(3):
		for particle in range(counts[layer]):
			var angle: float = TAU * float(particle) / counts[layer] + layer * 0.37 + grain_rng.randf_range(-0.12,0.12)
			var radius: float = radii[layer] - grain_rng.randf_range(0,1.7 if layer < 2 else 1.0)
			var offset := (Vector2.from_angle(angle) * radius * Vector2(1,0.88)).round()
			bait.grains.append({"id":("%d_%d" % [index, serial] if batch==0 else "%d_%d_%d" % [index,batch,serial]), "offset":offset, "pos":home + offset, "layer":layer, "fleck":serial%5, "free":false, "eaten":false, "progress":0.0, "points":rule("bait_points")*(0.6 / 24 if layer == 0 else 0.4 / 20)})
			serial += 1
	return bait

func refill_hook_bait(index: int) -> void:
	bait_batch+=1
	var loose: Array=[]
	for grain in baits[index].grains:
		if grain.free and not grain.eaten: loose.append(grain)
	baits[index]=_make_bait(index,bait_batch)
	baits[index].active=false
	baits[index].grains.append_array(loose)

func mouth() -> Vector2:
	return fish + aim * 10

func _tip(index: int) -> Vector2:
	return mouth() if bound_bait == index and hooked != HookState.FREE else Vector2(baits[index].pos) + Vector2(2, 1).rotated(baits[index].angle)

func hook_point(index: int, local: Vector2) -> Vector2:
	return _tip(index)+(local*rule("hook_scale")).rotated(baits[index].angle)

func water_offset(point: Vector2) -> Vector2:
	return Vector2(sin(elapsed*0.75+point.y*0.007)*5+sin(elapsed*1.25+point.x*0.005),sin(elapsed*0.95+point.x*0.008)*2.5)*water_strength

func water_velocity(point: Vector2) -> Vector2:
	# The same smooth field drives fish drift, tethered bait and suspended particles.
	return Vector2(cos(elapsed*0.75+point.y*0.007)*3.75+cos(elapsed*1.25+point.x*0.005)*1.25,cos(elapsed*0.95+point.x*0.008)*2.375)*water_strength

func strength(point: Vector2) -> float:
	var local := point - mouth()
	var depth := local.dot(aim)
	var side := absf(local.cross(aim))
	if depth < 0 or depth > rule("suction_range") or side > rule("suction_mouth") + depth * rule("suction_spread"): return 0
	return (0.6 + 0.4 * (1 - depth / rule("suction_range"))) * (1 - 0.2 * side / (rule("suction_mouth") + depth * rule("suction_spread")))

func _collision(point: Vector2, radius: float) -> bool:
	for solid in SOLIDS:
		if Layout.touches(point,radius,PackedVector2Array(solid.points)): return true
	return false

func vegetation_drag(point: Vector2) -> float:
	for patch in Layout.GRASS:
		if patch.has_point(point): return rule("vegetation_speed")
	return 1.0

func move_fish(motion: Vector2) -> void:
	var radius := 17.0 if hooked == HookState.HOOKED else 12.0
	fish = (fish+motion).clamp(Layout.fish_bounds(radius).position,Layout.fish_bounds(radius).end)
	if not uses_mobile_tackle() or hooked!=HookState.HOOKED or landing or line_tuning().y<=0: return
	var contact := line_anchor(bound_bait) if wraps.is_empty() else Vector2(wraps[-1].entry)
	var available := rope_length if wraps.is_empty() else fish_line_length
	var base := 0.5 if wraps.is_empty() else 0.18
	# Mobile, player-controlled tackle cannot stretch invisibly past the red gauge.
	# Resolve this before swept net capture, so the net sees the actual fish motion.
	var reach := maxf(0,available)+rule("line_elastic")*(1-base)
	var radial := mouth()-contact
	if radial.length()>reach:
		fish=(contact+radial.normalized()*reach-aim*10).clamp(Layout.fish_bounds(radius).position,Layout.fish_bounds(radius).end)

func touching_target(index: int) -> bool:
	return index>=0 and index<targets.size() and Layout.touches(fish,12,targets[index].polygon)

func target_is_wrapped(index: int) -> bool:
	for wrap in wraps:
		if wrap.target==index: return true
	return false

func _update_contacts(delta: float) -> void:
	for index in targets.size():
		var opacity := rule("cover_opacity") if touching_target(index) else 1.0
		target_opacity[index] = move_toward(target_opacity[index],opacity,delta*4)
	if qte=="wrap":
		contact_target = wrap_target
		return
	if touching_target(contact_target) and not target_is_wrapped(contact_target): return
	contact_target = -1
	var nearest := INF
	for index in targets.size():
		if not touching_target(index) or target_is_wrapped(index): continue
		var bounds: Rect2 = targets[index].bounds
		var distance := fish.distance_squared_to(bounds.get_center())
		if distance<nearest:
			nearest = distance
			contact_target = index

func winding() -> bool:
	return untangle_phase!="unwind" and not wraps.is_empty() and wraps[-1].progress<1.0

func movement_locked() -> bool:
	return hooked==HookState.MOUTH or landing or net_state=="caught"

func line_pull_velocity() -> Vector2:
	if hooked!=HookState.HOOKED or landing: return Vector2.ZERO
	var target := line_anchor(bound_bait) if wraps.is_empty() else Vector2(wraps[-1].entry)
	var load := clampf((tension-0.12)/0.88,0,1)
	# A taut line transmits a real force toward its last contact; slack does not push the fish.
	return (target-mouth()).normalized()*rule("line_pull")*load*sqrt(line_tuning().y)*effort_multiplier("angler")/effort_multiplier("fish")*(1.0 if wraps.is_empty() else rule("wrap_pull"))

func _open_qte(kind: String) -> void:
	qte_id+=1
	qte = kind
	qte_age = 0
	qte_timing=Rules.qte(rules,kind)
	qte_width=float(qte_timing.window)/float(qte_timing.sweep)
	qte_zone=rng.randf_range(0.10,0.90-qte_width) if qte_timing.random else float(qte_timing.zone)
	qte_origin = Vector2(452,83) if fish.x<320 else Vector2(12,83)
	qte_result_age = 0
	_cancel_effort("fish")
	play_feedback("qte_fish")

func _finish_qte_visual(good: bool, message: String = "", judged: bool = true) -> void:
	if qte.is_empty(): return
	if judged:
		Stats.record(round_stats,"fish",good)
		if good and qte=="wrap": round_stats.wrap_good+=1
	qte_result_kind = qte
	qte_result_progress = qte_progress()
	qte_result_zone = qte_zone
	qte_result_width = qte_width
	qte_result_good = good
	qte_result_age = 0.7
	qte_result = message if not message.is_empty() else (("缠线成功" if qte=="wrap" else "吐钩成功") if good else "判定失败")

func _begin_wrap() -> bool:
	if untangle_phase=="unwind": return false
	if hooked!=HookState.HOOKED or wrap_retry>0 or winding() or not touching_target(contact_target): return false
	if target_is_wrapped(contact_target) or not qte.is_empty(): return false
	wrap_target = contact_target
	_open_qte("wrap")
	low_age = 0
	return true

func _fail_wrap() -> void:
	_finish_qte_visual(false)
	qte = ""
	wrap_target = -1
	wrap_retry = rule("wrap_retry")
	result_flash = 0.7
	result_good = false
	notice = "缠线失败 · 仍然上钩，可稍后再试"
	notice_age = 2
	play_feedback("fail")

func _commit_wrap() -> void:
	if not touching_target(wrap_target) or target_is_wrapped(wrap_target): _fail_wrap(); return
	var coil := Layout.coil_at(targets[wrap_target],fish)
	coil.target = wrap_target
	wraps.append(coil)
	untangle_cooldown=maxf(untangle_cooldown,rule("wrap_seconds")+0.5)
	# Only this successful skill check creates an attachment. The coil stays after swimming away.
	fish_line_length = mouth().distance_to(coil.entry)+rule("wrap_slack")
	reel_speed = 0
	tension = 0.03
	latched = true
	high_age = 0
	low_age = 0
	retry_age = 0
	_finish_qte_visual(true)
	qte = ""
	wrap_target = -1
	wrap_retry = 0.8
	result_flash = 0.7
	result_good = true
	play_feedback("success")
	_rebuild_rope()

func visible_coil(wrap: Dictionary) -> PackedVector2Array:
	var loop: PackedVector2Array = wrap.loop
	var progress: float = clampf(wrap.progress,0,1)*(loop.size()-1)
	var last := int(progress)
	var points := loop.slice(0,last+1)
	if last<loop.size()-1: points.append(loop[last].lerp(loop[last+1],progress-last))
	return points

func _rebuild_rope() -> void:
	if hooked!=HookState.HOOKED: return
	rope_path = PackedVector2Array([line_anchor(bound_bait)])
	for wrap in wraps:
		rope_path.append_array(visible_coil(wrap))
	rope_path.append(mouth())

func step(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false, qte_pressed: bool = false) -> void:
	# Compatibility helper for existing gameplay probes; production uses advance_tick.
	if match_paused or match_over or not is_finite(delta) or delta<=0: return
	_simulate_fish(delta,movement,sucking,interact,dash,slow,qte_pressed)
	angler.step_tackle_feedback(self,delta)

func _simulate_fish(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false, qte_pressed: bool = false, qte_at_age: float = -1) -> void:
	if match_paused or match_over or not is_finite(delta) or delta<=0: return
	simulation_tick+=1
	elapsed += delta
	if hooked==HookState.HOOKED and not landing and net_state!="caught": round_stats.hooked_seconds+=delta
	if fish.distance_to(HOME) > 34: started = true
	if challenge and rules.timer_enabled and started: clock = minf(rule("time_limit"), clock + delta)
	notice_age = maxf(0, notice_age - delta)
	result_flash = maxf(0, result_flash - delta)
	qte_result_age = maxf(0,qte_result_age-delta)
	hook_cooldown = maxf(0, hook_cooldown - delta)
	retry_age = maxf(0, retry_age - delta)
	wrap_retry = maxf(0,wrap_retry-delta)
	net_recovery = maxf(0, net_recovery - delta)
	fish_before = fish
	var previous_mouth := mouth()
	if landing:
		_step_landing(delta)
		return
	_update_contacts(delta)
	var began_wrap := false
	# An active check owns Space. Its judgment must never start or replace another check.
	if qte_pressed and qte.is_empty(): began_wrap = _begin_wrap()
	sprinting = false
	resisting = false
	feeding = sucking and hooked!=HookState.MOUTH and net_state!="caught"
	stamina_delay = maxf(0,stamina_delay-delta)
	if not dash and stamina_ratio()>=rule("sprint_restart"): sprint_exhausted = false
	if not movement_locked():
		var pull := line_pull_velocity()
		var opposition := maxf(0,-movement.limit_length(1).dot(pull.normalized()))
		resisting = opposition>0.1 and pull.length()>2
		sprinting = dash and movement.length()>0.01 and stamina>0 and not sprint_exhausted
		if sprinting or resisting:
			stamina = maxf(0,stamina-delta*(rule("sprint_drain") if sprinting else opposition*rule("resist_drain")))
			stamina_delay = rule("stamina_delay")
			if stamina<=0 and sprinting: sprint_exhausted = true
		var speed := rule("sprint_speed") if sprinting else (rule("slow_speed") if slow else rule("swim_speed"))
		if hooked==HookState.HOOKED:
			speed *= fatigue_factor()*effort_multiplier("fish")
			if feeding: speed *= rule("feeding_speed")
		speed *= rule("net_slow_factor") if net_action.slow_age>0 else 1.0
		velocity = velocity.move_toward(movement.limit_length(1)*speed,delta*(rule("sprint_accel") if sprinting else rule("swim_accel")))
		move_fish((velocity*vegetation_drag(fish)+water_velocity(fish)+pull+net_action.impulse)*delta)
	else: velocity = Vector2.ZERO
	if not sprinting and stamina_delay<=0: stamina = minf(rule("stamina_max"),stamina+delta*rule("stamina_recovery"))
	_update_contacts(delta)
	_step_net(delta)
	if match_over or net_state=="caught": return
	var was_free := hooked == HookState.FREE
	if hooked == HookState.MOUTH:
		_step_qte(delta, qte_pressed,qte_at_age)
	elif hooked == HookState.HOOKED:
		_step_line(delta, qte_pressed and not began_wrap,qte_at_age)
	if match_over or landing: return
	for index in baits.size(): _step_bait(index, delta, feeding and hooked!=HookState.MOUTH, previous_mouth)
	if hooked != HookState.FREE: returning = false
	if interact and was_free and hooked == HookState.FREE and can_home(): returning = not returning
	if returning and can_home():
		home_age += delta
		if home_age >= rule("home_hold"): finish(true, "home")
	else:
		returning = false
		home_age = 0
	if match_over: return
	if challenge and rules.timer_enabled and clock >= rule("time_limit"):
		finish(uses_mobile_tackle(), "timeout")
		return
	_step_supply(delta)

func _step_bait(index: int, delta: float, sucking: bool, old_mouth: Vector2) -> void:
	var bait := baits[index]
	var old_tip := Vector2(bait.tip_before)
	if bait.active:
		bait.age += delta
		if uses_mobile_tackle() and bait.hook and not bait.removed and bound_bait!=index:
			angler.step_free_hook(self,index,delta,sucking)
		elif bound_bait==index and hooked!=HookState.FREE:
			bait.pos=mouth()-Vector2(2,1).rotated(bait.angle)
		else:
			var target: Vector2 = bait.home + water_offset(bait.home)
			bait.angle = sin(elapsed*0.75+bait.home.y*0.007)*0.16*water_strength
			if bait.hook and not bait.removed and bound_bait != index and sucking:
				var gain := strength(_tip(index)) * power
				target = target.move_toward(mouth(),gain*26*rule("hook_suction"))
			bait.pos = Vector2(bait.pos).move_toward(target, delta * 44)
		if bait.active and bait.hook and not bait.removed and hooked == HookState.FREE and hook_cooldown <= 0 and net_state!="caught":
			var relative := _tip(index) - mouth() - aim * 3
			var before := old_tip - old_mouth - aim * 3
			if _segment_distance(before, relative, Vector2.ZERO) < rule("bite_radius"):
				_enter_hook(index)
				sucking = false
	var layer := 3
	for grain in bait.grains:
		if not grain.eaten and not grain.free: layer = mini(layer, grain.layer)
	bait.budget = minf(2, float(bait.budget) + delta * (8 + 20 * power)*rule("pellet_rate")/28.0) if sucking else 0.0
	for grain in bait.grains:
		if grain.eaten: continue
		if not grain.free: grain.pos = Vector2(bait.pos) + Vector2(grain.offset).rotated(bait.angle)
		else: grain.pos = Vector2(grain.pos)+water_velocity(grain.pos)*delta*1.15
		if not sucking or (not bait.active and not grain.free): continue
		var pull := strength(grain.pos)
		if pull <= 0: continue
		if grain.free:
			grain.pos = Vector2(grain.pos).move_toward(mouth(), delta * rule("pellet_speed"))
			if Vector2(grain.pos).distance_to(mouth()) < 4:
				grain.eaten = true
				if not counted.has(grain.id):
					counted[grain.id] = true
					score += float(grain.points)
					stamina = minf(rule("stamina_max"),stamina+float(grain.points)*rule("food_recovery"))
					play_feedback("eat")
		elif grain.layer == layer:
			grain.progress += delta * pull * power * rule("pellet_detach")
			if grain.progress >= 1 and bait.budget >= 1:
				grain.free = true
				bait.budget -= 1
	bait.tip_before = _tip(index)

func _enter_hook(index: int) -> void:
	bound_bait = index
	hooked = HookState.MOUTH
	velocity = Vector2.ZERO
	sprinting = false
	_open_qte("entry")
	hook_count += 1
	returning = false

func _attach_hook() -> void:
	for role in effort_checks: Effort.reset(effort_checks[role],rng.randf_range(1.2,2.8))
	hooked = HookState.HOOKED
	qte = ""
	tension = 0.5
	reel_speed = 0
	high_age = 0
	low_age = 0
	landing_age = 0
	landing = false
	# Props are pass-through cover; only the pond perimeter constrains swimming.
	fish = fish.clamp(Layout.fish_bounds(17).position,Layout.fish_bounds(17).end)
	wraps.clear()
	wrap_target = -1
	_rebuild_rope()
	rope_length = Rope.length_of(rope_path)

func _step_qte(delta: float, qte_pressed: bool, judged_age: float = -1) -> void:
	if qte.is_empty(): return
	qte_age += delta
	# Only the authority can supply an age verified against its own QTE history.
	var age := judged_age if judged_age>=0 else qte_age
	var progress := clampf((age-float(qte_timing.lead))/float(qte_timing.sweep),0,1)
	if qte_pressed or qte_age >= float(qte_timing.lead)+float(qte_timing.sweep)+qte_grace_seconds:
		var success := qte_pressed and age>=float(qte_timing.lead) and age<=float(qte_timing.lead)+float(qte_timing.sweep) and progress>=qte_zone and progress<=qte_zone+qte_width
		result_flash = 0.7
		result_good = success
		if qte=="wrap":
			if success: _commit_wrap()
			else: _fail_wrap()
			qte_result_progress=progress
			return
		_finish_qte_visual(success)
		qte_result_progress=progress
		if success:
			_release_hook(false)
		else:
			if qte == "entry": _attach_hook()
			else:
				qte = ""
				retry_age = rule("slack_retry")
				low_age = 0
			play_feedback("fail")

func qte_progress() -> float:
	return clampf((qte_age - float(qte_timing.lead)) / float(qte_timing.sweep), 0, 1)

func _step_line(delta: float, qte_pressed: bool, judged_age: float = -1) -> void:
	var anchor := line_anchor(bound_bait)
	var animating := winding()
	if animating: wraps[-1].progress = minf(1,wraps[-1].progress+delta/rule("wrap_seconds"))
	_rebuild_rope()
	latched = not wraps.is_empty()
	var length_now := anchor.distance_to(mouth()) if not latched else Vector2(wraps[-1].entry).distance_to(mouth())
	var base := 0.18 if latched else 0.5
	var available := fish_line_length if latched else rope_length
	var raw_tension := base+(length_now-available)/rule("line_elastic")
	var tuning := line_tuning()
	# Reeling is the objective. Tension feedback only tempers it or pays out under heavy load.
	var force_gain := effort_multiplier("angler")/effort_multiplier("fish")
	var desired_speed := angler.spool_target(raw_tension,tuning,not angler.auto_reel,rules)
	if angler.auto_reel and untangle_phase in ["check","unwind"]:
		# The AI uses the same spool actuator; no direct tension/line-length edits.
		desired_speed=clampf((raw_tension-lerpf(rule("untangle_min"),rule("untangle_max"),0.5))*170,-rule("reel_speed"),rule("release_speed"))*tuning.y
	if Net.busy(self): desired_speed=0
	if desired_speed<0: desired_speed*=force_gain
	if tuning.y<=0: reel_speed=0
	elif not angler.auto_reel: reel_speed=angler.manual_spool_speed(reel_speed,delta*tuning.x*maxf(1,tuning.y),force_gain,rules)
	else: reel_speed=move_toward(reel_speed,desired_speed,delta*60*tuning.x*maxf(1,tuning.y))
	available = clampf(available+reel_speed*delta*(rule("wrap_spool") if latched else 1.0),0,rule("line_max"))
	if latched: fish_line_length = available
	else: rope_length = available
	tension = clampf(base+(length_now-available)/rule("line_elastic"),0,1)
	if tension>=rule("tension_high"): round_stats.danger_seconds+=delta
	high_age = high_age + delta if tension >= rule("tension_high") else 0.0
	if high_age >= break_hold_seconds:
		_release_hook(true)
		return
	if not latched and fish.y < 91 and absf(fish.x - anchor.x) < 30 and tension >= rule("tension_low"):
		landing_age += delta
		if landing_age >= rule("landing_hold"):
			Net.cancel_manual_net(self)
			landing = true
			for role in effort_checks: Effort.reset(effort_checks[role])
			landing_from = fish
			landing_age = 0
			line_catches += 1
			qte = ""
			qte_result_age = 0
			velocity = Vector2.ZERO
			sprinting = false
			feeding = false
			resisting = false
			play_feedback("fail")
			return
	else: landing_age = 0
	if qte=="wrap":
		if not touching_target(wrap_target): _fail_wrap()
		else: _step_qte(delta,qte_pressed,judged_age)
		return
	if animating: return
	if qte == "slack":
		if tension >= rule("tension_low"):
			_finish_qte_visual(false,"张力回升")
			qte = ""
			retry_age = rule("slack_retry")
			low_age = 0
			result_flash = 0.7
			result_good = false
			play_feedback("fail")
		else: _step_qte(delta, qte_pressed,judged_age)
	else:
		low_age = low_age + delta if tension < rule("tension_low") and retry_age <= 0 else 0.0
		if low_age >= slack_hold_seconds:
			_open_qte("slack")

func _step_landing(delta: float) -> void:
	landing_age += delta
	var ratio := clampf(landing_age/rule("landing_lift"),0,1)
	fish = landing_from.lerp(Vector2(line_anchor(bound_bait).x,39),ratio*ratio)
	_rebuild_rope()
	if ratio<1: return
	if challenge: finish(false,"landed")
	else:
		_clear_hook()
		fish = HOME+Vector2(0,-14)
		fish_before = fish
		notice = "被拉出水了 · 食物保留，已回到巢边"
		notice_age = 4

func _clear_hook() -> void:
	_reset_untangle()
	untangle_cooldown=0.0
	for role in effort_checks: Effort.reset(effort_checks[role])
	hooked = HookState.FREE
	bound_bait = -1
	qte = ""
	wrap_target = -1
	wraps.clear()
	fish_line_length = 0
	wrap_retry = 0
	hook_cooldown = rule("hook_immunity")
	net_recovery = 4
	latched = false
	tension = 0
	reel_speed = 0
	high_age = 0
	low_age = 0
	landing = false
	landing_age = 0
	resisting = false
	feeding = false
	rope_path.clear()

func _release_hook(broken: bool) -> void:
	if uses_mobile_tackle() and bound_bait>=0:
		baits[bound_bait].pos=mouth()-Vector2(2,1).rotated(baits[bound_bait].angle)
		baits[bound_bait].home=baits[bound_bait].pos
		angler.free_line_length=angler.anchor().distance_to(baits[bound_bait].pos)
		angler.previous_anchor=angler.anchor()
		angler.hook_velocity=velocity*0.3
	if broken: _finish_qte_visual(true,"鱼线断开",false)
	round_stats["breaks" if broken else "slips"]+=1
	if broken: baits[bound_bait].removed = true
	_clear_hook()
	escape_count += 1
	notice = "鱼线断了！继续觅食。" if broken else "吐钩成功！换个角度继续。"
	if uses_mobile_tackle(): notice="鱼挣断了线 · Q 重新挂饵下钩" if broken else "鱼逃脱了 · 调整钓点或准备抄网"
	notice_age = 3
	result_flash = 0.7
	result_good = true
	play_feedback("break" if broken else "success")

func _remaining(bait: Dictionary, attached_only: bool = false) -> bool:
	for grain in bait.grains:
		if not grain.eaten and (not attached_only or not grain.free): return true
	return false

func _step_supply(delta: float) -> void:
	if not challenge or hooked != HookState.FREE or not net_state in ["wait", "rest"]: return
	if cycle_phase.is_empty():
		for index in baits.size():
			if uses_mobile_tackle() and baits[index].hook: continue
			if baits[index].active and (baits[index].age >= rule("bait_cycle") or not _remaining(baits[index])):
				cycle_slot = index
				cycle_phase = "warning"
				cycle_age = 0
				break
	else:
		cycle_age += delta
		if cycle_phase == "warning" and cycle_age >= 2:
			baits[cycle_slot].active = false
			cycle_phase = "refill"
			cycle_age = 0
		elif cycle_phase == "refill" and cycle_age >= rule("bait_refill"):
			if _remaining(baits[cycle_slot], true): supply_queue.append(cycle_slot)
			var next := -1
			for candidate in supply_queue:
				if candidate % 2 == cycle_slot % 2 and not baits[candidate].active:
					next = candidate
					break
			if next >= 0:
				supply_queue.erase(next)
				baits[next].active = true
				baits[next].age = 0
			cycle_phase = ""
			cycle_slot = -1

func net_warning_seconds() -> float:
	return Net.net_warning_seconds(self)

func record_manual_net_point(point: Vector2) -> void:
	Net.record_manual_net_point(self, point)

func manual_net_blocked(point: Vector2) -> bool:
	return Net.manual_net_blocked(self, point)

func _manual_net_exit(point: Vector2) -> PackedVector2Array:
	return Net._manual_net_exit(self, point)

func _manual_net_lane_clear(a: Vector2, b: Vector2) -> bool:
	return Net._manual_net_lane_clear(self, a, b)

func begin_manual_net(point: Vector2) -> bool:
	return Net.begin_manual_net(self, point)

func _prepare_manual_return() -> void:
	Net._prepare_manual_return(self)

func cancel_manual_net() -> void:
	Net.cancel_manual_net(self)

func request_net() -> void:
	Net.request_net(self)

func net_active() -> bool:
	return Net.net_active(self)

func _net_contact(point: Vector2, angle: float = NAN) -> bool:
	return Net._net_contact(self, point, angle)

func _plan_net() -> void:
	Net._plan_net(self)

func net_warning_outline() -> PackedVector2Array:
	return Net.net_warning_outline(self)

func _make_net_warning_outline() -> PackedVector2Array:
	return Net._make_net_warning_outline(self)

func _catch_in_net() -> void:
	Net._catch_in_net(self)

func _net_splash(point: Vector2) -> void:
	Net._net_splash(self, point)

func _net_retract_length() -> float:
	return Net._net_retract_length(self)

func _net_retract_point(progress: float) -> Vector2:
	return Net._net_retract_point(self, progress)

func net_bag_offset() -> Vector2:
	return Net.net_bag_offset(self)

func _net_reaches_fish(point: Vector2, center: Vector2) -> bool:
	return Net._net_reaches_fish(self, point, center)

func _finish_net_recovery() -> void:
	Net._finish_net_recovery(self)

func _step_net(delta: float) -> void:
	Net._step_net(self, delta)

func _advance_net(delta: float, frame_from: Vector2, frame_to: Vector2) -> void:
	Net._advance_net(self, delta, frame_from, frame_to)

static func _segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var length_squared := a.distance_squared_to(b)
	var factor := clampf((point - a).dot(b - a) / length_squared, 0, 1) if length_squared > 0.000001 else 0.0
	return point.distance_to(a.lerp(b, factor))

func can_home() -> bool:
	return hooked == HookState.FREE and score >= food_target() - 0.001 and fish.distance_to(HOME) < 29

func finish(success: bool, why: String) -> void:
	if match_over: return
	for role in effort_checks: Effort.reset(effort_checks[role])
	Net.cancel_manual_net(self)
	match_over=true
	winner_role="fish" if success else "angler"
	reason=why
	velocity=Vector2.ZERO
	match_ended.emit(winner_role,reason)

