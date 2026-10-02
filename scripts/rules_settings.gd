extends Control

# Schema-driven editor: draft -> validation -> saved next-round preferences.
# Never changes an active world. Network rules are shown through the same read-only UI.
const Rules = preload("res://scripts/game_rules.gd")
const Store = preload("res://scripts/rules_store.gd")
signal closed
var game: Node2D
var draft := {}
var read_only := false
var category := "体力"
var category_picker: OptionButton
var search: LineEdit
var changed_only: CheckBox
var rows: VBoxContainer
var status: Label
var description: Label
var controls := {}
var overlay: Panel
var preset_picker: OptionButton
var preset_name: LineEdit
var json_text: TextEdit
var preset_status: Label
const INK := Color("142e39")
const CREAM := Color("fff0cd")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")

func _ready() -> void:
	size=Vector2(608,336)
	draft=game.saved_rules.duplicate(true)
	if read_only and game.shared_session: draft=game.rules.duplicate(true)
	elif read_only and game.network.active(): draft=game.network.config.get("rules",game.saved_rules).duplicate(true)
	draft=Rules.normalize(draft)
	_label(self,"玩法规则"+(" · 房主锁定" if read_only else ""),Vector2(12,6),18)
	_button(self,"返回",Rect2(540,7,56,25),func(): closed.emit())
	description=_label(self,"只读查看本房间规则；个人音量与显示设置不受影响。" if read_only else "保存后下一局生效 · 默认值沿用当前玩法 · 支持单项、分类和全部还原",Vector2(12,33),10)
	category_picker=OptionButton.new(); category_picker.add_theme_font_size_override("font_size",12)
	category_picker.position=Vector2(12,54); category_picker.size=Vector2(145,28)
	var groups: Array[String]=[]
	for item in Rules.Catalog.ITEMS:
		if item.get("developer",false): continue
		if not item.group in groups: groups.append(item.group)
	for group in groups: category_picker.add_item(group)
	category_picker.select(maxi(0,groups.find(category)))
	category_picker.item_selected.connect(func(index: int): category=groups[index]; _rebuild())
	add_child(category_picker)
	search=LineEdit.new(); search.add_theme_font_size_override("font_size",11); search.position=Vector2(165,54); search.size=Vector2(283,28); search.placeholder_text="搜索全部选项，例如：体力 / QTE / 抄网"
	search.text_changed.connect(func(_value: String): _rebuild()); add_child(search)
	changed_only=CheckBox.new(); changed_only.add_theme_font_size_override("font_size",11); changed_only.text="只看修改"; changed_only.position=Vector2(464,54); changed_only.size=Vector2(132,28)
	changed_only.toggled.connect(func(_value: bool): _rebuild()); add_child(changed_only)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(12,89); scroll.size=Vector2(584,177)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows=VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",4); scroll.add_child(rows)
	status=_label(self,"",Vector2(12,269),10)
	status.size=Vector2(584,23); status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if not read_only:
		_button(self,"还原本类",Rect2(12,301,82,27),func(): _reset_group())
		_button(self,"全部默认",Rect2(100,301,82,27),func(): draft=Rules.defaults(); _rebuild())
		_button(self,"方案 / 导入导出",Rect2(188,301,125,27),_presets)
		_button(self,"保存，下局使用",Rect2(327,301,125,27),func(): _save(false))
		_button(self,"保存并重开",Rect2(464,301,132,27),func(): _save(true),true)
	else:
		_button(self,"复制规则 JSON",Rect2(432,301,164,27),func(): DisplayServer.clipboard_set(JSON.stringify(Rules.document(draft),"  ")); status.text="已复制房主规则")
	_rebuild()

func _label(parent: Node, text: String, point: Vector2, font_size: int=11) -> Label:
	var node := Label.new(); node.text=text; node.position=point; node.add_theme_color_override("font_color",CREAM); node.add_theme_font_size_override("font_size",font_size); parent.add_child(node)
	return node

