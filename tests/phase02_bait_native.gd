extends SceneTree

const Main = preload("res://scenes/main.tscn")
const FoodProfile = preload("res://scripts/food_profile.gd")
const Camera = preload("res://scripts/pond_camera.gd")
const FOCUS := Vector2(770,190)
const FOOD_REGION := Rect2i(367,151,46,44)
var game: Node2D
var passed := 0
var failed := 0
var output := "res://artifacts/phase02-bait-native"

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed+=1
		print("BAIT_TYPE_NATIVE_PASS | ",title)
	else:
		failed+=1
		push_error("BAIT_TYPE_NATIVE_FAIL | "+title)

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

func put_bait(kind: String, position: Vector2=FOCUS, slot: int=0) -> Dictionary:
	var bait: Dictionary=game._make_bait(slot,0,kind)
	bait.bait_id=100+slot; bait.hook=false; bait.hook_id=0
	bait.active=true; bait.pos=position; bait.home=position; bait.angle=0.0
	for grain in bait.grains: grain.pos=position+Vector2(grain.offset)
	game.baits[slot]=bait
	return bait

func toggle_hooks(present: bool) -> void:
	for bait in game.baits:
		bait.hook=present
		bait.hook_id=int(bait.bait_id)+1000 if present else 0

func food_bytes(picture: Image) -> PackedByteArray:
	return picture.get_region(FOOD_REGION).get_data()

func changed_pixels(picture: Image, empty: Image) -> int:
	var total:=0
	for y in range(FOOD_REGION.position.y,FOOD_REGION.end.y):
		for x in range(FOOD_REGION.position.x,FOOD_REGION.end.x):
			if picture.get_pixel(x,y)!=empty.get_pixel(x,y): total+=1
	return total

func food_bounds(picture: Image, empty: Image) -> Rect2i:
	var low:=FOOD_REGION.end
	var high:=FOOD_REGION.position
	var found:=false
	for y in range(FOOD_REGION.position.y,FOOD_REGION.end.y):
		for x in range(FOOD_REGION.position.x,FOOD_REGION.end.x):
			if picture.get_pixel(x,y)==empty.get_pixel(x,y): continue
			found=true
			low=Vector2i(mini(low.x,x),mini(low.y,y))
			high=Vector2i(maxi(high.x,x),maxi(high.y,y))
	return Rect2i(low,high-low+Vector2i.ONE) if found else Rect2i()

func anchored_pixels(picture: Image, empty: Image, bait: Dictionary) -> bool:
	var anchors: Array[Rect2i]=[]
	for grain in bait.grains:
		if grain.eaten or (not grain.free and not bait.active): continue
		var point:=Vector2i((Vector2(grain.pos)-Camera.offset(game,"fish")).round())
		anchors.append(Rect2i(point,Vector2i(3,3)))
	for y in range(FOOD_REGION.position.y,FOOD_REGION.end.y):
		for x in range(FOOD_REGION.position.x,FOOD_REGION.end.x):
			if picture.get_pixel(x,y)==empty.get_pixel(x,y): continue
			var anchored:=false
			for rect in anchors:
				if rect.has_point(Vector2i(x,y)): anchored=true; break
			if not anchored: return false
	return true

