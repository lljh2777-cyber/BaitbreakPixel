extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const Layout = preload("res://scripts/pond_layout.gd")
const Gauge = preload("res://scripts/hook_gauge.gd")
const AnglerVisual = preload("res://scripts/angler_visual.gd")
const Shore = preload("res://scripts/shore_view.gd")
const LineMotion = preload("res://scripts/line_motion.gd")
const FishWinding = preload("res://scripts/fish_winding.gd")
var line_frame: Dictionary={}
var line_motion := LineMotion.new()
const INK := Color("142e39")
const CREAM := Color("fff0cd")
const MINT := Color("8de0bd")
const GOLD := Color("ffd379")
const RED := Color("f58375")
const SKILL_ORIGIN := Vector2(10,122)
var game: Node2D
var world: Node2D
var angler_visual := AnglerVisual.new()
var shore := Shore.new()
var fish_texture: Texture2D
var gauge_texture: Texture2D
var bobber_texture: Texture2D
var font: SystemFont
var props: Array[Dictionary] = []
var plant_frames: Array = []

func _ready() -> void:
	shore.hand.prepare(self)
	shore.reel_hand.prepare(self)
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
	world=game.network.display_world() if is_instance_valid(game.network) and game.network.active() and game.shared_session else game
	var t: float = world.elapsed
	line_frame=line_motion.sample(world)
	if game.player_role=="angler":
		shore.draw(self,world,t)
		_hud(t)
		_network_badge()
		return
	_world(t)
	_baits(t)
	_angler(t)
	_line()
	_net_back(t)
	_player(t)
	_net(t)
	_hud(t)
	_network_badge()

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
	if world.uses_mobile_tackle():
		# A narrow bank walkway leaves room for the full character below either HUD.
		draw_rect(Rect2(0,56,640,8),Color("253e42"))
		for plank in range(40):
			var x := plank*16
			draw_rect(Rect2(x,57,15,5),Color("8d8665") if plank%3 else Color("9e9470"))
			draw_rect(Rect2(x+1,57,13,1),Color("c9bb87"))
			draw_rect(Rect2(x+4,59,7,1),Color("736f57"))
			draw_rect(Rect2(x+2,58,1,1),Color("405450"))
		for post in range(8):
			draw_rect(Rect2(post*88+23,63,4,7),Color("344f50"))
			draw_rect(Rect2(post*88+23,63,1,5),Color("717d62"))
	for shaft in range(5):
		for step in range(6):
			draw_rect(Rect2(shaft * 149 + step * 7 + 21, 55 + step * 43, 16 + step * 3, 43), Color(0.63, 0.89, 0.74, 0.025))
	for index in range(31):
		var base := Vector2(4+posmod(index*61,632),65+posmod(index*47,234))
		var drifting: Vector2 = (base+world.water_offset(base)*2).round()
		draw_rect(Rect2(drifting,Vector2(1+index%2,1)),Color(0.65,0.86,0.75,0.35))
	for index in range(16):
		var base := Vector2(30+posmod(index*97,580),77+posmod(index*53,220))
		var drifting: Vector2 = base+world.water_offset(base)*2
		var flow: Vector2 = world.water_velocity(base)
		var alpha: float = (0.09+0.055*sin(t*1.3+index))*world.water_strength
		draw_line(drifting.round(),(drifting-flow*2.4).round(),Color(0.68,0.91,0.85,alpha),1)
	# Distant silhouettes are muted; detailed foreground silhouettes share collision data.
	for index in range(15):
		var x := index*47-16
		var height := 12 + index*17%29
		draw_colored_polygon(PackedVector2Array([Vector2(x,315),Vector2(x+5,313-height),Vector2(x+22,306-height),Vector2(x+42,315-height/2),Vector2(x+52,320)]),Color("275963"))
	# The far half of the lap is genuinely behind wood, rocks and both weed layers.
	_winding_fish(t,false)
	_baits(t,true)
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
		draw_texture(prop.texture,prop.position,Color(1,1,1,world.target_opacity[index]))
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
	if world.score >= (world.TARGET if world.challenge else 18):
		var bounce := int(sin(t * 4) * 2)
		draw_colored_polygon(PackedVector2Array([Vector2(55, 267 + bounce), Vector2(65, 267 + bounce), Vector2(60, 272 + bounce)]), MINT)

func _plants(t: float, background: bool) -> void:
	var frame := posmod(int(t*12.0/TAU),8)
	for index in Layout.PLANTS.size():
		if Layout.PLANTS[index].back!=background: continue
		var sprite: Dictionary = plant_frames[index][frame]
		draw_texture(sprite.texture,sprite.position,Color(1,1,1,world.target_opacity[Layout.SOLIDS.size()+index]))

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

func _bait_point(index: int, point: Vector2) -> Vector2:
	if index!=world.bound_bait: return point
	return FishWinding.attached_point(world,line_frame.fish,point)

