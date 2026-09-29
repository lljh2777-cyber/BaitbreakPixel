extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const INK := Color("142e39")
const CREAM := Color("fff0cd")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const RED := Color("f58375")
var game: Node2D
var fish_texture: Texture2D
var font: SystemFont
var props: Array[Dictionary] = []
var plant_frames: Array = []

func _ready() -> void:
	fish_texture = Art.fish()
	for solid in Layout.SOLIDS: props.append(Art.prop(solid))
	for index in Layout.PLANTS.size():
		var frames: Array[Dictionary] = []
		for frame in range(8): frames.append(_make_plant_layer(frame*TAU/12.0,index))
		plant_frames.append(frames)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

func label_at(point: Vector2, text: String, size: int = 12, color: Color = CREAM) -> void:
	draw_string(font, point.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color = INK) -> void:
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.01, 0.07, 0.10, 0.5))
	draw_rect(rect, color)
	draw_rect(rect, Color("3e6870"), false, 1)

func _draw() -> void:
	if not is_instance_valid(game): return
	var t: float = game.elapsed
	_world(t)
	_baits(t)
	_line()
	_player(t)
	_net(t)
	_hud(t)

func _world(t: float) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("193c48"))
	draw_rect(Rect2(0, 35, 640, 19), Color("c2c5a4"))
	for index in range(20):
		var x := index * 34
		var height := 8 + (index * 7) % 16
		draw_rect(Rect2(x, 53 - height, 24, height), Color("668e83"))
		draw_rect(Rect2(x + 5, 48 - height, 13, 5), Color("668e83"))
	draw_rect(Rect2(0, 53, 640, 2), MINT)
	for band in range(8):
		var shade := Color("317e82").lerp(Color("174a5a"), band / 7.0)
		draw_rect(Rect2(0, 55 + band * 33, 640, 33), shade)
	for shaft in range(5):
		for step in range(6):
			draw_rect(Rect2(shaft * 149 + step * 7 + 21, 55 + step * 43, 16 + step * 3, 43), Color(0.63, 0.89, 0.74, 0.025))
	for index in range(31):
		var base := Vector2(4+posmod(index*61,632),65+posmod(index*47,234))
		var drifting: Vector2 = (base+game.water_offset(base)*2).round()
		draw_rect(Rect2(drifting,Vector2(1+index%2,1)),Color(0.65,0.86,0.75,0.35))
	for index in range(16):
		var base := Vector2(30+posmod(index*97,580),77+posmod(index*53,220))
		var drifting: Vector2 = base+game.water_offset(base)*2
		var flow: Vector2 = game.water_velocity(base)
		var alpha: float = (0.09+0.055*sin(t*1.3+index))*game.water_strength
		draw_line(drifting.round(),(drifting-flow*2.4).round(),Color(0.68,0.91,0.85,alpha),1)
	# Distant silhouettes are muted; detailed foreground silhouettes share collision data.
	for index in range(15):
		var x := index*47-16
		var height := 12 + index*17%29
		draw_colored_polygon(PackedVector2Array([Vector2(x,315),Vector2(x+5,313-height),Vector2(x+22,306-height),Vector2(x+42,315-height/2),Vector2(x+52,320)]),Color("275963"))
	_plants(t,true)
	draw_rect(Rect2(0, 313, 640, 47), Color("697f70"))
	for x in range(0,640,4):
		draw_rect(Rect2(x,313,4,2+(x*13)%3),Color("9faa7b"))
	for index in range(71):
		var x := (index * 73) % 638
		var y := 319 + index * 19 % 38
		draw_rect(Rect2(x, y, 3, 2), Color("506b66") if index % 2 else Color("8d9b78"))
	_line_back()
	for index in props.size():
		var prop: Dictionary = props[index]
		draw_texture(prop.texture,prop.position,Color(1,1,1,game.target_opacity[index]))
	# Small gravel lies below the swimming floor and never creates invisible blockers.
	for index in range(42):
		var x := (index*83+11)%636
		var y := 314+index*7%13
		var width := 2+index%5
		draw_rect(Rect2(x,y,width,2),Color("506d69"))
		draw_rect(Rect2(x+1,y-1,width-1,1),Color("bcc09a") if index%3 else Color("819a85"))
	_plants(t,false)
	# A mint nest is the single return destination.
	draw_rect(Rect2(37, 280, 46, 28), Color("123b42"))
	draw_rect(Rect2(34, 280, 5, 27), Color("86b49a"))
	draw_rect(Rect2(81, 280, 5, 27), Color("86b49a"))
	draw_rect(Rect2(34, 306, 52, 5), Color("86b49a"))
	draw_rect(Rect2(42, 304, 35, 2), MINT)
	label_at(Vector2(46, 322), "巢穴", 10, MINT)
	if game.score >= (game.TARGET if game.challenge else 18):
		var bounce := int(sin(t * 4) * 2)
		draw_colored_polygon(PackedVector2Array([Vector2(55, 267 + bounce), Vector2(65, 267 + bounce), Vector2(60, 272 + bounce)]), MINT)

