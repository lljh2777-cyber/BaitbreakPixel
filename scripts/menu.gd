extends Control

var game: Node2D
var screen := "title"
var previous := "title"
var content: Control
var first_button: Button
const CREAM := Color("fff0cd")
const GOLD := Color("ffd379")
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
	if which=="practice" and game.challenge: return
	if which in ["help","settings","practice"] and (not visible or not screen in ["help","settings","practice"]):
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
	frame.add_theme_stylebox_override("panel",style(INK,Color("527b7b")))
	content.add_child(frame)
	first_button = null
	match which:
		"title": _title(frame)
		"pause": _pause(frame)
		"help": _help(frame)
		"settings": _settings(frame)
		"practice": _practice(frame)
		"result": _result(frame)
	if first_button: first_button.grab_focus()

func close() -> void:
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
	button(frame,"自由练习   ·   小鱼 / 调节鱼线",172,func(): game.reset(false),false,254)
	button(frame,"操作说明",206,func(): open("help"),false,254)
	button(frame,"设置",240,func(): open("settings"),false,124)
	var quit := button(frame,"退出",240,func(): get_tree().quit(),false,124)
	quit.position.x = 150
	text(content,"0.9 · 单人双视角",Vector2(391,280),10,Color("91afa7"))
	text(content,"小鱼 · 吃饵脱身",Vector2(391,119),18,GOLD)
	text(content,"人类 · 收线抄网",Vector2(391,159),18,GOLD)
	text(content,"另一方由 AI 控制",Vector2(391,199),18,GOLD)
	text(content,"6 分钟 · 一场拉锯",Vector2(391,239),12,CREAM)

func _pause(frame: Control) -> void:
	text(frame,"水下小憩",Vector2(20,19),24)
	button(frame,"继续本局",57,close,true)
	button(frame,"重新开始本局",89,func(): game.restart_round())
	var offset := 0
	if not game.challenge:
		button(frame,"练习调节 · 收放线",121,func(): open("practice"),false,158)
		var net_button := button(frame,"抄网练习 · N",121,func(): close(); game.request_net(),false,158)
		net_button.position.x=188
		offset=32
	button(frame,"操作说明",121+offset,func(): open("help"))
	button(frame,"设置",153+offset,func(): open("settings"))
	button(frame,"返回标题",185+offset,func(): open("title"))
	text(frame,"Esc 继续 · 切出窗口会自动暂停",Vector2(20,258),11,Color("91afa7"))

func _help(frame: Control) -> void:
	var human: bool=game.player_role=="angler"
	text(frame,"把鱼带出水面" if human else "怎样在池塘里活下来",Vector2(20,16),21)
	var lines := [
		"WASD / 方向键 游动 · 鼠标决定朝向",
		"左键吸食 · 滚轮调吸力 · Q 慢游",
		"按住右键加速耗体力 · 吃饵补体力",
		"所有 QTE：浮漂到绿色判定区按空格",
		"上钩会被拉向水面 · 吸食时游速降低",
		"接触草木石按空格，边游抗拉、绿区再按",
		"缠线后松线按空格脱钩 · 拉紧 3 秒断线",
		"抄网：红区锁定后躲开 · 木石能挡住网口",
		"吃够食物后回左下巢穴，按 E 停留 2 秒",
		"R 重开 · Esc 暂停 · F11 全屏 · 练习 N 试网"
	]
	if human:
		lines=[
			"A / D 沿岸移动 · 鼠标选择投饵 / 抄网位置",
			"未上钩：左键投饵 · E 收回并重新选落点",
			"上钩后：按住右键收线 · 按住左键放线",
			"松开鼠标保持线长 · 留意张力和鱼的体力",
			"持续过紧会断线 · 过松会给鱼脱钩机会",
			"鱼会借草木石缠线；移动钓位改变拉力方向",
			"空格向鼠标位置抄网 · 冷却 12 秒",
			"抄网有准备时间，木石挡网，预判鱼的去向",
			"钩饵有限；6 分钟内提鱼出水或抄中即胜利",
			"鱼吃满 60 回巢则失败 · R 重开 / Esc 暂停"
		]
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
	text(frame,"画面按整数倍缩放，保留清晰像素。",Vector2(20,201),12,Color("91afa7"))
	button(frame,"保存并返回",251,func(): game.save_profile(); open(previous),true)