func _button(parent: Node, title: String, rect: Rect2, action: Callable, primary: bool=false) -> Button:
	var button := Button.new(); button.text=title; button.position=rect.position; button.size=rect.size
	button.add_theme_font_size_override("font_size",11)
	for state in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new(); style.bg_color=(Color("365d63") if state=="hover" else Color("23444e")) if not primary else GOLD; style.border_color=MINT if state=="hover" else Color("416770"); style.set_border_width_all(1)
		button.add_theme_stylebox_override(state,style)
	for color in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(color,INK if primary else CREAM)
	button.pressed.connect(action); parent.add_child(button)
	return button

func _rebuild() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	controls.clear()
	var query := search.text.strip_edges().to_lower()
	var modified := Rules.changed(draft)
	var count := 0
	for item in Rules.Catalog.ITEMS:
		if item.get("developer",false): continue
		if query.is_empty() and item.group!=category: continue
		if not query.is_empty() and not query in (item.label+" "+item.group+" "+item.id+" "+item.help).to_lower(): continue
		if changed_only.button_pressed and not modified.has(item.id): continue
		_add_row(item); count+=1
	status.text="%d 项可见 · 共 %d 项 · 已修改 %d 项%s" % [count,Rules.Catalog.ITEMS.size(),modified.size()," · 下局生效" if not read_only else ""]

func _add_row(item: Dictionary) -> void:
	var row := Control.new(); row.custom_minimum_size=Vector2(562,65); rows.add_child(row)
	var label := _label(row,item.label,Vector2(4,0),11)
	label.size.x=184; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text=item.help
	var help := _label(row,item.help,Vector2(4,29),10)
	help.size=Vector2(550,31); help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; help.add_theme_color_override("font_color",Color("a8c6c2"))
	if item.value is bool:
		var check := CheckButton.new(); check.position=Vector2(190,-3); check.size=Vector2(100,28); check.button_pressed=draft[item.id]; check.disabled=read_only
		check.toggled.connect(func(value: bool): draft[item.id]=value; _rebuild())
		row.add_child(check); controls[item.id]=check
	else:
		var slider := HSlider.new(); slider.position=Vector2(190,4); slider.size=Vector2(128,20); slider.min_value=item.min; slider.max_value=item.max; slider.step=item.step; slider.value=draft[item.id]; slider.editable=not read_only
		row.add_child(slider)
		var spin := SpinBox.new(); spin.position=Vector2(330,-3); spin.size=Vector2(88,26); spin.min_value=item.min; spin.max_value=item.max; spin.step=item.step; spin.value=draft[item.id]; spin.editable=not read_only
		spin.add_theme_font_size_override("font_size",11); row.add_child(spin); controls[item.id]=spin
		var update := func(value: float):
			draft[item.id]=value; slider.set_value_no_signal(value); spin.set_value_no_signal(value)
			status.text="已修改 %d 项 · 尚未保存 · 下一局生效" % Rules.changed(draft).size()
		slider.value_changed.connect(update); spin.value_changed.connect(update)
		if item.id.begins_with("qte_") and item.id.ends_with("_zone"):
			var random_key: String=item.id.trim_suffix("zone")+"random"
			if draft[random_key]: slider.editable=false; spin.editable=false; help.text="随机位置已开启。关闭本类“随机成功区位置”后可调节固定起点。"
		_label(row,item.unit,Vector2(424,1),10)
	var reset := _button(row,"还原",Rect2(512,-2,44,24),func(): draft[item.id]=item.value; _rebuild())
	reset.disabled=read_only
	row.tooltip_text="默认：%s %s\n%s" % [str(item.value),item.unit,item.help]
	_label(row,"默认 "+str(item.value),Vector2(4,15),9).add_theme_color_override("font_color",Color("789c9f"))

