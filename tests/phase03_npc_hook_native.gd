extends SceneTree

# Real renderer coverage for the one-rig NPC target. This is intentionally a
# standalone script, so exported packs can use the same external test entry.
const Main=preload("res://scenes/main.tscn")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")
const LineMotion=preload("res://scripts/line_motion.gd")
const Shore=preload("res://scripts/shore_view.gd")
const Camera=preload("res://scripts/pond_camera.gd")
var game: Node2D
var passed:=0
var failed:=0
var output:="res://artifacts/phase03-npc-hook-native"

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("NPC_HOOK_NATIVE_PASS | ",title)
	else: failed+=1; push_error("NPC_HOOK_NATIVE_FAIL | "+title)

func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(name: String="") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not name.is_empty() and picture.save_png(output.path_join(name+".png"))!=OK:
		failed+=1; push_error("CAPTURE_OUTPUT_FAIL | cannot save "+name)
	return picture

func setup_fixture() -> void:
	game.reset(false,"fish"); game.menu.close()
	game.reset_world({"ruleset":"survival","seed":8231,"npc_count":1,"npc_hook_enabled":true,
		"rules":{"water_strength":0,"timer_enabled":false,"satiety_decay":0,"instinct_max_strength":0}})
	freeze(game)
	game.fish=Vector2(700,210); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.velocity=Vector2.ZERO
	game.elapsed=2.0; game.feeding=false; game.notice_age=0; game.hook_cooldown=0
	game.satiety=50; game.instinct_drive=0; game.caution_state="CALM"; game.angler.x=550
	for bait: Dictionary in game.baits:
		bait.active=false; bait.hook=false; bait.hook_id=0
		for grain: Dictionary in bait.grains: grain.eaten=true
	var npc: Dictionary=game.npc_fishes[0]
	npc.position=Vector2(620,160); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0

func contact_fixture() -> bool:
	setup_fixture()
	var npc: Dictionary=game.npc_fishes[0]
	var bait: Dictionary=game.baits[1]
	bait.active=true; bait.removed=false; bait.hook=true; bait.hook_id=game.next_hook_id; game.next_hook_id+=1
	bait.angle=0; bait.pos=Feeding.mouth(npc.position,npc.aim)+Vector2(npc.aim)*3-Vector2(2,1)
	bait.home=bait.pos; bait.tip_before=game._tip(1)
	# Advance the ordinary authority path, not a render-only fake attachment.
	game.advance_tick({}, {})
	check(game.hook_target_fish_id==npc.fish_id and game.npc_hook.phase=="hooked","real mouth contact selects an NPC in the native scene")
	return game.hook_target_fish_id==npc.fish_id

func same_player_hud(a: Image, b: Image) -> bool:
	return a.get_region(Rect2i(0,0,640,55)).get_data()==b.get_region(Rect2i(0,0,640,55)).get_data() and a.get_region(Rect2i(0,313,640,47)).get_data()==b.get_region(Rect2i(0,313,640,47)).get_data()

func toggle_private_truth() -> void:
	# These canaries are never advanced or accepted as authoritative snapshots.
	for bait: Dictionary in game.baits:
		if int(bait.id)==game.bound_bait: continue
		bait.hook=not bait.hook; bait.hook_id=9000+int(bait.bait_id) if bait.hook else 0
	for npc: Dictionary in game.npc_fishes:
		npc.brain_seed=911; npc.brain_rng_state=12345; npc.target_bait_id=987
		npc.focus_bait_id=987; npc.satiety=1.0; npc.risk_tolerance=0.59
		npc.suspicion_by_bait={987:0.99}; npc.caution_by_bait={987:"ALARMED"}
		npc.caution_state="ALARMED"; npc.feeding=true; npc.power=0.95; npc.bite_cooldown=0.79
		# Public animation is contact-derived, never a leaked private behavior label.
		npc.behavior_state="FLEE"; npc.behavior_age=100.0
	for key: String in ["age","low_age","high_age","landing_age","struggle_phase"]: game.npc_hook[key]=99.0

