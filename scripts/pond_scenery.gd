extends RefCounted

# Native pixel scenery. Cover geometry comes exclusively from PondLayout.
const Layout = preload("res://scripts/pond_layout.gd")
const Water = preload("res://scripts/pond_water_art.gd")

static func environment_layer(view: Node2D, name: String, legacy_offset: Vector2) -> void:
	if view.generated_water_active:
		view.water_appearance.draw_slot(view, name, view.camera_offset, view.water_visual_time)
	else:
		view.draw_texture(view.water_layers[name], legacy_offset)

static func background(view: Node2D, world: Node2D, t: float) -> void:
	environment_layer(view,"water",Vector2.ZERO)
	# A quiet irregular far bank above the waterline, rather than repeated blocks.
	view.draw_rect(Rect2(0,0,Layout.SIZE.x,55),Color("a9b8a3"))
	var bank:=PackedVector2Array([Vector2(0,55)])
	for x in range(0,int(Layout.SIZE.x)+8,8):
		var height: float=9+sin(x*0.010)*4+sin(x*0.031+1.2)*2+sin(x*0.067)*0.8
		bank.append(Vector2(x,53-roundf(height)))
	bank.append(Vector2(Layout.SIZE.x,55))
	view.draw_colored_polygon(bank,Color("6c9287"))
	view.draw_rect(Rect2(0,53,Layout.SIZE.x,2),Color("6faaa0"))
	if world.uses_mobile_tackle():
		view.draw_rect(Rect2(0,56,Layout.SIZE.x,8),Color("253e42"))
		for x in range(0,int(Layout.SIZE.x),16):
			view.draw_rect(Rect2(x,57,15,5),Color("8d8665"))
			view.draw_rect(Rect2(x+1,57,13,1),Color("c9bb87"))
			view.draw_rect(Rect2(x+4,59,7,1),Color("736f57"))
	# Far silhouettes scroll slightly slower than the real interaction geometry.
	var distance_offset: Vector2=(view.camera_offset*Vector2(0.22,0.08)).round()
	environment_layer(view,"distance",distance_offset)
	environment_layer(view,"surface",(view.camera_offset*Vector2(0.13,0.03)).round())
	environment_layer(view,"floor",Vector2.ZERO)
	environment_layer(view,"terrain",(view.camera_offset*Vector2(0.06,0.02)).round())
	for index in 58:
		var base:=Water.mote(index)
		var p: Vector2=(base+world.water_offset(base)*2).round()
		var alpha: float=0.12+0.04*sin(index*2.1)
		view.draw_rect(Rect2(p,Vector2.ONE),Color(0.64,0.84,0.75,alpha))
	for index in 24:
		var base:=Water.mote(index+71)
		var p: Vector2=base+world.water_offset(base)*2
		view.draw_line(p.round(),(p-world.water_velocity(base)*2.0).round(),Color(0.68,0.91,0.85,(0.05+0.02*sin(t*1.3+index))*world.water_strength),1)

static func floor_layer(view: Node2D) -> void:
	var floor:=Layout.FLOOR
	view.draw_rect(Rect2(0,floor,Layout.SIZE.x,Layout.SIZE.y-floor),Color("365751"))
	if view.generated_water_active:
		view.water_appearance.draw_slot(view,"floor",view.camera_offset,view.water_visual_time,Rect2(0,floor,Layout.SIZE.x,Layout.SIZE.y-floor))
	else:
		view.draw_texture_rect_region(view.water_layers.floor,Rect2(0,floor,Layout.SIZE.x,Layout.SIZE.y-floor),Rect2(0,floor,Layout.SIZE.x,Layout.SIZE.y-floor))
	# Contact shadows sit under grounded solids, behind their unchanged sprites.
	for solid: Dictionary in Layout.SOLIDS:
		var bounds:=Water.Art.prop_bounds(solid)
		if bounds.end.y<430: continue
		var x: float=bounds.position.x+bounds.size.x*0.5
		var radius: float=bounds.size.x*0.42
		view.draw_colored_polygon(PackedVector2Array([Vector2(x-radius,floor+1),Vector2(x-radius*0.52,floor-2),Vector2(x+radius*0.58,floor-1),Vector2(x+radius,floor+2),Vector2(x+radius*0.48,floor+6),Vector2(x-radius*0.49,floor+5)]),Color(0.10,0.20,0.18,0.28))
	for index in 17:
		var x:=18+posmod(index*157+index*index*11,1240)
		var y:=floor+2+index%8
		view.draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+3,y-1),Vector2(x+7,y+1),Vector2(x+2,y+2)]),Color("65785c") if index%2 else Color("58674e"))

static func foreground(view: Node2D) -> void:
	environment_layer(view,"foreground",(-view.camera_offset*Vector2(0.045,0.0)).round())

static func nest(view: Node2D, world: Node2D, t: float) -> void:
	var p:=Layout.HOME
	# An irregular root arch surrounds the same destination and entrance.
	view.draw_colored_polygon(PackedVector2Array([p+Vector2(-22,25),p+Vector2(-22,8),p+Vector2(-12,-1),p+Vector2(8,-3),p+Vector2(23,8),p+Vector2(23,25)]),Color("10363c"))
	view.draw_colored_polygon(PackedVector2Array([p+Vector2(-29,24),p+Vector2(-28,3),p+Vector2(-21,-6),p+Vector2(-7,-12),p+Vector2(9,-10),p+Vector2(24,-3),p+Vector2(29,9),p+Vector2(27,25),p+Vector2(17,26),p+Vector2(20,13),p+Vector2(14,4),p+Vector2(2,1),p+Vector2(-10,4),p+Vector2(-17,12),p+Vector2(-17,25)]),Color("526b58"))
	view.draw_polyline(PackedVector2Array([p+Vector2(-25,16),p+Vector2(-24,3),p+Vector2(-14,-4),p+Vector2(1,-8),p+Vector2(17,-3),p+Vector2(24,6)]),Color("82917a"),1)
	view.draw_polyline(PackedVector2Array([p+Vector2(-26,22),p+Vector2(-22,8),p+Vector2(-16,4)]),Color("344f49"),2)
	view.draw_polyline(PackedVector2Array([p+Vector2(22,24),p+Vector2(25,12),p+Vector2(21,6)]),Color("344f49"),2)
	for moss: Array in [[-18,-5,6],[-6,-10,8],[14,-5,5],[-24,10,3]]:
		view.draw_rect(Rect2(p+Vector2(moss[0],moss[1]),Vector2(moss[2],2)),Color("86a483"))
	view.draw_colored_polygon(PackedVector2Array([p+Vector2(-24,26),p+Vector2(-17,21),p+Vector2(12,22),p+Vector2(26,27),p+Vector2(13,30),p+Vector2(-14,30)]),Color("5e7966"))
	view.label_at(p+Vector2(-14,39),"巢穴",10,Color("8de0bd"))
	if world.score>=world.food_target():
		view.draw_rect(Rect2(p+Vector2(-15,23),Vector2(29,1)),Color("8de0bd"))
		var y:=int(sin(t*4)*2)-17
		view.draw_colored_polygon(PackedVector2Array([p+Vector2(-5,y),p+Vector2(5,y),p+Vector2(0,y+5)]),Color("8de0bd"))
