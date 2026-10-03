extends SceneTree

# Rendered input-routing regression. Fixtures isolate the transitions; this is
# repeatable software evidence, not a replacement for human timing/feel review.
const Main=preload("res://scenes/main.tscn")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/player-hook-entry-native"

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2); return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PLAYER_HOOK_NATIVE_PASS | ",label)
	else: failed+=1; push_error("PLAYER_HOOK_NATIVE_FAIL | "+label)

func key(code: Key, pressed: bool, echo: bool=false) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.pressed=pressed; event.echo=echo
	Input.parse_input_event(event); Input.flush_buffered_events()

func render(name: String="") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if not name.is_empty(): check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	check(image.get_size()==Vector2i(640,360),"native 640x360 canvas "+name)
	return image

func setup() -> void:
	key(KEY_SPACE,false); key(KEY_ESCAPE,false); key(KEY_S,false); key(KEY_W,false)
	game.reset(false,"fish")
	game.reset_world({"ruleset":"survival","seed":2649,"npc_count":0,
		"rules":{"timer_enabled":false,"water_strength":0,"line_force":0,"satiety_decay":0,"instinct_max_strength":0}})
	game.set_process(false); game.set_physics_process(false); game.menu.close()
	game.fish=Vector2(332,245); game.fish_before=game.fish
	game.aim=Vector2.RIGHT; game.velocity=Vector2.ZERO
	game.angler.auto_reel=false; game.angler_source="external"
	for bait: Dictionary in game.baits:
		bait.active=false; bait.hook=false; bait.hook_id=0
		for grain: Dictionary in bait.grains: grain.eaten=true

func contact_entry() -> void:
	setup()
	var bait: Dictionary=game.baits[0]
	bait.active=true; bait.removed=false; bait.hook=true; bait.hook_id=game.next_hook_id; game.next_hook_id+=1
	bait.angle=0; bait.pos=game.mouth()+Vector2(3,0)-Vector2(2,1); bait.home=bait.pos
	bait.tip_before=game._tip(0)
	game.advance_tick({}, {})
	game.local_input.fish_command(game,game.fish+game.aim*80)
	check(game.hooked==game.HookState.MOUTH and game.qte=="entry","real mouth contact opens entry")

func tick_local(role: String="fish") -> Dictionary:
	var command: Dictionary=game.local_input.fish_command(game,game.fish+game.aim*80) if role=="fish" else game.local_input.angler_command(game,Vector2(440,120))
	game.advance_tick(command if role=="fish" else {},command if role=="angler" else {})
	return command

func release_space() -> void:
	key(KEY_SPACE,false)
	await process_frame
	# The fixture owns physics ticks. Sample the actual neutral local input just
	# as the running app does, so resume/reset gating can re-arm deliberately.
	game.local_input.fish_command(game,game.fish+game.aim*80)

func green_age() -> float:
	return float(game.qte_timing.lead)+(game.qte_zone+game.qte_width*0.5)*float(game.qte_timing.sweep)

func check_entry_repeats() -> void:
	for attempt in 6:
		contact_entry(); await process_frame
		key(KEY_SPACE,true); tick_local()
		check(game.qte=="entry" and game.hooked==game.HookState.MOUTH and game.qte_result_age==0,"entry "+str(attempt)+" ignores a warning-period Space")
		if attempt==0: await render("entry-early-space")
		await release_space()
		if game.qte=="entry":
			game.qte_age=green_age()-game.TICK_SECONDS
			if attempt==0: await render("entry-green")
			key(KEY_SPACE,true); tick_local()
			check(game.hooked==game.HookState.FREE and game.qte.is_empty() and game.qte_result_good,"entry "+str(attempt)+" accepts a fresh visible green-zone Space")
		await release_space()
	contact_entry(); await process_frame
	key(KEY_SPACE,true); tick_local()
	for frame in 32:
		await process_frame
		tick_local()
	check(game.qte=="entry" and game.hooked==game.HookState.MOUTH,"held Space across the warning-to-sweep boundary does not auto-judge")
	key(KEY_SPACE,true,true); tick_local()
	check(game.qte=="entry","keyboard repeat echo cannot judge a held warning key")
	await release_space()
	contact_entry(); await process_frame
	game.qte_age=float(game.qte_timing.lead)+0.02
	key(KEY_SPACE,true); tick_local()
	check(game.hooked==game.HookState.HOOKED and not game.qte_result_good,"visible off-zone entry Space still fails and attaches the hook")
	await render("entry-visible-failure"); await release_space()

