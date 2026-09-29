extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const Gauge = preload("res://scripts/hook_gauge.gd")
const INK := Color("142e39")
const CREAM := Color("fff0cd")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const RED := Color("f58375")
var game: Node2D
var fish_texture: Texture2D
var gauge_texture: Texture2D
var bobber_texture: Texture2D
var font: SystemFont
var props: Array[Dictionary] = []
var plant_frames: Array = []

func _ready() -> void:
	fish_texture = Art.fish()
	gauge_texture = Gauge.metal_texture()
	bobber_texture = Gauge.bobber_texture()
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
	_angler(t)
	_line()
	_net_back(t)
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
		# Net activity suppresses new bites, not the physical hook or its hanging line.
		if bait.active and bait.hook and not bait.removed:
			if game.bound_bait != index:
				var filament := PackedVector2Array()
				var eye: Vector2 = game.hook_point(index,Vector2(-5,-10))
				for segment in range(17):
					var ratio := segment/16.0
					var point: Vector2 = game.line_anchor(index).lerp(eye,ratio)
					point.x += sin(ratio*PI)*(game.angler.line_sway if game.player_role=="angler" else sin(t*0.75+ratio*2)*2.5*game.water_strength)
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
		if bait.active and bait.hook and not bait.removed:
			draw_rect(Rect2(game._tip(index).round(),Vector2.ONE),RED if game.bound_bait==index else CREAM)

func _angler(t: float) -> void:
	if game.player_role!="angler": return
	var p := Vector2(roundf(game.angler.x),43)
	var flex: float=game.tension*3 if game.hooked==game.HookState.HOOKED else sin(t*1.4)
	draw_rect(Rect2(p+Vector2(-5,-8),Vector2(8,8)),Color("ecc695"))
	draw_rect(Rect2(p+Vector2(-7,-11),Vector2(12,4)),Color("be9056"))
	draw_rect(Rect2(p+Vector2(-4,-14),Vector2(7,4)),Color("dfbd78"))
	draw_rect(Rect2(p+Vector2(2,-6),Vector2(1,2)),INK)
	draw_rect(Rect2(p+Vector2(-5,0),Vector2(9,7)),Color("34495a"))
	draw_rect(Rect2(p+Vector2(-5,7),Vector2(3,4)),Color("102f3f"))
	draw_rect(Rect2(p+Vector2(1,7),Vector2(3,4)),Color("102f3f"))
	draw_line(p+Vector2(3,1),p+Vector2(10,3),Color("ecc695"),3)
	var rod := PackedVector2Array([p+Vector2(8,4),p+Vector2(18,-8-flex),p+Vector2(25,-4-flex),game.angler.anchor()])
	draw_polyline(rod,INK,3)
	draw_polyline(rod,GOLD,1)
	if game.angler.casting:
		var ball: Vector2=game.angler.projectile().round()
		draw_line(game.angler.anchor(),ball,Color("b9d5bf"),1)
		draw_rect(Rect2(ball-Vector2(2,2),Vector2(5,4)),Color("a26c3f"))
		draw_rect(Rect2(ball-Vector2(2,2),Vector2(3,2)),GOLD)
		draw_line(ball,ball+Vector2(0,4),CREAM,1)
	if game.menu.visible or not game.angler.net_held: return
	var cursor: Vector2=game.angler.cursor.round()
	var color := MINT if game.angler.net_cooldown<=0 else Color("7ca9a0")
	for side in [-1,1]:
		draw_line(cursor+Vector2(side*5,0),cursor+Vector2(side*9,0),color,1)
		draw_line(cursor+Vector2(0,side*5),cursor+Vector2(0,side*9),color,1)
	if game.angler.net_held and not game.net_blocks_hooks():
		draw_arc(cursor,15,0,TAU,24,Color(MINT,0.5),1)
		label_at(cursor+Vector2(-28,-22),"左键拖动",10,MINT)
	if game.manual_net and game.net_state in ["prepare","warning","sweep"]:
		var target: Vector2=game.manual_net_target(game.angler.cursor)
		var direction: Vector2=(target-game.net_pos).normalized()
		draw_line(game.net_pos,target,Color(MINT,0.4),1)
		draw_line(target-direction*7+direction.orthogonal()*4,target,MINT,1)
		draw_line(target-direction*7-direction.orthogonal()*4,target,MINT,1)
	if game.hooked==game.HookState.FREE and not game.angler.casting:
		draw_rect(Rect2(cursor-Vector2(1,1),Vector2(2,2)),GOLD)

