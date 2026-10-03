extends SceneTree

const Main = preload("res://scenes/main.tscn")
const Camera = preload("res://scripts/pond_camera.gd")
const Art = preload("res://scripts/pixel_art.gd")
const NPCPublic = preload("res://scripts/npc_fish_public_state.gd")
const Shore = preload("res://scripts/shore_view.gd")
const POINTS: Array[Vector2] = [Vector2(600,150),Vector2(770,145),Vector2(850,230)]
var game: Node2D
var templates: Array[Dictionary]=[]
var passed:=0
var failed:=0
var output:="res://artifacts/phase03-npc-native"

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed+=1
		print("NPC_NATIVE_PASS | ",title)
	else:
		failed+=1
		push_error("NPC_NATIVE_FAIL | "+title)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func render(name: String="") -> Image:
	game.view.queue_redraw()
	for frame in 2: await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not name.is_empty() and picture.save_png(output.path_join(name+".png"))!=OK:
		failed+=1
		push_error("CAPTURE_OUTPUT_FAIL | cannot save %s in %s" % [name,output])
	return picture

func setup_fixture() -> void:
	game.reset(false,"fish"); game.menu.close()
	game.reset_world({"ruleset":"survival","seed":8231,"rules":{"water_strength":0,"timer_enabled":false,"satiety_decay":0,"instinct_max_strength":0}})
	freeze(game)
	game.fish=Vector2(700,210); game.fish_before=game.fish; game.aim=Vector2.RIGHT; game.velocity=Vector2.ZERO
	game.elapsed=2.0; game.power=0.35; game.feeding=false; game.notice_age=0; game.hook_cooldown=1000
	game.satiety=50; game.instinct_drive=0; game.caution_state="CALM"
	for bait in game.baits:
		bait.active=false; bait.hook=false
		for grain in bait.grains: grain.eaten=true
	templates=game.npc_fishes.duplicate(true)
	place_fishes(3)

func place_fishes(count: int) -> void:
	game.npc_fishes.clear()
	game.next_fish_id=maxi(game.next_fish_id,count+2)
	for index in count:
		var fish: Dictionary=templates[index%templates.size()].duplicate(true)
		fish.fish_id=2+index; fish.active=true
		fish.position=POINTS[index%POINTS.size()]+Vector2(0,90 if index>=3 else 0)
		fish.velocity=Vector2(28,0); fish.aim=Vector2.RIGHT; fish.visual_variant=index%3
		game.npc_fishes.append(fish)

func difference_bounds(a: Image, b: Image) -> Rect2i:
	var low:=a.get_size()
	var high:=Vector2i.ZERO
	var found:=false
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y)==b.get_pixel(x,y): continue
			found=true
			low=Vector2i(mini(low.x,x),mini(low.y,y))
			high=Vector2i(maxi(high.x,x),maxi(high.y,y))
	return Rect2i(low,high-low+Vector2i.ONE) if found else Rect2i()

func changed_pixels(a: Image, b: Image, region: Rect2i) -> int:
	var count:=0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count

func same_hud(a: Image, b: Image) -> bool:
	return a.get_region(Rect2i(0,0,640,55)).get_data()==b.get_region(Rect2i(0,0,640,55)).get_data() and a.get_region(Rect2i(0,313,640,47)).get_data()==b.get_region(Rect2i(0,313,640,47)).get_data()

