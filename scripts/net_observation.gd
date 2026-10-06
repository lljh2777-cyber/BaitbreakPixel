extends RefCounted

# View-only underwater observation. Never exposes the fish HUD or writes simulation state.
const Camera = preload("res://scripts/pond_camera.gd")
const Net = preload("res://scripts/net_simulation.gd")
const Presentation = preload("res://scripts/maps/map_presentation.gd")
const INK := Color("142e39")
const MINT := Color("8de0bd")
const RED := Color("f58375")

static func interactive(view: Node2D, world: Node2D, point: Vector2) -> bool:
	if not Rect2(0,55,640,258).has_point(point): return false
	if Rect2(10,65,151,50).has_point(point) or Rect2(445,65,182,39).has_point(point): return false
	var check: Dictionary=world.skill_check("angler")
	if (check.active or check.result_age>0) and Rect2(view.SKILL_ORIGIN,Vector2(176,200)).has_point(point): return false
	return true

static func draw(view: Node2D, world: Node2D, t: float) -> void:
	var map := Presentation.for_context(world.map_context)
	var offset:=Camera.offset(world,"angler")
	view.draw_set_transform(Vector2.ZERO)
	view.draw_rect(Rect2(0,0,640,360),INK)
	view.draw_set_transform(-offset)
	if view.woodland.active:
		view.woodland.draw_background(view)
		# Assemble the complete plate before applying the observation veil. Tinting
		# individual image crops would reveal their polygon edges in open water.
		for prop in view.props: view.draw_texture(prop.texture,prop.position)
		for frames in view.plant_frames:
			var sprite: Dictionary=frames[0]
			view.draw_texture(sprite.texture,sprite.position)
		view.draw_texture(view.bed_texture,Vector2.ZERO)
		view.woodland.draw_foreground(view)
	else:
		var bands:=maxi(2,ceili((map.floor_y-map.surface_y)/29.0))
		for band in bands:
			view.draw_rect(Rect2(0,map.surface_y+band*29,map.size.x,29),Color("285e68").lerp(Color("153d4e"),band/float(bands-1)))
		view.draw_rect(Rect2(0,map.surface_y-2,map.size.x,2),Color("64958f"))
	# A sparse, native-pixel veil preserves edges without a blur filter.
	for tile_y in range(int(map.water.position.y-4),int(map.floor_y),16):
		for tile_x in range(0,int(map.size.x),16):
			var p := Vector2(tile_x+8,tile_y+8)
			if not Net.reachable(world,p): view.draw_rect(Rect2(tile_x,tile_y,16,16),Color(0.02,0.08,0.13,0.32))
	for index in 28:
		var p: Vector2=Vector2(posmod(index*79,int(map.size.x)),map.water.position.y+2+posmod(index*41,maxi(1,int(map.water.size.y-8))))+world.water_offset(Vector2(index*17,map.water.position.y+112))
		view.draw_line(p.round(),(p+Vector2(5+index%4,0)).round(),Color(0.47,0.71,0.68,0.15),1)
	for prop in view.props:
		if not view.woodland.active: view.draw_texture(prop.texture,prop.position,Color(0.58,0.72,0.69,0.9))
	for plant_index in map.plants.size():
		var plant: Dictionary=map.plants[plant_index]
		if view.woodland.active: continue
		for stem in range(3):
			var origin := Vector2(plant.x,plant.y)
			if plant.has("root_y"):
				origin.x+=(stem-1)*plant.width*0.5
				origin.y=world.map_context.floor_at(origin.x)
			var top := origin+Vector2((stem-1)*plant.width*0.2+sin(t+plant.x)*2,-plant.height*(0.7+stem*0.12))
			view.draw_line(origin.round(),top.round(),Color("386d68"),2)
			for leaf in range(1,4):
				var p := origin.lerp(top,leaf/4.0).round()
				view.draw_line(p,p+Vector2(7 if (leaf+stem)%2 else -7,-6),Color("3c746d"),1)
	if not view.woodland.active:
		if view.bed_texture!=null: view.draw_texture(view.bed_texture,Vector2.ZERO,Color("b3cac0"))
		else: view.draw_rect(Rect2(0,map.floor_y,map.size.x,30),Color("405b59"))
	view.shore.draw_observed_npcs(view,world)
	# Silhouettes are approximate in position and contain no face, stamina or food detail.
	var visibility := Net.visibility(world,world.fish)
	if visibility>0.02:
		var p: Vector2=world.fish.snapped(Vector2(3,3))
		var facing: float=-1 if world.aim.x<0 else 1
		var color := Color(0.06,0.18,0.23,visibility*0.7)
		view.draw_colored_polygon(PackedVector2Array([p+Vector2(-10*facing,-2),p+Vector2(-5*facing,-5),p+Vector2(6*facing,-4),p+Vector2(11*facing,0),p+Vector2(5*facing,4),p+Vector2(-5*facing,5)]),color)
		view.draw_colored_polygon(PackedVector2Array([p+Vector2(-8*facing,0),p+Vector2(-15*facing,-5),p+Vector2(-15*facing,5)]),color)
	for bait in world.baits:
		if bait.active and not bait.removed:
			view.draw_rect(Rect2(Vector2(bait.pos).snapped(Vector2(2,2))-Vector2(2,2),Vector2(4,4)),Color("668579"))
	if world.hooked!=world.HookState.FREE or world.line_hooked():
		var path: PackedVector2Array=world.rope_path
		if path.size()>1: view.draw_polyline(path,Color(0.52,0.67,0.61,0.25),1)
	# Reach boundary is independent of hidden fish information.
	var boundary := PackedVector2Array()
	for index in 97:
		var p: Vector2=world.angler.anchor()+Vector2.from_angle(index*PI/96)*world.rule("net_reach")
		if p.y>=map.surface_y and p.y<=map.floor_y and p.x>=0 and p.x<=map.size.x: boundary.append(p.round())
		elif boundary.size()>1:
			view.draw_polyline(boundary,Color(MINT,0.25),1); boundary.clear()
	if boundary.size()>1: view.draw_polyline(boundary,Color(MINT,0.25),1)
	var screen_cursor: Vector2=view.get_global_mouse_position()
	var cursor:=Camera.to_world(screen_cursor,world,"angler")
	if interactive(view,world,screen_cursor):
		if world.net_action.has_a:
			var plan := Net.preview(world,cursor)
			var tint := MINT if plan.valid else RED
			var a: Vector2=plan.a
			var b: Vector2=plan.b
			if plan.valid:
				var side: Vector2=(b-a).normalized().orthogonal()*world.net_rim().y
				view.draw_colored_polygon(PackedVector2Array([a+side,b+side,b-side,a-side]),Color(tint,0.08))
				view.draw_line(a.round(),b.round(),tint,1)
				var dir := (b-a).normalized()
				for ratio in [0.33,0.66]:
					var p := a.lerp(b,ratio)
					view.draw_polyline(PackedVector2Array([(p-dir*5+dir.orthogonal()*3).round(),p.round(),(p-dir*5-dir.orthogonal()*3).round()]),tint,1)
				if plan.blocked:
					view.draw_line(b.round(),plan.requested.round(),Color(RED,0.5),1)
					view.label_at(b+Vector2(8,-8),"木石阻挡",10,RED)
			marker(view,a,"A",MINT)
			marker(view,b if plan.valid else cursor,"B",tint)
		else:
			var valid := Net.reachable(world,cursor) and not Net.manual_net_blocked(world,cursor)
			view.draw_arc(cursor.round(),world.net_rim().y+2,0,TAU,24,MINT if valid else RED,1)
			marker(view,cursor,"A",MINT if valid else RED)
	view.draw_set_transform(Vector2.ZERO)
	view.panel(Rect2(445,65,182,39))
	var remaining: float=maxf(0,world.rule("net_observe_time")-world.net_action.age)
	view.label_at(Vector2(455,82),"水下观察  %.1f 秒" % remaining,12,MINT)
	view.draw_rect(Rect2(455,92,162,3),Color("335762"))
	view.draw_rect(Rect2(455,92,162*remaining/world.rule("net_observe_time"),3),MINT)

static func marker(view: Node2D, point: Vector2, caption: String, color: Color) -> void:
	view.draw_rect(Rect2(point.round()-Vector2(3,3),Vector2(6,6)),INK)
	view.draw_rect(Rect2(point.round()-Vector2(2,2),Vector2(4,4)),color)
	view.label_at(point.round()+Vector2(7,-5),caption,11,color)
