extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
var world: Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("BALANCE_PASS | ",message)
	else: failed+=1; push_error("BALANCE_FAIL | "+message)
func fresh(challenge: bool=false) -> void:
	world.reset_world({"ruleset":"duel","challenge":challenge,"water_strength":0,"seed":1401})
	world.fish=Vector2(460,200); world.aim=Vector2.RIGHT
func attach() -> void:
	world.baits[0].active=true; world._enter_hook(0); world._attach_hook()
func tick(seconds: float, fish: Dictionary={}, human: Dictionary={}) -> void:
	for index in roundi(seconds*60): world.advance_tick(fish,human)
func net_ready(stamina: float=100, y: float=160) -> void:
	fresh(); world.fish=Vector2(460,y); world.fish_before=world.fish; world.stamina=stamina
	world.begin_manual_net(world.fish); world.net_state="sweep"; world.net_age=0
func capture_time(rate: int, stamina: float, hooked: bool=false) -> float:
	net_ready(stamina,105 if hooked else 160)
	if hooked: attach()
	var time:=0.0
	while world.net_state!="caught" and time<1.0:
		world.fish_before=world.fish; world._step_net(1.0/rate); time+=1.0/rate
	return time
func run() -> void:
	world=World.new()
	fresh(); world.set_practice_effort_tuning(2,0.4,1.7,0.4); attach()
	world.effort_checks.angler.wait=1.0
	tick(0.55,{}, {"reel":true})
	check(world.effort_checks.angler.active,"2x frequency triggers within half the qualifying wait")
	var state: Dictionary=world.effort_checks.angler
	check(is_equal_approx(state.width,0.2),"practice success window reaches the actual random ring")
	world.set_practice_effort_tuning(0.5,0.12,1.1,0.9)
	check(state.width==0.2 and state.boost==1.7,"changing settings does not alter an already announced check")
	state.age=0.4+(state.zone+state.width*0.5)*2-1.0/60
	world.advance_tick({}, {"qte":true})
	check(state.multiplier==1.7 and world.round_stats.angler_good==1 and world.round_stats.angler_total==1,"successful effort uses captured strength and is counted once")
	world.advance_tick({}, {"qte":true})
	check(world.round_stats.angler_total==1,"repeated Space cannot duplicate a resolved result")
	fresh(); attach(); world.set_practice_effort_tuning(0.5,0.12,1.1,0.9); world.effort_checks.angler.wait=1.0
	tick(0.6,{}, {"reel":true})
	check(not world.effort_checks.angler.active and world.effort_checks.angler.wait>0.69,"lower frequency counts active exertion more slowly")
	tick(0.3,{}, {"release":true})
	check(is_equal_approx(world.effort_checks.angler.wait,0.7),"paying out neither rerolls nor consumes the effort wait")
	fresh(true); world.set_practice_effort_tuning(2,0.5,1.8,0.3)
	check(world.effort_tuning().frequency==2 and world.effort_tuning().window==0.5 and world.effort_tuning().boost==1.8,"challenge now honors the same configured strength and difficulty")
	fresh(); world.set_practice_effort_tuning(NAN,INF,-100,100)
	check(world.practice_effort_frequency==1 and world.practice_effort_window==0.2 and world.practice_effort_boost==1.05 and world.practice_effort_weak==1.0,"invalid tuning is safely defaulted or clamped")
	fresh(); world._enter_hook(0); world._step_qte(0.1,true)
	check(world.round_stats.fish_total==1 and world.round_stats.fish_good==0 and world.hooked==world.HookState.HOOKED,"failed entry records one fish check and attaches the hook")
	world._open_qte("slack"); world.qte_age=0.4+(world.qte_zone+world.qte_width*0.5)*2
	world._step_qte(0,true)
	check(world.round_stats.fish_total==2 and world.round_stats.fish_good==1 and world.round_stats.slips==1,"successful slack escape records success and the escape cause")
	attach(); world._open_qte("slack"); world._release_hook(true)
	check(world.round_stats.breaks==1 and world.round_stats.fish_total==2,"line break during a check is an escape, not a free QTE success")
	attach(); world._open_qte("wrap"); world._fail_wrap()
	check(world.round_stats.fish_total==3 and world.round_stats.fish_good==1,"losing wrap contact counts a failed committed check")
	world.rope_length=world.line_anchor(0).distance_to(world.mouth())-18
	world._step_line(0.25,false); world._step_line(0.25,false)
	check(is_equal_approx(world.round_stats.danger_seconds,0.5),"dangerous tension accumulates across updates")
	var before: Dictionary=world.round_stats.duplicate(true)
	world.match_paused=true; tick(1)
	check(world.round_stats==before,"pause does not accumulate round statistics")
	world.match_paused=false
	var copy=World.new(); var snapshot: Dictionary=world.capture_snapshot()
	check(copy.restore_snapshot(snapshot) and copy.round_stats==world.round_stats,"round statistics survive authority snapshot restore")
	snapshot.state.round_stats.fish_good=99
	check(not copy.restore_snapshot(snapshot) and copy.round_stats==before,"invalid statistics are rejected atomically")
	copy.free(); fresh()
	check(world.round_stats==world.Stats.fresh() and world.Stats.rate(world.round_stats,"fish").contains("未判定"),"rematch clears stats and zero checks are shown without a false 0 percent")
	var times: Array[float]=[]
	for rate in [30,60,120]: times.append(capture_time(rate,100))
	check(times.max()-times.min()<0.035 and times.min()>=0.59,"fresh fish need about 0.6 seconds of contact at 30/60/120 Hz")
	var tired := capture_time(120,10)
	var hauled := capture_time(120,10,true)
	check(tired<times[2]-0.2 and hauled<tired-0.07,"exhaustion and hauling toward the surface each shorten net closure")
	net_ready(); world._step_net(0.12)
	check(world.net_state=="sweep" and world.net_capture>0,"first contact starts closing without freezing the fish")
	world.fish+=Vector2(85,0); world.fish_before=world.fish; world._step_net(0.3)
	check(world.net_state=="sweep" and world.net_capture==0,"swimming out before closure removes the capture progress")
	net_ready(); world._step_net(0.1); world.cancel_manual_net()
	check(world.net_state=="withdraw" and world.net_capture==0,"releasing the net cancels partial capture immediately")
	net_ready(); world.fish=Vector2(385,160); world.fish_before=world.fish
	world.fish=Vector2(535,160); world._step_net(1.0/60)
	check(world.net_state=="sweep" and world.net_capture<0.05,"fast crossing counts actual overlap, not a full-frame instant catch")
	net_ready(); world._step_net(0.1); snapshot=world.capture_snapshot(); copy=World.new()
	check(copy.restore_snapshot(snapshot) and copy.net_capture==world.net_capture,"net closure progress synchronizes to the remote player")
	copy.free()
	# Fixed scenarios reveal tradeoffs, without relying on random AI victories.
	fresh(true); world.fish=Vector2(240,205); attach(); world.effort_checks.angler.wait=12; world.effort_checks.fish.wait=12
	tick(3.5,{"move":Vector2.DOWN,"dash":true},{"reel":true})
	check(world.round_stats.breaks>0,"holding W into sustained fish sprint can break the line")
	fresh(true); world.fish=Vector2(240,205); attach(); world.effort_checks.angler.wait=12; world.effort_checks.fish.wait=12
	tick(1.5,{"move":Vector2.DOWN,"dash":true},{"reel":true}); tick(1.0,{"move":Vector2.DOWN,"dash":true},{"release":true})
	check(world.hooked==world.HookState.HOOKED and world.tension<0.9 and world.round_stats.breaks==0,"timely S pays out and avoids the same dangerous tug")
	fresh(); world.fish=Vector2(420,160); tick(3.6,{"move":Vector2.RIGHT,"dash":true})
	check(world.stamina<2 and world.sprint_exhausted,"holding sprint consumes stamina and eventually exhausts the fish")
	tick(1.8,{"move":Vector2.LEFT})
	check(world.stamina>20 and not world.sprint_exhausted,"releasing sprint creates a usable recovery window")
	print("BALANCE_V014_TESTS | passed=",passed," | failed=",failed," | net_fresh=",times," | net_tired=",tired," | net_hauled=",hauled)
	world.free(); quit(1 if failed else 0)