func _angler_hud(_t: float) -> void:
	draw_rect(Rect2(0,0,640,29),INK)
	label_at(Vector2(12,19),"钓鱼人",13,GOLD)
	label_at(Vector2(94,19),"鱼的食物 %02d / 60" % int(game.score),12,CREAM)
	label_at(Vector2(237,19),"鱼体力",11,CREAM)
	draw_rect(Rect2(281,11,62,6),Color("335762"))
	draw_rect(Rect2(281,11,62*game.stamina/100,6),MINT)
	label_at(Vector2(360,19),"抄网 %.1fs" % game.angler.net_cooldown if game.angler.net_cooldown>0 else "E + 拖动 抄网",11,MINT)
	var remaining := maxi(0,int(ceil(game.TIME_LIMIT-game.clock)))
	label_at(Vector2(529,20),"%02d:%02d" % [remaining/60,remaining%60],14,CREAM)
	draw_rect(Rect2(0,327,640,33),INK)
	label_at(Vector2(12,341),game.angler_hint(),11,GOLD)
	label_at(Vector2(12,355),"A/D 钓位   W/S 收放线   Q 下钩 / 补饵   E + 左键拖网   F3 时间",10,Color("9cbbb4"))
	label_at(Vector2(584,350),"H 帮助",10,CREAM)
	# Opponent checks remain autonomous; never invite the angler to press a fish QTE.
	panel(Rect2(10,65,151,50))
	label_at(Vector2(18,81),"小鱼 · "+game.fish_brain.state,11,MINT)
	if game.hooked==game.HookState.HOOKED:
		var spool := "放线" if game.reel_speed>0.5 else ("收线" if game.reel_speed< -0.5 else "稳线")
		label_at(Vector2(18,96),"张力 %d%% · %s" % [int(game.tension*100),spool],11,RED if game.tension>=0.88 else CREAM)
		draw_rect(Rect2(18,103,134,5),Color("335762"))
		draw_rect(Rect2(18,103,134*game.tension,5),MINT.lerp(RED,game.tension))
		if game.high_age>0: label_at(Vector2(18,129),"断线风险 %.1f / %.1fs" % [game.high_age,game.break_hold_seconds],10,RED)
	elif game.hooked==game.HookState.MOUTH:
		label_at(Vector2(18,100),"钩尖入口 · 等待挂牢",11,GOLD)
	else:
		var remaining_bait := 0
		for bait in game.baits:
			if bait.hook and not bait.removed:
				for grain in bait.grains:
					if not grain.eaten and not grain.free: remaining_bait+=1
		label_at(Vector2(18,100),"钩饵 %d 粒 · Q 下钩" % remaining_bait,11,CREAM)
	if game.net_blocks_hooks():
		var names := {"prepare":"抄网入水","warning":"准备扫网…","sweep":"拖动扫网 · 松 E 取消","miss":"被木石挡住" if game.net_blocked else "扑空了","withdraw":"撤网中","caught":"收拢提网…"}
		panel(Rect2(445,65,182,26))
		label_at(Vector2(454,83),names.get(game.net_state,"抄网中"),12,RED)

