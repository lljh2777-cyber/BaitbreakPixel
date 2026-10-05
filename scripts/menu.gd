extends Control

const RulesSettings = preload("res://scripts/rules_settings.gd")
var rules_previous := "settings"
var rules_editor: Control

var game: Node2D
var screen := "title"
var previous := "title"
var content: Control
var first_button: Button
var net_address := "127.0.0.1"
var net_port := "24712"
var net_role := "fish"
var room_status: Label
var ready_button: Button
var room_roles: Label
var room_map: Label
const CREAM := Color("fff0cd")
const GOLD := Color("ffd379")
const MINT := Color("8de0bd")
const INK := Color("142e39")

func _ready() -> void:
	# Parent is Node2D, so use the game's fixed logical viewport explicitly.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(640,360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	add_theme_font_override("font",font)
	add_theme_font_size_override("font_size",12)

func style(color: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.content_margin_left = 10
	result.content_margin_right = 10
	return result

func open(which: String) -> void:
	var rule_category := "体力"
	if which in ["practice","timing","effort"]:
		if game.shared_session: return
		rule_category="收放线" if which=="practice" else "张力与逃脱" if which=="timing" else "QTE·鱼发力"
		which="rules"
	if which=="rules" and screen!="rules": rules_previous=screen if visible else "pause"
	if which!="result": game.local_input.suspend_qte()
	if game.player_role=="angler" and which!="result": game.suspend_local_controls()
	if which in ["help","settings"] and (not visible or not screen in ["help","settings","rules"]):
		previous = screen if visible else "pause"
	screen = which
	game.paused = true
	visible = true
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.09,0.12,0.68)
	content.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Panel.new()
	frame.position = Vector2(28,54) if which == "title" else Vector2(136,33)
	frame.size = Vector2(294,280) if which == "title" else Vector2(368,296)
	if which=="title": frame.position.y=29; frame.size.y=306
	if which=="rules": frame.position=Vector2(16,12); frame.size=Vector2(608,336)
	if which in ["network","room"]: frame.position=Vector2(91,20); frame.size=Vector2(458,322)
	frame.add_theme_stylebox_override("panel",style(INK,Color("527b7b")))
	content.add_child(frame)
	first_button = null
	match which:
		"title": _title(frame)
		"map": _map_choice(frame)
		"pause": _pause(frame)
		"help": _help(frame)
		"settings": _settings(frame)
		"rules": _rules(frame,rule_category)
		"result": _result(frame)
		"network": _network(frame)
		"room": _room(frame)
	if first_button: first_button.grab_focus()

func close() -> void:
	game.local_input.suspend_qte()
	visible = false
	game.paused = false

func text(parent: Control, value: String, point: Vector2, size_px: int = 12, color: Color = CREAM, width: float = 326) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size.x = width
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func button(parent: Control, title: String, y: float, action: Callable, primary: bool = false, width: float = 326) -> Button:
	var result := Button.new()
	result.text = title
	result.position = Vector2(20,y)
	result.size = Vector2(width,28)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_stylebox_override("normal",style(GOLD if primary else Color("23444e"),GOLD if primary else Color("416770")))
	result.add_theme_stylebox_override("hover",style(Color("ffe3a2") if primary else Color("365d63"),CREAM))
	result.add_theme_stylebox_override("pressed",style(Color("9ed9b7"),CREAM))
	result.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,CREAM))
	for kind in ["font_color","font_hover_color","font_focus_color"]:
		result.add_theme_color_override(kind,INK if primary else CREAM)
	result.add_theme_color_override("font_pressed_color",INK)
	result.pressed.connect(action)
	parent.add_child(result)
	if first_button == null: first_button = result
	return result