func _plants(t: float, background: bool) -> void:
	var frame := posmod(int(t*12.0/TAU),8)
	for index in Layout.PLANTS.size():
		if Layout.PLANTS[index].back!=background: continue
		var sprite: Dictionary = plant_frames[index][frame]
		draw_texture(sprite.texture,sprite.position,Color(1,1,1,game.target_opacity[Layout.SOLIDS.size()+index]))

func _make_plant_layer(t: float, plant_index: int) -> Dictionary:
	# Crop cached frames per clump so only the contacted plants fade.
	var canvas := Image.create(640,112,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	for index in range(plant_index,plant_index+1):
		var plant: Dictionary = Layout.PLANTS[index]
		var background: bool = plant.back
		var base_color := Color("3c8174") if background else Color("70a678")
		var light := Color("4b8979") if background else Color("a4c486")
		var shade := Color("2c6867") if background else Color("45846a")
		for stem in range(plant.stems):
			var fraction := float(stem)/maxi(1,plant.stems-1)
			var base := Vector2(plant.x+(fraction-0.5)*plant.width,109)
			var height: float = plant.height * (0.67+0.33*sin(stem*2.37+1.2))
			if stem == plant.stems/2: height = plant.height
			var lean: float = (fraction-0.5)*plant.width*0.38
			var phase: float = plant.x*0.13+stem*0.7
			var path := PackedVector2Array()
			for step in range(9):
				var growth := step/8.0
				var sway := sin(t*1.5+phase+growth*2.1)*growth*2
				path.append((base+Vector2(lean*growth+sway,-height*growth)).round())
			if plant.kind == "ribbon":
				var blade := PackedVector2Array(path)
				for step in range(8,-1,-1): blade.append(path[step]+Vector2(1 if step==8 else 2,0))
				Art.paint_polygon(canvas,blade,base_color if stem%2 else shade)
				for segment in range(1,path.size()): Art.paint_line(canvas,path[segment-1],path[segment],light if stem%3==0 else base_color)
			else:
				for segment in range(1,path.size()): Art.paint_line(canvas,path[segment-1],path[segment],shade)
				for step in range(2,8):
					var anchor: Vector2 = path[step]
					var leaf_length := 3.0+(8-step)*0.7 if plant.kind == "fern" else 4.0
					for side in [-1,1]:
						var tip := anchor+Vector2(side*leaf_length,-3)
						Art.paint_polygon(canvas,PackedVector2Array([anchor,tip,tip+Vector2(-side*2,3),anchor+Vector2(0,2)]),base_color if side==1 else light)
				if plant.kind == "reed":
					canvas.fill_rect(Rect2i(Vector2i(path[8])-Vector2i(1,6),Vector2i(3,7)),Color("657e66") if background else Color("aeaa73"))
					canvas.fill_rect(Rect2i(Vector2i(path[8])-Vector2i(1,6),Vector2i(1,5)),light)
	var plant: Dictionary = Layout.PLANTS[plant_index]
	var region := Rect2i(int(plant.x-plant.width*0.5-14),int(109-plant.height-8),int(plant.width+29),int(plant.height+12))
	region = region.intersection(Rect2i(0,0,640,112))
	return {"texture":ImageTexture.create_from_image(canvas.get_region(region)),"position":Vector2(region.position)+Vector2(0,205)}

func _baits(t: float) -> void:
	for index in game.baits.size():
		var bait: Dictionary = game.baits[index]
		if bait.active and bait.hook and not bait.removed and not game.net_blocks_hooks():
			if game.bound_bait != index:
				var filament := PackedVector2Array()
				var eye: Vector2 = game.hook_point(index,Vector2(-5,-10))
				for segment in range(17):
					var ratio := segment/16.0
					var point := Vector2(bait.home.x,55).lerp(eye,ratio)
					point.x += sin(ratio*PI)*sin(t*0.75+ratio*2)*2.5*game.water_strength
					filament.append(point.round())
				draw_polyline(filament,Color("b9d5bf"),1)
			var hook := PackedVector2Array([Vector2(-5,-10),Vector2(-5,4),Vector2(-3,7),Vector2(1,7),Vector2(3,5),Vector2(3,1),Vector2.ZERO])
			for point in hook.size(): hook[point] = game.hook_point(index,hook[point]).round()
			draw_polyline(hook, RED if game.bound_bait == index else Color("e1e3ce"), 1)
		var flashing: bool = game.cycle_phase == "warning" and game.cycle_slot == index and int(t * 6) % 2 == 0
		for grain in bait.grains:
			if grain.eaten or (not grain.free and not bait.active): continue
			var offset: Vector2 = grain.offset
			var shade: float = clampf(0.48-(offset.x+offset.y)/22.0,0,1)
			var color := Color("a26c3f").lerp(Color("f1d798"),shade)
			if grain.fleck == 0: color = color.lightened(0.13)
			if flashing and not grain.free: color = RED
			var p: Vector2 = Vector2(grain.pos).round()
			if grain.free:
				draw_rect(Rect2(p,Vector2.ONE),color.lightened(0.15))
			else:
				draw_rect(Rect2(p,Vector2(2,2) if grain.layer<2 else Vector2.ONE),color.darkened(0.18))
				draw_rect(Rect2(p,Vector2(2 if grain.fleck%2 else 1,1)),color)
		if bait.active and not game.menu.visible:
			var label := "有钩饵" if bait.hook and not bait.removed else "散饵"
			label_at(Vector2(bait.pos) + Vector2(-17, -14), label, 10, Color("bdd4be"))
		# A tiny glint remains at the actual tip after the grains are drawn over the hook.
		if bait.active and bait.hook and not bait.removed and not game.net_blocks_hooks():
			draw_rect(Rect2(game._tip(index).round(),Vector2.ONE),RED if game.bound_bait==index else CREAM)

func _line_back() -> void:
	if game.hooked == game.HookState.HOOKED and game.rope_path.size() >= 2:
		draw_polyline(game.rope_path,INK,3)
		draw_polyline(game.rope_path,Color("91b8ab"),1)

func _line() -> void:
	if game.hooked==game.HookState.HOOKED:
		for wrap in game.wraps:
			var points: PackedVector2Array = game.visible_coil(wrap)
			for index in range(1,points.size()):
				# Rear half is below the prop; the front half draws over it to read as a full turn.
				if points[index].y>=wrap.center.y and points[index-1].y>=wrap.center.y:
					draw_line(points[index-1],points[index],INK,3)
					draw_line(points[index-1],points[index],GOLD if wrap.progress<1 else MINT,1)
			if wrap.progress<1:
				var head: Vector2 = points[-1].round()
				draw_rect(Rect2(head-Vector2(2,1),Vector2(5,3)),GOLD)
				draw_rect(Rect2(head-Vector2(1,2),Vector2(3,5)),CREAM)
		if not game.wraps.is_empty():
			var coil: PackedVector2Array = game.visible_coil(game.wraps[-1])
			var start: Vector2 = coil[-1]
			var points := PackedVector2Array([start,start.lerp(game.mouth(),0.5)+Vector2(0,(1-game.tension)*3),game.mouth()])
			draw_polyline(points,INK,3)
			draw_polyline(points,MINT.lerp(RED,game.tension),1)
		if game.contact_target>=0 and not game.winding() and not game.menu.visible:
			var target: Dictionary = game.targets[game.contact_target]
			var outline: PackedVector2Array = target.polygon.duplicate()
			outline.append(outline[0])
			draw_polyline(outline,Color(MINT,0.65 if game.qte=="wrap" else 0.32),1)
	elif game.hooked == game.HookState.MOUTH:
		draw_line(Vector2(game.baits[game.bound_bait].home.x, 53), game.mouth(), RED, 1)

func _player(t: float) -> void:
	var mouth: Vector2 = game.mouth()
	var direction: Vector2 = game.aim
	if game.hooked == game.HookState.FREE and not game.menu.visible:
		var side := direction.orthogonal() * 27
		var far := mouth + direction * 44
		var pulling := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var fade := 0.17 if pulling else 0.045
		draw_colored_polygon(PackedVector2Array([mouth, far+side, far-side]), Color(0.67,0.94,0.81,fade))
		if pulling:
			for index in range(5):
				var ratio := fmod(t * 1.7 + index * 0.2, 1)
				var start := far + side * sin(index * 3.8) * 0.7
				var p := start.lerp(mouth, ratio).round()
				draw_rect(Rect2(p, Vector2(2,1)), MINT)
	var position: Vector2 = game.fish.round()
	var tilt: float = direction.angle()+game.water_velocity(game.fish).x*0.009
	var flip := 1.0
	if direction.x < 0:
		tilt -= PI
		flip = -1
	if game.hooked == game.HookState.MOUTH:
		tilt += sin(t * 45) * 0.13
		position.y += int(sin(t * 32) * 1.5)
	elif game.velocity.length() > 5:
		position.y += int(sin(t * 18))
	if game.sprinting:
		for index in range(7):
			var life := fmod(t*2.8+index/7.0,1)
			var wake: Vector2 = position-direction*(13+life*27)+direction.orthogonal()*sin(index*2.7)*5
			draw_rect(Rect2(wake.round(),Vector2(3,1)),Color(MINT,(1-life)*0.65))
	draw_set_transform(position, tilt, Vector2(flip, 1))
	draw_texture(fish_texture, Vector2(-12,-6))
	draw_set_transform(Vector2.ZERO)
	if game.result_flash > 0:
		var radius: float = (0.7 - game.result_flash) * 25 + 12
		draw_arc(position, radius, 0, TAU, 16, MINT if game.result_good else RED, 1)
	if game.returning:
		draw_rect(Rect2(38, 276, 44, 2), INK)
		draw_rect(Rect2(38, 276, 44 * game.home_age / 2, 2), MINT)

func _net(t: float) -> void:
	if not game.net_state in ["prepare", "warning", "sweep"]: return
	var from: Vector2 = game.net_from
	var to: Vector2 = game.net_to
	var left: bool = from.x < to.x
	var alpha := 0.18 + 0.12 * sin(t * 9)
	var x := 0 if left else 628
	draw_rect(Rect2(x, 55, 12, 258), Color(0.98,0.35,0.32,alpha + 0.1))
	if game.net_state == "warning":
		var low := minf(from.x, to.x) - 18
		var high := maxf(from.x, to.x) + 18
		draw_rect(Rect2(low, from.y-33, high-low, 66), Color(0.95,0.37,0.33,0.08))
		for xx in range(int(low), int(high), 12):
			draw_rect(Rect2(xx, from.y-33, 6, 1), RED)
			draw_rect(Rect2(xx, from.y+33, 6, 1), RED)
		label_at(Vector2(low + 10, from.y - 40), "抄网来向  ››" if left else "‹‹  抄网来向", 12, RED)
		var arrow_x := 14 if left else 626
		var sign_x := 1 if left else -1
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x,from.y-6),Vector2(arrow_x+sign_x*8,from.y),Vector2(arrow_x,from.y+6)]), RED)
	if game.net_state == "sweep":
		var p: Vector2 = game.net_pos.round()
		var outline := PackedVector2Array([Vector2(-12,-28),Vector2(12,-28),Vector2(20,-17),Vector2(20,17),Vector2(12,28),Vector2(-12,28),Vector2(-20,17),Vector2(-20,-17),Vector2(-12,-28)])
		for index in outline.size(): outline[index] += p
		draw_colored_polygon(outline, Color(0.75,0.80,0.73,0.14))
		for offset in range(-14, 15, 7): draw_line(p+Vector2(offset,-24),p+Vector2(offset,24),Color("90a79b"),1)
		for offset in range(-21, 22, 7): draw_line(p+Vector2(-17,offset),p+Vector2(17,offset),Color("90a79b"),1)
		draw_polyline(outline, Color("e2b386"), 2)
		draw_line(p+Vector2(0,-28), Vector2(p.x + (-20 if left else 20),40), Color("e2b386"),3)

