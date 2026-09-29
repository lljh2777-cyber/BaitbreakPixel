extends Node2D

const Rope = preload("res://scripts/rope.gd")
const View = preload("res://scripts/pond_view.gd")
const Menus = preload("res://scripts/menu.gd")
const Sound = preload("res://scripts/sound.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const AnglerController = preload("res://scripts/angler_controller.gd")
const FishBrain = preload("res://scripts/fish_brain.gd")
enum HookState { FREE, MOUTH, HOOKED }
const HOME := Vector2(60, 281)
const TARGET := 60.0
const TIME_LIMIT := 360.0
const SOLIDS: Array = Layout.SOLIDS
const HOOK_SCALE := 0.70
const BITE_RADIUS := 7.0
const NET_RIM := Vector2(23,31)
const NET_CATCH := Vector2(30,36)
const NET_PREPARE := 0.8
const NET_WARNING := 2.2
const NET_SWEEP := 1.6
const NET_WITHDRAW := 1.0
const NET_LIFT := 1.15
const NET_SETTLE := 0.32
const NET_MISS := 0.22

var fish := Vector2(66, 265)
var player_role := "fish"
var angler := AnglerController.new()
var fish_brain := FishBrain.new()
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
var angler_wins := 0
var velocity := Vector2.ZERO
var aim := Vector2.RIGHT
var power := 0.35
var stamina := 100.0
var sprinting := false
var sprint_exhausted := false
var stamina_delay := 0.0
const SPRINT_SPEED := 140.0
const SPRINT_DRAIN := 28.0
var water_strength := 1.0
var fish_before := Vector2.ZERO
var hooked := HookState.FREE
var bound_bait := -1
var hook_cooldown := 0.0
var rope_path := PackedVector2Array()
var rope_length := 0.0
var tension := 0.0
var reel_speed := 0.0
var practice_line_sensitivity := 1.0
var practice_line_force := 1.0
var slack_hold_seconds := 0.5
var mouth_window_seconds := 0.4
var break_hold_seconds := 3.0
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
var won := false
var lost := false
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
var paused := false
var view: Node2D
var menu: Control
var sound: Node
var volume := 0.6
var fullscreen := false
var best_score := 0.0
var wins := 0
var save_path := "user://pixel.cfg"
var save_error := OK
var rng := RandomNumberGenerator.new()
var capture_mode := ""
var capture_frame := 0

func _ready() -> void:
	Engine.max_fps = 60
	rng.seed = 2649
	targets = Layout.interaction_targets()
	_register_inputs()
	if "--test-profile" in OS.get_cmdline_user_args(): save_path = "user://pixel-test.cfg"
	else: _load_profile()
	sound = Sound.new()
	add_child(sound)
	view = View.new()
	view.game = self
	add_child(view)
	menu = Menus.new()
	menu.game = self
	add_child(menu)
	reset(false)
	menu.open("title")
	apply_settings()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-") and not argument.begins_with("--capture-output="):
			capture_mode = argument.trim_prefix("--capture-")
	print("PIXEL_READY | side-view | 640x360 | v0.10.2 | recorded-net-route")

func _register_inputs() -> void:
	var mapping := {"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT], "up":[KEY_W, KEY_UP], "down":[KEY_S, KEY_DOWN], "dash":[], "use":[KEY_E], "slow":[KEY_Q], "qte":[KEY_SPACE]}
	for action in mapping:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in mapping[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var sprint_button := InputEventMouseButton.new()
	sprint_button.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dash",sprint_button)
	if not InputMap.has_action("cast"): InputMap.add_action("cast")
	InputMap.action_erase_events("cast")
	var cast_button := InputEventMouseButton.new()
	cast_button.button_index=MOUSE_BUTTON_LEFT
	InputMap.action_add_event("cast",cast_button)

func _load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		volume = clampf(float(file.get_value("settings", "volume", 0.6)), 0, 1)
		fullscreen = bool(file.get_value("settings", "fullscreen", false))
		best_score = maxf(0, float(file.get_value("record", "best", 0)))
		wins = maxi(0, int(file.get_value("record", "wins", 0)))
		angler_wins=maxi(0,int(file.get_value("record","angler_wins",0)))
		set_practice_line_tuning(float(file.get_value("practice", "line_sensitivity", 1.0)),float(file.get_value("practice", "line_force", 1.0)))
		set_escape_timing(float(file.get_value("timing","slack_hold",0.5)),float(file.get_value("timing","mouth_window",0.4)),float(file.get_value("timing","break_hold",3.0)))

func save_profile() -> void:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("record", "best", best_score)
	file.set_value("record", "wins", wins)
	file.set_value("record","angler_wins",angler_wins)
	file.set_value("practice", "line_sensitivity", practice_line_sensitivity)
	file.set_value("practice", "line_force", practice_line_force)
	file.set_value("timing","slack_hold",slack_hold_seconds)
	file.set_value("timing","mouth_window",mouth_window_seconds)
	file.set_value("timing","break_hold",break_hold_seconds)
	save_error = file.save(save_path)

func set_escape_timing(slack: float, window: float, breaking: float) -> void:
	slack_hold_seconds=clampf(slack,0.1,3.0) if is_finite(slack) else 0.5
	mouth_window_seconds=clampf(window,0.12,1.0) if is_finite(window) else 0.4
	break_hold_seconds=clampf(breaking,0.5,10.0) if is_finite(breaking) else 3.0

func set_practice_line_tuning(sensitivity: float, force: float) -> void:
	practice_line_sensitivity = clampf(sensitivity,0.25,2.5) if is_finite(sensitivity) else 1.0
	practice_line_force = clampf(force,0,2.5) if is_finite(force) else 1.0
	reel_speed = 0

func line_tuning() -> Vector2:
	return Vector2.ONE if challenge else Vector2(practice_line_sensitivity,practice_line_force)

func apply_settings() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func reset(is_challenge: bool, role: String = "fish") -> void:
	player_role="angler" if role=="angler" else "fish"
	# Preserve every delivered turn of a hand-drawn route, even between physics ticks.
	Input.use_accumulated_input=player_role!="angler"
	angler.reset()
	fish_brain.reset(rng.randi())
	net_aim=Vector2.ZERO
	manual_net=false
	net_trail.clear()
	net_return_path.clear()
	net_exit_path.clear()
	net_route.clear()
	net_route_next=1
	bait_batch=0
	challenge = is_challenge
	if player_role=="angler": challenge=true
	fish = Vector2(66, 265)
	velocity = Vector2.ZERO
	aim = Vector2.RIGHT
	fish_before = fish
	stamina = 100
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
	won = false
	lost = false
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
	supply_queue.assign([2, 3])
	baits.clear()
	for index in range(4): _create_bait(index)
	if player_role=="angler":
		baits[0].active=false
		started=true
	paused = false
	notice = "鼠标朝向决定吸食方向 · 先试试右侧无钩饵"
	notice_age = 5
	if player_role=="angler": notice="Q 下钩 · W 收线 / S 放线 · 按住 E + 左键拖动抄网"
	menu.close()

func restart_round() -> void:
	reset(challenge,player_role)

func line_anchor(index: int) -> Vector2:
	return angler.anchor() if player_role=="angler" else Vector2(baits[index].home.x,53)

func _create_bait(index: int) -> void:
	baits.append(_make_bait(index))

func _make_bait(index: int, batch: int = 0) -> Dictionary:
	var hooked_bait := index % 2 == 0
	var home := Vector2(232, 153) if hooked_bait else Vector2(532, 216)
	var bait := {"id":index, "home":home, "pos":home, "angle":0.0, "hook":hooked_bait, "removed":false, "active":index < 2, "age":0.0, "budget":0.0, "grains":[], "tip_before":home + Vector2(2, 1)}
	var counts := [24, 14, 6]
	var radii := [7.0, 4.4, 1.9]
	var grain_rng := RandomNumberGenerator.new()
	grain_rng.seed = 3901 + index*97
	var serial := 0
	for layer in range(3):
		for particle in range(counts[layer]):
			var angle: float = TAU * float(particle) / counts[layer] + layer * 0.37 + grain_rng.randf_range(-0.12,0.12)
			var radius: float = radii[layer] - grain_rng.randf_range(0,1.7 if layer < 2 else 1.0)
			var offset := (Vector2.from_angle(angle) * radius * Vector2(1,0.88)).round()
			bait.grains.append({"id":("%d_%d" % [index, serial] if batch==0 else "%d_%d_%d" % [index,batch,serial]), "offset":offset, "pos":home + offset, "layer":layer, "fleck":serial%5, "free":false, "eaten":false, "progress":0.0, "points":18.0 / 24 if layer == 0 else 12.0 / 20})
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
	return _tip(index)+(local*HOOK_SCALE).rotated(baits[index].angle)

func water_offset(point: Vector2) -> Vector2:
	return Vector2(sin(elapsed*0.75+point.y*0.007)*5+sin(elapsed*1.25+point.x*0.005),sin(elapsed*0.95+point.x*0.008)*2.5)*water_strength

func water_velocity(point: Vector2) -> Vector2:
	# The same smooth field drives fish drift, tethered bait and suspended particles.
	return Vector2(cos(elapsed*0.75+point.y*0.007)*3.75+cos(elapsed*1.25+point.x*0.005)*1.25,cos(elapsed*0.95+point.x*0.008)*2.375)*water_strength

func strength(point: Vector2) -> float:
	var local := point - mouth()
	var depth := local.dot(aim)
	var side := absf(local.cross(aim))
	if depth < 0 or depth > 44 or side > 4 + depth * 0.53: return 0
	return (0.6 + 0.4 * (1 - depth / 44)) * (1 - 0.2 * side / (4 + depth * 0.53))

func _collision(point: Vector2, radius: float) -> bool:
	for solid in SOLIDS:
		if Layout.touches(point,radius,PackedVector2Array(solid.points)): return true
	return false

func vegetation_drag(point: Vector2) -> float:
	for patch in Layout.GRASS:
		if patch.has_point(point): return 0.68
	return 1.0

func move_fish(motion: Vector2) -> void:
	var radius := 17.0 if hooked == HookState.HOOKED else 12.0
	fish = (fish+motion).clamp(Vector2(radius+8,68+radius),Vector2(632-radius,311-radius))

func touching_target(index: int) -> bool:
	return index>=0 and index<targets.size() and Layout.touches(fish,12,targets[index].polygon)

func target_is_wrapped(index: int) -> bool:
	for wrap in wraps:
		if wrap.target==index: return true
	return false

func _update_contacts(delta: float) -> void:
	for index in targets.size():
		var opacity := 0.68 if touching_target(index) else 1.0
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
	return not wraps.is_empty() and wraps[-1].progress<1.0

func movement_locked() -> bool:
	return hooked==HookState.MOUTH or landing or net_state=="caught"

func line_pull_velocity() -> Vector2:
	if hooked!=HookState.HOOKED or landing: return Vector2.ZERO
	var target := line_anchor(bound_bait) if wraps.is_empty() else Vector2(wraps[-1].entry)
	var load := clampf((tension-0.12)/0.88,0,1)
	# A taut line transmits a real force toward its last contact; slack does not push the fish.
	return (target-mouth()).normalized()*65*load*sqrt(line_tuning().y)*(1.0 if wraps.is_empty() else 0.5)

func _open_qte(kind: String) -> void:
	qte = kind
	qte_age = 0
	qte_width=0.2 if kind=="wrap" else mouth_window_seconds/2.0
	qte_zone=clampf(rng.randf_range(0.67,0.75)-qte_width*0.5,0.1,0.98-qte_width)
	qte_origin = Vector2(452,83) if fish.x<320 else Vector2(12,83)
	qte_result_age = 0

func _finish_qte_visual(good: bool, message: String = "") -> void:
	if qte.is_empty(): return
	qte_result_kind = qte
	qte_result_progress = qte_progress()
	qte_result_zone = qte_zone
	qte_result_width = qte_width
	qte_result_good = good
	qte_result_age = 0.7
	qte_result = message if not message.is_empty() else (("缠线成功" if qte=="wrap" else "吐钩成功") if good else "判定失败")

func _begin_wrap() -> bool:
	if hooked!=HookState.HOOKED or wrap_retry>0 or winding() or not touching_target(contact_target): return false
	if target_is_wrapped(contact_target) or not qte.is_empty(): return false
	wrap_target = contact_target
	_open_qte("wrap")
	low_age = 0
	sound.play("warn")
	return true

func _fail_wrap() -> void:
	_finish_qte_visual(false)
	qte = ""
	wrap_target = -1
	wrap_retry = 1.2
	result_flash = 0.7
	result_good = false
	notice = "缠线失败 · 仍然上钩，可稍后再试"
	notice_age = 2
	sound.play("fail")

func _commit_wrap() -> void:
	if not touching_target(wrap_target) or target_is_wrapped(wrap_target): _fail_wrap(); return
	var coil := Layout.coil_at(targets[wrap_target],fish)
	coil.target = wrap_target
	wraps.append(coil)
	# Only this successful skill check creates an attachment. The coil stays after swimming away.
	fish_line_length = mouth().distance_to(coil.entry)+9.0
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
	sound.play("success")
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

func _physics_process(delta: float) -> void:
	if menu.visible or paused or won or lost: return
	if player_role=="angler":
		controlled_step(delta,{"target":get_global_mouse_position(),"walk":Input.get_axis("left","right"),"deploy":Input.is_action_just_pressed("slow"),"release":Input.is_action_pressed("down"),"reel":Input.is_action_pressed("up"),"net_hold":Input.is_action_pressed("use"),"drag":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)})
		return
	if not movement_locked():
		var pointing := get_global_mouse_position() - fish
		if pointing.length() > 4: aim = pointing.normalized()
	var movement := Input.get_vector("left", "right", "up", "down")
	step(delta, movement, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_action_just_pressed("use"), Input.is_action_pressed("dash"), Input.is_action_pressed("slow"),Input.is_action_just_pressed("qte"))

func controlled_step(delta: float, angler_command: Dictionary = {}) -> void:
	if paused or won or lost: return
	angler.update(self,delta,angler_command)
	var command: Dictionary=fish_brain.command(self,delta)
	power=0.35
	if not movement_locked() and Vector2(command.aim).length()>0.01: aim=Vector2(command.aim).normalized()
	step(delta,command.move,command.suck,command.home,command.dash,command.slow,command.qte)

func step(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false, qte_pressed: bool = false) -> void:
	if paused or won or lost: return
	elapsed += delta
	if fish.distance_to(HOME) > 34: started = true
	if challenge and started: clock = minf(TIME_LIMIT, clock + delta)
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
	if not dash and stamina>=20: sprint_exhausted = false
	if not movement_locked():
		var pull := line_pull_velocity()
		var opposition := maxf(0,-movement.limit_length(1).dot(pull.normalized()))
		resisting = opposition>0.1 and pull.length()>2
		sprinting = dash and movement.length()>0.01 and stamina>0 and not sprint_exhausted
		if sprinting or resisting:
			stamina = maxf(0,stamina-delta*(SPRINT_DRAIN if sprinting else opposition*11))
			stamina_delay = 0.55
			if stamina<=0 and sprinting: sprint_exhausted = true
		var speed := SPRINT_SPEED if sprinting else (26.0 if slow else 70.0)
		if hooked==HookState.HOOKED:
			speed *= lerpf(0.4,1.0,clampf(stamina/20,0,1))
			if feeding: speed *= 0.68
		velocity = velocity.move_toward(movement.limit_length(1)*speed,delta*(650 if sprinting else 330))
		move_fish((velocity*vegetation_drag(fish)+water_velocity(fish)+pull)*delta)
	else: velocity = Vector2.ZERO
	if not sprinting and stamina_delay<=0: stamina = minf(100,stamina+delta*18)
	_update_contacts(delta)
	_step_net(delta)
	if won or lost or net_state=="caught": return
	var was_free := hooked == HookState.FREE
	if hooked == HookState.MOUTH:
		_step_qte(delta, qte_pressed)
	elif hooked == HookState.HOOKED:
		_step_line(delta, qte_pressed and not began_wrap)
	if won or lost or landing: return
	for index in baits.size(): _step_bait(index, delta, feeding and hooked!=HookState.MOUTH, previous_mouth)
	if hooked != HookState.FREE: returning = false
	if interact and was_free and hooked == HookState.FREE and can_home(): returning = not returning
	if returning and can_home():
		home_age += delta
		if home_age >= 2.0: finish(true, "home")
	else:
		returning = false
		home_age = 0
	if won or lost: return
	if challenge and clock >= TIME_LIMIT:
		finish(false, "timeout")
		return
	_step_supply(delta)

func _step_bait(index: int, delta: float, sucking: bool, old_mouth: Vector2) -> void:
	var bait := baits[index]
	var old_tip := Vector2(bait.tip_before)
	if bait.active:
		bait.age += delta
		if player_role=="angler" and bait.hook and not bait.removed and bound_bait!=index:
			angler.step_free_hook(self,index,delta,sucking)
		elif bound_bait==index and hooked!=HookState.FREE:
			bait.pos=mouth()-Vector2(2,1).rotated(bait.angle)
		else:
			var target: Vector2 = bait.home + water_offset(bait.home)
			bait.angle = sin(elapsed*0.75+bait.home.y*0.007)*0.16*water_strength
			if bait.hook and not bait.removed and bound_bait != index and sucking:
				var gain := strength(_tip(index)) * power
				target = target.move_toward(mouth(),gain*26)
			bait.pos = Vector2(bait.pos).move_toward(target, delta * 44)
		if bait.active and bait.hook and not bait.removed and hooked == HookState.FREE and hook_cooldown <= 0 and not net_blocks_hooks():
			var relative := _tip(index) - mouth() - aim * 3
			var before := old_tip - old_mouth - aim * 3
			if _segment_distance(before, relative, Vector2.ZERO) < BITE_RADIUS:
				_enter_hook(index)
				sucking = false
	var layer := 3
	for grain in bait.grains:
		if not grain.eaten and not grain.free: layer = mini(layer, grain.layer)
	bait.budget = minf(2, float(bait.budget) + delta * (8 + 20 * power)) if sucking else 0.0
	for grain in bait.grains:
		if grain.eaten: continue
		if not grain.free: grain.pos = Vector2(bait.pos) + Vector2(grain.offset).rotated(bait.angle)
		else: grain.pos = Vector2(grain.pos)+water_velocity(grain.pos)*delta*1.15
		if not sucking or (not bait.active and not grain.free): continue
		var pull := strength(grain.pos)
		if pull <= 0: continue
		if grain.free:
			grain.pos = Vector2(grain.pos).move_toward(mouth(), delta * 95)
			if Vector2(grain.pos).distance_to(mouth()) < 4:
				grain.eaten = true
				if not counted.has(grain.id):
					counted[grain.id] = true
					score += float(grain.points)
					stamina = minf(100,stamina+float(grain.points)*4)
					sound.play("eat")
		elif grain.layer == layer:
			grain.progress += delta * pull * power * 4.5
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
	sound.play("warn")

func _attach_hook() -> void:
	hooked = HookState.HOOKED
	qte = ""
	tension = 0.5
	reel_speed = 0
	high_age = 0
	low_age = 0
	landing_age = 0
	landing = false
	# Props are pass-through cover; only the pond perimeter constrains swimming.
	fish = fish.clamp(Vector2(25,85),Vector2(615,294))
	wraps.clear()
	wrap_target = -1
	_rebuild_rope()
	rope_length = Rope.length_of(rope_path)

func _step_qte(delta: float, qte_pressed: bool) -> void:
	if qte.is_empty(): return
	qte_age += delta
	var progress := qte_progress()
	if qte_pressed or qte_age >= 2.4:
		var success := qte_pressed and qte_age >= 0.4 and progress >= qte_zone and progress <= qte_zone + qte_width
		result_flash = 0.7
		result_good = success
		if qte=="wrap":
			if success: _commit_wrap()
			else: _fail_wrap()
			return
		_finish_qte_visual(success)
		if success:
			_release_hook(false)
		else:
			if qte == "entry": _attach_hook()
			else:
				qte = ""
				retry_age = 1.2
				low_age = 0
			sound.play("fail")

func qte_progress() -> float:
	return clampf((qte_age - 0.4) / 2.0, 0, 1)

func _step_line(delta: float, qte_pressed: bool) -> void:
	var anchor := line_anchor(bound_bait)
	var animating := winding()
	if animating: wraps[-1].progress = minf(1,wraps[-1].progress+delta/WIND_SECONDS)
	_rebuild_rope()
	latched = not wraps.is_empty()
	var length_now := anchor.distance_to(mouth()) if not latched else Vector2(wraps[-1].entry).distance_to(mouth())
	var base := 0.18 if latched else 0.5
	var available := fish_line_length if latched else rope_length
	var raw_tension := base+(length_now-available)/32
	var tuning := line_tuning()
	# Reeling is the objective. Tension feedback only tempers it or pays out under heavy load.
	var desired_speed := angler.spool_target(raw_tension,tuning,player_role=="angler")
	reel_speed = move_toward(reel_speed,desired_speed,delta*(180 if player_role=="angler" else 60)*tuning.x*maxf(1,tuning.y)) if tuning.y>0 else 0.0
	available = maxf(0,available+reel_speed*delta*(0.22 if latched else 1.0))
	if latched: fish_line_length = available
	else: rope_length = available
	tension = clampf(base+(length_now-available)/32,0,1)
	high_age = high_age + delta if tension >= 0.9 else 0.0
	if high_age >= break_hold_seconds:
		_release_hook(true)
		return
	if not latched and fish.y < 91 and absf(fish.x - anchor.x) < 30 and tension >= 0.25:
		landing_age += delta
		if landing_age >= 0.65:
			landing = true
			landing_from = fish
			landing_age = 0
			line_catches += 1
			qte = ""
			qte_result_age = 0
			velocity = Vector2.ZERO
			sprinting = false
			feeding = false
			resisting = false
			sound.play("fail")
			return
	else: landing_age = 0
	if qte=="wrap":
		if not touching_target(wrap_target): _fail_wrap()
		else: _step_qte(delta,qte_pressed)
		return
	if animating: return
	if qte == "slack":
		if tension >= 0.25:
			_finish_qte_visual(false,"张力回升")
			qte = ""
			retry_age = 1.2
			low_age = 0
			result_flash = 0.7
			result_good = false
			sound.play("fail")
		else: _step_qte(delta, qte_pressed)
	else:
		low_age = low_age + delta if tension < 0.25 and retry_age <= 0 else 0.0
		if low_age >= slack_hold_seconds:
			_open_qte("slack")

func _step_landing(delta: float) -> void:
	landing_age += delta
	var ratio := clampf(landing_age/1.05,0,1)
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
	hooked = HookState.FREE
	bound_bait = -1
	qte = ""
	wrap_target = -1
	wraps.clear()
	fish_line_length = 0
	wrap_retry = 0
	hook_cooldown = 1.8
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
	if player_role=="angler" and bound_bait>=0:
		baits[bound_bait].pos=mouth()-Vector2(2,1).rotated(baits[bound_bait].angle)
		baits[bound_bait].home=baits[bound_bait].pos
		angler.free_line_length=angler.anchor().distance_to(baits[bound_bait].pos)
		angler.previous_anchor=angler.anchor()
		angler.hook_velocity=velocity*0.3
	if broken: _finish_qte_visual(true,"鱼线断开")
	if broken: baits[bound_bait].removed = true
	_clear_hook()
	escape_count += 1
	notice = "鱼线断了！继续觅食。" if broken else "吐钩成功！换个角度继续。"
	if player_role=="angler": notice="鱼挣断了线 · Q 重新挂饵下钩" if broken else "鱼逃脱了 · 调整钓点或准备抄网"
	notice_age = 3
	result_flash = 0.7
	result_good = true
	sound.play("break" if broken else "success")

func _remaining(bait: Dictionary, attached_only: bool = false) -> bool:
	for grain in bait.grains:
		if not grain.eaten and (not attached_only or not grain.free): return true
	return false

func _step_supply(delta: float) -> void:
	if not challenge or hooked != HookState.FREE or not net_state in ["wait", "rest"]: return
	if cycle_phase.is_empty():
		for index in baits.size():
			if player_role=="angler" and baits[index].hook: continue
			if baits[index].active and (baits[index].age >= 30 or not _remaining(baits[index])):
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
		elif cycle_phase == "refill" and cycle_age >= 5:
			if _remaining(baits[cycle_slot], true): supply_queue.append(cycle_slot)
			var next := -1
			for candidate in supply_queue:
				if candidate % 2 == cycle_slot % 2:
					next = candidate
					break
			if next >= 0:
				supply_queue.erase(next)
				baits[next].active = true
				baits[next].age = 0
			cycle_phase = ""
			cycle_slot = -1

func net_warning_seconds() -> float:
	return MANUAL_NET_WARNING if manual_net else NET_WARNING

func manual_net_target(point: Vector2) -> Vector2:
	return point.clamp(Vector2(30,85),Vector2(610,280))

func record_manual_net_point(point: Vector2) -> void:
	if not manual_net or not net_state in ["prepare","warning","sweep"]: return
	var target := manual_net_target(point)
	net_aim=target
	if net_route.is_empty() or net_route[-1].distance_to(target)>=0.1:
		net_route.append(target)
	net_to=manual_net_goal()

func manual_net_goal() -> Vector2:
	return net_route[net_route_next] if net_route_next<net_route.size() else net_pos

func manual_net_pending_path() -> PackedVector2Array:
	var path := PackedVector2Array([net_pos])
	for index in range(net_route_next,net_route.size()): path.append(net_route[index])
	return path

func manual_net_blocked(point: Vector2) -> bool:
	for solid in SOLIDS:
		if Layout.touches(point,NET_RIM.y+2,PackedVector2Array(solid.points)): return true
	return false

func _manual_net_exit(point: Vector2) -> PackedVector2Array:
	var surface := Vector2(point.x,5)
	if _manual_net_lane_clear(point,surface): return PackedVector2Array([point,surface])
	# Inflate the obstacles by the turnable rim, then find a clear lift to the surface.
	var expanded: Array=[]
	for solid in SOLIDS:
		for polygon in Geometry2D.offset_polygon(PackedVector2Array(solid.points),NET_RIM.y+2,Geometry2D.JOIN_MITER):
			expanded.append({"points":Array(polygon)})
	var path := Rope.solve(surface,point,expanded)
	path.reverse()
	for index in range(1,path.size()):
		if not _manual_net_lane_clear(path[index-1],path[index]): return PackedVector2Array()
	return path

func _manual_net_lane_clear(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)))
	for step in range(steps+1):
		if manual_net_blocked(a.lerp(b,float(step)/steps)): return false
	return true