func _title(frame: Control) -> void:
	text(frame,"BAITBREAK  /  PIXEL",Vector2(20,16),11,Color("8de0bd"))
	text(frame,"吃饵，不上钩",Vector2(18,38),27)
	text(frame,"一座池塘 · 两种立场",Vector2(21,80),13,Color("b4c8bc"))
	button(frame,"小鱼挑战   ·   对抗钓鱼人 AI",104,func(): game.reset(true),true,254)
	button(frame,"钓鱼人挑战   ·   对抗小鱼 AI",138,func(): game.reset(true,"angler"),false,254)
	button(frame,"自由练习   ·   双角色 / 调节参数",172,func(): game.reset(false),false,254)
	button(frame,"双人联机   ·   局域网 / 本机",206,func(): open("network"),false,254)
	button(frame,"操作说明",240,func(): open("help"),false,254)
	button(frame,"设置",274,func(): open("settings"),false,124)
	var quit := button(frame,"退出",274,func(): get_tree().quit(),false,124)
	quit.position.x = 150
	var maps:=button(content,game.map_caption(),301,func(): open("map"),false,275)
	maps.position.x=341; maps.add_theme_font_size_override("font_size",10)
	text(content,"0.27.5 · 程序生成池塘",Vector2(341,280),10,Color("91afa7"))
	text(content,"小鱼 · 吃饵脱身",Vector2(391,119),18,GOLD)
	text(content,"人类 · 收线抄网",Vector2(391,159),18,GOLD)
	text(content,"独自练习 · 双人对战",Vector2(375,199),16,GOLD)
	text(content,"自定规则 · 一场拉锯",Vector2(391,239),12,CREAM)

func _pause(frame: Control) -> void:
	text(frame,"水下小憩",Vector2(20,19),24)
	button(frame,"继续本局",57,close,true)
	if not game.shared_session:
		if game.selected_map_source.kind=="generated":
			button(frame,"同 Seed 重开 · R",89,func(): game.restart_round(),false,158)
			var fresh:=button(frame,"新地图",89,func(): game.new_map_round(),false,158); fresh.position.x=188
		else: button(frame,"重新开始本局",89,func(): game.restart_round())
	else: text(frame,"联机对局继续运行，菜单不会暂停",Vector2(20,108),12,GOLD)
	var offset := 0
	if not game.challenge and not game.shared_session:
		button(frame,"玩法规则 · F3",121,func(): open("practice"),false,158)
		var net_button := button(frame,"改练小鱼" if game.player_role=="angler" else "改练钓鱼人",121,func(): game.reset(false,"fish" if game.player_role=="angler" else "angler"),false,158)
		net_button.position.x=188
		offset=32
	button(frame,"操作说明",121+offset,func(): open("help"))
	button(frame,"设置",153+offset,func(): open("settings"))
	button(frame,"离开房间" if game.shared_session else "返回标题",185+offset,func(): game.return_to_title())
	text(frame,"Esc 返回对局" if game.shared_session else "Esc 继续 · 切出窗口会自动暂停",Vector2(20,258),11,Color("91afa7"))

func _help(frame: Control) -> void:
	var human: bool=game.player_role=="angler"
	text(frame,"把鱼带出水面" if human else "怎样在池塘里活下来",Vector2(20,16),21)
	var lines := [
		"WASD / 方向键 游动 · 鼠标决定朝向",
		"左键吸食 · 靠近自动咬食 · 滚轮调吸力 · Q 慢游",
		"按住右键加速耗体力 · 吃饵补体力",
		"所有 QTE：浮漂到绿色判定区按空格",
		"上钩抗拉会触发发力：成功加力，失败脱力",
		"接触草木石按空格，边游抗拉、绿区再按",
		"缠线后松线按空格脱钩 · 持续拉紧可断线",
		"对手抄网：收拢前游出网口 · 木石能挡网",
		"吃够食物回左下巢穴，按 E 停留 %.1f 秒" % game.rule("home_hold"),
		"R 重开 · Esc 暂停 · F3 规则 · 练习 N 试网"
	]
	if human:
		lines=[
			"A / D 左右移竿 · 按住右键以 2 倍速度移动",
			"Q 下钩；饵用完 / 断线后 Q 重新挂饵",
			"W 收线 · S 放线，未咬钩时也能调整深度",
			"F 解缠 · W/S 保持张力 %d–%d%%" % [game.rule("untangle_min")*100,game.rule("untangle_max")*100],
			"持续过紧会断线 · 过松会给鱼脱钩机会",
			"听音准备 · 空格判定，解缠成功退开一圈",
			"E 观察，左键选 A/B；再按 E 取消并冷却",
			"保持网口接触直到收拢 · 疲惫的鱼更易捞",
			"规定时间内提鱼出水获胜；F3 查看玩法规则",
			"鱼吃满目标回巢则失败 · R 重开 / Esc 暂停"
		]
	if game.shared_session:
		lines[8]="时限内提鱼获胜 · 鱼回巢或超时则败" if human else "吃满回巢，或存活到超时，即可获胜"
		lines[9]="Esc 打开菜单 · 联机对局不会暂停"
	for index in lines.size(): text(frame,lines[index],Vector2(20,50+index*19),12,CREAM)
	button(frame,"明白了",251,func(): open(previous),true)