func _baits(t: float, behind: bool=false) -> void:
	for index in world.baits.size():
		var bait: Dictionary = world.baits[index]
		var orbit: bool=line_frame.fish.active and index==world.bound_bait
		if behind!=(orbit and not line_frame.fish.front): continue
		# Net activity suppresses new bites, not the physical hook or its hanging line.
		if bait.active and bait.hook and not bait.removed:
			if world.bound_bait != index:
				var filament := PackedVector2Array()
				var eye: Vector2 = world.hook_point(index,Vector2(-5,-10))
				for segment in range(17):
					var ratio := segment/16.0
					var point: Vector2 = world.line_anchor(index).lerp(eye,ratio)
					point.x += sin(ratio*PI)*(world.angler.line_sway if world.uses_mobile_tackle() else sin(t*0.75+ratio*2)*2.5*world.water_strength)
					filament.append(point.round())
				draw_polyline(filament,Color("b9d5bf"),1)
			var hook := PackedVector2Array([Vector2(-5,-10),Vector2(-5,4),Vector2(-3,7),Vector2(1,7),Vector2(3,5),Vector2(3,1),Vector2.ZERO])
			for point in hook.size(): hook[point] = _bait_point(index,world.hook_point(index,hook[point])).round()
			draw_polyline(hook, RED if world.bound_bait == index else Color("e1e3ce"), 1)
		var flashing: bool = world.cycle_phase == "warning" and world.cycle_slot == index and int(t * 6) % 2 == 0
		for grain in bait.grains:
			if grain.eaten or (not grain.free and not bait.active): continue
			var offset: Vector2 = grain.offset
			var shade: float = clampf(0.48-(offset.x+offset.y)/22.0,0,1)
			var color := Color("a26c3f").lerp(Color("f1d798"),shade)
			if grain.fleck == 0: color = color.lightened(0.13)
			if flashing and not grain.free: color = RED
			var p: Vector2 = Vector2(grain.pos).round()
			if not grain.free: p=_bait_point(index,grain.pos).round()
			if grain.free:
				draw_rect(Rect2(p,Vector2.ONE),color.lightened(0.15))
			else:
				draw_rect(Rect2(p,Vector2(2,2) if grain.layer<2 else Vector2.ONE),color.darkened(0.18))
				draw_rect(Rect2(p,Vector2(2 if grain.fleck%2 else 1,1)),color)
		if bait.active and not game.menu.visible and not orbit:
			var label := "有钩饵" if bait.hook and not bait.removed else "散饵"
			label_at(Vector2(bait.pos) + Vector2(-17, -14), label, 10, Color("bdd4be"))
		# A tiny glint remains at the actual tip after the grains are drawn over the hook.
		if bait.active and bait.hook and not bait.removed:
			draw_rect(Rect2(_bait_point(index,world._tip(index)).round(),Vector2.ONE),RED if world.bound_bait==index else CREAM)

func _angler(t: float) -> void:
	if not world.uses_mobile_tackle(): return
	angler_visual.draw(self,world,t)
	if world.angler.casting:
		var ball: Vector2=world.angler.projectile().round()
		draw_line(world.angler.anchor(),ball,Color("b9d5bf"),1)
		draw_rect(Rect2(ball-Vector2(2,2),Vector2(5,4)),Color("a26c3f"))
		draw_rect(Rect2(ball-Vector2(2,2),Vector2(3,2)),GOLD)
		draw_line(ball,ball+Vector2(0,4),CREAM,1)
	if game.player_role!="angler" or game.menu.visible or not world.angler.net_held: return
	var cursor: Vector2=world.angler.cursor.round()
	var color := MINT if world.angler.net_cooldown<=0 else Color("7ca9a0")
	for side in [-1,1]:
		draw_line(cursor+Vector2(side*5,0),cursor+Vector2(side*9,0),color,1)
		draw_line(cursor+Vector2(0,side*5),cursor+Vector2(0,side*9),color,1)
	if world.angler.net_held and not world.net_blocks_hooks():
		var start: Vector2=world.manual_net_target(cursor)
		var blocked: bool=world.manual_net_blocked(start)
		var preview := RED if blocked else MINT
		draw_arc(start,world.NET_RIM.y+2,0,TAU,32,Color(preview,0.5),1)
		label_at(start+Vector2(-30,-38),"木石挡网" if blocked else "从这里下网",10,preview)
	if world.manual_net and world.net_state in ["prepare","warning","sweep"]:
		var path: PackedVector2Array=world.manual_net_pending_path()
		if path.size()>1:
			draw_polyline(path,Color(MINT,0.7),1)
			var direction: Vector2=(path[-1]-path[-2]).normalized()
			draw_line(path[-1]-direction*7+direction.orthogonal()*4,path[-1],MINT,1)
			draw_line(path[-1]-direction*7-direction.orthogonal()*4,path[-1],MINT,1)
	if world.hooked==world.HookState.FREE and not world.angler.casting:
		draw_rect(Rect2(cursor-Vector2(1,1),Vector2(2,2)),GOLD)

