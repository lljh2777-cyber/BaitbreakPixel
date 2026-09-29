extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const INK := Color("142e39")
const CREAM := Color("fff0cd")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const RED := Color("f58375")
var game: Node2D
var fish_texture: Texture2D
var reed_texture: Texture2D
var font: SystemFont

func _ready() -> void:
	fish_texture = Art.fish()
	reed_texture = Art.reed()
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
		var x := posmod(index * 61 + int(t * 2), 632) + 4
		var y := 65 + posmod(index * 47 - int(t * (2 + index % 3)), 234)
		draw_rect(Rect2(x, y, 1 + index % 2, 1), Color(0.65, 0.86, 0.75, 0.35))
	# Background plants remain decorative; every solid foreground shape matches physics.
	for index in range(22):
		var x := (index * 89 + 29) % 625
		var tall := 16 + (index * 13) % 40
		draw_texture_rect(reed_texture, Rect2(x, 315 - tall, 16, tall), false, Color("376e71"))
	draw_rect(Rect2(0, 313, 640, 47), Color("697f70"))
	draw_rect(Rect2(0, 313, 640, 3), Color("9faa7b"))
	for index in range(71):
		var x := (index * 73) % 638
		var y := 319 + index * 19 % 38
		draw_rect(Rect2(x, y, 3, 2), Color("506b66") if index % 2 else Color("8d9b78"))
	for index in range(1, game.SOLIDS.size()):
		var rock: Rect2 = game.SOLIDS[index]
		draw_rect(rock, Color("465f64"))
		draw_rect(Rect2(rock.position, Vector2(rock.size.x, 3)), Color("90a18c"))
		draw_rect(Rect2(rock.position + Vector2(6, 6), Vector2(rock.size.x - 14, 4)), Color("647c77"))
	var root: Rect2 = game.SOLIDS[0]
	draw_rect(root, Color("796a50"))
	draw_rect(Rect2(root.position, Vector2(4, root.size.y)), Color("a08b61"))
	draw_rect(Rect2(root.position + Vector2(17, 0), Vector2(5, root.size.y)), Color("4a594e"))
	draw_rect(Rect2(326, 172, 22, 4), Color("c1a979"))
	for index in range(9):
		draw_rect(Rect2(333 + index % 3 * 3, 182 + index * 15, 2, 8), Color("5f624e"))
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
	for index in range(12):
		var x := 96 + index * 45
		if abs(x - 336) < 23: continue
		draw_texture(reed_texture, Vector2(x, 298))

func _baits(t: float) -> void:
	for index in game.baits.size():
		var bait: Dictionary = game.baits[index]
		if bait.active and bait.hook and not bait.removed and not game.net_blocks_hooks():
			if game.bound_bait != index:
				draw_line(Vector2(bait.home.x, 55), Vector2(bait.pos) + Vector2(0, -4), Color("b9d5bf"), 1)
			var tip: Vector2 = game._tip(index)
			var hook := PackedVector2Array([Vector2(-5,-10),Vector2(-5,4),Vector2(-3,7),Vector2(1,7),Vector2(3,5),Vector2(3,1),Vector2.ZERO])
			for point in hook.size(): hook[point] = (hook[point] + tip).round()
			draw_polyline(hook, RED if game.bound_bait == index else Color("e1e3ce"), 1)
		var flashing: bool = game.cycle_phase == "warning" and game.cycle_slot == index and int(t * 6) % 2 == 0
		for grain in bait.grains:
			if grain.eaten or (not grain.free and not bait.active): continue
			var color := GOLD if grain.layer == 0 else Color("e4a45b")
			if flashing and not grain.free: color = RED
			var p: Vector2 = Vector2(grain.pos).round()
			draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), color)
			if not grain.free: draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE), CREAM)
		if bait.active and not game.menu.visible:
			var label := "有钩饵" if bait.hook and not bait.removed else "散饵"
			label_at(Vector2(bait.pos) + Vector2(-17, -19), label, 10, Color("bdd4be"))