func _reset_group() -> void:
	for item in Rules.Catalog.ITEMS:
		if item.get("developer",false): continue
		if item.group==category: draft[item.id]=item.value
	_rebuild()

func _save(restart: bool) -> void:
	if read_only: return
	# Commit SpinBox text edits before taking the draft snapshot.
	for control in controls.values():
		if control is SpinBox and control.get_line_edit().has_focus(): control.apply()
	var normalized := Rules.normalize(draft)
	var adjusted := 0
	for key in draft:
		if draft[key]!=normalized[key]: adjusted+=1
	draft=normalized
	game.saved_rules=draft.duplicate(true)
	game.save_profile()
	_rebuild()
	if game.save_error!=OK: status.text="保存失败（%d），请检查存储空间；当前对局未改变" % game.save_error; return
	status.text="已保存，下一局使用"+(" · 已自动校正 %d 项关联范围" % adjusted if adjusted>0 else "")
	if restart: game.reset(game.challenge,game.player_role)

func _presets() -> void:
	overlay=Panel.new(); overlay.position=Vector2(6,4); overlay.size=Vector2(596,328)
	var style := StyleBoxFlat.new(); style.bg_color=INK; style.border_color=MINT; style.set_border_width_all(1); overlay.add_theme_stylebox_override("panel",style)
	add_child(overlay)
	_label(overlay,"规则方案 · JSON 可复制、分享和导入",Vector2(12,10),14)
	preset_picker=OptionButton.new(); preset_picker.position=Vector2(12,44); preset_picker.size=Vector2(190,28); overlay.add_child(preset_picker)
	_refresh_presets()
	_button(overlay,"载入",Rect2(209,44,50,28),func():
		if preset_picker.selected>=0: _import_result(Store.load_preset(game.rules_preset_path(),preset_picker.get_item_text(preset_picker.selected))))
	preset_name=LineEdit.new(); preset_name.position=Vector2(273,44); preset_name.size=Vector2(202,28); preset_name.placeholder_text="新方案名（同名覆盖）"; overlay.add_child(preset_name)
	_button(overlay,"保存方案",Rect2(483,44,99,28),func():
		var error := Store.save_preset(game.rules_preset_path(),preset_name.text,draft)
		preset_status.text="方案已保存" if error==OK else "保存失败：检查方案名和存储空间（%d）" % error
		if error==OK: _refresh_presets())
	json_text=TextEdit.new(); json_text.position=Vector2(12,83); json_text.size=Vector2(570,168); json_text.placeholder_text="在此粘贴导出的规则 JSON，再点击导入草稿。"; json_text.add_theme_font_size_override("font_size",10); overlay.add_child(json_text)
	preset_status=_label(overlay,"载入与导入只更新草稿，返回后点击保存才会生效。",Vector2(12,257),10)
	preset_status.size.x=570; preset_status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_button(overlay,"复制当前 JSON",Rect2(12,291,126,27),func(): DisplayServer.clipboard_set(JSON.stringify(Rules.document(draft),"  ")); preset_status.text="已复制，可粘贴到文本文件或分享")
	_button(overlay,"粘贴",Rect2(148,291,63,27),func(): json_text.text=DisplayServer.clipboard_get())
	_button(overlay,"导入草稿",Rect2(221,291,90,27),func():
		if json_text.text.length()>65536: preset_status.text="内容过大，最多 64 KB"; return
		_import_result(Rules.parse_text(json_text.text)))
	_button(overlay,"返回设置",Rect2(481,291,101,27),func(): overlay.queue_free(); _rebuild())

func _refresh_presets() -> void:
	preset_picker.clear()
	for title in Store.preset_names(game.rules_preset_path()): preset_picker.add_item(title)

func _import_result(result: Dictionary) -> void:
	if result.has("error"): preset_status.text=result.error; return
	draft=result.values
	preset_status.text="已载入草稿，返回设置后保存。越界值已校正到可用范围。"
