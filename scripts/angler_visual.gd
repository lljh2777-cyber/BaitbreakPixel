extends RefCounted

# Cosmetic state lives in the view; the rig remains the source of the line anchor.
const Art = preload("res://scripts/pixel_art.gd")
const OUTLINE := Color("192d36")
const SKIN := Color("efc39a")
const LIGHT := Color("ffe2b0")
var last_x := INF
var last_time := -1.0
var stride := 0.0
var walking := 0.0
var head: Texture2D
var coat: Texture2D

func _init() -> void:
	head = Art.sprite([
		"......oooooo......",
		".....ohhhhhho.....",
		"....ohllhhhhho....",
		"....ohhhhhhssso...",
		"..oossssssssssooo.",
		".ohllhhhhhhhhhhhso",
		"..ooooooossooooo..",
		"....owwwkkssko....",
		"....owwksllsleko..",
		".....owksllssso...",
		"......oosssssko...",
		".......okkkko....."],
		{"o":"192d36","h":"d8b878","l":"ffe2b0","s":"b78752",
		 "w":"615447","k":"c78e68","e":"132b35"})
	coat = Art.sprite([
		"....oooccco....",
		"...ouuoccuuo...",
		"..oulluccuupo..",
		".obulluocuuupo.",
		".obulggoclguuo.",
		".obblddocdduuo.",
		"..obuddocddso..",
		"...ouuuocuuuo..",
		"...osssosssso..",
		"....oooooooo..."],
		{"o":"192d36","u":"68816c","l":"a5b589","p":"d5cc9c",
		 "c":"e6c98e","b":"875c40","g":"edda9e","d":"405d55","s":"344f51"})

func _limb(view: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	for index in points.size(): points[index] = points[index].round()
	view.draw_polyline(points, OUTLINE, width+2)
	view.draw_polyline(points, color, width)

func _rod_point(a: Vector2, b: Vector2, c: Vector2, d: Vector2, weight: float) -> Vector2:
	return a.bezier_interpolate(b,c,d,weight)

func draw(view: Node2D, world: Node2D, t: float) -> void:
	var x: float = world.angler.x
	if last_time < 0 or t < last_time or absf(x-last_x)>80:
		walking=0; stride=0
	elif t > last_time:
		var distance := x-last_x
		walking=move_toward(walking,clampf(absf(distance)/maxf(t-last_time,0.001)/60.0,0,1),(t-last_time)*10)
		stride+=distance*0.30
	last_x=x; last_time=t
	var load: float = world.tension if world.line_hooked() else 0.0
	var strength: float=world.effort_multiplier("angler")
	var effort := strength-1.0
	var cast: float = sin(clampf(world.angler.cast_age/world.angler.CAST_SECONDS,0,1)*PI) if world.angler.casting else 0.0
	var bob := roundf(absf(sin(stride))*walking)
	var p := Vector2(roundf(x-7-load*(2+effort*7)),50-bob+roundf(maxf(0,-effort)*3))
	var swing := sin(stride)*3*walking
	# Boots stay on the boardwalk, with alternating heel lifts while walking.
	view.draw_rect(Rect2(Vector2(roundf(x-15),61),Vector2(22,2)),Color(0.03,0.10,0.12,0.40))
	for side in [-1,1]:
		var hip := p+Vector2(side*3,5)
		var foot := Vector2(roundf(x-7+side*4+swing*side),60-maxf(0,swing*side)*0.5).round()
		_limb(view,PackedVector2Array([hip,hip.lerp(foot,0.6)+Vector2(-1,0),foot]),Color("3b5659") if side<0 else Color("56716a"),3)
		view.draw_rect(Rect2(foot+Vector2(-2,-1),Vector2(7,3)),OUTLINE)
		view.draw_rect(Rect2(foot+Vector2(-1,-1),Vector2(5,1)),Color("987a51"))
	# Backpack, vest pockets, scarf, hat band, hair and nose are authored pixels.
	view.draw_texture(coat,(p+Vector2(-8,-4)).round())
	view.draw_texture(head,(p+Vector2(-9,-14)+Vector2(-roundf(load),0)).round())
	var grip := Vector2(roundf(x+1-load*2),50+roundf(cast*2)-bob)
	var butt := grip+Vector2(-7,5)
	var tip: Vector2 = world.angler.anchor()
	var breathe := sin(t*1.8)*0.6*(1-load)
	var first := grip+Vector2(9,-4-load*(12+effort*10)-cast*6+breathe)
	var second := tip+Vector2(-8+world.angler.line_sway*0.025,-2-load*(8+effort*6)-cast*3+sin(t*28)*load*absf(effort))
	var rod := PackedVector2Array()
	for index in 29: rod.append(_rod_point(grip,first,second,tip,index/28.0).round())
	# Dark silhouette, graphite blank, gold ferrules and actual eye at the tip.
	view.draw_polyline(rod,OUTLINE,3)
	view.draw_polyline(rod,Color("f3d48b") if strength>1 else Color("78969b") if strength<1 else Color("afc4b0"),1)
	_limb(view,PackedVector2Array([butt,grip]),Color("b98249"),3)
	view.draw_line(butt+Vector2(0,-1),grip+Vector2(0,-1),Color("e4bc78"),1)
	for ratio in [0.18,0.46,0.72]:
		var ferrule := _rod_point(grip,first,second,tip,ratio).round()
		view.draw_rect(Rect2(ferrule,Vector2(2,2)),Color("e6c98e"))
		view.draw_rect(Rect2(ferrule+Vector2(1,2),Vector2(2,2)),OUTLINE)
		view.draw_rect(Rect2(ferrule+Vector2(1,2),Vector2.ONE),Color("b8d2ca"))
	view.draw_rect(Rect2(tip-Vector2.ONE,Vector2(3,3)),OUTLINE)
	view.draw_rect(Rect2(tip,Vector2.ONE),Color("fff0cd"))
	# Cork grip is held by the forward hand; the lower hand turns the reel.
	var shoulder := p+Vector2(3,-2)
	var elbow := p+Vector2(5,3+roundf(load))
	_limb(view,PackedVector2Array([shoulder,elbow]),Color("9cad82"),3)
	_limb(view,PackedVector2Array([elbow,grip]),SKIN,2)
	view.draw_rect(Rect2(grip-Vector2.ONE,Vector2(3,2)),LIGHT)
	var reel := grip+Vector2(-3,7)
	view.draw_line(grip+Vector2(-3,2),reel,OUTLINE,2)
	view.draw_rect(Rect2(reel-Vector2(3,2),Vector2(6,5)),OUTLINE)
	view.draw_rect(Rect2(reel-Vector2(2,1),Vector2(4,3)),Color("6e9696"))
	view.draw_rect(Rect2(reel-Vector2(2,1),Vector2(4,1)),Color("d9e2c2"))
	var reel_speed: float = world.reel_speed if world.line_hooked() else world.angler.free_reel_speed
	var turning := absf(reel_speed)>0.5 or absf(world.angler.spool)>0.1
	var crank := reel+Vector2(3,1)+Vector2(cos(t*12),sin(t*12)*2).round() if turning else reel+Vector2(4,2)
	view.draw_line(reel,crank,Color("e1c58b"),1)
	if world.angler.net_held:
		_limb(view,PackedVector2Array([p+Vector2(-2,0),p+Vector2(1,3),Vector2(x+7,50)]),SKIN,2)
	else:
		_limb(view,PackedVector2Array([p+Vector2(-2,1),p+Vector2(0,6),crank]),Color("c99877"),2)
	view.draw_rect(Rect2(crank,Vector2(2,2)),LIGHT if turning else Color("d5ad77"))
