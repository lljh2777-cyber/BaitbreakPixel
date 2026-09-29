extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const View=preload("res://scripts/pond_view.gd")
var game: Node2D
var passed:=0
var failed:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("REEL_PASS | ",description)
	else: failed+=1; push_error("REEL_FAIL | "+description)
func fresh() -> void:
	game.reset_world({"ruleset":"duel","challenge":true,"water_strength":0,"seed":2719})
	game.fish=Vector2(240,205); game.aim=Vector2.RIGHT
	game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
func tick(seconds: float, rod: Dictionary, fish: Dictionary={}, rate: int=60) -> void:
	for frame in roundi(seconds*rate): game.simulate(1.0/rate,fish,rod)
func stretch() -> float: return game.line_anchor(0).distance_to(game.mouth())-game.rope_length

func run() -> void:
	game=World.new()
	var fighter: Dictionary={"move":Vector2.DOWN,"dash":true}
	fresh()
	var before: Vector2=game.fish
	tick(2,{"reel":true},fighter)
	check(game.hooked==game.HookState.HOOKED and game.fish.y<before.y-40,"holding W pulls even a sprinting fish toward the bank")
	check(stretch()<17 and game.tension>=0.9,"sprinting cannot create invisible stretch beyond the red gauge")
	before=game.fish
	tick(1,{"release":true},fighter)
	check(game.hooked==game.HookState.HOOKED and game.tension<0.89 and game.high_age==0,"S clears dangerous tension within one second after two seconds of resisted reeling")
	check(game.fish.y>before.y+25,"paying out gives a resisting fish physical swimming room")
	tick(0.6,{},fighter)
	check(game.angler.spool==0 and is_zero_approx(game.reel_speed),"releasing W/S stops the manual spool after deceleration")
	fresh(); tick(3.5,{"reel":true},fighter)
	check(game.hooked==game.HookState.FREE and game.baits[0].removed,"ignoring sustained red tension still breaks the line")
	fresh(); before=game.fish
	tick(2,{"reel":true})
	check(game.fish.y<before.y-50,"W reels a passive fish up as before")
	tick(1,{"release":true})
	check(game.tension<0.25 and game.rope_length>game.line_anchor(0).distance_to(game.mouth())+20,"S creates real slack without pushing a passive fish away")
	var view=View.new()
	var start: Vector2=game.line_anchor(0)
	var end: Vector2=game.mouth()
	var curve: PackedVector2Array=view._slack_line(start,end,game.rope_length)
	check(curve[0].distance_to(start)<1 and curve[-1].distance_to(end)<1,"visible slack keeps the rod and hook endpoints attached")
	check(curve[12].distance_to(start.lerp(end,0.5))>10,"excess paid-out line creates a clearly visible curve")
	var tight: PackedVector2Array=view._slack_line(start,end,start.distance_to(end)-10)
	check(tight[12].distance_to(start.lerp(end,0.5))<1,"reeling the excess line removes the slack curve")
	view.free()
	fresh(); game.break_hold_seconds=10; game.slack_hold_seconds=3
	tick(1,{"release":true}); var slack: float=game.tension
	tick(3.5,{"reel":true})
	check(game.hooked==game.HookState.HOOKED and game.tension>slack+0.4,"W takes up previously paid-out slack and restores pull")
	fresh()
	game.wraps.append({"entry":Vector2(240,180),"center":Vector2(240,180),"loop":PackedVector2Array([Vector2(240,180),Vector2(241,180),Vector2(240,180)]),"progress":1.0,"target":0})
	game.fish_line_length=25
	tick(0.7,{},fighter)
	check(game.mouth().distance_to(game.wraps[-1].entry)-game.fish_line_length<27,"wrapped fish-side line also has bounded extension")
	var samples: Array[Vector2]=[]
	for rate in [30,60,120]:
		fresh(); tick(2,{"reel":true},fighter,rate); tick(1,{"release":true},fighter,rate)
		samples.append(game.fish)
		print("REEL_RATE | ",rate," | fish=",game.fish," | tension=",game.tension)
		check(game.hooked==game.HookState.HOOKED and game.tension<0.9,"release relieves tension at %d Hz" % rate)
	check(samples[0].distance_to(samples[2])<3 and samples[1].distance_to(samples[2])<3,"tether and spool response remain stable across tick rates")
	fresh(); game.challenge=false; game.set_practice_line_tuning(1,0)
	before=game.fish; tick(1,{},fighter)
	check(game.fish.y>before.y+50,"zero-force practice still disables physical tether limits")
	fresh(); tick(12,{"release":true})
	check(game.rope_length<=game.MAX_LINE_LENGTH,"holding S cannot accumulate unlimited line")
	fresh(); tick(8,{"reel":true})
	check(game.match_over and game.reason=="landed" and game.winner_role=="angler","manual W still completes the lift and capture of a passive fish")
	print("REELING_V0122_TESTS | passed=",passed," | failed=",failed)
	game.free(); quit(1 if failed else 0)