func _sway_line(start: Vector2, end: Vector2, sway: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 17:
		var ratio := index/16.0
		points.append(start.lerp(end,ratio)+Vector2(sin(PI*ratio)*sway,0))
	return points

func _line_back() -> void:
	if game.hooked == game.HookState.HOOKED and game.rope_path.size() >= 2:
		var points: PackedVector2Array=game.rope_path
		if game.player_role=="angler" and game.wraps.is_empty(): points=_sway_line(points[0],points[-1],game.angler.line_sway*(1-game.tension)*0.5)
		draw_polyline(points,INK,3)
		draw_polyline(points,Color("91b8ab"),1)

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
		draw_line(game.line_anchor(game.bound_bait), game.mouth(), RED, 1)

func _player(t: float) -> void:
	var mouth: Vector2 = game.mouth()
	var direction: Vector2 = game.aim
	if game.hooked == game.HookState.FREE and not game.menu.visible and (game.player_role=="fish" or game.feeding):
		var side := direction.orthogonal() * 27
		var far := mouth + direction * 44
		var pulling: bool=game.feeding
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
	if game.hooked == game.HookState.MOUTH or game.net_state=="caught" or game.landing:
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
	if game.hooked==game.HookState.HOOKED and not game.landing:
		var pull: Vector2 = game.line_pull_velocity()
		if pull.length()>2:
			var direction_to_line := pull.normalized()
			var pointer := position+direction_to_line*(23+fmod(t*12,9))
			draw_line(pointer-direction_to_line*4+direction_to_line.orthogonal()*3,pointer,RED,1)
			draw_line(pointer-direction_to_line*4-direction_to_line.orthogonal()*3,pointer,RED,1)
		if not game.latched and position.y<125:
			draw_rect(Rect2(game.line_anchor(game.bound_bait).x-35,57,70,4),Color(RED,0.4+0.2*sin(t*9)))
	if game.result_flash > 0:
		var radius: float = (0.7 - game.result_flash) * 25 + 12
		draw_arc(position, radius, 0, TAU, 16, MINT if game.result_good else RED, 1)
	if game.returning:
		draw_rect(Rect2(38, 276, 44, 2), INK)
		draw_rect(Rect2(38, 276, 44 * game.home_age / 2, 2), MINT)

func _net_draw_position() -> Vector2:
	var p: Vector2=game.net_pos
	if game.net_state=="miss":
		p-=Vector2.from_angle(game.net_angle)*sin(PI*game.net_age/game.NET_MISS)*(4 if game.net_blocked else 2)
	return p.round()

func _net_back(t: float) -> void:
	if game.net_blocks_hooks(): _draw_landing_net(_net_draw_position(),t,false)

func _net(t: float) -> void:
	if not game.net_blocks_hooks(): return
	var from: Vector2=game.net_from
	var to: Vector2=game.net_to
	var direction := Vector2.from_angle(game.net_angle)
	var alpha := 0.18+0.12*sin(t*9)
	if game.net_state in ["prepare","warning","sweep"]:
		if game.net_kind=="drop":
			draw_rect(Rect2(clampf(from.x-50,0,540),55,100,7),Color(RED,alpha+0.1))
		else:
			draw_rect(Rect2(0 if direction.x>0 else 630,55,10,258),Color(RED,alpha+0.1))
		var arrow := Vector2(from.x,73) if game.net_kind=="drop" else Vector2(16 if direction.x>0 else 624,from.y)
		draw_colored_polygon(PackedVector2Array([arrow+direction*8,arrow-direction*5+direction.orthogonal()*5,arrow-direction*5-direction.orthogonal()*5]),RED)
	if game.net_state in ["prepare","warning"]:
		var danger: PackedVector2Array=game.net_warning_outline()
		draw_colored_polygon(danger,Color(RED,0.04 if game.net_state=="prepare" else 0.10))
		for index in range(1,danger.size()):
			if index%2==0: draw_line(danger[index-1],danger[index],Color(RED,0.7),1)
		for index in range(1,5):
			var arrow := from.lerp(to,index/5.0)
			draw_line(arrow-direction*4+direction.orthogonal()*3,arrow,Color(RED,0.5),1)
			draw_line(arrow-direction*4-direction.orthogonal()*3,arrow,Color(RED,0.5),1)
		if game.net_state=="warning":
			var remaining: float=1-game.net_age/game.net_warning_seconds()
			draw_arc(from,9,-PI/2,-PI/2+TAU*remaining,24,RED,2)
	_draw_landing_net(_net_draw_position(),t,true)
	if game.net_state=="sweep":
		var velocity_scale := clampf(game.net_motion.length()/300,0,1)
		for index in range(12):
			var life := fmod(game.net_age*2.5+index/12.0,1)
			var bubble: Vector2=game.net_pos-direction*(10+life*38)+direction.orthogonal()*sin(index*2.7)*24
			draw_rect(Rect2(bubble.round(),Vector2(2,2)),Color(MINT,(1-life)*velocity_scale*0.65))
	if game.net_state=="miss" and game.net_blocked:
		var progress: float=game.net_age/game.NET_MISS
		for index in range(5):
			var normal := direction.rotated((index-2)*0.3)
			var at: Vector2=to+direction*game.NET_RIM.x+normal*(2+progress*8)
			draw_line(at,at+normal*4,Color(GOLD,1-progress),1)
	if game.net_state in ["caught","withdraw"] and game.net_pos.y<95:
		for index in range(7):
			var life := fmod(t*2.4+index/7.0,1)
			var drip: Vector2=game.net_pos+Vector2((index-3)*5,12+life*42)
			draw_line(drip.round(),(drip+Vector2(0,3+life*4)).round(),Color(MINT,0.7*(1-life)),1)
	if game.net_splash>0:
		var life: float=1-game.net_splash/0.6
		var origin: Vector2=game.net_splash_at
		var surface := absf(origin.y-57)<2
		for index in range(11):
			var spread := Vector2((index-5)*4*life,-sin(index*1.7)*12*life+life*life*18)
			draw_rect(Rect2((origin+spread).round(),Vector2(2,2)),Color(CREAM,(1-life)*0.8))
		if surface:
			var ring := PackedVector2Array()
			for index in range(33): ring.append(origin+Vector2.from_angle(index*TAU/32)*Vector2(8+life*32,2+life*3))
			draw_polyline(ring,Color(MINT,1-life),1)
		else: draw_arc(origin,6+life*16,0,TAU,24,Color(MINT,(1-life)*0.6),1)

func _draw_landing_net(p: Vector2, t: float, front: bool) -> void:
	var rim: Vector2=game.NET_RIM
	var angle: float=game.net_angle
	var caught: bool=game.net_state=="caught"
	var settling: float=smoothstep(0,1,game.net_age/game.NET_SETTLE) if caught else 0.0
	var outline := PackedVector2Array()
	var bag := PackedVector2Array()
	var back: Vector2=p+game.net_bag_offset()
	var joint := p
	for index in range(33):
		var circle := Vector2.from_angle(index*TAU/32)
		var rim_point := p+(circle*rim).rotated(angle)
		outline.append(rim_point.round())
		var bag_shape := (circle*rim*0.60).rotated(angle).lerp(circle*Vector2(18,25),settling)
		bag.append((back+bag_shape).round())
		if rim_point.y<joint.y: joint=rim_point
	if not front:
		var pole_top: Vector2=Vector2(game.angler.x+7,45) if game.manual_net else Vector2(game.net_from.x+(-18 if game.net_from.x<320 else 18),40)
		var pole := PackedVector2Array([pole_top,pole_top.lerp(joint,0.52)+Vector2(sin(t*3)*1.5,0),joint])
		draw_polyline(pole,INK,7)
		draw_polyline(pole,Color("957044"),5)
		draw_polyline(pole,Color("d8b87a"),2)
		var bag_hull := Geometry2D.convex_hull(outline+bag)
		draw_colored_polygon(bag_hull,Color(0.28,0.49,0.49,0.20))
		draw_colored_polygon(bag,Color(0.12,0.28,0.33,0.28 if caught else 0.16))
		draw_polyline(bag,Color("7ca2a0"),1)
		for index in range(0,32,4): draw_line(outline[index],bag[index],Color(0.62,0.78,0.70,0.55),1)
		return
	# Mesh is drawn over the fish; it settles into the actual bag, not in front of the hoop.
	for lean in [-1,1]:
		var along := Vector2(lean*0.65,0.76).normalized()
		for index in range(-4,5):
			var offset := index/5.0
			var base := along.orthogonal()*offset
			var reach := sqrt(1-offset*offset)
			var a := ((base-along*reach)*rim*0.60).rotated(angle).lerp((base-along*reach)*Vector2(18,25),settling)
			var b := ((base+along*reach)*rim*0.60).rotated(angle).lerp((base+along*reach)*Vector2(18,25),settling)
			draw_line((back+a).round(),(back+b).round(),Color(0.66,0.81,0.74,0.58),1)
	for index in range(0,32,4): draw_line(outline[index],bag[index],Color(0.65,0.81,0.73,0.32),1)
	draw_polyline(outline,INK,5)
	draw_polyline(outline,Color("b59663"),3)
	for index in range(1,outline.size()):
		if outline[index].y<p.y: draw_line(outline[index-1],outline[index],CREAM,1)
		else: draw_line(outline[index-1],outline[index],Color("8dbeac"),1)
	draw_rect(Rect2(joint-Vector2(3,3),Vector2(7,6)),Color("8cabad"))

func _hud(t: float) -> void:
	if game.menu.visible: return
	if game.player_role=="angler":
		_angler_hud(t)
		return
	draw_rect(Rect2(0,0,640,35), INK)
	label_at(Vector2(12,15), "像素池塘", 12, GOLD)
	label_at(Vector2(12,28), "限时挑战" if game.challenge else "练习 · F2 调节", 10, MINT)
	var target: float = game.TARGET if game.challenge else 18
	label_at(Vector2(111,22), "食物 %02d / %d" % [int(game.score),int(target)], 15)
	label_at(Vector2(272,15), "吸力 %d%%" % int(game.power*100), 11, CREAM)
	draw_rect(Rect2(272,22,68,3), Color("335762"))
	draw_rect(Rect2(272,22,68*game.power,3), GOLD)
	label_at(Vector2(366,15), "加速" if game.sprinting else ("抗拉" if game.resisting else ("乏力" if game.stamina<20 else "体力")), 11, GOLD if game.sprinting or game.resisting else CREAM)
	draw_rect(Rect2(366,22,70,3), Color("335762"))
	draw_rect(Rect2(366,22,70*game.stamina/100,3), GOLD if game.sprinting else (RED if game.sprint_exhausted else MINT))
	var remaining := maxi(0, int(ceil(game.TIME_LIMIT-game.clock)))
	label_at(Vector2(515,23), "%02d:%02d" % [remaining/60,remaining%60] if game.challenge else "N 抄网练习", 14, RED if remaining < 60 else CREAM)
	draw_rect(Rect2(0,333,640,27), INK)
	label_at(Vector2(12,350), game.hint(), 12)
	label_at(Vector2(584,350), "H 帮助", 10, Color("9cbbb4"))
	if game.net_state in ["prepare","warning","sweep","miss","withdraw","caught"]:
		panel(Rect2(230,63,180,26))
		var phase := "横向扫网" if game.net_kind=="sweep" else "上方下探"
		if game.net_state=="prepare": phase+=" · 准备"
		elif game.net_state=="warning": phase+=" · %.1f 秒" % maxf(0,game.net_warning_seconds()-game.net_age)
		elif game.net_state=="caught": phase="网袋收拢…" if game.net_age<game.NET_SETTLE else "正在提网…"
		elif game.net_state=="miss": phase="网口被挡住" if game.net_blocked else "抄网扑空"
		elif game.net_state=="withdraw": phase="抄网撤回 · 继续觅食"
		label_at(Vector2(240,81),phase,12,RED)
	if game.hooked == game.HookState.HOOKED:
		panel(Rect2(246,62,148,43))
		label_at(Vector2(254,76), "张力 %d%%" % int(game.tension*100), 11, CREAM)
		label_at(Vector2(325,76), "缠线 ×%d" % game.wraps.size() if game.latched else ("提离水面" if game.landing else "收鱼中"), 10, MINT if game.latched else RED)
		draw_rect(Rect2(254,83,132,6), Color("335762"))
		draw_rect(Rect2(254,83,132*game.tension,6), MINT.lerp(RED,game.tension))
		var spool := "放线 ↓" if game.reel_speed>0.5 else ("收线 ↑" if game.reel_speed < -0.5 else "稳线")
		label_at(Vector2(254,100), spool+(" · 缠绕减力" if game.latched else " · 向水面牵引"), 9, Color("9cbbb4"))
		if game.high_age > 0:
			draw_rect(Rect2(246,108,148*minf(1,game.high_age/game.break_hold_seconds),3), RED)
	if not game.qte.is_empty() or game.qte_result_age>0: _qte(t)

func _qte(t: float) -> void:
	var showing_result: bool = game.qte.is_empty()
	var kind: String = game.qte_result_kind if showing_result else game.qte
	var zone_start: float = game.qte_result_zone if showing_result else game.qte_zone
	var progress: float = game.qte_result_progress if showing_result else game.qte_progress()
	var zone_width: float=game.qte_result_width if showing_result else game.qte_width
	var success_zone: bool = progress>=zone_start and progress<=zone_start+zone_width
	var effect: float = 1-game.qte_result_age/0.7
	var intro: float = clampf(game.qte_age/0.3,0,1) if not showing_result else 1.0
	var origin: Vector2 = game.qte_origin+Vector2(0,roundf(10*pow(1-intro,3)))
	if showing_result and not game.qte_result_good: origin.x += roundf(sin(effect*42)*(1-effect)*3)
	var accent := MINT if kind=="slack" else GOLD
	if showing_result: accent = MINT if game.qte_result_good else RED
	panel(Rect2(origin,Vector2(176,216)),Color("103e57"))
	# Muted water ripples echo the reference without obscuring the metal and green zone.
	for wave in range(15):
		var base := origin+Vector2(8+posmod(wave*67,148),32+posmod(wave*29,133))
		var points := PackedVector2Array()
		for part in range(6): points.append((base+Vector2(part*3,sin(part*0.7+t*0.8+wave)*2)).round())
		draw_polyline(points,Color(0.12,0.47,0.64,0.25),1)
	var title := "吐钩判定" if kind=="entry" else ("缠线判定" if kind=="wrap" else "松线脱钩")
	label_at(origin+Vector2(14,23),title,14,accent)
	var center := origin+Gauge.CENTER
	draw_arc(center,69,0,TAU,48,Color(0.22,0.66,0.76,0.13),1)
	draw_texture(gauge_texture,origin)
	for tick in range(1,9):
		var ratio := tick/10.0
		draw_line((origin+Gauge.point(ratio,37)).round(),(origin+Gauge.point(ratio,43)).round(),Color("081724"),4)
		draw_line((origin+Gauge.point(ratio,37)).round(),(origin+Gauge.point(ratio,43)).round(),Color("b5c0c1"),2)
	var zone: PackedVector2Array = Gauge.section(zone_start,zone_start+zone_width)
	for index in zone.size(): zone[index]+=origin
	var green := Color("63ed4d") if success_zone else Color("2fbe44")
	draw_polyline(zone,Color("082818"),10)
	draw_polyline(zone,Color("157432"),8)
	draw_polyline(zone,green,5)
	for ratio in [zone_start,zone_start+zone_width]:
		draw_line((origin+Gauge.point(ratio,43)).round(),(origin+Gauge.point(ratio,55)).round(),Color("081724"),4)
		draw_line((origin+Gauge.point(ratio,44)).round(),(origin+Gauge.point(ratio,54)).round(),CREAM,2)
	var marker: Vector2 = (origin+Gauge.point(progress)).round()
	if game.qte_age>=0.4 or showing_result:
		for trail in range(1,6):
			var p: Vector2 = origin+Gauge.point(maxf(0,progress-trail*0.018))
			draw_rect(Rect2(p.round(),Vector2(2,2)),Color(CREAM,(1-trail/6.0)*0.35))
	else:
		draw_arc(center,69,-PI/2,-PI/2+TAU*game.qte_age/0.4,40,Color(MINT,0.5),1)
	draw_arc(marker+Vector2(0,3),10+sin(t*4),0,TAU,16,Color(MINT,0.25),1)
	draw_texture(bobber_texture,marker-Vector2(8,8))
	var key_center := center+Vector2(1,-1)
	var key_size := Vector2(40,22)
	var key_rect := Rect2((key_center-key_size*0.5).round(),key_size)
	draw_rect(Rect2(key_rect.position+Vector2(0,2),key_size),Color("091f29"))
	draw_rect(key_rect,Color("22473e") if success_zone else Color("10354a"))
	draw_rect(key_rect,green if success_zone else Color("547c85"),false,1)
	label_at(key_rect.position+Vector2(8,16),"空格",12,CREAM)
	if showing_result:
		label_at(origin+Vector2(14,187),game.qte_result,14,accent)
		label_at(origin+Vector2(14,204),"线圈保留 · 准备松线" if game.qte_result_good and kind=="wrap" else ("继续游动" if game.qte_result_good else "调整后可以再试"),10,CREAM)
		if game.qte_result_good:
			draw_arc(center,57+effect*13,0,TAU,48,Color(accent,(1-effect)*0.6),1)
			for spark in range(10):
				var p := center+Vector2.from_angle(spark*TAU/10)*(57+effect*15)
				draw_rect(Rect2(p.round(),Vector2(2,2)),Color(accent,1-effect))
	else:
		var instruction := "浮漂进入绿区时按空格"
		if game.qte_age<0.4: instruction="准备…"
		elif success_zone: instruction="现在按空格"
		label_at(origin+Vector2(14,187),instruction,12,green if success_zone else CREAM)
		var detail := "边游动抗拉，边保持接触" if kind=="wrap" else ("移动保持低张力" if kind=="slack" else "抓住机会吐出鱼钩")
		label_at(origin+Vector2(14,204),detail,10,Color("9cbbb4"))

func _track_point(path: PackedVector2Array, progress: float) -> Vector2:
	var index := clampf(progress,0,1)*(path.size()-1)
	var before := int(index)
	return path[before].lerp(path[mini(before+1,path.size()-1)],index-before).round()