func begin_manual_net(point: Vector2) -> bool:
	if player_role!="angler" or won or lost or landing or hooked==HookState.MOUTH or not net_state in ["wait","rest"]: return false
	var start := manual_net_target(point)
	if manual_net_blocked(start):
		notice="这里放不下网口 · 移到木石旁的空水域"
		notice_age=2
		return false
	var exit_path := _manual_net_exit(start)
	if exit_path.is_empty():
		notice="这里无法提网 · 移到木石旁的空水域"
		notice_age=2
		return false
	manual_net=true
	net_queued=false
	net_aim=start
	net_kind="drop"
	net_from=start
	net_park=exit_path[-1]
	net_exit_path=exit_path
	net_pos=start
	net_last_position=start
	net_to=start
	net_angle=PI/2
	net_state="prepare"
	net_age=0
	net_motion=Vector2.ZERO
	net_blocked=false
	net_trail=PackedVector2Array([net_from])
	net_route=PackedVector2Array([start])
	net_route_next=1
	net_return_path.clear()
	net_warning_shape=_make_net_warning_outline()
	sound.play("warn")
	_net_splash(start)
	return true

func _prepare_manual_return() -> void:
	net_return_path=PackedVector2Array([net_pos])
	# Retrace the drag before taking the collision-cleared lift from the chosen start.
	for index in range(net_trail.size()-1,-1,-1):
		if net_return_path[-1].distance_to(net_trail[index])>0.01: net_return_path.append(net_trail[index])
	for point in net_exit_path:
		if net_return_path[-1].distance_to(point)>0.01: net_return_path.append(point)