func check_wrap_repeats() -> void:
	for attempt in 6:
		contact_entry(); game._attach_hook(); game._update_contacts(0)
		await process_frame
		key(KEY_SPACE,true); tick_local()
		check(game.qte=="wrap" and game.wraps.is_empty() and game.qte_result_age==0,"wrap "+str(attempt)+" opening key never judges itself")
		await process_frame; tick_local()
		check(game.qte=="wrap","wrap "+str(attempt)+" held opening key stays unjudged")
		await release_space(); key(KEY_SPACE,true); tick_local()
		check(game.qte=="wrap" and game.qte_result_age==0,"wrap "+str(attempt)+" ignores a second warning-period Space")
		if attempt==0: await render("wrap-early-space")
		await release_space()
		if game.qte=="wrap":
			game.qte_age=green_age()-game.TICK_SECONDS
			if attempt==0: await render("wrap-green")
			key(KEY_SPACE,true); tick_local()
			check(game.wraps.size()==1 and game.qte.is_empty() and game.qte_result_good,"wrap "+str(attempt)+" visible green-zone press creates exactly one coil")
			if attempt==0: await render("wrap-success")
		await release_space()

func check_menu_interruptions() -> void:
	for kind: String in ["pause","focus"]:
		contact_entry(); game.qte_age=float(game.qte_timing.lead)+0.02
		await process_frame
		if kind=="pause": key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
		else:
			game.capture_mode=""
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			game.capture_mode="player-hook-native"
		check(game.menu.visible and game.paused,kind+" opens the real pause menu")
		var age: float=game.qte_age
		var tick: int=game.simulation_tick
		for frame in 12:
			game._physics_process(game.TICK_SECONDS)
			await process_frame
		check(game.qte_age==age and game.simulation_tick==tick,kind+" freezes the active QTE and simulation")
		await render(kind+"-menu")
		# Space is also the pause button's UI accept key. Real dispatch, then the
		# normal app physics route must not reuse it for a hidden gameplay input.
		key(KEY_SPACE,true); key(KEY_SPACE,false)
		check(not game.menu.visible and not game.paused,kind+" Space activates the focused Continue button")
		game._physics_process(game.TICK_SECONDS)
		check(game.qte=="entry" and game.qte_result_age==0,kind+" resume Space is not also a gameplay judgment")
		await release_space()
		if game.qte=="entry":
			game.qte_age=green_age()-game.TICK_SECONDS
			key(KEY_SPACE,true); tick_local()
			check(game.qte_result_good and game.hooked==game.HookState.FREE,kind+" accepts a new deliberate press after release")
		await release_space()

func check_last_warning_tick() -> void:
	for kind: String in ["entry","wrap"]:
		contact_entry()
		if kind=="wrap": game._attach_hook(); game._update_contacts(0); game._begin_wrap()
		game.qte_age=float(game.qte_timing.lead)-game.TICK_SECONDS*0.5
		await process_frame; key(KEY_SPACE,true); tick_local()
		check(game.qte==kind and game.qte_result_age==0 and game.qte_age>=float(game.qte_timing.lead),kind+" last-warning-frame Space is not judged on the first visible tick")
		await release_space()

func check_held_interruptions() -> void:
	for kind: String in ["focus","restart"]:
		contact_entry(); await process_frame; key(KEY_SPACE,true)
		if kind=="focus":
			game.capture_mode=""; game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			game.capture_mode="player-hook-native"
			await process_frame
			# Resume by an actual click on Continue while Space stays held.
			var button: Button=game.menu.first_button
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT; event.position=root.get_final_transform()*button.get_global_rect().get_center(); event.pressed=true
			Input.parse_input_event(event); Input.flush_buffered_events()
			await process_frame
			event=event.duplicate(); event.pressed=false
			Input.parse_input_event(event); Input.flush_buffered_events()
		else:
			game.restart_round()
			game._enter_hook(0)
		game.qte_age=float(game.qte_timing.lead)+0.02
		for frame in 4:
			tick_local(); await process_frame
		check(not game.menu.visible and game.qte=="entry" and game.qte_result_age==0,kind+" held Space remains blocked across resume/reset")
		await release_space()
		if game.qte=="entry":
			game.qte_age=green_age()-game.TICK_SECONDS
			key(KEY_SPACE,true); tick_local()
			check(game.hooked==game.HookState.FREE and game.qte_result_good,kind+" re-arms only after neutral input then a fresh press")
		await release_space()