func _hud(t: float) -> void:
	if game.menu.visible: return
	draw_rect(Rect2(0,0,640,35), INK)
	label_at(Vector2(12,15), "像素池塘", 12, GOLD)
	label_at(Vector2(12,28), "限时挑战" if game.challenge else "自由练习", 10, MINT)
	var target: float = game.TARGET if game.challenge else 18
	label_at(Vector2(111,22), "食物 %02d / %d" % [int(game.score),int(target)], 15)
	label_at(Vector2(272,15), "吸力 %d%%" % int(game.power*100), 11, CREAM)
	draw_rect(Rect2(272,22,68,3), Color("335762"))
	draw_rect(Rect2(272,22,68*game.power,3), GOLD)
	label_at(Vector2(366,15), "加速" if game.sprinting else ("恢复" if game.sprint_exhausted else "体力"), 11, GOLD if game.sprinting else CREAM)
	draw_rect(Rect2(366,22,70,3), Color("335762"))
	draw_rect(Rect2(366,22,70*game.stamina/100,3), GOLD if game.sprinting else (RED if game.sprint_exhausted else MINT))
	var remaining := maxi(0, int(ceil(game.TIME_LIMIT-game.clock)))
	label_at(Vector2(515,23), "%02d:%02d" % [remaining/60,remaining%60] if game.challenge else "无倒计时", 16, RED if remaining < 60 else CREAM)
	draw_rect(Rect2(0,333,640,27), INK)
	label_at(Vector2(12,350), game.hint(), 12)
	label_at(Vector2(584,350), "H 帮助", 10, Color("9cbbb4"))
	if game.hooked == game.HookState.HOOKED:
		panel(Rect2(246,62,148,43))
		label_at(Vector2(254,76), "张力 %d%%" % int(game.tension*100), 11, CREAM)
		label_at(Vector2(325,76), "缠线 ×%d" % game.wraps.size() if game.latched else "上钩", 10, MINT if game.latched else RED)
		draw_rect(Rect2(254,83,132,6), Color("335762"))
		draw_rect(Rect2(254,83,132*game.tension,6), MINT.lerp(RED,game.tension))
		var spool := "放线 ↓" if game.reel_speed>0.5 else ("收线 ↑" if game.reel_speed < -0.5 else "稳线")
		label_at(Vector2(254,100), "自动"+spool, 9, Color("9cbbb4"))
		if game.high_age > 0:
			draw_rect(Rect2(246,108,148*minf(1,game.high_age/3),3), RED)
	if not game.qte.is_empty() or game.qte_result_age>0: _qte(t)

