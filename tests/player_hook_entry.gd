extends SceneTree

# Preparation is not a visible timing target. These regressions retain the real
# sweep/green-zone/timeout and ongoing physical contact/net/round requirements.
const World=preload("res://scripts/world_simulation.gd")
const DT=1.0/60.0
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PLAYER_HOOK_PASS | ",label)
	else: failed+=1; push_error("PLAYER_HOOK_FAIL | "+label)

func fresh(extra: Dictionary={}) -> Node2D:
	var values: Dictionary={"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0,"line_force":0.0}
	values.merge(extra,true)
	var world:=World.new()
	world.reset_world({"seed":64317,"ruleset":"survival","challenge":true,"npc_count":0,"npc_foraging_enabled":false,"rules":values})
	world.angler.auto_net=false
	world.fish=Vector2(100,380); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	for bait: Dictionary in world.baits: bait.active=false
	return world

func attach(world: Node2D) -> void:
	world.baits[0].home.x=100.0
	world._enter_hook(0); world._attach_hook()

func advance(world: Node2D, count: int, fish: Dictionary={}, angler: Dictionary={}) -> void:
	for tick in count: world.advance_tick(fish,angler)

func entry_checks() -> void:
	var contact:=fresh()
	contact.fish=Vector2(250,200); contact.fish_before=contact.fish
	var bait: Dictionary=contact.baits[0]
	bait.active=true; bait.hook=true; bait.angle=0.0
	bait.pos=contact.mouth()+contact.aim*3-Vector2(2,1); bait.home=bait.pos; bait.tip_before=bait.pos+Vector2(2,1)
	contact.advance_tick({"qte":true},{})
	check(contact.hooked==contact.HookState.MOUTH and contact.qte=="entry" and contact.qte_age==0 and contact.round_stats.fish_total==0,"physical mouth contact opens a fresh entry without reusing the same tick's Space")
	contact.advance_tick({},{})
	check(contact.qte=="entry" and is_equal_approx(contact.qte_age,DT),"neutral next tick cannot replay the physical-entry edge")
	contact.free()
	var world:=fresh()
	world.qte_age=9.0; world.qte_result_age=0.7
	world._enter_hook(0)
	check(world.qte_age==0 and world.qte_result_age==0,"new entry resets old check age and old feedback")
	advance(world,12,{"qte":true})
	check(world.qte=="entry" and world.round_stats.fish_total==0 and world.qte_age>0.19,"repeated preparation presses cannot judge an invisible entry target")
	world.qte_age=world.qte_timing.lead-DT*0.5; world.advance_tick({"qte":true},{})
	check(world.qte=="entry" and world.round_stats.fish_total==0,"last rendered warning-frame press cannot cross the lead boundary into a miss")
	advance(world,15)
	check(world.qte=="entry" and world.round_stats.fish_total==0,"ignored preparation presses are not buffered at the sweep start")
	world.qte_age=world.qte_timing.lead+world.qte_timing.sweep*(world.qte_zone+world.qte_width*0.5)-DT
	world.advance_tick({"qte":true},{})
	check(world.hooked==world.HookState.FREE and world.round_stats.fish_good==1 and world.round_stats.fish_total==1,"fresh press in the unchanged entry green zone ejects exactly once")
	world.free()
	world=fresh(); world._enter_hook(0); world.qte_age=world.qte_timing.lead+0.01
	world.advance_tick({"qte":true},{})
	check(world.hooked==world.HookState.HOOKED and world.qte_result=="判定失败" and world.round_stats.fish_total==1 and not world.match_over,"visible early miss still attaches hook without ending the round")
	world.free()
	world=fresh(); world._enter_hook(0); advance(world,143)
	check(world.qte=="entry" and world.round_stats.fish_total==0,"entry does not time out before its full configured sweep")
	advance(world,2)
	check(world.hooked==world.HookState.HOOKED and world.round_stats.fish_total==1 and not world.match_over,"unanswered entry still expires at the original timeout")
	world.free()
	world=fresh(); world._enter_hook(0); world.qte_age=world.qte_timing.lead+0.1
	world.advance_tick({"qte":true,"qte_at_age":0.02},{})
	check(world.qte=="entry" and world.round_stats.fish_total==0,"authority-verified preparation age is ignored even after live time enters sweep")
	world.free()
	world=fresh({"qte_entry_lead":0.0}); world._enter_hook(0); world.advance_tick({"qte":true},{})
	check(world.hooked==world.HookState.HOOKED and world.round_stats.fish_total==1,"zero-lead custom rules retain immediate visible judgment")
	world.free()

func wrap_checks() -> void:
	var world:=fresh({"line_force":1.0})
	world.fish=Vector2(100,346.1); attach(world); world._update_contacts(0)
	check(world.contact_target==18 and world.touching_target(18),"boundary fixture begins inside the ordinary 12-pixel plant contact")
	world.advance_tick({"qte":true},{})
	check(world.fish.y<346 and world.qte.is_empty() and world.round_stats.fish_total==0 and world.qte_result_age==0,"normal line pull out of contact cannot open and fail wrapping in the same tick")
	world.free()
	world=fresh(); attach(world); world.advance_tick({"qte":true},{})
	check(world.qte=="wrap" and world.qte_age>0 and world.round_stats.fish_total==0,"one opening press starts wrap without judging it")
	advance(world,10,{"qte":true})
	check(world.qte=="wrap" and world.round_stats.fish_total==0,"repeat preparation presses do not fail wrapping")
	world.qte_age=world.qte_timing.lead+world.qte_timing.sweep*(world.qte_zone+world.qte_width*0.5)-DT
	world.advance_tick({"qte":true},{})
	check(world.wraps.size()==1 and world.round_stats.wrap_good==1 and world.round_stats.fish_total==1,"fresh green-zone press still earns one physical coil")
	world.free()
	for visible: bool in [false,true]:
		world=fresh(); attach(world); world.advance_tick({"qte":true},{})
		world.qte_age=world.qte_timing.lead+0.05 if visible else 0.05
		world.fish=Vector2(210,240); world.advance_tick({},{})
		check(world.qte.is_empty() and world.wraps.is_empty() and world.wrap_retry>0 and world.qte_result=="离开障碍 · 缠线中断","contact loss explains interruption and retains cooldown: visible="+str(visible))
		check(world.round_stats.fish_total==(1 if visible else 0) and not world.match_over,"only contact loss during a visible sweep counts as a failed check: visible="+str(visible))
		world.free()

func slack_checks() -> void:
	for visible: bool in [false,true]:
		var world:=fresh(); attach(world); world._open_qte("slack")
		world.qte_age=world.qte_timing.lead+0.05 if visible else 0.05
		world.advance_tick({},{})
		check(world.qte.is_empty() and world.qte_result=="张力回升" and world.retry_age>0,"slack interruption remains tension-dependent: visible="+str(visible))
		check(world.round_stats.fish_total==(1 if visible else 0),"hidden-lead tension rebound is unjudged; visible rebound is a miss: visible="+str(visible))
		world.free()

func effort_checks() -> void:
	for role: String in ["fish","angler"]:
		var world:=fresh(); attach(world)
		var state: Dictionary=world.effort_checks[role]
		world.Effort.open(state,world.rng,world.effort_tuning(role))
		var press: Dictionary={"qte":true}
		advance(world,12,press if role=="fish" else {},press if role=="angler" else {})
		check(state.active and world.round_stats[role+"_total"]==0 and world.qte.is_empty(),role+" effort owns preparation Space without failure or accidental wrap")
		state.age=state.lead-DT*0.5
		world.advance_tick(press if role=="fish" else {},press if role=="angler" else {})
		check(state.active and world.round_stats[role+"_total"]==0,role+" effort ignores the final pre-lead frame edge")
		state.age=state.lead+0.1
		var old_press: Dictionary={"qte":true,"qte_at_age":0.01}
		world.advance_tick(old_press if role=="fish" else {},old_press if role=="angler" else {})
		check(state.active and world.round_stats[role+"_total"]==0,role+" effort uses authority press age for preparation guard")
		state.age=state.lead+state.sweep*(state.zone+state.width*0.5)-DT
		world.advance_tick(press if role=="fish" else {},press if role=="angler" else {})
		check(not state.active and state.good and state.multiplier>1 and world.round_stats[role+"_total"]==1,role+" effort fresh green press still grants the configured boost")
		world.free()

func untangle_checks() -> void:
	var world:=fresh(); attach(world); world._update_contacts(0); world._begin_wrap(); world._commit_wrap()
	world.wraps[0].progress=1.0; world.untangle_cooldown=0.0
	world.fish+=Vector2(48,0)
	world.fish_line_length=world.mouth().distance_to(world.wraps[0].entry)-(0.4-0.18)*world.rule("line_elastic")
	world.tension=0.4
	check(world._begin_untangle(),"real completed coil opens an angler untangle check")
	advance(world,12,{}, {"qte":true})
	check(world.untangle_phase=="check" and world.round_stats.angler_total==0,"untangle preparation presses do not trigger recovery/failure")
	var state: Dictionary=world.effort_checks.angler
	state.age=state.lead-DT*0.5; world.advance_tick({}, {"qte":true})
	check(world.untangle_phase=="check" and world.round_stats.angler_total==0,"untangle ignores the final pre-lead frame edge")
	state.age=state.lead+0.1; world.advance_tick({}, {"qte":true,"qte_at_age":0.01})
	check(world.untangle_phase=="check" and world.round_stats.angler_total==0,"untangle guard respects verified historical preparation age")
	state.age=state.lead+state.sweep*(state.zone+state.width*0.5)-DT
	world.advance_tick({}, {"qte":true})
	check(world.untangle_phase=="unwind" and state.good and world.round_stats.angler_total==1,"fresh visible green press with valid tension still starts unwinding")
	world.free()

func interruption_checks() -> void:
	var world:=fresh(); world._enter_hook(0); world.rules.timer_enabled=true
	world.clock=world.rule("time_limit")-DT*0.5; world.started=true; world.advance_tick({},{})
	check(world.match_over and world.reason=="timeout" and world.round_stats.fish_total==0,"round timeout during preparation remains a round result, not a QTE miss")
	world.free()
	world=fresh(); world.fish=Vector2(200,200); world._enter_hook(0)
	world.net_state="sweep"; world.net_pos=Vector2(235,200); world.net_to=Vector2(280,200); world.net_from=Vector2(160,200)
	world.net_angle=0; world.net_action.admitted=true; world.net_trail=PackedVector2Array([world.net_pos]); world.advance_tick({},{})
	check(world.net_state=="caught" and world.qte.is_empty() and world.round_stats.fish_total==0,"committed net capture interrupts preparation without inventing a QTE miss")
	advance(world,180)
	check(world.match_over and world.reason=="net","net interruption retains its own eventual loss reason")
	world.free()

	world=fresh(); world.fish=Vector2(100,85); attach(world); advance(world,38)
	check(not world.landing and not world.match_over,"normal bank proximity cannot cause an immediate landing loss")
	advance(world,3)
	check(world.landing and not world.match_over,"landing still requires the configured bank hold before its lift")
	advance(world,64)
	check(world.match_over and world.reason=="landed" and world.round_stats.fish_total==0,"bank lift retains a distinct eventual loss reason without judging a QTE")
	world.free()

func replay_checks() -> void:
	var world:=fresh(); attach(world); world.advance_tick({"qte":true},{})
	var replay:=World.new(); replay.reset_world()
	check(replay.restore_snapshot(world.capture_snapshot()),"snapshot restores a preparation-phase wrap")
	for tick in 40:
		var command: Dictionary={"qte":tick in [1,4,8,12,16]}
		world.advance_tick(command,{}); replay.advance_tick(command,{})
	check(world.capture_snapshot()==replay.capture_snapshot(),"preparation filtering and later misses replay deterministically")
	world.free(); replay.free()

func _initialize() -> void:
	entry_checks(); wrap_checks(); slack_checks(); effort_checks(); untangle_checks(); interruption_checks(); replay_checks()
	print("PLAYER_HOOK_ENTRY | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
