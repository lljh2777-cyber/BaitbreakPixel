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
var dash_age := 0.0
var dash_dir := Vector2.RIGHT
var fish_before := Vector2.ZERO
var hooked := HookState.FREE
var bound_bait := -1
var hook_cooldown := 0.0
var rope_path := PackedVector2Array()
var rope_length := 0.0
var tension := 0.0
var latched := false
var high_age := 0.0
var low_age := 0.0
var retry_age := 0.0
var landing_age := 0.0
var qte := ""
var qte_age := 0.0
var qte_zone := 0.60
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
	print("PIXEL_READY | side-view | 640x360 | v0.2")

func _register_inputs() -> void:
	var mapping := {"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT], "up":[KEY_W, KEY_UP, KEY_SPACE], "down":[KEY_S, KEY_DOWN, KEY_CTRL], "dash":[KEY_SHIFT], "use":[KEY_E], "slow":[KEY_Q]}
	for action in mapping:
		if not InputMap.has_action(action): InputMap.add_action(action)
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
	dash_age = 0
	hooked = HookState.FREE
	bound_bait = -1
	hook_cooldown = 0
	qte = ""
	qte_age = 0
	result_flash = 0
	tension = 0
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
	var bait := {"id":index, "home":home, "pos":home, "hook":hooked_bait, "removed":false, "active":index < 2, "age":0.0, "budget":0.0, "grains":[], "tip_before":home + Vector2(5, 10)}
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
	return mouth() if bound_bait == index and hooked != HookState.FREE else Vector2(baits[index].pos) + Vector2(5, 10)

func strength(point: Vector2) -> float:
	var local := point - mouth()
	var depth := local.dot(aim)
	var side := absf(local.cross(aim))
	if depth < 0 or depth > 44 or side > 4 + depth * 0.53: return 0
	if not Rope.clear(mouth(), point, SOLIDS): return 0
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
	var slices := maxi(1, ceili(motion.length() / 2.0))
	var part := motion / slices
	for index in slices:
		for axis in range(2):
			var point := fish
			point[axis] += part[axis]
			point = point.clamp(Vector2(radius + 8, 68 + radius), Vector2(632 - radius, 311 - radius))
			if not _collision(point, radius): fish = point

func _physics_process(delta: float) -> void:
	if menu.visible or paused or won or lost: return
	if hooked != HookState.MOUTH:
		var pointing := get_global_mouse_position() - fish
		if pointing.length() > 4: aim = pointing.normalized()
	var movement := Input.get_vector("left", "right", "up", "down")
	step(delta, movement, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_action_just_pressed("use"), Input.is_action_just_pressed("dash"), Input.is_action_pressed("slow"))

func step(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false) -> void:
	if paused or won or lost: return
	elapsed += delta
	if fish.distance_to(HOME) > 34: started = true
	if challenge and started: clock = minf(TIME_LIMIT, clock + delta)
	notice_age = maxf(0, notice_age - delta)
	result_flash = maxf(0, result_flash - delta)
	hook_cooldown = maxf(0, hook_cooldown - delta)
	retry_age = maxf(0, retry_age - delta)
	net_recovery = maxf(0, net_recovery - delta)
	fish_before = fish
	var previous_mouth := mouth()
	if hooked != HookState.MOUTH:
		if dash and stamina >= 25 and dash_age <= 0:
			dash_dir = movement.normalized() if movement.length() > 0.01 else aim
			dash_age = 0.27
			stamina -= 25
		if dash_age > 0:
			dash_age = maxf(0, dash_age - delta)
			velocity = dash_dir * 145
		else:
			stamina = minf(100, stamina + delta * 11)
			velocity = velocity.move_toward(movement.limit_length(1) * (26 if slow else 70), delta * 330)
		move_fish(velocity * delta * vegetation_drag(fish))
	else: velocity = Vector2.ZERO
	_step_net(delta)
	if lost: return
	var was_free := hooked == HookState.FREE
	if hooked == HookState.MOUTH:
		_step_qte(delta, interact)
	elif hooked == HookState.HOOKED:
		_step_line(delta, interact)
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
		var target: Vector2 = bait.home + Vector2(sin(elapsed * 1.5 + index) * 3.0, sin(elapsed * 2.1) * 2.0)
		if bait.hook and not bait.removed and bound_bait != index and sucking:
			var gain := strength(_tip(index)) * power * power
			target += (mouth() - target).normalized() * gain * 16
		bait.pos = Vector2(bait.pos).move_toward(target, delta * 28)
		if bait.hook and not bait.removed and hooked == HookState.FREE and hook_cooldown <= 0 and not net_blocks_hooks():
			var relative := _tip(index) - mouth() - aim * 3
			var before := old_tip - old_mouth - aim * 3
			if _segment_distance(before, relative, Vector2.ZERO) < 5 and Rope.clear(mouth(), _tip(index), SOLIDS):
				_enter_hook(index)
				sucking = false
	var layer := 3
	for grain in bait.grains:
		if not grain.eaten and not grain.free: layer = mini(layer, grain.layer)
	bait.budget = minf(2, float(bait.budget) + delta * (8 + 20 * power)) if sucking else 0.0
	for grain in bait.grains:
		if grain.eaten: continue
		if not grain.free: grain.pos = Vector2(bait.pos) + Vector2(grain.offset)
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
	dash_age = 0
	qte = "entry"
	qte_age = 0
	qte_zone = rng.randf_range(0.57, 0.65)
	hook_count += 1
	returning = false
	sound.play("warn")

func _attach_hook() -> void:
	hooked = HookState.HOOKED
	qte = ""
	tension = 0.5
	high_age = 0
	low_age = 0
	landing_age = 0
	# The larger hooked body must also respect the floor after it is separated from a prop.
	fish = fish.clamp(Vector2(25,85),Vector2(615,294))
	for iteration in range(20):
		if not _collision(fish, 17): break
		for solid in SOLIDS:
			var polygon := PackedVector2Array(solid.points)
			var nearest := Layout.nearest_boundary(fish,polygon)
			var away := fish - nearest
			if Geometry2D.is_point_in_polygon(fish,polygon):
				fish = nearest - away.normalized()*17.01
			elif away.length() > 0.001 and away.length() < 17: fish += away.normalized() * (17.01 - away.length())
		fish = fish.clamp(Vector2(25,85),Vector2(615,294))
	rope_path = Rope.solve(Vector2(baits[bound_bait].home.x, 53), mouth(), SOLIDS)
	rope_length = Rope.length_of(rope_path)

func _step_qte(delta: float, interact: bool) -> void:
	if qte.is_empty(): return
	qte_age += delta
	var progress := qte_progress()
	if interact or qte_age >= 2.4:
		var success := interact and qte_age >= 0.4 and progress >= qte_zone and progress <= qte_zone + 0.20
		result_flash = 0.7
		result_good = success
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

func _step_line(delta: float, interact: bool) -> void:
	var anchor := Vector2(baits[bound_bait].home.x, 53)
	var solved := Rope.solve(anchor, mouth(), SOLIDS)
	if not solved.is_empty(): rope_path = solved
	latched = rope_path.size() > 2
	var length_now := Rope.length_of(rope_path)
	var base := 0.38 if latched else 0.5
	tension = clampf(base + (length_now - rope_length) / 32, 0, 1)
	if tension > 0.75: rope_length += delta * 2.0
	elif tension < 0.35: rope_length -= delta * 3.0
	else: rope_length -= delta * 2.0
	tension = clampf(base + (length_now - rope_length) / 32, 0, 1)
	high_age = high_age + delta if tension >= 0.9 else 0.0
	if high_age >= 3:
		_release_hook(true)
		return
	if challenge and fish.y < 91 and absf(fish.x - anchor.x) < 30 and tension >= 0.25:
		landing_age += delta
		if landing_age >= 1: finish(false, "landed"); return
	else: landing_age = 0
	if qte == "slack":
		if tension >= 0.25:
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
			qte = "slack"
			qte_age = 0
			qte_zone = rng.randf_range(0.57, 0.65)

func _release_hook(broken: bool) -> void:
	if broken: baits[bound_bait].removed = true
	hooked = HookState.FREE
	bound_bait = -1
	qte = ""
	hook_cooldown = 1.8
	net_recovery = 4
	latched = false
	tension = 0
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
		if qte == "slack": return "保持松线，同时在白区按 E"
		if high_age > 0: return "持续拉紧 %.1f / 3.0 秒可断线" % high_age
		return "靠近线的接触点制造松线；或远游持续拉紧断线"
	if net_state == "prepare": return "钓鱼者正收竿，准备抄网……"
	if net_state in ["warning", "sweep"]: return "红光是抄网来向 · 游离红框，或升降躲避"
	if returning: return "正在回巢 %.1f / 2.0 秒" % home_age
	if can_home(): return "按 E 并停留 2 秒回巢"
	if score >= (TARGET if challenge else 18) - 0.001: return "食物够了！回左下角薄荷色巢穴按 E"
	if notice_age > 0: return notice
	if cycle_phase == "warning": return "闪烁的饵即将收回，剩余颗粒下次继续"
	if cycle_phase == "refill": return "正在补饵，可前往另一侧取食"
	if vegetation_drag(fish) < 1: return "浓密水草中 · 游动稍慢，向上游出草丛"
	return "左键吸食 · 滚轮调吸力 · Q 慢游 · Shift 冲刺"

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
	elif event is InputEventMouseMotion and hooked != HookState.MOUTH:
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