func _angler_hud(_t: float) -> void:
	draw_rect(Rect2(0,0,640,29),INK)
	label_at(Vector2(12,19),"岸边 · 钓鱼人",13,GOLD)
	var rig := "挂鱼 · 留意张力" if world.hooked==world.HookState.HOOKED else "浮漂下顿" if world.hooked==world.HookState.MOUTH else "钩饵在水中" if Shore.rig_index(world)>=0 else "Q 下钩 / 补饵"
	label_at(Vector2(140,19),rig,12,CREAM)
	label_at(Vector2(360,19),"抄网 %.1fs" % world.angler.net_cooldown if world.angler.net_cooldown>0 else "E + 拖动 抄网",11,MINT)
	var remaining := maxi(0,int(ceil(world.TIME_LIMIT-world.clock)))
	label_at(Vector2(529,20),"%02d:%02d" % [remaining/60,remaining%60] if world.challenge else "练习 · F2",14,CREAM)
	draw_rect(Rect2(0,327,640,33),INK)
	label_at(Vector2(12,341),game.angler_hint(),11,GOLD)
	label_at(Vector2(12,355),"A/D 左右移竿   W/S 收放线   Q 下钩 / 补饵   F 解缠   E + 左键拖网",10,Color("9cbbb4"))
	label_at(Vector2(584,350),"H 帮助",10,CREAM)
	# Opponent checks remain autonomous; never invite the angler to press a fish QTE.
	panel(Rect2(10,65,151,50))
	if world.hooked==world.HookState.HOOKED:
		var spool := "S 放线" if world.angler.spool>0 else ("W 收线" if world.angler.spool<0 else "稳线")
		label_at(Vector2(18,81),"张力 %d%% · %s" % [int(world.tension*100),spool],11,RED if world.tension>=0.88 else CREAM)
		draw_rect(Rect2(18,88,134,5),Color("335762"))
		draw_rect(Rect2(18,88,134*world.tension,5),MINT.lerp(RED,world.tension))
		if world.untangle_phase=="check":
			draw_rect(Rect2(18+134*world.UNTANGLE_MIN,86,134*(world.UNTANGLE_MAX-world.UNTANGLE_MIN),9),GOLD,false,1)
		label_at(Vector2(18,108),"断线风险 %.1f / %.1fs" % [world.high_age,world.break_hold_seconds] if world.high_age>0 else ("正在退线" if world.untangle_phase=="unwind" else "解缠 · 张力 25–55%" if world.untangle_phase=="check" else "鱼线受阻 · F 解缠" if world.latched else world.tug_status()),10,RED if world.high_age>0 else MINT)
	elif world.hooked==world.HookState.MOUTH:
		label_at(Vector2(18,81),"浮漂正在下顿",11,MINT)
		label_at(Vector2(18,100),"吐钩判定中 · 暂缓收放",10,GOLD)
	else:
		label_at(Vector2(18,81),"观察浮漂与水面",11,MINT)
		var remaining_bait := 0
		for bait in world.baits:
			if bait.hook and not bait.removed:
				for grain in bait.grains:
					if not grain.eaten and not grain.free: remaining_bait+=1
		label_at(Vector2(18,100),"钩饵 %d 粒 · Q 下钩" % remaining_bait,11,CREAM)
	if world.net_blocks_hooks():
		var names := {"prepare":"抄网入水","warning":"准备扫网…","sweep":"沿轨迹扫网 · 松 E 取消","miss":"被木石挡住" if world.net_blocked else "扑空了","withdraw":"撤网中","caught":"收拢提网…"}
		panel(Rect2(445,65,182,26))
		label_at(Vector2(454,83),names.get(world.net_state,"抄网中"),12,RED)

func _slack_line(start: Vector2, end: Vector2, available: float, sway: float = 0.0) -> PackedVector2Array:
	var chord := start.distance_to(end)
	var excess := maxf(0,available-chord)
	var bow := minf(46,sqrt(excess*(2*chord+excess))*0.40)
	var normal := (end-start).normalized().orthogonal()
	var points := PackedVector2Array()
	for index in 25:
		var ratio := index/24.0
		var offset := normal*bow+Vector2(sway,0)
		points.append((start.lerp(end,ratio)+offset*sin(PI*ratio)).round())
	return points

func _line_pixels(points: PackedVector2Array) -> PackedVector2Array:
	var pixels := PackedVector2Array()
	for p in points:
		var pixel := p.round()
		if pixels.is_empty() or pixel!=pixels[-1]: pixels.append(pixel)
	return pixels

func _draw_strand(points: PackedVector2Array, color: Color) -> void:
	var pixels := _line_pixels(points)
	if pixels.size()<2: return
	draw_polyline(pixels,Color(INK,0.82),3)
	draw_polyline(pixels,color,1)

func _line_back() -> void:
	if line_frame.get("path",PackedVector2Array()).size()<2: return
	_draw_strand(line_frame.path,MINT.lerp(RED,world.tension))
	_line_details(false)
	if world.wraps.is_empty(): _line_force_marks(line_frame.path)