func _settings(frame: Control) -> void:
	text(frame,"设置",Vector2(20,19),24)
	var volume_label := text(frame,"音量 %d%%" % int(game.volume*100),Vector2(20,73),14)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = game.volume*100
	slider.position = Vector2(20,107)
	slider.size = Vector2(326,23)
	frame.add_child(slider)
	slider.value_changed.connect(func(value: float):
		game.volume = value/100
		game.apply_settings()
		volume_label.text = "音量 %d%%" % int(value)
	)
	button(frame,"切换全屏 / 窗口",155,func(): game.fullscreen = not game.fullscreen; game.apply_settings())
	button(frame,"查看房主玩法规则" if game.shared_session or game.network.active() else "玩法规则 · 128 项数值设置 · F3",199,func(): open("rules"))
	button(frame,"保存并返回",251,func(): game.save_profile(); open(previous),true)

func _rules(frame: Control, selected: String) -> void:
	rules_editor=RulesSettings.new()
	rules_editor.game=game
	rules_editor.read_only=game.shared_session or game.network.active()
	rules_editor.category=selected
	rules_editor.closed.connect(func(): open(rules_previous))
	frame.add_child(rules_editor)

func _result(frame: Control) -> void:
	var human: bool=game.player_role=="angler"
	var title: String=("成功捕获" if game.won else "鱼逃走了") if human else ("安全回巢" if game.won else "这次没能逃掉")
	if not human and game.won and game.reason=="timeout": title="存活到最后"
	text(frame,title,Vector2(20,18),25,GOLD if game.won else Color("f58375"))
	var why := "带着食物回家，池塘又安静了。"
	if game.reason == "net": why = "被抄网捞起了。下次早点离开红色区域。"
	elif game.reason == "landed": why = "被提到水面。保持深度，寻找脱钩机会。"
	elif game.reason == "timeout": why = "时间到了。下次吃够食物就及时回巢。"
	if not human and game.won and game.reason=="timeout": why="时间耗尽，你躲过了这次追捕。"
	if human:
		why="收拢网袋，把鱼带出了水面。" if game.reason=="net" else ("成功收线，将鱼提离水面。" if game.reason=="landed" else ("小鱼吃够食物，抢先返回了巢穴。" if game.reason=="home" else "时间到了，小鱼仍然自由。"))
	text(frame,why,Vector2(20,62),12)
	text(frame,"食物 %.1f   ·   用时 %02d:%02d" % [game.score,int(game.elapsed)/60,int(game.elapsed)%60],Vector2(20,87),14,GOLD)
	text(frame,"上钩 %d 次 · 吐钩 %d 次 · 断线逃脱 %d 次" % [game.hook_count,game.round_stats.slips,game.round_stats.breaks],Vector2(20,115),12)
	text(frame,"小鱼 QTE   "+game.Stats.rate(game.round_stats,"fish"),Vector2(20,137),12,MINT)
	text(frame,"人类 QTE   "+game.Stats.rate(game.round_stats,"angler"),Vector2(20,157),12,GOLD)
	text(frame,"危险张力 %.1fs / 拉扯 %.1fs" % [game.round_stats.danger_seconds,game.round_stats.hooked_seconds],Vector2(20,179),12)
	text(frame,"缠线 %d · 解缠 %d · 下网 %d / 捕获 %d" % [game.round_stats.wrap_good,game.round_stats.unwrap_good,game.net_count,game.net_catches],Vector2(20,199),12,Color("91afa7"))
	ready_button=button(frame,"准备下一局" if game.shared_session else "再来一局",227,func(): game.restart_round(),true)
	if not game.shared_session and game.selected_map_source.kind=="generated":
		ready_button.text="同 Seed 再来一局"; ready_button.size.x=158
		var fresh:=button(frame,"新地图",227,func(): game.new_map_round(),false,158); fresh.position.x=188
	button(frame,"离开房间" if game.shared_session else "返回标题",261,func(): game.return_to_title())

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		if screen=="rules":
			if is_instance_valid(rules_editor.overlay): rules_editor.overlay.queue_free(); rules_editor.overlay=null; rules_editor._rebuild()
			else: open(rules_previous)
			get_viewport().set_input_as_handled()
			return
		if screen in ["help","settings"]:
			if screen=="settings": game.save_profile()
			open(previous)
		elif screen == "pause": close()
		elif screen in ["network","map"]: open("title")
		get_viewport().set_input_as_handled()