func cancel_manual_net() -> void:
	if not manual_net or not net_state in ["prepare","warning","sweep"]: return
	_prepare_manual_return()
	net_state="withdraw"
	net_age=0
	net_return_from=net_pos
	net_retract_duration=maxf(0.25,_net_retract_length()/250)
	notice="已放弃抄网 · 正在撤回"
	notice_age=2

func request_net() -> void:
	if won or lost: return
	if player_role=="angler" and (landing or hooked==HookState.MOUTH): return
	if net_state in ["wait","rest"]:
		net_state="wait"
		net_queued=true
		notice="抄网练习已准备 · 脱钩后开始" if hooked!=HookState.FREE else "抄网即将入水 · 留意红光"
		notice_age=3
		if player_role=="angler": notice="抄网路线已锁定 · 收线把鱼引入网口"

func net_blocks_hooks() -> bool:
	return net_state in ["prepare", "warning", "sweep", "miss", "withdraw", "caught"]

func _net_contact(point: Vector2, angle: float = NAN) -> bool:
	if manual_net:
		return manual_net_blocked(point)
	if is_nan(angle): angle=net_angle
	var net_scale := NET_RIM+Vector2(2,2) # Include the drawn rim, not just its centerline.
	for solid in SOLIDS:
		var scaled := PackedVector2Array()
		for vertex in solid.points: scaled.append((vertex-point).rotated(-angle)/net_scale)
		if Layout.touches(Vector2.ZERO,1.0,scaled): return true
	return false