func check_pixels(phase: String) -> void:
	for role: String in ["fish","angler","observation"]:
		game.player_role="fish" if role=="fish" else "angler"
		game.net_action.observing=role=="observation"
		var before: Dictionary=game.capture_snapshot()
		var original:=await render(phase+"-"+role)
		check(original.get_size()==Vector2i(640,360),phase+" "+role+" retains native pixel canvas")
		check(original.get_data()==(await render()).get_data() and before==game.capture_snapshot(),phase+" "+role+" rendering is deterministic and authority-neutral")
		var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
		var hook: Dictionary=game.npc_hook.duplicate(true)
		var baits: Array[Dictionary]=game.baits.duplicate(true)
		toggle_private_truth()
		check(original.get_data()==(await render(phase+"-"+role+"-hidden")).get_data(),phase+" "+role+" ignores uncontacted hook truth, NPC AI and private struggle timers")
		game.npc_fishes=NPCPublic.capture(authority,game.hook_target_fish_id,hook)
		game.npc_hook={"phase":hook.phase}; game.baits=baits
		check(original.get_data()==(await render(phase+"-"+role+"-public")).get_data(),phase+" "+role+" public-only NPC geometry and phase produce identical pixels")
		game.npc_fishes=authority; game.npc_hook=hook
		check(game.capture_snapshot()==before,phase+" "+role+" private/public controls restore exact authority")
	game.player_role="fish"; game.net_action.observing=false

