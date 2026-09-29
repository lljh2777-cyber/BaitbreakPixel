extends Node2D

const Rope = preload("res://scripts/rope.gd")
const View = preload("res://scripts/pond_view.gd")
const Menus = preload("res://scripts/menu.gd")
const Sound = preload("res://scripts/sound.gd")
const Layout = preload("res://scripts/pond_layout.gd")
enum HookState { FREE, MOUTH, HOOKED }
const HOME := Vector2(60, 281)
const TARGET := 60.0
const TIME_LIMIT := 360.0
const SOLIDS: Array = Layout.SOLIDS

var fish := Vector2(66, 265)
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
var latched := false
var high_age := 0.0
var low_age := 0.0
var retry_age := 0.0
var landing_age := 0.0
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
	print("PIXEL_READY | side-view | 640x360 | v0.4")

func _register_inputs() -> void:
	var mapping := {"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT], "up":[KEY_W, KEY_UP], "down":[KEY_S, KEY_DOWN], "dash":[KEY_SHIFT], "use":[KEY_E], "slow":[KEY_Q], "wrap":[KEY_SPACE]}
	for action in mapping:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in mapping[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		volume = clampf(float(file.get_value("settings", "volume", 0.6)), 0, 1)
		fullscreen = bool(file.get_value("settings", "fullscreen", false))
		best_score = maxf(0, float(file.get_value("record", "best", 0)))
		wins = maxi(0, int(file.get_value("record", "wins", 0)))

func save_profile() -> void:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("record", "best", best_score)
	file.set_value("record", "wins", wins)
	save_error = file.save(save_path)

func apply_settings() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func reset(is_challenge: bool) -> void:
	challenge = is_challenge
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
	rope_path.clear()
	score = 0
	counted.clear()
	clock = 0
	elapsed = 0
	started = false
	won = false
	lost = false
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
	cycle_phase = ""
	cycle_slot = -1
	cycle_age = 0
	supply_queue.assign([2, 3])
	baits.clear()
	for index in range(4): _create_bait(index)
	paused = false
	notice = "鼠标朝向决定吸食方向 · 先试试右侧无钩饵"
	notice_age = 5
	menu.close()

func _create_bait(index: int) -> void:
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
			bait.grains.append({"id":"%d_%d" % [index, serial], "offset":offset, "pos":home + offset, "layer":layer, "fleck":serial%5, "free":false, "eaten":false, "progress":0.0, "points":18.0 / 24 if layer == 0 else 12.0 / 20})
			serial += 1
	baits.append(bait)

func mouth() -> Vector2:
	return fish + aim * 10

func _tip(index: int) -> Vector2:
	return mouth() if bound_bait == index and hooked != HookState.FREE else Vector2(baits[index].pos) + Vector2(2, 1).rotated(baits[index].angle)

func hook_point(index: int, local: Vector2) -> Vector2:
	return _tip(index)+local.rotated(baits[index].angle)

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
	return hooked==HookState.MOUTH or qte=="wrap" or winding()

func _open_qte(kind: String) -> void:
	qte = kind
	qte_age = 0
	qte_zone = rng.randf_range(0.57,0.65)
	qte_origin = Vector2(468,92) if fish.x<320 else Vector2(12,92)
	qte_result_age = 0

func _finish_qte_visual(good: bool, message: String = "") -> void:
	if qte.is_empty(): return
	qte_result_kind = qte
	qte_result_progress = qte_progress()
	qte_result_zone = qte_zone
	qte_result_good = good
	qte_result_age = 0.7
	qte_result = message if not message.is_empty() else (("缠线成功" if qte=="wrap" else "吐钩成功") if good else "判定失败")

func _begin_wrap() -> bool:
	if hooked!=HookState.HOOKED or wrap_retry>0 or winding() or not touching_target(contact_target): return false
	if target_is_wrapped(contact_target) or not qte in ["","slack"]: return false
	wrap_target = contact_target
	_open_qte("wrap")
	velocity = Vector2.ZERO
	sprinting = false
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
	rope_path = PackedVector2Array([Vector2(baits[bound_bait].home.x,53)])
	for wrap in wraps:
		rope_path.append_array(visible_coil(wrap))
	rope_path.append(mouth())

func _physics_process(delta: float) -> void:
	if menu.visible or paused or won or lost: return
	if not movement_locked():
		var pointing := get_global_mouse_position() - fish
		if pointing.length() > 4: aim = pointing.normalized()
	var movement := Input.get_vector("left", "right", "up", "down")
	step(delta, movement, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_action_just_pressed("use"), Input.is_action_pressed("dash"), Input.is_action_pressed("slow"),Input.is_action_just_pressed("wrap"))

func step(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false, wrap_pressed: bool = false) -> void:
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
	_update_contacts(delta)
	var began_wrap := false
	if wrap_pressed and qte!="wrap": began_wrap = _begin_wrap()
	sprinting = false
	stamina_delay = maxf(0,stamina_delay-delta)
	if not dash and stamina>=20: sprint_exhausted = false
	if not movement_locked():
		sprinting = dash and movement.length()>0.01 and stamina>0 and not sprint_exhausted
		if sprinting:
			stamina = maxf(0,stamina-delta*SPRINT_DRAIN)
			stamina_delay = 0.55
			if stamina<=0: sprint_exhausted = true
		var speed := SPRINT_SPEED if sprinting else (26.0 if slow else 70.0)
		velocity = velocity.move_toward(movement.limit_length(1)*speed,delta*(650 if sprinting else 330))
		move_fish((velocity*vegetation_drag(fish)+water_velocity(fish))*delta)
	else: velocity = Vector2.ZERO
	if not sprinting and stamina_delay<=0: stamina = minf(100,stamina+delta*18)
	_update_contacts(delta)
	_step_net(delta)
	if lost: return
	var was_free := hooked == HookState.FREE
	if hooked == HookState.MOUTH:
		_step_qte(delta, interact)
	elif hooked == HookState.HOOKED:
		_step_line(delta, interact,wrap_pressed and not began_wrap)
	if lost: return
	for index in baits.size(): _step_bait(index, delta, sucking and hooked == HookState.FREE, previous_mouth)
	if hooked != HookState.FREE: returning = false
	if interact and was_free and hooked == HookState.FREE and can_home(): returning = not returning
	if returning and can_home():
		home_age += delta
		if home_age >= 2.0: finish(true, "home")
	else:
		returning = false
		home_age = 0
	if won: return
	if challenge and clock >= TIME_LIMIT:
		finish(false, "timeout")
		return
	_step_supply(delta)

func _step_bait(index: int, delta: float, sucking: bool, old_mouth: Vector2) -> void:
	var bait := baits[index]
	var old_tip := Vector2(bait.tip_before)
	if bait.active:
		bait.age += delta
		var target: Vector2 = bait.home + water_offset(bait.home)
		bait.angle = sin(elapsed*0.75+bait.home.y*0.007)*0.16*water_strength
		if bait.hook and not bait.removed and bound_bait != index and sucking:
			var gain := strength(_tip(index)) * power * power
			target += (mouth() - target).normalized() * gain * 16
		bait.pos = Vector2(bait.pos).move_toward(target, delta * 28)
		if bait.hook and not bait.removed and hooked == HookState.FREE and hook_cooldown <= 0 and not net_blocks_hooks():
			var relative := _tip(index) - mouth() - aim * 3
			var before := old_tip - old_mouth - aim * 3
			if _segment_distance(before, relative, Vector2.ZERO) < 5:
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
	# Props are pass-through cover; only the pond perimeter constrains swimming.
	fish = fish.clamp(Vector2(25,85),Vector2(615,294))
	wraps.clear()
	wrap_target = -1
	_rebuild_rope()
	rope_length = Rope.length_of(rope_path)

func _step_qte(delta: float, interact: bool) -> void:
	if qte.is_empty(): return
	qte_age += delta
	var progress := qte_progress()
	if interact or qte_age >= 2.4:
		var success := interact and qte_age >= 0.4 and progress >= qte_zone and progress <= qte_zone + 0.20
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

func _step_line(delta: float, interact: bool, wrap_pressed: bool = false) -> void:
	var anchor := Vector2(baits[bound_bait].home.x, 53)
	var animating := winding()
	if animating: wraps[-1].progress = minf(1,wraps[-1].progress+delta/WIND_SECONDS)
	_rebuild_rope()
	latched = not wraps.is_empty()
	var length_now := anchor.distance_to(mouth()) if not latched else Vector2(wraps[-1].entry).distance_to(mouth())
	var base := 0.18 if latched else 0.5
	var available := fish_line_length if latched else rope_length
	var raw_tension := base+(length_now-available)/32
	var error := raw_tension-0.50
	var desired_speed := clampf(error*36,-12,16) if absf(error)>0.06 else 0.0
	# Responsive spool, with finite speed. A coil slows transmission to the fish end.
	reel_speed = move_toward(reel_speed,desired_speed,delta*60)
	if animating:
		reel_speed = 0
	else:
		var desired_length := maxf(0,length_now+(base-0.5)*32)
		if signf(desired_length-available)==signf(reel_speed):
			available = move_toward(available,desired_length,absf(reel_speed)*delta*(0.5 if latched else 1.0))
	if latched: fish_line_length = available
	else: rope_length = available
	tension = clampf(base+(length_now-available)/32,0,1)
	high_age = high_age + delta if tension >= 0.9 else 0.0
	if high_age >= 3:
		_release_hook(true)
		return
	if challenge and fish.y < 91 and absf(fish.x - anchor.x) < 30 and tension >= 0.25:
		landing_age += delta
		if landing_age >= 1: finish(false, "landed"); return
	else: landing_age = 0
	if qte=="wrap":
		if not touching_target(wrap_target): _fail_wrap()
		else: _step_qte(delta,wrap_pressed)
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
		else: _step_qte(delta, interact)
	else:
		low_age = low_age + delta if tension < 0.25 and retry_age <= 0 else 0.0
		if low_age >= 0.5:
			_open_qte("slack")

func _release_hook(broken: bool) -> void:
	if broken: _finish_qte_visual(true,"鱼线断开")
	if broken: baits[bound_bait].removed = true
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
	rope_path.clear()
	escape_count += 1
	notice = "鱼线断了！继续觅食。" if broken else "吐钩成功！换个角度继续。"
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

func request_net() -> void:
	if net_count < 3 and net_state in ["wait", "rest"]: net_queued = true

func net_blocks_hooks() -> bool:
	return net_state in ["prepare", "warning", "sweep"]

func _net_contact(point: Vector2) -> bool:
	var net_scale := Vector2(22,33)
	for solid in SOLIDS:
		var scaled := PackedVector2Array()
		for vertex in solid.points: scaled.append(vertex/net_scale)
		if Layout.touches(point/net_scale,1.0,scaled): return true
	return false

func _plan_net() -> void:
	# The rim stops at solid cover; its telegraph shows only the reachable sweep lane.
	var y := clampf(fish.y,112,245)
	net_from = Vector2(620 if fish.x > 337 else 20,y)
	var destination := Vector2(366 if fish.x > 337 else 307,y)
	net_to = net_from
	var steps := ceili(net_from.distance_to(destination)/2)
	for step in range(1,steps+1):
		var candidate := net_from.lerp(destination,float(step)/steps)
		if _net_contact(candidate): break
		net_to = candidate
	net_pos = net_from

func _step_net(delta: float) -> void:
	if net_state == "rest":
		net_age += delta
		if net_age >= 25: net_state = "wait"; net_wait = 0
		return
	if hooked != HookState.FREE:
		net_recovery = 4
		if net_state == "prepare": net_state = "wait"; net_queued = true
		return
	if not cycle_phase.is_empty() or net_recovery > 0: return
	if net_state == "wait":
		if challenge and started: net_wait += delta
		if (net_queued or net_wait >= 90) and net_count < 3:
			net_state = "prepare"
			net_age = 0
			net_queued = false
			_plan_net()
		return
	net_age += delta
	if net_state == "prepare" and net_age >= 1.5:
		net_state = "warning"; net_age = 0; sound.play("warn")
	elif net_state == "warning":
		if net_age >= 2.5:
			net_state = "sweep"; net_age = 0; net_count += 1
	elif net_state == "sweep":
		var old_net := net_pos
		net_pos = net_from.lerp(net_to, clampf(net_age / 2.3, 0, 1))
		var scale := Vector2(22, 33)
		if _segment_distance((fish_before - old_net) / scale, (fish - net_pos) / scale, Vector2.ZERO) <= 1:
			finish(false, "net")
		elif net_age >= 2.3:
			net_state = "rest"; net_age = 0
			notice = "躲过抄网！趁休整继续吃饵。"; notice_age = 3

static func _segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var length_squared := a.distance_squared_to(b)
	var factor := clampf((point - a).dot(b - a) / length_squared, 0, 1) if length_squared > 0.000001 else 0.0
	return point.distance_to(a.lerp(b, factor))

func can_home() -> bool:
	return hooked == HookState.FREE and score >= (TARGET if challenge else 18) - 0.001 and fish.distance_to(HOME) < 29

func finish(success: bool, why: String) -> void:
	if won or lost: return
	won = success
	lost = not success
	reason = why
	velocity = Vector2.ZERO
	if success and challenge:
		wins += 1
		best_score = maxf(best_score, score)
		save_profile()
	sound.play("win" if success else "fail")
	menu.open("result")
	print("PIXEL_RESULT | success=", success, " | score=", score, " | seconds=", clock, " | reason=", why)

func hint() -> String:
	if hooked == HookState.MOUTH: return "暂时不能移动 · 白区内按 E 吐钩"
	if hooked == HookState.HOOKED:
		if qte=="wrap": return "缠线判定 · 白区内再按一次空格"
		if winding(): return "正在自动缠绕一圈……"
		if qte == "slack": return "保持松线，同时在白区按 E"
		if contact_target>=0 and wrap_retry<=0: return "接触%s · 按空格开始缠线判定" % targets[contact_target].name
		if high_age > 0: return "持续拉紧 %.1f / 3.0 秒可断线" % high_age
		if latched: return "已缠线 · 靠近线圈保持低张力，圆环白区按 E"
		return "游入水草、木枝或石头 · 空格缠线；也可持续拉紧断线"
	if net_state == "prepare": return "钓鱼者正收竿，准备抄网……"
	if net_state in ["warning", "sweep"]: return "红光是抄网来向 · 游离红框，或升降躲避"
	if returning: return "正在回巢 %.1f / 2.0 秒" % home_age
	if can_home(): return "按 E 并停留 2 秒回巢"
	if score >= (TARGET if challenge else 18) - 0.001: return "食物够了！回左下角薄荷色巢穴按 E"
	if notice_age > 0: return notice
	if cycle_phase == "warning": return "闪烁的饵即将收回，剩余颗粒下次继续"
	if cycle_phase == "refill": return "正在补饵，可前往另一侧取食"
	if vegetation_drag(fish) < 1: return "浓密水草中 · 游动稍慢，向上游出草丛"
	return "左键吸食 · 滚轮调吸力 · Q 慢游 · 长按 Shift 加速"

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: paused = true; menu.open("pause")
			KEY_H: paused = true; menu.open("help")
			KEY_R: reset(challenge)
			KEY_N:
				if not challenge: request_net()
			KEY_F11: fullscreen = not fullscreen; apply_settings(); save_profile()
	elif event is InputEventMouseMotion and not movement_locked():
		var direction := get_global_mouse_position() - fish
		if direction.length() > 4: aim = direction.normalized()
	elif event is InputEventMouseButton and event.pressed:
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