func _plan_net() -> void:
	# The rim stops at solid cover; its telegraph shows only the reachable sweep lane.
	net_kind="sweep" if net_count%2==0 else "drop"
	var y := clampf(fish.y,112,278)
	net_from = Vector2(620 if fish.x > 337 else 20,y)
	net_angle=PI if fish.x>337 else 0.0
	# A low attack must enter above bank-side rocks, never spawn with its rim inside one.
	if net_kind=="sweep":
		for attempt in range(48):
			if not _net_contact(net_from): break
			net_from.y-=2
		y=net_from.y
	var destination := Vector2(36 if fish.x > 337 else 604,y)
	if net_kind=="drop":
		net_from=Vector2(clampf(fish.x+(72 if fish.x<320 else -72),38,602),67)
		destination=Vector2(fish.x,clampf(fish.y+40,120,278))
	if player_role=="angler":
		net_kind="drop"
		net_from=Vector2(angler.anchor().x,67)
		destination=net_from+(net_aim.clamp(Vector2(30,100),Vector2(610,278))-net_from).limit_length(230)
	net_angle=(destination-net_from).angle()
	net_to = net_from
	net_blocked=false
	var steps := ceili(net_from.distance_to(destination)/2)
	for step in range(1,steps+1):
		var candidate := net_from.lerp(destination,float(step)/steps)
		if _net_contact(candidate): net_blocked=true; break
		net_to = candidate
	net_park=Vector2(net_from.x,5)
	net_pos=net_park
	net_last_position=net_pos
	net_motion=Vector2.ZERO
	net_warning_shape=_make_net_warning_outline()