func _qte(t: float) -> void:
	var showing_result: bool = game.qte.is_empty()
	var kind: String = game.qte_result_kind if showing_result else game.qte
	var zone_start: float = game.qte_result_zone if showing_result else game.qte_zone
	var progress: float = game.qte_result_progress if showing_result else game.qte_progress()
	var success_zone: bool = progress>=zone_start and progress<=zone_start+0.2
	var effect: float = 1-game.qte_result_age/0.7
	var intro: float = clampf(game.qte_age/0.3,0,1) if not showing_result else 1.0
	var origin: Vector2 = game.qte_origin+Vector2(0,roundf(10*pow(1-intro,3)))
	if showing_result and not game.qte_result_good: origin.x += roundf(sin(effect*42)*(1-effect)*3)
	var accent := MINT if kind=="slack" else GOLD
	if showing_result: accent = MINT if game.qte_result_good else RED
	panel(Rect2(origin,Vector2(160,185)))
	draw_rect(Rect2(origin+Vector2(1,1),Vector2(158,2)),accent)
	for corner in [Vector2(5,6),Vector2(152,6),Vector2(5,176),Vector2(152,176)]:
		draw_rect(Rect2(origin+corner,Vector2(3,3)),Color(accent,0.55))
	var title := "吐钩判定" if kind=="entry" else ("缠线判定" if kind=="wrap" else "松线脱钩")
	label_at(origin+Vector2(14,23),title,14,accent)
	var center := origin+Vector2(80,87)
	draw_circle(center,47,Color("102833"))
	for tick in range(24):
		var direction := Vector2.from_angle(-PI/2+tick*TAU/24)
		draw_line((center+direction*44).round(),(center+direction*(47 if tick%3==0 else 45)).round(),Color(accent,0.30),1)
	var path := PackedVector2Array()
	# All decoration follows the exact normalized progress used by the skill check.
	for index in range(121):
		var ratio := index/120.0
		var p: Vector2
		if kind == "entry":
			if ratio < 0.42: p = Vector2(54,47+ratio/0.42*53)
			elif ratio < 0.87:
				var angle := PI-(ratio-0.42)/0.45*PI
				p = Vector2(78,100) + Vector2(cos(angle),sin(angle))*24
			else: p = Vector2(102,100-(ratio-0.87)/0.13*23)
		else: p = Vector2(80,87)+Vector2.from_angle(-PI/2+ratio*TAU)*36
		path.append((origin+p).round())
	draw_polyline(path,Color("091f29"),9)
	draw_polyline(path,Color("547c80"),5)
	draw_polyline(path,Color("284b58"),2)
	var zone := PackedVector2Array()
	zone.append(_track_point(path,zone_start))
	for index in range(ceili(zone_start*120),mini(121,ceili((zone_start+0.2)*120))): zone.append(path[index])
	zone.append(_track_point(path,zone_start+0.2))
	draw_polyline(zone,Color(accent,0.14+0.08*sin(t*8)),11)
	draw_polyline(zone,CREAM,5)
	draw_polyline(zone,Color.WHITE,1)
	for endpoint in [zone[0],zone[-1]]: draw_rect(Rect2(endpoint-Vector2.ONE,Vector2(3,3)),accent)
	var marker := _track_point(path,progress)
	if game.qte_age>=0.4 or showing_result:
		for trail in range(1,9):
			var p := _track_point(path,maxf(0,progress-trail*0.013))
			draw_rect(Rect2(p-Vector2.ONE,Vector2(3,3)),Color(accent,(1-trail/9.0)*0.55))
		var head_color := accent if success_zone or showing_result else RED
		draw_circle(marker,6,Color(head_color,0.2))
		draw_colored_polygon(PackedVector2Array([marker+Vector2(0,-4),marker+Vector2(4,0),marker+Vector2(0,4),marker+Vector2(-4,0)]),head_color)
		draw_rect(Rect2(marker-Vector2.ONE,Vector2(3,3)),CREAM)
	else:
		draw_arc(center,49,-PI/2,-PI/2+TAU*game.qte_age/0.4,32,accent,1)
	var key_center := center if kind!="entry" else origin+Vector2(79,69)
	var key_size := Vector2(40,22) if kind=="wrap" else Vector2(24,22)
	var key_rect := Rect2((key_center-key_size*0.5).round(),key_size)
	draw_rect(Rect2(key_rect.position+Vector2(0,2),key_size),Color("091f29"))
	draw_rect(key_rect,accent if success_zone else Color("254651"))
	draw_rect(key_rect,accent,false,1)
	label_at(key_rect.position+Vector2(8,16),"空格" if kind=="wrap" else "E",12,INK if success_zone else CREAM)
	if showing_result:
		label_at(origin+Vector2(14,155),game.qte_result,14,accent)
		label_at(origin+Vector2(14,173),"线圈保留 · 准备松线" if game.qte_result_good and kind=="wrap" else ("继续游动" if game.qte_result_good else "调整后可以再试"),10,CREAM)
		if game.qte_result_good:
			draw_arc(center,39+effect*15,0,TAU,32,Color(accent,1-effect),2)
			for spark in range(10):
				var p := center+Vector2.from_angle(spark*TAU/10)*(38+effect*22)
				draw_rect(Rect2(p.round(),Vector2(2,2)),Color(accent,1-effect))
	else:
		var instruction := "指针进入白区时按键"
		if game.qte_age<0.4: instruction="准备…"
		elif success_zone: instruction="现在按空格" if kind=="wrap" else "现在按 E"
		label_at(origin+Vector2(14,155),instruction,12,accent if success_zone else CREAM)
		var detail := "成功自动缠绕一圈" if kind=="wrap" else ("移动保持低张力" if kind=="slack" else "抓住机会吐出鱼钩")
		label_at(origin+Vector2(14,173),detail,10,Color("9cbbb4"))

func _track_point(path: PackedVector2Array, progress: float) -> Vector2:
	var index := clampf(progress,0,1)*(path.size()-1)
	var before := int(index)
	return path[before].lerp(path[mini(before+1,path.size()-1)],index-before).round()
