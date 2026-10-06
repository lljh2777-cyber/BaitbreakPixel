extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Fish=preload("res://scripts/fish_network_observation.gd")
const Angler=preload("res://scripts/angler_network_observation.gd")
const Grass=preload("res://scripts/grass_binding.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Fauna=preload("res://scripts/watergen/woodland_fauna.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("WOODLAND_FAIL | "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loaded:=Resolver.resolve(Resolver.woodland())
	check(loaded.valid,"authored definition validates: "+str(loaded.errors))
	if not loaded.valid: finish(); return
	var context: RefCounted=loaded.context
	for source in [Resolver.classic(),Resolver.woodland(),Resolver.classic(),Resolver.woodland()]:
		var result:=Resolver.resolve(source)
		check(result.valid and result.context.id==source.id,"built-in cache never substitutes another map")
	check(context.has_relief and context.floor_at(730)>context.floor_at(50)+140,"real broad asymmetric valley")
	check(context.target_count()==12,"wood pieces, stone and grass use explicit stable targets")
	for target: Dictionary in context.interaction_targets:
		check(target.capabilities.fish_passable and target.capabilities.rope_anchor and target.capabilities.contact_fade,"same cover rules: "+target.id)
		check(target.capabilities.net_blocking==(target.kind!="grass") and target.capabilities.grass_binding==(target.kind=="grass"),"same net/grass rules: "+target.id)
		check(not context.coil_at(target.id,target.bounds.get_center()).is_empty(),"coil geometry exists: "+target.id)
	for x in range(20,1260,20):
		var p: Vector2=context.move_in_water(Vector2(x,100),Vector2(0,600),12)
		check(not context.bed_blocked(p,12) and p.y<=context.floor_at(x)-11.9,"fish cannot enter authored soil")
	var g:=World.new(); var copy:=World.new()
	check(g.reset_world({"map_source":Resolver.woodland(),"seed":713284,"challenge":false}),"real world startup")
	check(g.npc_fishes.size()==3 and g.targets.size()==12,"existing NPC and authority initialize on fixed map")
	var fauna:=Fauna.new()
	var before:=var_to_bytes(g.capture_snapshot())
	for t in [0.0,1.0,8.0,40.0]: check(fauna.sample(t).size()==15,"decorative animals remain visual only")
	check(before==var_to_bytes(g.capture_snapshot()),"fauna cannot change authority or RNG")
	check(copy.restore_snapshot(g.capture_snapshot()),"snapshot restores authored built-in map")
	check(Fish.valid(copy,Fish.capture(g)),"fish public packet accepts fixed map")
	check(Angler.valid(copy,Angler.capture(g)),"angler public packet accepts fixed map")
	var equal:=true; var valid:=true
	for tick in 900:
		var command: Dictionary={"move":Vector2(cos(tick*.02),sin(tick*.014)),"aim":Vector2.RIGHT,"suck":tick%120<50}
		g.advance_tick(command,{}); copy.advance_tick(command,{})
		if g.capture_snapshot()!=copy.capture_snapshot(): equal=false
		if not g.fish.is_finite() or g.map_context.bed_blocked(g.fish,11.9): valid=false
	check(equal and valid,"900 replay ticks preserve finite terrain-safe deterministic gameplay")
	check(g.Net.manual_net_blocked(g,Vector2(600,475)),"soil blocks the real net")
	check(g.Net.manual_net_blocked(g,Vector2(1120,325)),"right boulder blocks the real net")
	check(not g.Net.manual_net_blocked(g,Vector2(600,200)),"central water remains open for the net")
	g.fish=Vector2(400,315); g._update_contacts(1.0)
	var faded:=true
	for i in 7: faded=faded and g.target_opacity[i]==g.rule("cover_opacity")
	check(faded,"touching one wood piece fades the entire attached host")
	g.fish=Vector2(600,200); g._update_contacts(1.0)
	check(g.target_opacity.all(func(v: float) -> bool: return v==1.0),"leaving cover restores opacity")
	g.baits[0].active=true; g._enter_hook(0); g._attach_hook()
	for target in [10,11]:
		var bounds: Rect2=g.targets[target].bounds
		var coil: Dictionary=g.MapGeometry.coil_at(g.targets[target],bounds.get_center()); coil.target=target
		g.wraps.assign([coil]); g.fish=bounds.get_center()+Vector2(-15,10)
		for progress in [0.0,0.5,1.0]:
			g.wraps[0].progress=progress
			var snapshot:=var_to_bytes(g.capture_snapshot())
			var profile:=Grass.profile(g,g.wraps[0],progress)
			var route:=Motion.new().sample(g)
			check(Grass.deform(Vector2(profile.x,profile.base),profile)==Vector2(profile.x,profile.base),"authored grass root stays planted")
			check(route.path[0]==g.line_anchor(0) and route.path[-1].is_equal_approx(route.fish.mouth),"authored grass binds a connected rope")
			check(snapshot==var_to_bytes(g.capture_snapshot()),"grass drawing never changes authority")
	g.free(); copy.free(); finish()
func finish() -> void:
	print("WOODLAND_CONTRACT | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