func net_warning_outline() -> PackedVector2Array:
	return net_warning_shape

func _make_net_warning_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for endpoint in [net_pos if manual_net and net_state=="sweep" else net_from,net_to]:
		for index in range(48): points.append(endpoint+(Vector2.from_angle(index*TAU/48)*NET_CATCH*1.01).rotated(net_angle))
	return Geometry2D.convex_hull(points)

func _catch_in_net() -> void:
	net_state="caught"
	net_age=0
	net_return_from=net_pos
	net_catch_offset=fish-net_pos
	if manual_net: _prepare_manual_return()
	net_retract_duration=maxf(NET_LIFT,_net_retract_length()/240)
	net_catches+=1
	velocity=Vector2.ZERO
	sprinting=false
	feeding=false
	resisting=false
	returning=false
	home_age=0
	sound.play("fail")
	_net_splash(net_pos)

func _net_splash(point: Vector2) -> void:
	net_splash=0.6
	net_splash_at=point
	sound.play("splash")

func _net_retract_length() -> float:
	if manual_net and net_return_path.size()>1: return Rope.length_of(net_return_path)
	return net_return_from.distance_to(net_from)+net_from.distance_to(net_park)

func _net_retract_point(progress: float) -> Vector2:
	if manual_net and net_return_path.size()>1:
		var distance := _net_retract_length()*smoothstep(0,1,progress)
		for index in range(1,net_return_path.size()):
			var span := net_return_path[index-1].distance_to(net_return_path[index])
			if distance<=span: return net_return_path[index-1].lerp(net_return_path[index],distance/maxf(span,0.001))
			distance-=span
		return net_return_path[-1]
	# Retrace the collision-cleared route before lifting at the bank, away from wood and rocks.
	var first := net_return_from.distance_to(net_from)
	var distance := _net_retract_length()*smoothstep(0,1,progress)
	if first>0.001 and distance<first: return net_return_from.lerp(net_from,distance/first)
	var second := net_from.distance_to(net_park)
	return net_from.lerp(net_park,clampf((distance-first)/maxf(0.001,second),0,1))