func run() -> void:
	if not prepare_capture_output(): quit(2); return
	game=Main.instantiate(); root.add_child(game); game.capture_mode="phase02_bait"
	setup_fixture()
	for index in FoodProfile.TYPES.size():
		put_bait(FoodProfile.TYPES[index],Vector2(660+index*70,155),index)
	var scene:=await render("three-bait-types-safe")
	check(scene.get_size()==Vector2i(640,360),"three-type scene preserves native 640x360 pixel canvas")
	var initial: Dictionary=game.capture_snapshot()
	var rng_state: int=game.rng.state
	var repeat:=await render()
	check(scene.get_data()==repeat.get_data(),"three-type fixed-tick rendering is exactly deterministic")
	check(game.capture_snapshot()==initial and game.rng.state==rng_state,"three-type rendering is simulation and RNG neutral")
	toggle_hooks(true)
	var hooked_scene:=await render("three-bait-types-hooked")
	check(scene.get_data()==hooked_scene.get_data(),"all three types have identical whole-scene safe and hidden-hook pixels")
	var silhouettes: Array[PackedByteArray]=[]
	var dimensions: Dictionary={}
	for kind: String in FoodProfile.TYPES:
		setup_fixture()
		var empty:=await render()
		var bait:=put_bait(kind)
		var safe:=await render(kind+"-safe")
		silhouettes.append(food_bytes(safe))
		dimensions[kind]=food_bounds(safe,empty).size
		check(changed_pixels(safe,empty)>=20,kind+": full food is visibly present at its physical position")
		check(anchored_pixels(safe,empty,bait),kind+": all food pixels stay within three pixels of real edible grains")
		var snapshot: Dictionary=game.capture_snapshot()
		var state: int=game.rng.state
		var identical:=await render()
		check(safe.get_data()==identical.get_data() and game.capture_snapshot()==snapshot and game.rng.state==state,kind+": repeated rendering preserves pixels, simulation and RNG")
		toggle_hooks(true)
		var hidden:=await render(kind+"-hooked")
		check(safe.get_data()==hidden.get_data(),kind+": hook flags and IDs never change pre-contact pixels")
		toggle_hooks(false)
		for grain in bait.grains: grain.eaten=Vector2(grain.offset).x<0
		var partial:=await render(kind+"-partially-eaten")
		check(changed_pixels(partial,empty)>0 and changed_pixels(partial,empty)<changed_pixels(safe,empty),kind+": eaten fragments visibly reduce the real silhouette")
		check(anchored_pixels(partial,empty,bait),kind+": partial silhouette has no phantom food beyond surviving grains")
		toggle_hooks(true)
		var partial_hidden:=await render(kind+"-partially-eaten-hooked")
		check(partial.get_data()==partial_hidden.get_data(),kind+": partial eating does not expose hook truth")
		toggle_hooks(false)
		for grain in bait.grains: grain.eaten=true
		var gone:=await render()
		check(food_bytes(gone)==food_bytes(empty),kind+": fully eaten food leaves no complete-bait sprite behind")
		bait.active=false
		var crumb: Dictionary=bait.grains[0]
		crumb.eaten=false; crumb.free=true; crumb.pos=FOCUS
		var loose:=await render(kind+"-loose-fragment")
		check(changed_pixels(loose,empty)>0 and anchored_pixels(loose,empty,bait),kind+": detached fragment remains at its actual food position")
		# A newly re-hung parent may have another kind; surviving loose food must
		# still use its own observation kind and never inherit the new silhouette.
		bait.bait_type=FoodProfile.TYPES[(FoodProfile.TYPES.find(kind)+1)%FoodProfile.TYPES.size()]
		var retyped_parent:=await render()
		check(loose.get_data()==retyped_parent.get_data(),kind+": old loose fragment retains its own visual kind after parent replacement")
		toggle_hooks(true)
		var loose_hidden:=await render(kind+"-loose-fragment-hooked")
		check(loose.get_data()==loose_hidden.get_data(),kind+": detached fragments never reveal a hidden hook")
		crumb.pos+=Vector2(8,0)
		var moved:=await render(kind+"-loose-fragment-moved")
		check(food_bounds(moved,empty).position==food_bounds(loose,empty).position+Vector2i(8,0),kind+": loose pixels follow the food position exactly")
		crumb.eaten=true
		var consumed:=await render()
		check(food_bytes(consumed)==food_bytes(empty),kind+": consumed loose fragment leaves no ghost pixels")
		setup_fixture(); bait=put_bait(kind)
		game.feeding=true; game.power=1.0; bait.suction_offset=Vector2(-6,-2)
		var suction_safe:=await render(kind+"-suction-safe")
		toggle_hooks(true)
		var suction_hooked:=await render(kind+"-suction-hooked")
		check(suction_safe.get_data()==suction_hooked.get_data(),kind+": whole-bait suction deformation stays hook-blind")
		setup_fixture(); bait=put_bait(kind,game.mouth()+Vector2(6,0))
		var offered_offsets: Array=[]
		for grain in bait.grains: offered_offsets.append(Vector2(grain.offset))
		var before_intake:=await render(kind+"-automatic-bite-before")
		game.advance_tick({},{}); game.elapsed=2.0
		var after_intake:=await render(kind+"-automatic-bite-after")
		var eaten_count:=0
		var retained_offsets: Array=[]
		for grain in bait.grains:
			eaten_count+=int(grain.eaten)
			retained_offsets.append(Vector2(grain.offset))
		check(eaten_count==4 and game.score>0 and game.bite_cooldown>0 and game.bite_feedback_age>0,kind+": actual mouth proximity automatically consumes four grains and starts cooldown")
		check(bait.grains.size()==44 and retained_offsets==offered_offsets,kind+": real intake depletes existing grains without replacing or changing physical type geometry")
		check(before_intake.get_region(Rect2i(310,175,55,35)).get_data()!=after_intake.get_region(Rect2i(310,175,55,35)).get_data(),kind+": real automatic intake visibly changes the mouth and food region")
	for pair in [[0,1],[1,2],[0,2]]:
		check(silhouettes[pair[0]]!=silhouettes[pair[1]],"types %s remain visibly distinct at the same position" % [pair])
	check(dimensions.worm.x>dimensions.worm.y*2,"worm forms a slender curved strip rather than a round cluster")
	check(dimensions.chunk.x<=dimensions.chunk.y*1.5,"chunk forms a compact block rather than a slender strip")
	setup_fixture()
	for index in FoodProfile.TYPES.size():
		var bait:=put_bait(FoodProfile.TYPES[index],Vector2(660+index*70,155),index)
		for grain in bait.grains: grain.eaten=Vector2(grain.offset).x<0
		for piece in 3:
			var grain: Dictionary=bait.grains[piece]
			grain.eaten=false; grain.free=true; grain.pos=bait.pos+Vector2(-11+piece*7,18+piece*3)
	await render("three-bait-types-partial-and-loose")
	print("BAIT_TYPE_NATIVE | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func prepare_capture_output() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output-directory="):
			output=argument.trim_prefix("--capture-output-directory=")
	if output.strip_edges().is_empty():
		push_error("CAPTURE_OUTPUT_FAIL | --capture-output-directory must not be empty")
		return false
	var error:=DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("CAPTURE_OUTPUT_FAIL | cannot create '%s': %s; choose a writable --capture-output-directory" % [output,error_string(error)])
		return false
	return true