func _line() -> void:
	if game.hooked == game.HookState.HOOKED and game.rope_path.size() >= 2:
		var points: PackedVector2Array = game.rope_path
		var color := MINT.lerp(RED, game.tension)
		draw_polyline(points, INK, 3)
		draw_polyline(points, color, 1)
		for index in range(1, points.size() - 1):
			draw_rect(Rect2(points[index].round() - Vector2(2,2), Vector2(4,4)), MINT)
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
	var tilt := direction.angle()
	var flip := 1.0
	if direction.x < 0:
		tilt -= PI
		flip = -1
	if game.hooked == game.HookState.MOUTH:
		tilt += sin(t * 45) * 0.13
		position.y += int(sin(t * 32) * 1.5)
	elif game.velocity.length() > 5:
		position.y += int(sin(t * 18))
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
	label_at(Vector2(366,15), "体力", 11, CREAM)
	draw_rect(Rect2(366,22,70,3), Color("335762"))
	draw_rect(Rect2(366,22,70*game.stamina/100,3), MINT)
	var remaining := maxi(0, int(ceil(game.TIME_LIMIT-game.clock)))
	label_at(Vector2(515,23), "%02d:%02d" % [remaining/60,remaining%60] if game.challenge else "无倒计时", 16, RED if remaining < 60 else CREAM)
	draw_rect(Rect2(0,333,640,27), INK)
	label_at(Vector2(12,350), game.hint(), 12)
	label_at(Vector2(584,350), "H 帮助", 10, Color("9cbbb4"))
	if game.hooked == game.HookState.HOOKED:
		panel(Rect2(246,62,148,43))
		label_at(Vector2(254,76), "张力 %d%%" % int(game.tension*100), 11, CREAM)
		label_at(Vector2(325,76), "绕根" if game.latched else "上钩", 11, MINT if game.latched else RED)
		draw_rect(Rect2(254,83,132,6), Color("335762"))
		draw_rect(Rect2(254,83,132*game.tension,6), MINT.lerp(RED,game.tension))
		label_at(Vector2(254,100), "自动收放线 · 缓慢", 9, Color("9cbbb4"))
		if game.high_age > 0:
			draw_rect(Rect2(246,108,148*minf(1,game.high_age/3),3), RED)
	if not game.qte.is_empty(): _qte(t)

func _qte(_t: float) -> void:
	var origin := Vector2(471,95) if game.fish.x < 320 else Vector2(19,95)
	panel(Rect2(origin,Vector2(150,159)))
	label_at(origin+Vector2(13,22), "吐钩判定" if game.qte == "entry" else "松线脱钩", 14, GOLD)
	var path := PackedVector2Array()
	# Entry follows a J-shaped metal hook; slack uses a full circular timing track.
	for index in range(101):
		var ratio := index/100.0
		var p: Vector2
		if game.qte == "entry":
			if ratio < 0.42: p = Vector2(50,39+ratio/0.42*53)
			elif ratio < 0.87:
				var angle := PI-(ratio-0.42)/0.45*PI
				p = Vector2(74,92) + Vector2(cos(angle),sin(angle))*24
			else: p = Vector2(98,92-(ratio-0.87)/0.13*23)
		else: p = Vector2(75,79)+Vector2.from_angle(-PI/2+ratio*TAU)*34
		path.append((origin+p).round())
	draw_polyline(path, Color("42636b"), 5)
	var zone := PackedVector2Array()
	for index in range(int(game.qte_zone*100), mini(101,int((game.qte_zone+0.2)*100)+1)): zone.append(path[index])
	draw_polyline(zone, CREAM, 5)
	var progress: float = game.qte_progress()
	var marker: Vector2 = path[clampi(int(progress*100),0,100)]
	if game.qte_age >= 0.4:
		draw_rect(Rect2(marker-Vector2(3,3),Vector2(7,7)), RED)
		draw_rect(Rect2(marker-Vector2.ONE,Vector2(3,3)), CREAM)
	else:
		label_at(origin+Vector2(106,64), "准备", 10, GOLD)
	label_at(origin+Vector2(18,138), "白区内按 E", 12)
	if game.qte == "slack": label_at(origin+Vector2(18,152), "同时移动，保持低张力", 10, MINT)