func net_bag_offset() -> Vector2:
	var back := -Vector2.from_angle(net_angle)*22+Vector2(0,6)
	if net_state=="caught":
		return back.lerp(Vector2(0,17),smoothstep(0,1,net_age/NET_SETTLE))
	return back+Vector2(0,sin(elapsed*5)*2)

func _net_reaches_fish(point: Vector2, center: Vector2) -> bool:
	# The small body allowance around the rim must not reach through cover.
	for solid in SOLIDS:
		var polygon := PackedVector2Array(solid.points)
		if Geometry2D.is_point_in_polygon(point,polygon): return false
		for index in polygon.size():
			if Geometry2D.segment_intersects_segment(center,point,polygon[index],polygon[(index+1)%polygon.size()])!=null: return false
	return true

static func _net_hit_fraction(a: Vector2, b: Vector2) -> float:
	if a.length_squared()<=1: return 0
	var motion := b-a
	var aa := motion.length_squared()
	if aa<0.000001: return -1
	var bb := 2*a.dot(motion)
	var cc := a.length_squared()-1
	var discriminant := bb*bb-4*aa*cc
	if discriminant<0: return -1
	var hit := (-bb-sqrt(discriminant))/(2*aa)
	return hit if hit>=0 and hit<=1 else -1

func _finish_net_recovery() -> void:
	manual_net=false
	net_trail.clear()
	net_return_path.clear()
	net_exit_path.clear()
	net_route.clear()
	net_route_next=1
	net_state="rest"
	net_age=0
	net_wait=0
	net_recovery=2