func _network(frame: Control) -> void:
	text(frame,"双人联机",Vector2(20,16),24)
	text(frame,"一人扮演鱼，一人钓鱼 · 双方准备后开始",Vector2(20,50),12,CREAM,418)
	text(frame,"房主地址",Vector2(20,87),12)
	var address_input := LineEdit.new()
	address_input.name="HostAddress"
	address_input.text=net_address
	address_input.placeholder_text="例如 192.168.1.10"
	address_input.position=Vector2(99,78); address_input.size=Vector2(218,28)
	frame.add_child(address_input)
	address_input.text_changed.connect(func(value: String): net_address=value)
	text(frame,"端口",Vector2(330,62),11)
	var port_input := LineEdit.new()
	port_input.name="HostPort"; port_input.text=net_port; port_input.max_length=5
	port_input.position=Vector2(329,78); port_input.size=Vector2(109,28)
	frame.add_child(port_input)
	port_input.text_changed.connect(func(value: String): net_port=value)
	text(frame,"房主扮演",Vector2(20,126),12)
	var role_input := OptionButton.new()
	role_input.name="HostRole"
	role_input.add_item("小鱼"); role_input.add_item("钓鱼人")
	role_input.selected=0 if net_role=="fish" else 1
	role_input.position=Vector2(99,116); role_input.size=Vector2(150,28)
	frame.add_child(role_input)
	role_input.item_selected.connect(func(value: int): net_role="fish" if value==0 else "angler")
	button(frame,"创建房间",158,func(): game.network.host_game(net_role,int(net_port),game.network_settings()),true,199)
	var join := button(frame,"加入房间",158,func(): game.network.join_game(net_address,int(net_port)),false,199)
	join.position.x=239
	text(frame,game.map_caption(),Vector2(20,198),12,CREAM,418)
	text(frame,"加入填写房主 IP；同机填写 127.0.0.1",Vector2(20,222),12,CREAM,418)
	text(frame,"地图与玩法由房主决定；创建后锁定",Vector2(20,246),11,Color("91afa7"),418)
	button(frame,"返回",276,func(): open("title"),false,418)