func toggle_private_truth() -> void:
	# Deliberate render-only canaries, never advanced or accepted as a save.
	# Even unsupported future private state must be absent at this boundary.
	for bait in game.baits:
		bait.hook=not bait.hook; bait.hook_id=9000+int(bait.bait_id) if bait.hook else 0
	for fish in game.npc_fishes:
		fish.brain_seed=int(fish.get("brain_seed",0))+327
		fish.brain_rng_state=int(fish.get("brain_rng_state",0))+1000
		fish.target_bait_id=987; fish.focus_bait_id=987
		fish.risk_tolerance=0.999; fish.satiety=1.0
		fish.suspicion_by_bait={987:0.999}; fish.caution_by_bait={987:0.999}
		fish.caution_state="ALARMED"; fish.behavior_state="FEED"; fish.behavior_age=999.0
		fish.feeding=true; fish.power=0.95; fish.bite_cooldown=0.4; fish.intent_aim=-fish.aim

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="phase03_npc"
	setup_fixture()
	check(templates.size()==3,"default world supplies three authority NPCs")
	if templates.is_empty(): quit(1); return
	var three:=await render("fish-three-ambient")
	check(three.get_size()==Vector2i(640,360),"ambient ecology preserves native 640x360 pixel canvas")
	var initial: Dictionary=game.capture_snapshot()
	var rng_state: int=game.rng.state
	var repeat:=await render()
	check(three.get_data()==repeat.get_data(),"fixed-tick NPC rendering is exactly deterministic")
	check(game.capture_snapshot()==initial and game.rng.state==rng_state,"rendering preserves authority, NPC brain state, and world RNG")
	game.npc_fishes.reverse()
	check(three.get_data()==(await render()).get_data(),"stable fish IDs preserve animation when the array is reordered")
	var separated: Array[Dictionary]=game.npc_fishes.duplicate(true)
	for fish in game.npc_fishes: fish.position=POINTS[0]
	var stacked:=await render()
	game.npc_fishes.reverse()
	check(stacked.get_data()==(await render()).get_data(),"overlapping NPC draw order is stable by identity rather than array index")
	game.npc_fishes=separated
	var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
	game.npc_fishes=NPCPublic.capture(authority)
	check(three.get_data()==(await render("fish-public-replica")).get_data(),"public-only NPC records produce the same fish-view pixels as authority")
	game.npc_fishes=authority
	toggle_private_truth()
	check(three.get_data()==(await render("fish-hidden-truth")).get_data(),"hidden hooks, RNG, targets, satiety, suspicion and private behavior do not change NPC pixels")
	place_fishes(0)
	var empty:=await render("fish-no-npcs")
	check(same_hud(three,empty),"ambient fish do not add names, bars, icons, or HUD state")
	var silhouettes: Array[PackedByteArray]=[]
	for variant in 3:
		place_fishes(1)
		var fish: Dictionary=game.npc_fishes[0]
		fish.visual_variant=variant
		var picture:=await render("fish-variant-%d" % variant)
		var anchor:=Vector2i(Camera.to_screen(fish.position,game,"fish").round())
		var region:=Rect2i(anchor-Vector2i(13,8),Vector2i(27,17))
		var bounds:=difference_bounds(picture,empty)
		check(changed_pixels(picture,empty,region)>=55,"variant %d is visibly fish-sized at its real position" % variant)
		check(region.encloses(bounds),"variant %d has no pixels, status markers or trails outside its physical sprite" % variant)
		check(bounds.size.x<=23 and bounds.size.y<=12,"variant %d remains smaller than the 24x12 player fish" % variant)
		silhouettes.append(picture.get_region(region).get_data())
		fish.active=false
		check(empty.get_data()==(await render()).get_data(),"inactive variant %d has no lingering sprite" % variant)
		fish.active=true; fish.position+=Vector2(25,12)
		var moved:=await render()
		check(difference_bounds(moved,empty).position==bounds.position+Vector2i(25,12),"variant %d follows authority movement exactly without a detached shadow" % variant)
	for pair in [[0,1],[0,2],[1,2]]:
		check(silhouettes[pair[0]]!=silhouettes[pair[1]],"variants %s have distinct silhouettes or markings at the same position" % [pair])
	place_fishes(1)
	game.npc_fishes[0].position=game.fish
	game.npc_fishes[0].velocity=Vector2.ZERO
	var overlap:=await render("fish-player-in-front")
	var sprite: Image=game.view.fish_texture.get_image()
	var origin:=Vector2i(Camera.to_screen(game.fish,game,"fish"))-Vector2i(12,6)
	var opaque_count:=0
	var player_unchanged:=true
	for y in sprite.get_height():
		for x in sprite.get_width():
			if sprite.get_pixel(x,y).a<0.99: continue
			opaque_count+=1
			if overlap.get_pixelv(origin+Vector2i(x,y))!=empty.get_pixelv(origin+Vector2i(x,y)): player_unchanged=false
	check(opaque_count>100 and player_unchanged,"all opaque player pixels stay in front when an NPC overlaps the protagonist")
	await check_shore_views()
	await check_actual_foraging()
	await record_frame_costs()
	print("NPC_NATIVE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func check_shore_views() -> void:
	setup_fixture(); game.player_role="angler"; game.angler.x=640
	place_fishes(0)
	var empty:=await render("shore-no-npcs")
	place_fishes(3)
	var scene:=await render("shore-ambient-shadows")
	check(scene.get_data()!=empty.get_data(),"shore view contains visible ambient fish shadows")
	check(same_hud(scene,empty),"shore NPCs do not expose identity or status in the HUD")
	var bounds:=difference_bounds(scene,empty)
	check(Rect2i(0,213,640,94).encloses(bounds),"shore differences stay inside projected underwater shadow band")
	toggle_private_truth()
	check(scene.get_data()==(await render("shore-hidden-truth")).get_data(),"shore shadows remain identical under private hook and AI changes")
	var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
	game.npc_fishes=NPCPublic.capture(authority)
	check(scene.get_data()==(await render()).get_data(),"shore public replica matches authority without private fields")
	game.npc_fishes=authority
	game.net_action.observing=true
	place_fishes(0)
	var observing_empty:=await render("observation-no-npcs")
	place_fishes(1)
	game.npc_fishes[0].position=Vector2(699,150)
	var observing:=await render("observation-ambient-shadow")
	check(observing.get_data()!=observing_empty.get_data(),"existing net observation can reveal an NPC using legal visibility")
	game.npc_fishes[0].position+=Vector2(0.3,0.3)
	var approximate:=await render()
	check(observing.get_data()==approximate.get_data(),"net observation stays on approximate 3px position grid, without exact-position icons")
	toggle_private_truth()
	check(approximate.get_data()==(await render("observation-hidden-truth")).get_data(),"net observation shadows are blind to private hook and brain truth")
	game.npc_fishes[0].position=Vector2(1260,400)
	check(observing_empty.get_data()==(await render()).get_data(),"NPC beyond existing net sight is not rendered in observation mode")

func check_actual_foraging() -> void:
	setup_fixture(); place_fishes(1)
	var npc: Dictionary=game.npc_fishes[0]
	npc.position=Vector2(600,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0
	var grain: Dictionary=game.baits[0].grains[0]
	grain.eaten=false; grain.free=true; grain.pos=npc.position+Vector2(12,0); grain.points=1.0
	await render("fish-npc-food-before")
	var score_before: float=game.score
	for tick in 120:
		game.advance_tick({}, {})
		if grain.eaten: break
	check(grain.eaten and game.round_stats.npc_food_consumed==1.0,"native authority NPC actually consumes the visible food fixture")
	check(game.score==score_before and game.round_stats.food_consumed==0 and game.hook_count==0,"native NPC food intake gives no player award or hook event")
	check(npc.behavior_state=="FEED" and npc.bite_cooldown>0,"native capture contains real feeding state and pending bite cooldown")
	var consumed:=await render("fish-npc-food-consumed")
	var actual: Dictionary=game.capture_snapshot()
	# Restore only the food's visible presence at the exact same tick to localize
	# its disappearance independently of animation, fish motion or HUD time.
	grain.eaten=false
	var visible:=await render("fish-npc-food-visible-control")
	grain.eaten=true
	var center:=Vector2i(Camera.to_screen(grain.pos,game,"fish").round())
	var food_region:=Rect2i(center-Vector2i(6,6),Vector2i(13,13))
	var bounds:=difference_bounds(consumed,visible)
	check(bounds.has_area() and food_region.encloses(bounds),"actual consumed-food pixels disappear only at the food's visible position")
	check(game.capture_snapshot()==actual,"food visibility control restores exact native authority")
	var authority: Array[Dictionary]=game.npc_fishes.duplicate(true)
	toggle_private_truth()
	check(consumed.get_data()==(await render("fish-npc-feeding-hidden-truth")).get_data(),"actual feeding pixels are invariant to private hook, feeding intent, power, cooldown and AI memory")
	game.npc_fishes=NPCPublic.capture(authority)
	check(consumed.get_data()==(await render("fish-npc-fed-public-replica")).get_data(),"fed NPC public-only replica preserves exactly the same native pixels")

func record_frame_costs() -> void:
	setup_fixture()
	var results: Array[Dictionary]=[]
	for count in [0,3,6]:
		place_fishes(count)
		await render("fish-count-%d" % count)
		var snapshot: Dictionary=game.capture_snapshot()
		var samples: Array[float]=[]
		for frame in 45:
			var began:=Time.get_ticks_usec()
			game.view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			samples.append(float(Time.get_ticks_usec()-began)/1000.0)
		samples.sort()
		var sum:=0.0
		for sample in samples: sum+=sample
		results.append({"npc_count":count,"samples":samples.size(),"mean_ms":sum/samples.size(),"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)]})
		check(game.capture_snapshot()==snapshot,"%d NPC frame-cost sampling preserves simulation" % count)
	var report:={"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"measurement":"Wall-clock redraw-to-frame-post-draw on a frozen native 640x360 scene; includes display pacing and scheduler, not isolated GPU or simulation cost","results":results}
	var file:=FileAccess.open(output.path_join("native-frame-costs.json"),FileAccess.WRITE)
	if file==null:
		check(false,"native frame-cost report can be written")
	else:
		file.store_string(JSON.stringify(report,"\t")+"\n")
		file.close()
		check(true,"0/3/6 NPC native frame-cost report recorded")
		print("NPC_NATIVE_FRAME_COSTS | ",JSON.stringify(report))

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="): output=argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | --capture-output-directory must not be empty")
		return false
	var error:=DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s; choose a writable --capture-output-directory" % [output,error_string(error)])
		return false
	return true