func check_effort_warning() -> void:
	for role: String in ["fish","angler"]:
		contact_entry(); game._attach_hook(); game.player_role=role
		var state: Dictionary=game.effort_checks[role]
		game.Effort.open(state,game.rng,game.effort_tuning(role))
		await process_frame; key(KEY_SPACE,true); tick_local(role)
		check(state.active and state.result_age==0,role+" effort ignores warning-period Space")
		await release_space()
		if state.active:
			state.age=float(state.lead)+0.02
			key(KEY_SPACE,true); tick_local(role)
			check(not state.active and not state.good and state.multiplier==0.6,role+" visible off-zone effort still fails with the original penalty")
		await release_space()
	contact_entry(); game._attach_hook(); game._update_contacts(0); game._begin_wrap(); game._commit_wrap()
	game.wraps[0].progress=1.0; game.untangle_cooldown=0
	game.effort_checks.angler.wait=12; game.fish_line_length=game.mouth().distance_to(game.wraps[0].entry)-(0.4-0.18)*game.rule("line_elastic")
	game.tension=0.4; game.player_role="angler"
	check(game._begin_untangle(),"untangle fixture opens real check")
	await process_frame; key(KEY_SPACE,true); tick_local("angler")
	check(game.untangle_phase=="check" and game.effort_checks.angler.active,"untangle ignores warning-period Space")
	await release_space()

func check_timeouts_and_contact_loss() -> void:
	contact_entry(); await process_frame
	var frames:=0
	var duration: float=game.qte_timing.lead+game.qte_timing.sweep
	while game.qte=="entry" and frames<240:
		tick_local(); frames+=1; await process_frame
	var observed: float=frames*game.TICK_SECONDS
	check(game.hooked==game.HookState.HOOKED and observed>=duration and observed<=duration+game.TICK_SECONDS*1.01,"untouched entry expires only after its full warning+sweep duration")
	print("PLAYER_HOOK_NATIVE_TIMING | entry_timeout_seconds=",observed," | configured_seconds=",duration," | frames=",frames)
	for visible: bool in [false,true]:
		contact_entry(); game._attach_hook(); game._update_contacts(0); game._begin_wrap()
		if visible: game.qte_age=float(game.qte_timing.lead)+0.02
		game.fish=Vector2(460,210); game.fish_before=game.fish
		var total: int=game.round_stats.fish_total
		tick_local()
		check(game.qte.is_empty() and game.wraps.is_empty() and game.qte_result=="离开障碍 · 缠线中断","contact loss names the interruption during "+("sweep" if visible else "warning"))
		check(game.round_stats.fish_total==total+(1 if visible else 0),"contact loss counts a skill failure only after the visible sweep")
		await render("wrap-contact-loss-"+("sweep" if visible else "warning"))
	contact_entry(); game.qte_age=0.2
	game.restart_round()
	check(game.hooked==game.HookState.FREE and game.qte.is_empty() and not game.paused and not game.match_over,"restart clears the pending hook and QTE")
	await render("restart-clear")

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="player-hook-native"; game.save_path="user://player-hook-native.cfg"
	await check_entry_repeats()
	await check_wrap_repeats()
	await check_menu_interruptions()
	await check_last_warning_tick()
	await check_held_interruptions()
	await check_effort_warning()
	await check_timeouts_and_contact_loss()
	print("PLAYER_HOOK_NATIVE | passed=",passed," | failed=",failed)
	game.queue_free(); await process_frame; quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty(): push_error("CAPTURE_OUTPUT_FAIL | output path must not be empty"); return false
	var error:=DirAccess.make_dir_recursive_absolute(output)
	if error != OK: push_error("CAPTURE_OUTPUT_FAIL | cannot create "+output+": "+error_string(error)); return false
	return true