func _room(frame: Control) -> void:
	text(frame,"联机房间",Vector2(20,17),24)
	room_status=text(frame,"",Vector2(20,61),13,GOLD,418)
	room_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	room_status.size.y=58
	room_roles=text(frame,"",Vector2(20,120),14,CREAM,418)
	if game.network.is_host and game.network.active():
		var ips: Array[String]=[]
		for ip in IP.get_local_addresses():
			if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
		text(frame,"房主 IP："+(" / ".join(ips.slice(0,2)) if not ips.is_empty() else "127.0.0.1"),Vector2(20,145),12,MINT,418)
		text(frame,"端口 %d · 本机加入填 127.0.0.1" % game.network.port,Vector2(20,168),12,CREAM,418)
	else: text(frame,"地址 %s : %d" % [game.network.address,game.network.port],Vector2(20,161),12,MINT,418)
	room_map=text(frame,game.map_caption(game.network.map_source),Vector2(20,194),11,MINT,335)
	var copy_seed:=button(frame,"复制",190,func():
		if game.network.map_source.kind=="generated": DisplayServer.clipboard_set(str(game.network.map_source.map_seed))
	,false,64)
	copy_seed.position.x=374; copy_seed.size.y=22
	copy_seed.disabled=game.network.map_source.get("kind")!="generated"
	var values: Dictionary=game.network.config.get("rules",game.Rules.defaults())
	button(frame,"查看房主规则 · %d 项自定义" % game.Rules.changed(values).size(),247,func(): open("rules"),false,418)
	ready_button=button(frame,"准备",218,func(): game.network.set_ready(not game.network.local_ready),true,418)
	button(frame,"返回标题",276,func(): game.return_to_title(),false,418)

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(game.network): return
	var net: Node=game.network
	if screen=="room":
		if is_instance_valid(room_status): room_status.text=net.message
		if is_instance_valid(room_roles): room_roles.text="你是%s · 对方%s" % ["小鱼" if net.local_role=="fish" else "钓鱼人","已准备" if net.remote_ready else "未准备"]
		if is_instance_valid(ready_button):
			ready_button.disabled=net.status!="waiting" or net.remote_id==0 or not net.map_validated
			ready_button.text="已准备 · 点击取消" if net.local_ready else "准备"
	elif screen=="result" and game.shared_session and is_instance_valid(ready_button):
		ready_button.disabled=not net.active()
		ready_button.text=("已准备 · 等待对方" if net.local_ready else ("对方已准备 · 再来一局" if net.remote_ready else "准备下一局")) if net.active() else "对方已离开"

func _map_choice(frame:Control)->void:
	text(frame,"选择池塘",Vector2(20,16),24)
	var mode:=OptionButton.new(); mode.name="MapMode"
	mode.add_item("经典池塘"); mode.add_item("生成池塘")
	mode.selected=1 if game.selected_map_source.kind=="generated" else 0
	mode.position=Vector2(20,57); mode.size=Vector2(326,28); frame.add_child(mode)
	text(frame,"地图种子 Seed · 0—2147483647",Vector2(20,96),12,MINT)
	var seed:=LineEdit.new(); seed.name="MapSeed"; seed.max_length=10
	seed.text=str(game.selected_map_source.get("map_seed",42)); seed.position=Vector2(20,118); seed.size=Vector2(211,28)
	frame.add_child(seed); seed.editable=mode.selected==1
	var random_seed:=button(frame,"随机",118,func(): seed.text=str(game.random_map_seed()),false,106); random_seed.position.x=240
	var copy_seed:=button(frame,"复制 Seed",153,func(): DisplayServer.clipboard_set(seed.text),false,158)
	var info:=text(frame,"相同 Seed 使用相同布局；R 重开保留地图。",Vector2(20,192),11,CREAM)
	text(frame,"联机由房主选图，加入者自动使用房主地图。",Vector2(20,211),11,CREAM)
	var refresh:=func():
		seed.editable=mode.selected==1; random_seed.disabled=mode.selected!=1; copy_seed.disabled=mode.selected!=1
	refresh.call(); mode.item_selected.connect(func(_index:int): refresh.call())
	button(frame,"使用这张地图",247,func():
		if not game.select_pond("generated" if mode.selected==1 else "classic",seed.text):
			info.text="请输入 0—2147483647 的整数 Seed"; info.add_theme_color_override("font_color",Color("f58375")); return
		game.save_profile(); game.return_to_title()
	,true,158)
	var back:=button(frame,"返回",247,func(): open("title"),false,158); back.position.x=188