func _practice(frame: Control) -> void:
	text(frame,"练习 · 收放线调节",Vector2(20,17),22)
	text(frame,"只影响自由练习，调整后继续当前这局。",Vector2(20,52),12,Color("91afa7"))
	var sensitivity_label := text(frame,"灵敏度 %d%%" % roundi(game.practice_line_sensitivity*100),Vector2(20,78),15,GOLD)
	var sensitivity := HSlider.new()
	sensitivity.name="LineSensitivity"
	sensitivity.min_value=25
	sensitivity.max_value=250
	sensitivity.step=5
	sensitivity.value=game.practice_line_sensitivity*100
	sensitivity.position=Vector2(20,106)
	sensitivity.size=Vector2(326,17)
	frame.add_child(sensitivity)
	text(frame,"越高，张力变化后响应越快。",Vector2(20,126),11,CREAM)
	var force_label := text(frame,"力度 %d%%" % roundi(game.practice_line_force*100),Vector2(20,153),15,GOLD)
	var force := HSlider.new()
	force.name="LineForce"
	force.min_value=0
	force.max_value=250
	force.step=10
	force.value=game.practice_line_force*100
	force.position=Vector2(20,181)
	force.size=Vector2(326,17)
	frame.add_child(force)
	text(frame,"越高收鱼越有力；0% 关闭收放线与拉力。",Vector2(20,201),11,CREAM)
	sensitivity.value_changed.connect(func(value: float):
		game.set_practice_line_tuning(value/100,game.practice_line_force)
		sensitivity_label.text="灵敏度 %d%%" % roundi(value)
	)
	force.value_changed.connect(func(value: float):
		game.set_practice_line_tuning(game.practice_line_sensitivity,value/100)
		force_label.text="力度 %d%%" % roundi(value)
	)
	button(frame,"恢复默认",251,func(): sensitivity.value=100; force.value=100,false,100)
	var back := button(frame,"保存并返回",251,func(): game.save_profile(); open(previous),true,216)
	back.position.x=130

func _result(frame: Control) -> void:
	var human: bool=game.player_role=="angler"
	var title: String=("成功捕获" if game.won else "鱼逃走了") if human else ("安全回巢" if game.won else "这次没能逃掉")
	text(frame,title,Vector2(20,18),25,GOLD if game.won else Color("f58375"))
	var why := "带着食物回家，池塘又安静了。"
	if game.reason == "net": why = "被抄网捞起了。下次早点离开红色区域。"
	elif game.reason == "landed": why = "被提到水面。保持深度，寻找脱钩机会。"
	elif game.reason == "timeout": why = "时间到了。下次吃够食物就及时回巢。"
	if human:
		why="收拢网袋，把鱼带出了水面。" if game.reason=="net" else ("成功收线，将鱼提离水面。" if game.reason=="landed" else ("小鱼吃够食物，抢先返回了巢穴。" if game.reason=="home" else "时间到了，小鱼仍然自由。"))
	text(frame,why,Vector2(20,62),12)
	text(frame,("鱼吃到的食物   %.1f" if human else "带回食物   %.1f") % game.score,Vector2(20,102),16,GOLD)
	text(frame,"用时 %02d:%02d   ·   上钩 %d 次 / 逃脱 %d 次" % [int(game.elapsed)/60,int(game.elapsed)%60,game.hook_count,game.escape_count],Vector2(20,134),12)
	text(frame,"钓鱼成功 %d 次" % game.angler_wins if human else "挑战成功 %d 次   ·   最佳收获 %.1f" % [game.wins,game.best_score],Vector2(20,160),12,Color("91afa7"))
	button(frame,"再来一局",207,func(): game.restart_round(),true)
	button(frame,"返回标题",245,func(): open("title"))

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		if screen in ["help","settings","practice"]:
			if screen in ["settings","practice"]: game.save_profile()
			open(previous)
		elif screen == "pause": close()
		get_viewport().set_input_as_handled()