func _line_details(foreground: bool) -> void:
	for effect: Dictionary in line_frame.get("effects",[]):
		var accent := Color("b8e3de") if effect.unwind else GOLD
		var strength: float=effect.strength
		if strength<=0.025: continue
		if foreground==effect.head_front:
			var trail: PackedVector2Array=_line_pixels(effect.trail)
			if trail.size()>1: draw_polyline(trail,Color(accent,strength*0.8),1)
			var p: Vector2=effect.point.round()
			draw_rect(Rect2(p-Vector2(1,0),Vector2(3,1)),Color(accent,strength))
			draw_rect(Rect2(p,Vector2.ONE),Color(CREAM,strength))
		if not foreground: continue
		# A few small underwater bubbles replace the large cross-shaped marker.
		for bubble in 4:
			var age: float=effect.progress-(0.08+bubble*0.16)
			if age<0 or age>0.46: continue
			var origin: Vector2=effect.center+Vector2(cos(bubble*1.7)*effect.radii.x,sin(bubble*1.7)*effect.radii.y)
			var p: Vector2=(origin+Vector2(sin(bubble+age*5)*2,-age*24)).round()
			var color := Color(accent,(1-age/0.46)*strength*0.48)
			draw_rect(Rect2(p,Vector2(2,2)),color,false,1)

func _line_vibration(path: PackedVector2Array) -> PackedVector2Array:
	var points := path.duplicate()
	var force: float=absf(world.effort_multiplier("angler")-1)+absf(world.effort_multiplier("fish")-1)
	var amplitude: float=world.tension*minf(1.5,0.4+force*2)
	var normal := (points[-1]-points[0]).normalized().orthogonal()
	for index in range(1,points.size()-1):
		var ratio := index/float(points.size()-1)
		points[index]+=normal*sin(ratio*PI)*sin(world.elapsed*28-ratio*18)*amplitude
	return points

func _line_force_marks(path: PackedVector2Array) -> void:
	if world.tension<0.25 or path.size()<2: return
	var human: float=world.effort_multiplier("angler")
	var fish_force: float=world.effort_multiplier("fish")
	if is_equal_approx(human,fish_force): return
	var color := GOLD if human>fish_force else MINT
	for index in 3:
		var progress := fmod(world.elapsed*0.8+index/3.0,1)
		if human>fish_force: progress=1-progress
		var p := _track_point(path,progress)
		var neighbor := _track_point(path,clampf(progress+(0.04 if human>fish_force else -0.04),0,1))
		draw_line(neighbor,p,color,2)

func _line() -> void:
	if world.hooked==world.HookState.HOOKED:
		# Repaint only the near-side portions using the exact same geometry as
		# the back layer. This preserves depth without ghost/double fish lines.
		var front := PackedVector2Array()
		for i in line_frame.front.size():
			if line_frame.front[i]:
				if front.is_empty(): front.append(line_frame.path[i])
				front.append(line_frame.path[i+1])
			else:
				_draw_strand(front,MINT.lerp(RED,world.tension))
				front.clear()
		_draw_strand(front,MINT.lerp(RED,world.tension))
		_line_details(true)
		if not world.wraps.is_empty() and line_frame.tail.size()>1: _line_force_marks(line_frame.tail)
		if world.contact_target>=0 and not world.winding() and not game.menu.visible:
			var target: Dictionary = world.targets[world.contact_target]
			var outline: PackedVector2Array = target.polygon.duplicate()
			outline.append(outline[0])
			draw_polyline(outline,Color(MINT,0.65 if world.qte=="wrap" else 0.32),1)
	elif world.hooked == world.HookState.MOUTH:
		draw_line(world.line_anchor(world.bound_bait), world.mouth(), RED, 1)

func _winding_fish(t: float, front: bool) -> void:
	var pose: Dictionary=line_frame.fish
	if not pose.active or pose.front!=front: return
	var transform:=Transform2D(pose.axis_x,pose.axis_y,Vector2(pose.position).round())
	var tint:=Color.WHITE.darkened(1.0-float(pose.shade))
	# Keep the head/mouth rigid; animate the tail around its attachment point.
	var tail:=Transform2D(sin(t*38)*0.28*float(pose.blend),Vector2(-4,0))
	draw_set_transform_matrix(transform*tail)
	draw_texture_rect_region(fish_texture,Rect2(-8,-6,8,12),Rect2(0,0,8,12),tint)
	draw_set_transform_matrix(transform)
	draw_texture_rect_region(fish_texture,Rect2(-4,-6,16,12),Rect2(8,0,16,12),tint)
	draw_set_transform(Vector2.ZERO)
	# A tiny end-on pose preserves body volume at the two tight turns. It
	# replaces the wafer-thin profile with a face / tail in the same palette.
	if pose.end_on>0.15:
		var p: Vector2=Vector2(pose.position).round()
		var half:=maxi(1,roundi(float(pose.end_on)*3))
		draw_rect(Rect2(p+Vector2(-half,-4),Vector2(half*2+1,8)),Color("985436"))
		draw_rect(Rect2(p+Vector2(-half+1,-4),Vector2(half*2-1,8)),Color("e6a448"))
		draw_rect(Rect2(p+Vector2(-half+1,-5),Vector2(half*2-1,1)),Color("985436"))
		draw_rect(Rect2(p+Vector2(-half+1,4),Vector2(half*2-1,1)),Color("985436"))
		if pose.toward_camera and half>=2:
			for side in [-1,1]:
				draw_rect(Rect2(p+Vector2(side*(half-1)-1,-2),Vector2(2,2)),CREAM)
				draw_rect(Rect2(p+Vector2(side*(half-1),-1),Vector2.ONE),INK)
			draw_rect(Rect2(Vector2(pose.mouth).round(),Vector2.ONE),Color("985436"))
		elif half>=2:
			draw_line(p+Vector2(0,-3),p+Vector2(sin(t*38),3),Color("ffd879"),1)

