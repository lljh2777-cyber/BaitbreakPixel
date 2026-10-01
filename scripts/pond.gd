extends "res://scripts/world_simulation.gd"

# Local application adapter. The base simulation has no input, menus, audio or profile I/O.
const RulesStore = preload("res://scripts/rules_store.gd")
var saved_rules := Rules.defaults()

const View = preload("res://scripts/pond_view.gd")
const Menus = preload("res://scripts/menu.gd")
const Sound = preload("res://scripts/sound.gd")
const FishBrain = preload("res://scripts/fish_brain.gd")
const AnglerBrain = preload("res://scripts/angler_brain.gd")
const LocalInput = preload("res://scripts/local_input.gd")
const Network = preload("res://scripts/network_session.gd")
var network: Node
var fish_brain := FishBrain.new()
var angler_brain := AnglerBrain.new()
var local_input := LocalInput.new()
var player_role := "fish"
var fish_source := "local"
var angler_source := "ai"
var shared_session := false
var paused := false
var won: bool:
	get: return match_over and winner_role==player_role
var lost: bool:
	get: return match_over and winner_role!=player_role
var angler_wins := 0
var view: Node2D
var menu: Control
var sound: Node
var volume := 0.6
var fullscreen := false
var best_score := 0.0
var wins := 0
var save_path := "user://pixel.cfg"
var save_error := OK
var capture_mode := ""
var capture_frame := 0

func reset(is_challenge: bool, role: String = "fish") -> void:
	if is_instance_valid(network) and network.active(): network.close(true)
	player_role="angler" if role=="angler" else "fish"
	shared_session=false
	fish_source="ai" if player_role=="angler" else "local"
	angler_source="local" if player_role=="angler" else "ai"
	var brain_seed := rng.randi()
	reset_world({"ruleset":"duel" if player_role=="angler" else "survival","challenge":is_challenge,"seed":rng.randi(),"rules":saved_rules})
	fish_brain.reset(brain_seed)
	local_input.reset()
	Input.use_accumulated_input=player_role!="angler"
	paused=false
	menu.close()

func start_shared_session(local_role: String, config: Dictionary) -> void:
	player_role="angler" if local_role=="angler" else "fish"
	shared_session=true
	fish_source="external"
	angler_source="external"
	reset_world(config)
	local_input.reset()
	Input.use_accumulated_input=player_role!="angler"
	paused=false
	menu.close()

func step(delta: float, movement: Vector2, sucking: bool, interact: bool, dash: bool = false, slow: bool = false, qte_pressed: bool = false) -> void:
	if paused and not shared_session: return
	super.step(delta,movement,sucking,interact,dash,slow,qte_pressed)

func suspend_local_controls() -> void:
	local_input.suspend()

func _present_result(_winner: String, _cause: String) -> void:
	if won and challenge:
		if player_role=="angler": angler_wins+=1
		else:
			wins+=1
			best_score=maxf(best_score,score)
		save_profile()
	sound.play("win" if won else "fail")
	menu.open("result")
	print("PIXEL_RESULT | role=",player_role," | success=",won," | score=",score," | seconds=",clock," | reason=",reason)

func _ready() -> void:
	Engine.max_fps = 60
	rng.seed = 2649
	_register_inputs()
	if "--test-profile" in OS.get_cmdline_user_args(): save_path = "user://pixel-test.cfg"
	else: _load_profile()
	sound = Sound.new()
	add_child(sound)
	feedback_requested.connect(_play_local_feedback)
	match_ended.connect(_present_result)
	network=Network.new()
	network.game=self
	add_child(network)
	network.changed.connect(_network_changed)
	feedback_requested.connect(network.remember_feedback)
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
	print("PIXEL_READY | asymmetric-2d | 640x360 | v0.22.5 | expanded-pond-unified-suction")

