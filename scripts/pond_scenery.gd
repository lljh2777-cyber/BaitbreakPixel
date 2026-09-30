extends RefCounted

# Native pixel scenery. Cover geometry comes exclusively from PondLayout.
const Layout = preload("res://scripts/pond_layout.gd")

static func background(view: Node2D, world: Node2D, t: float) -> void:
	view.draw_rect(Rect2(Vector2.ZERO,Layout.SIZE),Color("163f4d"))
	view.draw_rect(Rect2(0,35,Layout.SIZE.x,19),Color("c2c5a4"))
	for i in range(39):
		var x := i*35
		var h := 8+i*7%16
		view.draw_rect(Rect2(x,53-h,24,h),Color("668e83"))
		view.draw_rect(Rect2(x+5,48-h,13,5),Color("668e83"))
	view.draw_rect(Rect2(0,53,Layout.SIZE.x,2),Color("8de0bd"))
	for band in range(14):
		view.draw_rect(Rect2(0,55+band*28,Layout.SIZE.x,28),Color("317e82").lerp(Color("123e50"),band/13.0))
	if world.uses_mobile_tackle():
		view.draw_rect(Rect2(0,56,Layout.SIZE.x,8),Color("253e42"))
		for x in range(0,int(Layout.SIZE.x),16):
			view.draw_rect(Rect2(x,57,15,5),Color("8d8665"))
			view.draw_rect(Rect2(x+1,57,13,1),Color("c9bb87"))
			view.draw_rect(Rect2(x+4,59,7,1),Color("736f57"))
	for shaft in 9:
		for step in 9:
			view.draw_rect(Rect2(shaft*149+step*7+21,55+step*43,16+step*3,43),Color(0.63,0.89,0.74,0.023))
	for i in 75:
		var base := Vector2(4+posmod(i*61,1272),65+posmod(i*47,354))
		var p: Vector2 = (base+world.water_offset(base)*2).round()
		view.draw_rect(Rect2(p,Vector2(1+i%2,1)),Color(0.65,0.86,0.75,0.28))
	for i in 32:
		var base := Vector2(30+posmod(i*97,1220),77+posmod(i*53,330))
		var p: Vector2 = base+world.water_offset(base)*2
		view.draw_line(p.round(),(p-world.water_velocity(base)*2.4).round(),Color(0.68,0.91,0.85,(0.08+0.04*sin(t*1.3+i))*world.water_strength),1)
	# Distant low-contrast rocks and reeds add depth without creating hidden targets.
	for i in 25:
		var x := i*53-16
		var h := 12+i*17%38
		view.draw_colored_polygon(PackedVector2Array([Vector2(x,435),Vector2(x+8,431-h),Vector2(x+28,425-h),Vector2(x+52,435-h/2),Vector2(x+64,440)]),Color("20515c"))
		for stem in 3:
			var p := Vector2(x+stem*8,432)
			view.draw_polyline(PackedVector2Array([p,p+Vector2(3,-h),p+Vector2(-2,-h*1.7)]),Color("285f64"),2)

static func floor_layer(view: Node2D) -> void:
	view.draw_rect(Rect2(0,Layout.FLOOR,Layout.SIZE.x,Layout.SIZE.y-Layout.FLOOR),Color("516f69"))
	for x in range(0,int(Layout.SIZE.x),4):
		var h := 2+int(2+sin(x*0.018)*2)
		view.draw_rect(Rect2(x,Layout.FLOOR-1,4,h),Color("8b9c78"))
	for i in 145:
		var x := posmod(i*73,1278)
		var y := int(Layout.FLOOR)+6+i*19%39
		view.draw_rect(Rect2(x,y,3+i%3,2),Color("3f615f") if i%2 else Color("7e9273"))
	for i in 89:
		var x := posmod(i*83+11,1276)
		var y := int(Layout.FLOOR)+i*7%13
		var w := 2+i%5
		view.draw_rect(Rect2(x,y,w,2),Color("3e615f"))
		view.draw_rect(Rect2(x+1,y-1,w-1,1),Color("aab695") if i%3 else Color("719180"))

static func nest(view: Node2D, world: Node2D, t: float) -> void:
	var p := Layout.HOME
	# A small root hollow, with moss marking its only gameplay destination.
	view.draw_rect(Rect2(p+Vector2(-24,-4),Vector2(48,27)),Color("123b42"))
	view.draw_rect(Rect2(p+Vector2(-28,-4),Vector2(5,28)),Color("698571"))
	view.draw_rect(Rect2(p+Vector2(23,-4),Vector2(5,28)),Color("698571"))
	view.draw_rect(Rect2(p+Vector2(-28,22),Vector2(56,5)),Color("86b49a"))
	view.draw_rect(Rect2(p+Vector2(-20,20),Vector2(40,2)),Color("8de0bd"))
	view.label_at(p+Vector2(-14,39),"巢穴",10,Color("8de0bd"))
	if world.score>=world.food_target():
		var y := int(sin(t*4)*2)-17
		view.draw_colored_polygon(PackedVector2Array([p+Vector2(-5,y),p+Vector2(5,y),p+Vector2(0,y+5)]),Color("8de0bd"))