func _player(t: float) -> void:
	if line_frame.fish.active:
		_winding_fish(t,true)
		return
	var mouth: Vector2 = world.mouth()
	var direction: Vector2 = world.aim
	if world.hooked == world.HookState.FREE and not game.menu.visible and (game.player_role=="fish" or world.feeding):
		var side := direction.orthogonal() * 27
		var far := mouth + direction * 44
		var pulling: bool=world.feeding
		var fade := 0.17 if pulling else 0.045
		draw_colored_polygon(PackedVector2Array([mouth, far+side, far-side]), Color(0.67,0.94,0.81,fade))
		if pulling:
			for index in range(5):
				var ratio := fmod(t * 1.7 + index * 0.2, 1)
				var start := far + side * sin(index * 3.8) * 0.7
				var p := start.lerp(mouth, ratio).round()
				draw_rect(Rect2(p, Vector2(2,1)), MINT)
	var position: Vector2 = world.fish.round()
	var tilt: float = direction.angle()+world.water_velocity(world.fish).x*0.009
	var flip := 1.0
	if direction.x < 0:
		tilt -= PI
		flip = -1
	if world.hooked == world.HookState.MOUTH or world.net_state=="caught" or world.landing:
		tilt += sin(t * 45) * 0.13
		position.y += int(sin(t * 32) * 1.5)
	elif world.velocity.length() > 5:
		position.y += int(sin(t * 18))
	var effort: float=world.effort_multiplier("fish")
	if world.hooked==world.HookState.HOOKED and not world.landing:
		tilt+=sin(t*(30 if effort>1 else 10))*0.08*world.tension
		if effort<1: tilt+=0.13*flip
	if world.sprinting:
		for index in range(7):
			var life := fmod(t*2.8+index/7.0,1)
			var wake: Vector2 = position-direction*(13+life*27)+direction.orthogonal()*sin(index*2.7)*5
			draw_rect(Rect2(wake.round(),Vector2(3,1)),Color(MINT,(1-life)*0.65))
	draw_set_transform(position, tilt, Vector2(flip, 1))
	if world.resisting or effort>1:
		var tail := Vector2(-13,sin(t*(32 if effort>1 else 20))*3)
		draw_line(Vector2(-7,0),tail+Vector2(-4,-3),GOLD if effort>1 else MINT,2)
		draw_line(Vector2(-7,0),tail+Vector2(-4,3),GOLD if effort>1 else MINT,2)
	draw_texture(fish_texture, Vector2(-12,-6),Color("b8c3c6") if effort<1 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if world.hooked==world.HookState.HOOKED and not world.landing:
		var pull: Vector2 = world.line_pull_velocity()
		if pull.length()>2:
			var direction_to_line := pull.normalized()
			var pointer := position+direction_to_line*(23+fmod(t*12,9))
			draw_line(pointer-direction_to_line*4+direction_to_line.orthogonal()*3,pointer,RED,1)
			draw_line(pointer-direction_to_line*4-direction_to_line.orthogonal()*3,pointer,RED,1)
		if not world.latched and position.y<125:
			draw_rect(Rect2(world.line_anchor(world.bound_bait).x-35,57,70,4),Color(RED,0.4+0.2*sin(t*9)))
	if world.result_flash > 0 and not (world.qte_result_kind=="wrap" and world.result_good):
		var radius: float = (0.7 - world.result_flash) * 25 + 12
		draw_arc(position, radius, 0, TAU, 16, MINT if world.result_good else RED, 1)
	if world.returning:
		draw_rect(Rect2(38, 276, 44, 2), INK)
		draw_rect(Rect2(38, 276, 44 * world.home_age / 2, 2), MINT)

func _net_draw_position() -> Vector2:
	var p: Vector2=world.net_pos
	if world.net_state=="miss":
		p-=Vector2.from_angle(world.net_angle)*sin(PI*world.net_age/world.NET_MISS)*(4 if world.net_blocked else 2)
	return p.round()

func _net_back(t: float) -> void:
	if world.net_blocks_hooks(): _draw_landing_net(_net_draw_position(),t,false)

func _net(t: float) -> void:
	if not world.net_blocks_hooks(): return
	var from: Vector2=world.net_from
	var to: Vector2=world.net_to
	var direction := Vector2.from_angle(world.net_angle)
	var alpha := 0.18+0.12*sin(t*9)
	if world.net_state in ["prepare","warning","sweep"] and not world.manual_net:
		if world.net_kind=="drop":
			draw_rect(Rect2(clampf(from.x-50,0,540),55,100,7),Color(RED,alpha+0.1))
		else:
			draw_rect(Rect2(0 if direction.x>0 else 630,55,10,258),Color(RED,alpha+0.1))
		var arrow := Vector2(from.x,73) if world.net_kind=="drop" else Vector2(16 if direction.x>0 else 624,from.y)
		draw_colored_polygon(PackedVector2Array([arrow+direction*8,arrow-direction*5+direction.orthogonal()*5,arrow-direction*5-direction.orthogonal()*5]),RED)
	if world.net_state in ["prepare","warning"]:
		if world.manual_net:
			draw_arc(from,world.NET_CATCH.y,0,TAU,40,Color(RED,0.5),1)
		else:
			var danger: PackedVector2Array=world.net_warning_outline()
			draw_colored_polygon(danger,Color(RED,0.04 if world.net_state=="prepare" else 0.10))
			for index in range(1,danger.size()):
				if index%2==0: draw_line(danger[index-1],danger[index],Color(RED,0.7),1)
			for index in range(1,5):
				var arrow := from.lerp(to,index/5.0)
				draw_line(arrow-direction*4+direction.orthogonal()*3,arrow,Color(RED,0.5),1)
				draw_line(arrow-direction*4-direction.orthogonal()*3,arrow,Color(RED,0.5),1)
		if world.net_state=="warning":
			var remaining: float=1-world.net_age/world.net_warning_seconds()
			draw_arc(from,9,-PI/2,-PI/2+TAU*remaining,24,RED,2)
	_draw_landing_net(_net_draw_position(),t,true)
	if world.net_state=="sweep":
		var velocity_scale := clampf(world.net_motion.length()/300,0,1)
		for index in range(12):
			var life := fmod(world.net_age*2.5+index/12.0,1)
			var bubble: Vector2=world.net_pos-direction*(10+life*38)+direction.orthogonal()*sin(index*2.7)*24
			draw_rect(Rect2(bubble.round(),Vector2(2,2)),Color(MINT,(1-life)*velocity_scale*0.65))
	if world.net_state=="miss" and world.net_blocked:
		var progress: float=world.net_age/world.NET_MISS
		for index in range(5):
			var normal := direction.rotated((index-2)*0.3)
			var at: Vector2=to+direction*world.NET_RIM.x+normal*(2+progress*8)
			draw_line(at,at+normal*4,Color(GOLD,1-progress),1)
	if world.net_state in ["caught","withdraw"] and world.net_pos.y<95:
		for index in range(7):
			var life := fmod(t*2.4+index/7.0,1)
			var drip: Vector2=world.net_pos+Vector2((index-3)*5,12+life*42)
			draw_line(drip.round(),(drip+Vector2(0,3+life*4)).round(),Color(MINT,0.7*(1-life)),1)
	if world.net_splash>0:
		var life: float=1-world.net_splash/0.6
		var origin: Vector2=world.net_splash_at
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
	var opening: float=lerpf(0.25,1,smoothstep(0,1,world.net_age/world.NET_PREPARE)) if world.manual_net and world.net_state=="prepare" else 1.0
	var rim: Vector2=world.NET_RIM*opening
	var angle: float=world.net_angle
	var caught: bool=world.net_state=="caught"
	var settling: float=smoothstep(0,1,world.net_age/world.NET_SETTLE) if caught else 0.0
	if not caught and world.net_state=="sweep": settling=world.net_capture*0.45
	var outline := PackedVector2Array()
	var bag := PackedVector2Array()
	var back: Vector2=p+world.net_bag_offset()*opening
	var joint := p
	for index in range(33):
		var circle := Vector2.from_angle(index*TAU/32)
		var rim_point := p+(circle*rim).rotated(angle)
		outline.append(rim_point.round())
		var bag_shape := (circle*rim*0.60).rotated(angle).lerp(circle*Vector2(18,25),settling)
		bag.append((back+bag_shape).round())
		if rim_point.y<joint.y: joint=rim_point
	if not front:
		var pole_top: Vector2=Vector2(world.angler.x+7,50) if world.manual_net else Vector2(world.net_from.x+(-18 if world.net_from.x<320 else 18),40)
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
	if world.net_state=="sweep" and world.net_capture>0:
		draw_arc(p,37,-PI/2,-PI/2+TAU*world.net_capture,40,GOLD,2)
		label_at(p+Vector2(-26,-43),"收拢 %d%%" % int(world.net_capture*100),10,GOLD)

func _hud(t: float) -> void:
	if game.menu.visible: return
	if game.player_role=="angler":
		_angler_hud(t)
		_skill_hud(t)
		return
	draw_rect(Rect2(0,0,640,35), INK)
	label_at(Vector2(12,15), "像素池塘", 12, GOLD)
	label_at(Vector2(12,28), "双人对战" if game.shared_session else ("限时挑战" if world.challenge else "练习 · F2 调节"), 10, MINT)
	var target: float = world.TARGET if world.challenge else 18
	label_at(Vector2(111,22), "食物 %02d / %d" % [int(world.score),int(target)], 15)
	label_at(Vector2(272,15), "吸力 %d%%" % int(world.power*100), 11, CREAM)
	draw_rect(Rect2(272,22,68,3), Color("335762"))
	draw_rect(Rect2(272,22,68*world.power,3), GOLD)
	label_at(Vector2(366,15), "加速" if world.sprinting else ("抗拉" if world.resisting else ("乏力" if world.stamina<20 else "体力")), 11, GOLD if world.sprinting or world.resisting else CREAM)
	draw_rect(Rect2(366,22,70,3), Color("335762"))
	draw_rect(Rect2(366,22,70*world.stamina/100,3), GOLD if world.sprinting else (RED if world.sprint_exhausted else MINT))
	var remaining := maxi(0, int(ceil(world.TIME_LIMIT-world.clock)))
	label_at(Vector2(515,23), "%02d:%02d" % [remaining/60,remaining%60] if world.challenge else "N 抄网练习", 14, RED if remaining < 60 else CREAM)
	draw_rect(Rect2(0,333,640,27), INK)
	label_at(Vector2(12,350), game.hint(), 12)
	label_at(Vector2(584,350), "H 帮助", 10, Color("9cbbb4"))
	if world.net_state in ["prepare","warning","sweep","miss","withdraw","caught"]:
		panel(Rect2(230,63,180,26))
		var phase := "横向扫网" if world.net_kind=="sweep" else "上方下探"
		if world.manual_net: phase="对方抄网"
		if world.net_state=="prepare": phase+=" · 准备"
		elif world.net_state=="warning": phase+=" · %.1f 秒" % maxf(0,world.net_warning_seconds()-world.net_age)
		elif world.net_state=="caught": phase="网袋收拢…" if world.net_age<world.NET_SETTLE else "正在提网…"
		elif world.net_state=="miss": phase="网口被挡住" if world.net_blocked else "抄网扑空"
		elif world.net_state=="withdraw": phase="抄网撤回 · 继续觅食"
		label_at(Vector2(240,81),phase,12,RED)
	if world.hooked == world.HookState.HOOKED:
		panel(Rect2(10,65,148,50))
		label_at(Vector2(18,79), "张力 %d%%" % int(world.tension*100), 11, CREAM)
		label_at(Vector2(89,79), "缠线 ×%d" % world.wraps.size() if world.latched else ("提离水面" if world.landing else "收鱼中"), 10, MINT if world.latched else RED)
		draw_rect(Rect2(18,86,132,6), Color("335762"))
		draw_rect(Rect2(18,86,132*world.tension,6), MINT.lerp(RED,world.tension))
		var spool := "放线 ↓" if world.reel_speed>0.5 else ("收线 ↑" if world.reel_speed < -0.5 else "稳线")
		label_at(Vector2(18,105),("对方正在解缠" if world.untangle_phase in ["check","unwind"] else spool+" · "+world.tug_status()),9,Color("9cbbb4"))
		if world.high_age > 0:
			draw_rect(Rect2(10,112,148*minf(1,world.high_age/world.break_hold_seconds),3), RED)
	_skill_hud(t)

func _skill_hud(t: float) -> void:
	var check: Dictionary=world.skill_check(game.player_role)
	if check.active or check.result_age>0: _qte(t,check)
	var state: Dictionary=world.effort_checks[game.player_role]
	if state.effect_age>0 and not check.active and check.result_age<=0:
		var color := MINT if state.multiplier>1 else RED
		var p := SKILL_ORIGIN
		panel(Rect2(p,Vector2(180,20)))
		label_at(p+Vector2(8,14),("加力" if state.multiplier>1 else "脱力")+" %d%% · %.1f 秒" % [roundi(state.multiplier*100),state.effect_age],11,color)

func _qte(t: float, check: Dictionary) -> void:
	var showing_result: bool = not check.active
	var kind: String = check.kind
	var zone_start: float = check.zone
	var progress: float = check.progress
	var zone_width: float = check.width
	if check.active and check.age<0.4:
		panel(Rect2(SKILL_ORIGIN,Vector2(176,34)),Color("103e57"))
		label_at(SKILL_ORIGIN+Vector2(12,22),"注意 · 即将判定",13,GOLD)
		return
	var success_zone: bool = progress>=zone_start and progress<=zone_start+zone_width
	var effect: float = 1-check.result_age/0.7
	var intro: float = clampf(check.age/0.3,0,1) if not showing_result else 1.0
	var origin: Vector2 = SKILL_ORIGIN+Vector2(0,roundf(10*pow(1-intro,3)))
	if showing_result and not check.good: origin.x += roundf(sin(effect*42)*(1-effect)*3)
	var accent := MINT if kind=="slack" else GOLD
	if showing_result: accent = MINT if check.good else RED
	panel(Rect2(origin,Vector2(176,200)),Color("103e57"))
	# Muted water ripples echo the reference without obscuring the metal and green zone.
	for wave in range(15):
		var base := origin+Vector2(8+posmod(wave*67,148),32+posmod(wave*29,133))
		var points := PackedVector2Array()
		for part in range(6): points.append((base+Vector2(part*3,sin(part*0.7+t*0.8+wave)*2)).round())
		draw_polyline(points,Color(0.12,0.47,0.64,0.25),1)
	var title := "解缠判定" if kind=="untangle" else ("收线发力" if game.player_role=="angler" else "抗拉发力") if kind=="effort" else "吐钩判定" if kind=="entry" else ("缠线判定" if kind=="wrap" else "松线脱钩")
	label_at(origin+Vector2(14,20),title,14,accent)
	# Keep the hook at native pixel size; remove only vertical card padding.
	var gauge_origin := origin+Vector2(0,-12)
	var center := gauge_origin+Gauge.CENTER
	draw_arc(center,69,0,TAU,48,Color(0.22,0.66,0.76,0.13),1)
	draw_texture(gauge_texture,gauge_origin)
	for tick in range(1,9):
		var ratio := tick/10.0
		draw_line((gauge_origin+Gauge.point(ratio,37)).round(),(gauge_origin+Gauge.point(ratio,43)).round(),Color("081724"),4)
		draw_line((gauge_origin+Gauge.point(ratio,37)).round(),(gauge_origin+Gauge.point(ratio,43)).round(),Color("b5c0c1"),2)
	var zone: PackedVector2Array = Gauge.section(zone_start,zone_start+zone_width)
	for index in zone.size(): zone[index]+=gauge_origin
	var ready: bool=kind!="untangle" or world.untangle_tension_valid()
	if not ready: success_zone=false
	var green := (Color("63ed4d") if success_zone else Color("2fbe44")) if ready else Color("799088")
	draw_polyline(zone,Color("082818"),10)
	draw_polyline(zone,Color("157432"),8)
	draw_polyline(zone,green,5)
	for ratio in [zone_start,zone_start+zone_width]:
		draw_line((gauge_origin+Gauge.point(ratio,43)).round(),(gauge_origin+Gauge.point(ratio,55)).round(),Color("081724"),4)
		draw_line((gauge_origin+Gauge.point(ratio,44)).round(),(gauge_origin+Gauge.point(ratio,54)).round(),CREAM,2)
	var marker: Vector2 = (gauge_origin+Gauge.point(progress)).round()
	if check.age>=0.4 or showing_result:
		for trail in range(1,6):
			var p: Vector2 = gauge_origin+Gauge.point(maxf(0,progress-trail*0.018))
			draw_rect(Rect2(p.round(),Vector2(2,2)),Color(CREAM,(1-trail/6.0)*0.35))
	else:
		draw_arc(center,69,-PI/2,-PI/2+TAU*check.age/0.4,40,Color(MINT,0.5),1)
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
		label_at(origin+Vector2(14,180),check.result,14,accent)
		label_at(origin+Vector2(14,195),("正在退线 · 仍需控线" if check.good else "线圈保留 · 短暂恢复") if kind=="untangle" else ("力量提升 · 持续 2 秒" if check.good else "力量减弱 · 持续 1.5 秒") if kind=="effort" else "线圈保留 · 准备松线" if check.good and kind=="wrap" else ("继续游动" if check.good else "调整后可以再试"),10,CREAM)
		if check.good:
			draw_arc(center,57+effect*13,0,TAU,48,Color(accent,(1-effect)*0.6),1)
			for spark in range(10):
				var p := center+Vector2.from_angle(spark*TAU/10)*(57+effect*15)
				draw_rect(Rect2(p.round(),Vector2(2,2)),Color(accent,1-effect))
	else:
		var instruction := "浮漂进入绿区时按空格"
		if check.age<0.4: instruction="准备…"
		elif not ready: instruction="张力过低 · 按 W" if world.tension<world.UNTANGLE_MIN else "张力过高 · 按 S"
		elif success_zone: instruction="现在按空格"
		label_at(origin+Vector2(14,180),instruction,12,green if success_zone else CREAM)
		var detail := "W/S 保持张力 25–55%" if kind=="untangle" else ("保持 W 收线 · 空格判定" if game.player_role=="angler" else "继续游动抗拉 · 空格判定") if kind=="effort" else "边游动抗拉，边保持接触" if kind=="wrap" else ("移动保持低张力" if kind=="slack" else "抓住机会吐出鱼钩")
		label_at(origin+Vector2(14,195),detail,10,Color("9cbbb4"))

func _track_point(path: PackedVector2Array, progress: float) -> Vector2:
	var index := clampf(progress,0,1)*(path.size()-1)
	var before := int(index)
	return path[before].lerp(path[mini(before+1,path.size()-1)],index-before).round()

func _network_badge() -> void:
	if not is_instance_valid(game.network) or not game.network.active() or game.menu.visible: return
	var line: String=game.network.caption()
	if line.is_empty(): return
	if game.network.status in ["starting","countdown"]:
		panel(Rect2(216,146,208,56))
		label_at(Vector2(235,180),line,21,GOLD)
	else:
		# Leave the first-person hand visible; in fish view leave the opponent's bank clear.
		var origin := Vector2(450,34) if game.player_role=="angler" else Vector2(450,304)
		panel(Rect2(origin,Vector2(180,19)))
		label_at(origin+Vector2(6,14),line,10,MINT)