func _register_inputs() -> void:
	var mapping := {"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT], "up":[KEY_W, KEY_UP], "down":[KEY_S, KEY_DOWN], "dash":[], "use":[KEY_E], "slow":[KEY_Q], "qte":[KEY_SPACE], "untangle":[KEY_F]}
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

func _play_local_feedback(cue: String) -> void:
	if cue.begins_with("qte_") or cue.begins_with("effort_"):
		if not cue.ends_with("_"+player_role): return
		sound.play("qte" if cue.begins_with("qte_") else ("success" if cue.begins_with("effort_good_") else "fail"))
	else: sound.play(cue)

func _load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		volume = clampf(float(file.get_value("settings", "volume", 0.6)), 0, 1)
		fullscreen = bool(file.get_value("settings", "fullscreen", false))
		best_score = maxf(0, float(file.get_value("record", "best", 0)))
		wins = maxi(0, int(file.get_value("record", "wins", 0)))
		angler_wins=maxi(0,int(file.get_value("record","angler_wins",0)))
		saved_rules=RulesStore.load_profile(file)

func save_profile() -> void:
	var file := ConfigFile.new()
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("record", "best", best_score)
	file.set_value("record", "wins", wins)
	file.set_value("record","angler_wins",angler_wins)
	RulesStore.save_profile(file,saved_rules)
	save_error = file.save(save_path)

func apply_settings() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func restart_round() -> void:
	if is_instance_valid(network) and network.active():
		if network.status=="finished": network.set_ready(not network.local_ready)
	elif not shared_session: reset(challenge,player_role)

func return_to_title() -> void:
	network.close(true)
	reset(false)
	menu.open("title")

func _network_changed() -> void:
	if not is_instance_valid(menu): return
	if network.status=="failed" and shared_session and match_over: menu.open("result")
	elif network.status in ["waiting","connecting","failed"]: menu.open("room")
	elif network.status in ["starting","countdown"]: menu.close()

func network_settings() -> Dictionary:
	return {"rules":Rules.normalize(saved_rules)}

func rules_preset_path() -> String:
	return "user://rules-presets-test" if "--test-profile" in OS.get_cmdline_user_args() else "user://rules-presets"

func screen_to_game(point: Vector2) -> Vector2:
	var shown: Node2D=network.display_world() if is_instance_valid(network) and network.active() and shared_session else self
	return View.Shore.to_world(point,shown) if player_role=="angler" and not shown.net_action.observing else View.Camera.to_world(point,shown,player_role)

func _network_command() -> Dictionary:
	var role: String=network.local_role
	if menu.visible:
		var neutral: Dictionary=network.Protocol.neutral(role,self)
		if role=="angler":
			neutral.net_events=local_input.net_events.duplicate(true)
			local_input.net_events.clear()
		return neutral
	var pointer := get_global_mouse_position()
	if role=="angler": return local_input.angler_command(self,screen_to_game(pointer))
	network.local_power=clampf(network.local_power+local_input.power_steps*0.1,0.1,1)
	var command := local_input.fish_command(network.display_world(),screen_to_game(pointer))
	command.power=network.local_power
	return command

func _physics_process(_delta: float) -> void:
	if is_instance_valid(network) and network.active():
		network.poll()
		if network.active(): network.tick(TICK_SECONDS,_network_command() if network.status=="playing" else {})
		return
	if shared_session or menu.visible or paused or match_over: return
	var pointer := get_global_mouse_position()
	var fish_command: Dictionary=fish_brain.command(self,TICK_SECONDS) if fish_source=="ai" else local_input.fish_command(self,screen_to_game(pointer))
	var angler_command: Dictionary=angler_brain.command(self,TICK_SECONDS) if angler_source=="ai" else local_input.angler_command(self,screen_to_game(pointer))
	advance_tick(fish_command,angler_command)

func controlled_step(delta: float, angler_command: Dictionary = {}) -> void:
	if paused or match_over: return
	simulate(delta,fish_brain.command(self,delta),angler_command)

func hint() -> String:
	if player_role=="angler": return angler_hint()
	if net_action.slow_age>0: return "擦到网边 · 短暂减速，仍可游动"
	if landing: return "被拉出水了……" if challenge else "被拉出水了 · 正在送回巢边"
	if net_state=="caught": return "被抄网捞起……" if challenge else "被抄中了 · 正在送回巢边"
	if hooked == HookState.MOUTH: return "暂时不能移动 · 浮漂进入绿区时按空格"
	if hooked == HookState.HOOKED:
		if qte.is_empty() and effort_checks.fish.active: return "继续游动抗拉 · 发力浮漂到绿区按空格"
		if qte=="wrap": return "游动抗拉，保持接触 · 浮漂到绿区按空格"
		if winding(): return "正在缠绕 · 可继续游动，靠近线圈制造松线"
		if qte == "slack": return "保持松线，同时在绿区按空格"
		if untangle_phase=="check": return "对方正在解缠 · 游动改变张力，或争取松口"
		if untangle_phase=="unwind": return "线圈正在退开 · 仍可游动、松口或拉断线"
		if contact_target>=0 and wrap_retry<=0: return "接触%s · 按空格开始缠线判定" % targets[contact_target].name
		if high_age > 0: return "持续拉紧 %.1f / %.1f 秒可断线" % [high_age,break_hold_seconds]
		if latched: return "已缠线 · 靠近线圈保持低张力，浮漂到绿区按空格"
		if stamina_ratio()<rule("fatigue_threshold"): return "体力不足 · 缠线减轻拉力，或顺线游动恢复"
		return "正在被拉向水面 · 逆线游动抗拉，接触草木石后空格缠线"
	if manual_net and net_state in ["prepare","warning"]: return "对方正在展开抄网 · 留意网口，游开一段距离"
	if manual_net and net_state=="sweep": return "远离正在移动的网口 · 木石可以挡住抄网"
	if net_state == "prepare": return "抄网准备入水 · 留意红光方向"
	if net_state in ["warning", "sweep"]: return "上方下探 · 横向游离红色区域" if net_kind=="drop" else "横向扫网 · 向上或向下游离红色区域"
	if returning: return "正在回巢 %.1f / %.1f 秒" % [home_age,rule("home_hold")]
	if can_home(): return "按 E 并停留 %.1f 秒回巢" % rule("home_hold")
	if score >= food_target() - 0.001: return "食物够了！沿巢穴方向返回，按 E"
	if notice_age > 0 and not uses_mobile_tackle(): return notice
	if cycle_phase == "warning": return "闪烁的饵即将收回，剩余颗粒下次继续"
	if cycle_phase == "refill": return "正在补饵，可前往另一侧取食"
	if vegetation_drag(fish) < 1: return "浓密水草中 · 游动稍慢，向上游出草丛"
	return "左键吸食 · 滚轮轻吸/猛吸 · Q 慢游 · 按住右键加速"

func angler_hint() -> String:
	if landing or net_state=="caught": return "鱼已被控制 · 正在提出水面"
	if untangle_phase=="check": return "W/S 保持张力 %d–%d%% · 绿区按空格解缠" % [rule("untangle_min")*100,rule("untangle_max")*100]
	if untangle_phase=="unwind": return "正在退开一圈 · 可继续 W/S 控线，鱼仍可能逃脱"
	if untangle_phase=="recover": return "解缠失败 · 线圈保留，短暂恢复中"
	if effort_checks.angler.active: return "保持 W 收线 · 发力浮漂到绿区按空格"
	if net_action.observing: return "左键选终点 B · E 取消，仍消耗冷却" if net_action.has_a else "左键选起点 A · 观察期间世界继续运行"
	if Net.busy(self): return "路线已锁定 · 挥网期间暂停摇轮，鱼线仍有拉力"
	if angler.net_cooldown>0: return "抄网恢复 %.1f 秒 · W/S 控线，A/D 移竿" % angler.net_cooldown
	if angler.casting: return "正在下钩…"
	if hooked==HookState.MOUTH: return "鱼正在尝试松口 · 挂牢后 W/S 收放线"
	if hooked==HookState.HOOKED:
		if tension>=0.88: return "张力过高！按 S 放线，避免持续高张力断线"
		if tension<rule("tension_low"): return "鱼正在找机会松口 · 按 W 收线"
		if latched:
			return "鱼线缠住 · 解缠恢复 %.1fs，W/S 保持控制" % untangle_cooldown if untangle_cooldown>0 else "鱼线缠住 · F 解缠，W/S 保持张力并按空格判定"
		return "W 收线 · S 放线 · A/D 左右移竿 · E 观察 · 左键选 A/B"
	if notice_age>0: return notice
	return "Q 下钩 / 补饵 · W/S 收放线 · E 观察 · 左键选 A/B" if shared_session else "Q 下钩 / 补饵 · W 收线 / S 放线 · E 观察 · 左键选 A/B · F3 玩法规则"

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible: return
	var point := Vector2.ZERO
	if event is InputEventMouse: point=screen_to_game(get_global_transform_with_canvas().affine_inverse()*event.position)
	if player_role=="angler" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var shown: Node2D=network.display_world() if is_instance_valid(network) and network.active() and shared_session else self
		if not shown.net_action.observing or not View.Observation.interactive(view,shown,View.Camera.to_screen(point,shown,"angler")): return
	local_input.handle(event,player_role,point)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: paused = true; menu.open("pause")
			KEY_H: paused = true; menu.open("help")
			KEY_F3: menu.open("rules")
			KEY_F2: menu.open("rules")
			KEY_R: restart_round()
			KEY_N:
				if not shared_session and not challenge: request_net()
			KEY_F11: fullscreen = not fullscreen; apply_settings(); save_profile()
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