func _step_net(delta: float) -> void:
	net_splash=maxf(0,net_splash-delta)
	net_last_position=net_pos
	if net_state in ["prepare","warning","sweep","miss","withdraw","caught"]:
		var frame_from := fish_before
		var frame_to := fish
		# Substeps resolve relative fish/net motion and preserve the actual first impact position.
		var advanced := 0.0
		while advanced<delta-0.0000001:
			var span := minf(1.0/120,delta-advanced)
			if manual_net and net_state=="sweep" and net_route_next<net_route.size():
				var distance := net_pos.distance_to(manual_net_goal())
				if distance<0.0001:
					net_route_next+=1
					continue
				# End exactly at each turn; consume the remaining time on the next leg.
				span=minf(span,distance/MANUAL_NET_SPEED)
			_advance_net(span,frame_from.lerp(frame_to,advanced/delta),frame_from.lerp(frame_to,(advanced+span)/delta))
			advanced+=span
			if won or lost or net_state=="rest": break
		if manual_net and net_state in ["prepare","warning","sweep"]:
			net_to=manual_net_goal()
			net_warning_shape=_make_net_warning_outline()
		net_motion=(net_pos-net_last_position)/maxf(delta,0.001)
		return
	if net_state == "rest":
		net_age += delta
		if net_age >= 10: net_state = "wait"; net_wait = 0
		return
	if hooked != HookState.FREE and player_role!="angler":
		net_recovery = 4
		return
	if player_role!="angler" and (not cycle_phase.is_empty() or net_recovery > 0): return
	if net_state == "wait":
		if challenge and started and player_role!="angler": net_wait += delta
		if net_queued or (player_role!="angler" and net_wait >= (18 if net_count==0 else 35)):
			net_state = "prepare"
			net_age = 0
			net_queued = false
			_plan_net()
			sound.play("warn")

func _advance_net(delta: float, frame_from: Vector2, frame_to: Vector2) -> void:
	var old_pos := net_pos
	net_age+=delta
	if net_state=="caught":
		var settle := smoothstep(0,1,net_age/NET_SETTLE)
		var ratio := clampf((net_age-NET_SETTLE)/net_retract_duration,0,1)
		net_pos=_net_retract_point(ratio)
		fish=net_pos+net_catch_offset.lerp(net_bag_offset(),settle)
		_rebuild_rope()
		if ratio>=1:
			if challenge: finish(false,"net")
			else:
				fish=HOME+Vector2(0,-14)
				fish_before=fish
				hook_cooldown=2
				notice="被抄中了 · 已回到巢边，按 N 再试"
				notice_age=4
				_finish_net_recovery()
	elif net_state=="miss":
		if net_age>=NET_MISS:
			net_state="withdraw"
			net_age=0
			net_return_from=net_pos
			if manual_net: _prepare_manual_return()
			net_retract_duration=maxf(NET_WITHDRAW,_net_retract_length()/350)
	elif net_state=="withdraw":
		net_pos=_net_retract_point(clampf(net_age/net_retract_duration,0,1))
		if net_age>=net_retract_duration: _finish_net_recovery()
	elif net_state=="prepare":
		net_pos=net_from if manual_net else net_park.lerp(net_from,smoothstep(0,1,net_age/NET_PREPARE))
		if net_age>=NET_PREPARE:
			net_state="warning"; net_age=0; net_pos=net_from; sound.play("warn")
	elif net_state == "warning":
		if net_age >= net_warning_seconds():
			net_state = "sweep"; net_age = 0; net_count += 1
			_net_splash(net_pos)
	elif net_state == "sweep":
		var old_net := net_pos
		if manual_net:
			var goal := manual_net_goal()
			var shift := goal-net_pos
			if shift.length()>0.0001:
				net_angle=shift.angle()
				var candidate := net_pos.move_toward(goal,MANUAL_NET_SPEED*delta)
				if _net_contact(candidate):
					net_blocked=true
					net_state="miss"
					net_age=0
					sound.play("tap")
				else: net_pos=candidate
			net_to=goal
		else: net_pos = net_from.lerp(net_to, smoothstep(0,1,net_age / NET_SWEEP))
		var scale := NET_CATCH
		var hit := _net_hit_fraction((frame_from-old_net).rotated(-net_angle)/scale,(frame_to-net_pos).rotated(-net_angle)/scale)
		if hit>=0 and net_state=="sweep":
			var hit_fish := frame_from.lerp(frame_to,hit)
			var hit_net := old_net.lerp(net_pos,hit)
			if _net_reaches_fish(hit_fish,hit_net):
				net_pos=hit_net
				fish=hit_fish
				_catch_in_net()
		if manual_net and net_state=="sweep":
			if net_trail.is_empty() or net_trail[-1].distance_to(net_pos)>0.0001: net_trail.append(net_pos)
			if net_route_next<net_route.size() and net_pos.distance_to(manual_net_goal())<0.0001: net_route_next+=1
			net_to=manual_net_goal()
		if net_state=="sweep" and net_age >= (MANUAL_NET_SECONDS if manual_net else NET_SWEEP):
			net_state="miss"; net_age=0
			net_dodges+=1
			notice=("网口被木石挡住" if net_blocked else "这一网扑空了") if player_role=="angler" else ("木石挡住了网口 · 可以继续觅食" if net_blocked else "躲过抄网！继续觅食。")
			notice_age=3
			if net_blocked: sound.play("tap")
	if (old_pos.y-57)*(net_pos.y-57)<0: _net_splash(Vector2(net_pos.x,57))

static func _segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var length_squared := a.distance_squared_to(b)
	var factor := clampf((point - a).dot(b - a) / length_squared, 0, 1) if length_squared > 0.000001 else 0.0
	return point.distance_to(a.lerp(b, factor))

func can_home() -> bool:
	return hooked == HookState.FREE and score >= (TARGET if challenge else 18) - 0.001 and fish.distance_to(HOME) < 29

