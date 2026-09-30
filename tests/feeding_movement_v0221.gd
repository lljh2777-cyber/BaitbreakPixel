extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("FEEDING_MOVE_PASS | ",title)
	else: failed+=1; push_error("FEEDING_MOVE_FAIL | "+title)
func fresh(ruleset: String="survival", multiplier: float=0.68) -> Node2D:
	var w:=World.new()
	w.reset_world({"ruleset":ruleset,"seed":42,"rules":{"water_strength":0,"timer_enabled":false,"feeding_speed":multiplier,"sprint_drain":0,"stamina_recovery":0,"line_force":0,"slack_hold":5}})
	w.fish=Vector2(700,210); w.fish_before=w.fish; w.aim=Vector2.RIGHT; w.hook_cooldown=1000
	for bait in w.baits:
		bait.active=false
		for grain in bait.grains: grain.eaten=true
	return w
func command(mode: String, suck: bool, power: float=0.35) -> Dictionary:
	return {"move":Vector2.RIGHT,"aim":Vector2.RIGHT,"suck":suck,"power":power,"slow":mode=="slow","dash":mode=="sprint"}
func step(w: Node2D, input: Dictionary, count: int=30) -> void:
	for tick in count: w.advance_tick(input,{})
func run() -> void:
	for ruleset in ["survival","duel"]:
		for mode in ["normal","slow","sprint"]:
			var plain:=fresh(ruleset); var feeding:=fresh(ruleset)
			step(plain,command(mode,false)); step(feeding,command(mode,true))
			var label: String=ruleset+" / "+mode
			check(feeding.feeding and absf(feeding.velocity.length()/plain.velocity.length()-0.68)<0.0001,label+": suction lowers actual swim velocity to 68 percent")
			check(feeding.fish.x>700 and feeding.fish.x<plain.fish.x-2,label+": feeding actually travels less distance while retaining movement")
			step(feeding,command(mode,false))
			check(not feeding.feeding and feeding.velocity.distance_to(plain.velocity)<0.001,label+": release restores the current movement mode")
			plain.free(); feeding.free()
	for power in [0.1,1.0]:
		var w:=fresh(); step(w,command("normal",true,power))
		check(absf(w.velocity.length()-47.6)<0.001,"both gentle and strong suction slow swimming, power=%.1f" % power)
		w.free()
	for multiplier in [0.4,1.0]:
		var w:=fresh("survival",multiplier); step(w,command("normal",true))
		check(absf(w.velocity.length()-70*multiplier)<0.001,"saved room/profile multiplier remains effective: %.2f" % multiplier)
		w.free()
	for stamina in [100.0,0.0]:
		var w:=fresh(); w._enter_hook(0); w._attach_hook(); w.stamina=stamina
		step(w,command("normal",true))
		check(w.hooked==World.HookState.HOOKED and absf(w.velocity.length()-70*0.68*w.fatigue_factor())<0.001,"hooked feeding applies slowdown once, preserving fatigue, stamina=%.0f" % stamina)
		w.free()
	var w:=fresh(); step(w,{"suck":true})
	check(w.feeding and w.velocity==Vector2.ZERO and w.fish==Vector2(700,210),"suction without movement never makes the fish drift")
	step(w,command("normal",true)); var captured: Dictionary=w.capture_snapshot(); var replay:=World.new()
	check(replay.restore_snapshot(captured),"snapshot preserves active feeding and slowed velocity")
	for tick in 30:
		var input:=command("sprint",tick<15)
		w.advance_tick(input,{}); replay.advance_tick(input,{})
	check(var_to_bytes(w.capture_snapshot())==var_to_bytes(replay.capture_snapshot()),"host and restored world reproduce suction-to-release movement identically")
	w.match_paused=true; captured=w.capture_snapshot(); w.advance_tick(command("normal",false),{})
	check(w.capture_snapshot()==captured,"pause freezes feeding movement and ignores release until resumed")
	w.free(); replay.free()
	print("FEEDING_MOVEMENT_V0221 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
