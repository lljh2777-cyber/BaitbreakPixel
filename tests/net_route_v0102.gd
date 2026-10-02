extends SceneTree

const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0

# Historical multi-corner drag-net behavior was replaced by the committed
# two-point net action. Keep the original assertions, but never call its removed
# manual_net_pending_path() API: that aborts run() without reaching quit().
func _initialize() -> void:
	print("RETIRED_SUITE | net_route_v0102 | replacements=res://tests/net_v021.gd,res://tests/net_animation_v0201.gd")
	quit(2)
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("ROUTE_PASS | ",message)
	else: failed+=1; push_error("ROUTE_FAIL | "+message)

func fresh() -> void:
	game.reset(true,"angler")
	game.water_strength=0
	game.fish=Vector2(70,95)
	game.fish_before=game.fish
	game.set_process(false)
	game.set_physics_process(false)

func draw_route(points: PackedVector2Array) -> void:
	for point in points:
		game.angler.update(game,0,{"target":point,"net_hold":true,"drag":true})

func arm() -> void:
	for frame in 180:
		if game.net_state=="sweep": return
		game._step_net(1.0/120)

func advance(seconds: float, rate: int=60) -> void:
	for frame in roundi(seconds*rate): game._step_net(1.0/rate)

func distance_from_path(point: Vector2, path: PackedVector2Array) -> float:
	var distance:=INF
	for index in range(1,path.size()):
		distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,path[index-1],path[index])))
	return distance

func run() -> void:
	game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="route-test"
	game.save_path="user://net-route-v0102.cfg"
	var route:=PackedVector2Array([Vector2(400,110),Vector2(510,110),Vector2(510,210)])
	fresh(); draw_route(route)
	check(game.net_route==route and game.net_pos==route[0],"all turns drawn during entry are retained in order")
	check(game.manual_net_pending_path()==route,"preview is the queued polyline, not a line to the latest mouse position")
	arm(); advance(1)
	check(game.net_pos.distance_to(Vector2(510,160))<0.02,"L-shaped stroke reaches its corner before travelling down the next leg")
	var on_path:=true
	for point in game.net_trail:
		if distance_from_path(point,route)>0.01: on_path=false
	check(on_path,"every actual L-stroke position stays on the drawn route")
	advance(0.5)
	check(game.net_pos.distance_to(route[-1])<0.01,"stroke finishes at the drawn endpoint")
	game.cancel_manual_net()
	var return_path: PackedVector2Array=game.net_return_path.duplicate()
	check(return_path.has(route[1]),"cancel return retains the exact right-angle corner")
	var return_on_path:=true
	for frame in 180:
		game._step_net(1.0/120)
		if distance_from_path(game.net_pos,return_path)>0.01: return_on_path=false
	check(return_on_path and game.net_state=="rest","withdraw follows the travelled route without cutting a corner")
	check(game.net_route.is_empty(),"recovery clears pending route data")
	var loop:=PackedVector2Array([Vector2(400,100),Vector2(520,100),Vector2(520,200),Vector2(400,200),Vector2(400,100)])
	fresh(); draw_route(loop); arm(); advance(2.75)
	var visited:=true
	for corner in loop:
		if not game.net_trail.has(corner): visited=false
	check(visited and game.net_pos.distance_to(loop[0])<0.02,"a closed loop visits every corner before returning to its start")
	fresh(); draw_route(PackedVector2Array([Vector2(400,110),Vector2(520,110),Vector2(400,110)])); arm(); advance(1.5)
	check(game.net_trail.has(Vector2(520,110)) and game.net_pos==Vector2(400,110),"a fast out-and-back stroke does not collapse into a stationary net")
	fresh(); draw_route(PackedVector2Array([route[0]])); arm()
	game.record_manual_net_point(route[1]); game.record_manual_net_point(route[2])
	advance(1)
	check(game.net_pos.distance_to(Vector2(510,160))<0.02,"new turns added during the sweep also execute in order")
	fresh(); draw_route(PackedVector2Array([Vector2(400,110)]))
	for index in range(1,641): game.record_manual_net_point(Vector2(400+index*0.25,110))
	arm(); advance(1)
	check(game.net_pos.distance_to(Vector2(560,110))<0.02,"dense mouse samples retain the 160-pixel-per-second net speed")
	var samples: Array[Vector2]=[]
	for rate in [30,60,120]:
		fresh(); draw_route(route); arm(); advance(1,rate); samples.append(game.net_pos)
	check(samples[0].distance_to(samples[2])<0.02 and samples[1].distance_to(samples[2])<0.02,"turn execution agrees at 30, 60 and 120 Hz")
	fresh(); draw_route(route)
	game.fish=Vector2(455,160); game.fish_before=game.fish
	arm(); advance(1.5)
	check(game.net_catches==0,"fish on the shortcut diagonal is not captured by an L-shaped stroke")
	fresh(); draw_route(route)
	# A tired fish on the first leg can be held long enough before the turn.
	game.fish=route[1]-Vector2(35,0); game.fish_before=game.fish; game.stamina=10
	arm(); advance(0.65)
	check(game.net_state=="caught" and absf(game.net_return_from.y-110)<0.01,"fish on the first leg is captured there, before any later turn")
	var around:=PackedVector2Array([Vector2(275,180),Vector2(275,120),Vector2(415,120),Vector2(415,220)])
	fresh(); draw_route(around); arm(); advance(1.875)
	check(not game.net_blocked and game.net_pos.distance_to(around[-1])<0.02,"route drawn around the root goes around it instead of cutting through")
	fresh(); draw_route(PackedVector2Array([around[0],around[-1],Vector2(415,120)])); arm(); advance(0.3)
	check(game.net_blocked and game.net_state in ["miss","withdraw"] and game.net_route_next==1,"drawing through wood stops the net and never skips to a later clear waypoint")
	fresh(); draw_route(route); game.cancel_manual_net(); game.record_manual_net_point(Vector2(580,100))
	check(game.net_route==route and game.net_state=="withdraw","cancel immediately stops accepting more stroke points")
	game.reset(true,"angler")
	check(game.net_route.is_empty() and game.net_route_next==1,"restart clears every old route and its playback cursor")
	game.reset(true,"fish")
	check(Input.use_accumulated_input,"fish mode restores normal input batching")
	print("NET_ROUTE_V0102_TESTS | passed=",passed," | failed=",failed)
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