func check_attachment() -> void:
	if not contact_fixture(): return
	var npc: Dictionary=game.npc_fishes[0]
	var player_position: Vector2=game.fish
	var frame:=LineMotion.new().sample(game)
	check(game.hooked==game.HookState.FREE and not game.landing and not frame.fish.active,"NPC hook leaves the protagonist free and creates no player winding or landing pose")
	check(frame.path.size()>1 and frame.path[0]==game.line_anchor(game.bound_bait) and frame.path[-1]==Feeding.mouth(npc.position,npc.aim),"native line uses the bound rod anchor and exact NPC mouth")
	check(frame.path[-1]!=game.mouth() and frame.grass.is_empty() and frame.effects.is_empty(),"NPC line does not target the player's mouth or inherit player wrap effects")
	var first_mouth: Vector2=frame.path[-1]
	npc.position+=Vector2(12,8); npc.aim=Vector2(-1,0)
	var moved:=LineMotion.new().sample(game)
	check(moved.path[-1]==Feeding.mouth(npc.position,npc.aim) and moved.path[-1]!=first_mouth and game.fish==player_position,"line follows moving and turning NPC without displacing player authority")
	npc.position-=Vector2(12,8); npc.aim=Vector2.RIGHT; game._rebuild_rope()
	await check_pixels("hooked")
	var hooked:=await render()
	var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
	for fish: Dictionary in game.npc_fishes: fish.active=false
	var no_npc:=await render()
	check(same_player_hud(hooked,no_npc),"a hooked NPC adds no NPC names, status bars or fish-player HUD")
	game.npc_fishes=authority
	# Compare all opaque protagonist body pixels with and without a coincident
	# NPC; the player remains in front despite a visible global line target.
	var center: Vector2=game.npc_fishes[0].position
	game.npc_fishes[0].position=game.fish
	await render("hooked-player-in-front")
	var stacked:=await render()
	game.npc_fishes[0].active=false
	var solo:=await render()
	var texture: Image=game.view.fish_texture.get_image()
	var origin:=Vector2i(Camera.to_screen(game.fish,game,"fish"))-Vector2i(12,6)
	var unchanged:=true
	for y in texture.get_height():
		for x in texture.get_width():
			if texture.get_pixel(x,y).a>=0.99 and stacked.get_pixelv(origin+Vector2i(x,y))!=solo.get_pixelv(origin+Vector2i(x,y)): unchanged=false
	check(unchanged,"all opaque protagonist pixels remain in front of hooked NPC")
	game.npc_fishes[0].active=true; game.npc_fishes[0].position=center

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="phase03_npc_hook"
	await check_attachment()
	await check_outcomes()
	print("NPC_HOOK_NATIVE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func check_outcomes() -> void:
	if not contact_fixture(): return
	var npc: Dictionary=game.npc_fishes[0]
	var identity: int=npc.fish_id
	var anchor: Vector2=game.line_anchor(game.bound_bait)
	# Isolate the already-hooked landing boundary, then let authority lift it.
	npc.position=Vector2(anchor.x,82); npc.velocity=Vector2.ZERO; npc.aim=Vector2.UP
	game.angler.auto_reel=false; game.angler.spool=0
	game.rope_length=anchor.distance_to(game.hook_target_mouth())
	game.npc_hook.landing_age=game.rule("landing_hold")
	game.NPCHook.step(game,1.0/60.0)
	check(game.npc_hook.phase=="landing" and game.line_landing() and not game.landing,"NPC crosses the real landing gate without landing the protagonist")
	game.fish.y=170; game.fish_before=game.fish
	var player_position: Vector2=game.fish
	game.NPCHook.step(game,game.rule("landing_lift")*0.65)
	check(npc.position.y<82 and game.fish==player_position,"physical lift moves the NPC alone")
	var frame:=LineMotion.new().sample(game)
	check(frame.path.size()>1 and frame.path[-1]==game.hook_target_mouth(),"landing line stays attached to the lifted NPC mouth")
	check(Shore.float_position(game,game.elapsed)==Shore.to_screen(game.hook_target_mouth(),game)+Vector2(0,-3),"shore float follows lifted target rather than player")
	await check_pixels("landing")
	game.NPCHook.step(game,game.rule("landing_lift"))
	check(not game.npc_by_id(identity).active and game.hook_target_fish_id==-1 and game.public_npc_hook_result.result=="captured","completed native lift removes the captured NPC and records capture")
	check(not game.match_over and game.winner_role=="" and game.fish==player_position and game.hooked==game.HookState.FREE,"wrong catch leaves the main match and player running")
	check(LineMotion.new().sample(game).path.is_empty(),"capture leaves no orphan NPC line")
	for role: String in ["fish","angler"]:
		game.player_role=role
		var captured:=await render("captured-"+role)
		var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
		game.npc_fishes.clear()
		check(captured.get_data()==(await render()).get_data(),"captured "+role+" has no lingering NPC sprite, shadow or overlay")
		game.npc_fishes=authority
	game.NPCHook.respawn(game,game.NPCFishState.RESPAWN_SECONDS)
	check(game.npc_fishes.size()==1 and game.npc_fishes[0].active and game.npc_fishes[0].fish_id>identity,"native capture respawns an active fish with a fresh identity")
	await render("respawned-shore")
	for broken: bool in [false,true]:
		if not contact_fixture(): return
		var outcome: String="broken" if broken else "escaped"
		var player_before: Vector2=game.fish
		game.NPCHook.release(game,broken)
		check(game.public_npc_hook_result.result==outcome and game.npc_fishes[0].active and game.hook_target_fish_id==-1,"native "+outcome+" authority detaches the target without removing the fish")
		check(LineMotion.new().sample(game).path.is_empty() and not game.line_landing(),"native "+outcome+" clears all target line and lift geometry")
		check(game.fish==player_before and game.hooked==game.HookState.FREE and not game.match_over,"native "+outcome+" leaves the player and match unchanged")
		await check_pixels(outcome)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty(): push_error("CAPTURE_OUTPUT_FAIL | output path must not be empty"); return false
	var error:=DirAccess.make_dir_recursive_absolute(output)
	if error != OK: push_error("CAPTURE_OUTPUT_FAIL | cannot create "+output+": "+error_string(error)); return false
	return true
