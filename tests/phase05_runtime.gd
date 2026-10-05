extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Rope=preload("res://scripts/rope.gd")
const Feeding=preload("res://scripts/fish_feeding.gd")
const Shore=preload("res://scripts/shore_view.gd")
const SEEDS=[0,42,2166,1346,937,1141,144,296,64,22,2147483647]
var passed:=0
var failed:=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("RUNTIME_FAIL | "+label)
func make_world(seed: int) -> Node2D:
	var g:=World.new()
	check(g.reset_world({"map_source":Resolver.generated(seed),"seed":64317,"challenge":true,"npc_count":3,
		"rules":{"timer_enabled":false,"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}}),"generated reset")
	if not g.map_errors.is_empty():
		print(g.map_errors); g.free(); quit(1); return null
	return g
func _initialize() -> void:
	var classic:=World.new(); classic.reset_world()
	check(Rope.routing_limits(classic.map_context)==Vector3(9,631,309),"classic retains legacy routing")
	classic.free()
	for seed: int in SEEDS:
		var g:=make_world(seed); var repeat:=make_world(seed)
		check(g.map_context.map_source==Resolver.generated(seed) and g.map_context.routing_profile=="generated_pond_v1","recipe and routing selected together")
		check(Rope.routing_limits(g.map_context)==Vector3(9,1271,430),"full generated routing domain")
		check(g.fish==g.map_context.player_spawn and g.npc_fishes.size()==3,"spawn and NPCs installed")
		for bait:Dictionary in g.baits: check(bait.home in g.map_context.bait_sites,"six generated supply sites")
		for npc:Dictionary in g.npc_fishes:
			check(g.map_context.water.has_point(npc.position),"NPC in water")
			for blocker:Dictionary in g.map_npc_spawn_blockers: check(not g.MapGeometry.touches(npc.position,10,blocker.polygon),"NPC spawn clearance")
		for tick in 240:
			var command:Dictionary={"move":Vector2.RIGHT.rotated(tick*0.017),"aim":Vector2.RIGHT,"suck":tick%40<20,"bite":tick%50==0}
			g.advance_tick(command,{}); repeat.advance_tick(command,{})
		check(g.capture_snapshot()==repeat.capture_snapshot(),"generated gameplay repeatability")
		var before:PackedByteArray=var_to_bytes(g.capture_snapshot())
		check(not g.reset_world({"map_source":{"kind":"generated","generator_version":99}}) and var_to_bytes(g.capture_snapshot())==before,"bad source reset is atomic")
		for x in [160,360,560,760,960,1140]:
			var p:=Vector2(x,175)
			var route:PackedVector2Array=g.Net._manual_net_exit(g,p)
			check(route.size()>=2 and route[0]==p and route[-1].y<g.map_context.water.position.y,"real net exit on both sides of map")
			for index in range(1,route.size()): check(g.Net._manual_net_lane_clear(g,route[index-1],route[index]),"net exit physically clear")
		for target:Dictionary in g.map_net_blockers:
			check(g.Net.manual_net_blocked(g,target.polygon[0]),"generated polygons block net")
		check(Shore.to_world(Shore.to_screen(g.fish,g),g).distance_to(g.fish)<0.001,"shore projection roundtrip")
		g.free(); repeat.free()
		food_and_hook(seed)
		wrap_and_home(seed)
	print("PHASE05_RUNTIME | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
func clear_food(g:Node2D) -> void:
	for bait:Dictionary in g.baits:
		bait.active=false; bait.hook=false; bait.removed=false
		for grain:Dictionary in bait.grains: grain.eaten=true
func food_and_hook(seed:int) -> void:
	var g:=make_world(seed); clear_food(g)
	g.fish=Vector2(520,180); g.fish_before=g.fish; g.aim=Vector2.RIGHT
	for kind:String in ["cluster","worm","chunk"]:
		g._create_bait(0,0,kind)
		var bait:Dictionary=g.baits[0]
		for grain:Dictionary in bait.grains: grain.eaten=true
		var grain:Dictionary=bait.grains[0]; grain.eaten=false; grain.free=true; grain.pos=g.mouth()+Vector2(1,0)
		g.bite_cooldown=0; g.counted.clear()
		check(g._attempt_bite() and grain.eaten,"Bite consumes "+kind+" on generated map")
	clear_food(g)
	var npc:Dictionary=g.npc_fishes[0]; npc.position=Vector2(760,180); npc.aim=Vector2.RIGHT
	var bait:Dictionary=g.baits[1]; bait.active=true; bait.hook=true; bait.angle=0.0
	bait.pos=Feeding.mouth(npc.position,npc.aim)+Vector2(1,-1); bait.home=bait.pos; bait.tip_before=bait.pos+Vector2(2,1)
	g._step_bait(1,0.0,false,g.mouth())
	check(g.hook_target_fish_id==npc.fish_id and g.qte.is_empty(),"NPC wrong hook remains distinct")
	g.NPCHook.release(g,false)
	g._enter_hook(1)
	check(g.qte=="entry" and g.hook_target_fish_id==1,"player entry QTE")
	g._attach_hook(); check(g.line_hooked(),"player attachment")
	g._release_hook(false); check(not g.line_hooked(),"player escape")
	g.free()
func wrap_and_home(seed:int) -> void:
	var g:=make_world(seed); clear_food(g)
	g._enter_hook(1); g._attach_hook()
	var target:Dictionary=g.targets[0]
	g.fish=target.polygon[0]; g.fish_before=g.fish; g.contact_target=0; g.qte=""
	check(g._begin_wrap(),"generated feature offers wrap QTE")
	g._commit_wrap()
	check(g.wraps.size()==1 and g.wraps[0].target==0,"coil uses generated geometry")
	g.wraps[0].progress=1.0; g.untangle_cooldown=0.0; g.wrap_retry=0.0
	check(g._begin_untangle(),"angler can untangle generated coil")
	g._clear_hook(); g.net_state="wait"; g.fish=g.map_context.home; g.fish_before=g.fish; g.velocity=Vector2.ZERO; g.score=g.food_target()
	check(g.can_home(),"generated home is usable")
	g.advance_tick({"home":true},{})
	for tick in int(ceil(g.rule("home_hold")/World.TICK_SECONDS))+3: g.advance_tick({},{})
	check(g.match_over and g.reason=="home","complete home victory")
	g.free()
