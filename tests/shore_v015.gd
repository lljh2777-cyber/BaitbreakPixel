extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Shore=preload("res://scripts/shore_view.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("SHORE_PASS | ",message)
	else: failed+=1; push_error("SHORE_FAIL | "+message)
func run() -> void:
	var world=World.new(); world.reset_world({"ruleset":"duel","challenge":true,"water_strength":0})
	for point in [Vector2(0,55),Vector2(30,80),Vector2(610,294),Vector2(320,205)]:
		check(Shore.to_world(Shore.to_screen(point,world),world).distance_to(point)<0.001,"projection reverses correctly at "+str(point))
	check(Shore.to_screen(Vector2(30,80)).y>213 and Shore.to_screen(Vector2(610,294)).y<310,"the entire interactive water fits below the horizontal float lane")
	world.baits[0].active=true; world.baits[0].pos=Vector2(232,180)
	var before: Vector2=Shore.rod_tip(world,0); var y: float=Shore.float_position(world,0).y
	var horizontal_before: float=world.angler.x
	for frame in 60: world.advance_tick({}, {"walk":1})
	var after: Vector2=Shore.rod_tip(world,0)
	check(after.x>before.x and world.angler.x>horizontal_before+60 and world.angler.anchor().y==48,"D visibly turns the rod right while world movement retains its speed and horizontal lane")
	check(is_equal_approx(Shore.float_position(world,0).y,y),"float stays on its fixed horizontal water lane")
	var anchor: Vector2=world.angler.anchor()
	for frame in 60: world.advance_tick({}, {"target":Vector2(300,280),"reel":true})
	check(world.angler.anchor()==anchor and world.angler.free_line_length<132,"W reels underwater line without adding a vertical rod axis")
	for frame in 60: world.advance_tick({}, {"target":Vector2(300,80),"release":true})
	check(world.angler.anchor()==anchor and world.angler.free_line_length>132,"S and vertical mouse motion do not move the rod into another lane")
	for frame in 600: world.advance_tick({}, {"walk":-1})
	check(world.angler.x==18 and Shore.rod_tip(world,0).x>=80,"left limit keeps rod and float in the lake view")
	for frame in 600: world.advance_tick({}, {"walk":1})
	check(world.angler.x==588 and Shore.rod_tip(world,0).x<=614,"right limit keeps rod and float in the lake view")
	var route:=PackedVector2Array([Vector2(400,110),Vector2(520,110),Vector2(520,200),Vector2(400,200)])
	var projected: PackedVector2Array=Shore.projected(route,world)
	for index in route.size(): check(Shore.to_world(projected[index],world).distance_to(route[index])<0.001,"net corner "+str(index)+" is preserved by the first-person transform")
	var copy=World.new(); check(copy.restore_snapshot(world.capture_snapshot()) and Shore.float_position(copy,0)==Shore.float_position(world,0),"network snapshot produces the same float and projection")
	world.fish=Vector2(320,30); world.landing=true
	check(Shore.float_position(world,0).distance_to(Shore.to_screen(world.mouth(),world)+Vector2(0,-3))<0.01,"landing raises tackle with the fish instead of leaving its endpoint in the water")
	copy.free(); world.free()
	print("SHORE_V015_TESTS | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