func finish(success: bool, why: String) -> void:
	if won or lost: return
	# The shared simulation reports fish outcomes; the UI records the selected side's result.
	won = success if player_role=="fish" else why in ["net","landed"]
	lost = not won
	reason = why
	velocity = Vector2.ZERO
	if won and challenge and player_role=="angler":
		angler_wins+=1
		save_profile()
	elif success and challenge and player_role=="fish":
		wins += 1
		best_score = maxf(best_score, score)
		save_profile()
	sound.play("win" if won else "fail")
	menu.open("result")
	print("PIXEL_RESULT | role=",player_role," | success=", won, " | score=", score, " | seconds=", clock, " | reason=", why)

func hint() -> String:
	if player_role=="angler": return angler_hint()
	if landing: return "被拉出水了……" if challenge else "被拉出水了 · 正在送回巢边"
	if net_state=="caught": return "被抄网捞起……" if challenge else "被抄中了 · 正在送回巢边"
	if hooked == HookState.MOUTH: return "暂时不能移动 · 浮漂进入绿区时按空格"
	if hooked == HookState.HOOKED:
		if qte=="wrap": return "游动抗拉，保持接触 · 浮漂到绿区按空格"
		if winding(): return "正在缠绕 · 可继续游动，靠近线圈制造松线"
		if qte == "slack": return "保持松线，同时在绿区按空格"
		if contact_target>=0 and wrap_retry<=0: return "接触%s · 按空格开始缠线判定" % targets[contact_target].name
		if high_age > 0: return "持续拉紧 %.1f / %.1f 秒可断线" % [high_age,break_hold_seconds]
		if latched: return "已缠线 · 靠近线圈保持低张力，浮漂到绿区按空格"
		if stamina<20: return "体力不足 · 缠线减轻拉力，或顺线游动恢复"
		return "正在被拉向水面 · 逆线游动抗拉，接触草木石后空格缠线"
	if net_state == "prepare": return "抄网准备入水 · 留意红光方向"
	if net_state in ["warning", "sweep"]: return "上方下探 · 横向游离红色区域" if net_kind=="drop" else "横向扫网 · 向上或向下游离红色区域"
	if returning: return "正在回巢 %.1f / 2.0 秒" % home_age
	if can_home(): return "按 E 并停留 2 秒回巢"
	if score >= (TARGET if challenge else 18) - 0.001: return "食物够了！回左下角薄荷色巢穴按 E"
	if notice_age > 0: return notice
	if cycle_phase == "warning": return "闪烁的饵即将收回，剩余颗粒下次继续"
	if cycle_phase == "refill": return "正在补饵，可前往另一侧取食"
	if vegetation_drag(fish) < 1: return "浓密水草中 · 游动稍慢，向上游出草丛"
	return "左键吸食 · 滚轮调吸力 · Q 慢游 · 按住右键加速"

func angler_hint() -> String:
	if landing or net_state=="caught": return "鱼已被控制 · 正在提出水面"
	if manual_net and net_state in ["prepare","warning"]: return "抄网展开中 · 保持 E + 左键画路线，转弯会被保留"
	if manual_net and net_state=="sweep": return "网口沿所画路线前进 · 保持 E + 左键；W/S 仍可收放线"
	if angler.net_held and not net_blocks_hooks(): return "持网中 · 在水中按住左键拖动；松开 E 取消"
	if angler.casting: return "正在下钩…"
	if hooked==HookState.MOUTH: return "鱼正在尝试松口 · 挂牢后 W/S 收放线"
	if hooked==HookState.HOOKED:
		if tension>=0.88: return "张力过高！按 S 放线，避免持续高张力断线"
		if tension<0.25: return "鱼正在找机会松口 · 按 W 收线"
		if latched: return "鱼线已缠住 · W 收线压缩松口机会，E + 左键拖动抄网"
		return "W 收线 · S 放线 · A/D 移动钓位 · 按住 E + 左键拖动抄网"
	if notice_age>0: return notice
	return "Q 下钩 / 补饵 · W 收线 / S 放线 · E + 左键拖动抄网 · F3 时间设置"

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible: return
	if player_role=="angler":
		if event.is_action_released("use") or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed):
			cancel_manual_net()
		elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):
			if Input.is_action_pressed("use") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				angler.steer_net(self,get_global_transform_with_canvas().affine_inverse()*event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: paused = true; menu.open("pause")
			KEY_H: paused = true; menu.open("help")
			KEY_F3: menu.open("timing")
			KEY_F2:
				if not challenge: menu.open("practice")
			KEY_R: restart_round()
			KEY_N:
				if not challenge: request_net()
			KEY_F11: fullscreen = not fullscreen; apply_settings(); save_profile()
	elif event is InputEventMouseMotion and player_role=="fish" and not movement_locked():
		var direction := get_global_mouse_position() - fish
		if direction.length() > 4: aim = direction.normalized()
	elif event is InputEventMouseButton and event.pressed and player_role=="fish":
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: power = minf(1, power + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: power = maxf(0.1, power - 0.1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(menu) and not menu.visible and capture_mode.is_empty():
		paused = true
		menu.open("pause")

func _process(_delta: float) -> void:
	view.queue_redraw()
	if capture_mode.is_empty(): return
	capture_frame += 1
	if capture_frame == 5 and capture_mode != "menu":
		reset(true)
		if capture_mode == "game": fish = Vector2(191, 179); aim = Vector2(1, -0.25).normalized(); score = 21.75
		elif capture_mode == "qte": fish = Vector2(196, 166); _enter_hook(0); qte_age = 1.35
		elif capture_mode == "line": fish = Vector2(408, 250); _enter_hook(0); _attach_hook(); _step_line(0.01, false)
		elif capture_mode == "net": fish = Vector2(461, 205); request_net(); _step_net(0.0); net_state = "warning"; net_age = 0.8
		set_physics_process(false)
	if capture_frame == 12:
		await RenderingServer.frame_post_draw
		var output := "res://artifacts/%s.png" % capture_mode
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-output="): output = argument.trim_prefix("--capture-output=")
		var error := get_viewport().get_texture().get_image().save_png(output)
		print("PIXEL_CAPTURE | ", capture_mode, " | error=", error)
		get_tree().quit(error)
