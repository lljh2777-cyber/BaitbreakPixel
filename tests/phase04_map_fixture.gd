extends SceneTree

const Rope=preload("res://scripts/rope.gd")
const World=preload("res://scripts/world_simulation.gd")
const Fixture=preload("res://tests/fixtures/phase04/fixture_rect_small.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
const Context=preload("res://scripts/maps/map_context.gd")
const Validator=preload("res://scripts/maps/map_validator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Session=preload("res://scripts/network_session.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const NPC=preload("res://scripts/npc_fish_state.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Camera=preload("res://scripts/pond_camera.gd")
const Shore=preload("res://scripts/shore_view.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("MAP_FIXTURE_FAIL | "+label)

func world(npcs: int=3) -> Node2D:
	var result:=World.new()
	check(result.reset_world({"seed":45454,"ruleset":"duel","npc_count":npcs,"rules":{"water_strength":0.0,"hunger_enabled":false,"timer_enabled":false}},Fixture.create()),"small authored fixture initializes")
	return result

func _initialize() -> void:
	identity_and_geometry()
	movement_home_bait_net()
	npc_bounds_and_determinism()
	input_bounds_and_preflight()
	public_food_bounds()
	camera_and_shore()
	rope_routing_policy()
	same_tick_net_regression()
	print("PHASE04_MAP_FIXTURE | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)

func identity_and_geometry() -> void:
	var definition:=Fixture.create()
	check(Validator.validate(definition).valid,"fixture meets unchanged map contract")
	check(not Registry.load_map("fixture_rect_small",1).valid and not Registry.validate_ref(definition.meta).valid,"test map is absent from production registry and MapRef admission")
	var game:=world()
	check(game.map_context.size==Vector2(800,360) and game.map_context.water==Fixture.WATER and game.map_context.floor_y==324.0,"nondefault size, shifted water and floor are installed")
	check(game.map_context.home==Fixture.HOME and game.fish==Fixture.SPAWN,"spawn and home come from the selected fixture")
	check(game.map_context.bait_sites==Fixture.SITES and game.targets.size()==3 and game.target_opacity.size()==3,"bait sites and three-feature geometry use fixture order")
	for index in game.targets.size():
		check(game.targets[index].id==Fixture.FEATURE_IDS[index] and game.targets[index].bounds==Fixture.RECTS[index],"authored feature identity/geometry "+str(index))
	check(game.map_net_blockers.size()==2 and game.map_npc_spawn_blockers.size()==2,"capability caches are sized for the fixture")
	var before: Dictionary=game.capture_snapshot()
	check(before.map_ref==definition.meta and not game.restore_snapshot(before) and game.capture_snapshot()==before,"unregistered fixture capture preserves identity but restore fails atomically")
	var receiver:=World.new(); receiver.reset_world()
	var receiver_before: Dictionary=receiver.capture_snapshot()
	check(not FishWire.apply(receiver,FishWire.capture(game)) and not AnglerWire.apply(receiver,AnglerWire.capture(game)) and receiver.capture_snapshot()==receiver_before,"both wire schemas reject test-only geometry without registration or mutation")
	receiver.free(); game.free()

func movement_home_bait_net() -> void:
	var game:=world(0)
	game.move_fish(Vector2(-10000,-10000))
	check(game.fish==Vector2(54,66),"fish clamps to fixture left/top body inset")
	game.move_fish(Vector2(10000,10000))
	check(game.fish==Vector2(746,310),"fish clamps to fixture right/bottom body inset")
	game.fish=Fixture.HOME; game.score=game.food_target()
	check(game.can_home(),"home objective uses moved fixture anchor")
	for bait: Dictionary in game.baits:
		check(bait.pos in Fixture.SITES and bait.home==bait.pos,"initial bait uses one of six authored sites")
	var bait: Dictionary=game.baits[1]
	bait.home=Vector2(-1000,-1000); bait.pos=bait.home; bait.suction_offset=Vector2.ZERO
	game._step_bait_suction(bait,World.TICK_SECONDS,false)
	check(bait.pos==Vector2(49,61),"bait clamps to fixture water inset")
	check(game.Net.reachable(game,Vector2(120,135)) and not game.Net.reachable(game,Vector2(40,135)),"net reach admits only fixture net area")
	check(game.Net.manual_net_blocked(game,Vector2(314,200)),"fixture wood geometry blocks the net")
	game.net_action.a=Vector2(250,200)
	var blocked: Dictionary=game.Net.preview(game,Vector2(360,200))
	check(blocked.valid and blocked.blocked and blocked.b.x<300,"net preview stops at authored fixture wood")
	game.fish=Fixture.SPAWN; game.fish_before=game.fish
	game.advance_tick({}, {"net_events":[{"kind":"toggle"},{"kind":"point","point":Vector2(120,135)},{"kind":"point","point":Vector2(230,135)}]})
	check(game.net_state=="warning" and game.net_from==Vector2(120,135) and game.net_to==Vector2(230,135),"same-tick net endpoints commit within the small map")
	var coil: Dictionary=game.map_context.coil_at("fixture_wood",Vector2(314,210))
	check(coil.center==Vector2(314,210) and coil.radii==Vector2(18,6) and coil.loop.size()==65,"rope coil uses fixture polygon rather than pond geometry")
	game.free()

func npc_bounds_and_determinism() -> void:
	var game:=world(); var repeat:=world()
	check(game.npc_fishes.size()==3 and game.npc_fishes==repeat.npc_fishes,"NPC fixture allocation is deterministic")
	for tick in 360:
		var command: Dictionary={"move":Vector2.RIGHT.rotated(tick*0.03),"aim":Vector2.RIGHT,"suck":tick%60<20}
		game.advance_tick(command,{}); repeat.advance_tick(command,{})
		if tick%60==0:
			check(game.capture_snapshot()==repeat.capture_snapshot() and game.rng.state==repeat.rng.state,"same fixture input preserves complete state and RNG tick "+str(tick))
			for npc: Dictionary in game.npc_fishes:
				check(NPC.valid(npc,game.next_fish_id,game.map_context.water),"NPC decisions remain inside selected water")
	check(NPCPublic.valid(NPCPublic.capture(game.npc_fishes),game.fish_id,game.map_context.water),"public NPC projection validates against explicit fixture water")
	var outside:=NPC.fresh(2,1,Vector2(900,200),Vector2.RIGHT,1)
	check(not NPC.valid(outside,3,game.map_context.water) and not NPCPublic.valid(NPCPublic.capture([outside]),1,game.map_context.water),"private/public guards reject pond-only position outside fixture")
	outside.position=Vector2(100,64)
	check(NPC.valid(outside,3,game.map_context.water) and NPCPublic.valid(NPCPublic.capture([outside]),1,game.map_context.water),"private/public guards admit fixture-only position above old pond water")
	check(NPCPublic.landing_bounds(game.map_context.water)==Rect2(52,25,696,287),"NPC landing bounds derive from shifted fixture surface")
	game.free(); repeat.free()

func input_bounds_and_preflight() -> void:
	var game:=world(0)
	var clean:=Protocol.input("angler",{"target":Vector2(900,400),"auto_reel":true,"auto_net":true,"qte_at_age":1.0},game.map_context)
	check(clean.target==Fixture.SIZE and not clean.auto_reel and not clean.auto_net and clean.qte_at_age==-1.0,"wire target clamp uses 800x360 and preserves security flags")
	check(Protocol.input("angler",{"target":Vector2(-1,-2)},game.map_context).target==Vector2.ZERO,"wire lower bounds remain map origin")
	check(Protocol.input("angler",{},game.map_context).target==Fixture.WATER.position+Vector2(224,112),"wire fallback is relative to selected water")
	var session:=Session.new(); session.game=game
	var packet: Dictionary={"session":"fixture-test","round":0,"seq":1,"command":{"target":Vector2(900,400)},"events":[{"kind":"point","point":Vector2(900,400),"gesture":1}],"seen_tick":0,"qte_id":0,"gesture":1}
	session.is_host=true; session.status="playing"; session.session_id="fixture-test"
	session.receive_input(packet)
	check(session.remote_queue.is_empty() and session.rejected_inputs==1,"fixture cannot bypass normal map preflight")
	# Isolated post-admission input unit, not a fixture map handshake/registration.
	session.map_validated=true; session.remote_role="angler"
	session.receive_input(packet)
	check(session.remote_queue.size()==1 and session.remote_queue[0].command.target==Fixture.SIZE and session.remote_queue[0].command.net_events[0].point==Fixture.SIZE,"reliable event and held target clamp against the installed test context")
	session.presentation.dispose(); session.free(); game.free()

func public_food_bounds() -> void:
	var game:=world(0)
	game.fish=Vector2(60,100); game.fish_before=game.fish
	for bait: Dictionary in game.baits:
		bait.active=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	var bait: Dictionary=game.baits[0]
	var outside: Dictionary=bait.grains[0]; outside.eaten=false; outside.free=true; outside.pos=Vector2(30,100); outside.visual_kind="worm"
	var inside: Dictionary=bait.grains[1]; inside.eaten=false; inside.free=true; inside.pos=Vector2(150,100); inside.visual_kind="chunk"
	var observed:=Observation.build(game,false)
	check(Observation.food_position(observed,bait.bait_id)==inside.pos,"food decisions exclude a nearer grain in old-pond-only water")
	var wire:=FishWire.capture(game)
	check(wire.state.baits[0].visual_kind=="chunk" and wire.state.baits[0].shape_hint=="solid_chunk","fish wire derives nearest-food cues using fixture water")
	check(not wire.has("rng_state") and not wire.state.baits[0].has("hook") and not wire.state.baits[0].has("home"),"fixture does not widen public bait privacy")
	game.free()

func camera_and_shore() -> void:
	var game:=world(0)
	for point: Vector2 in [Fixture.SPAWN,Fixture.HOME,Vector2(450,120),Vector2(757,321)]:
		game.fish=point
		var offset:=Camera.offset(game,"fish")
		check(offset.x>=0 and offset.x<=160 and offset.y==0,"800x360 camera never scrolls below map or uses old height")
		check(Camera.to_world(Camera.to_screen(point,game,"fish"),game,"fish")==point,"camera input roundtrip uses selected map")
		check(Shore.to_world(Shore.to_screen(point,game),game).distance_to(point)<0.001,"shore projection/inverse use selected width/floor")
	game.angler.free_line_length=700.0
	check(Camera.offset(game,"angler").y==0,"angler observation depth is clamped to fixture height")
	var expected:=Vector2(24+Fixture.HOME.x*(640.0/800.0)*0.925,213+257.0*0.35)
	check(Shore.to_screen(Vector2(Fixture.HOME.x,Fixture.FLOOR-1),game).is_equal_approx(expected),"fixture floor reaches unchanged pond-style near projection")
	var smaller:=Fixture.create()
	smaller.meta.id="fixture_below_viewport"
	smaller.bounds.size=Vector2(400,180); smaller.bounds.water=Rect2(21,27,358,134); smaller.bounds.floor_y=162.0
	smaller.bounds.net_area=Rect2(34,40,332,104); smaller.bounds.vegetation_drag_zones=[]
	smaller.anchors.player_spawn=Fixture.SPAWN*0.5; smaller.anchors.home=Fixture.HOME*0.5
	for index in smaller.bait_sites.size(): smaller.bait_sites[index]*=0.5
	for feature: Dictionary in smaller.interaction_features:
		for index in feature.shape.points.size(): feature.shape.points[index]*=0.5
	smaller.meta.content_hash=Definition.content_hash(smaller)
	check(game.reset_world({"npc_count":0},smaller),"smaller-than-viewport fixture variant validates")
	game.fish=Vector2(378,160)
	check(Camera.offset(game,"fish")==Vector2.ZERO and Camera.offset(game,"angler")==Vector2.ZERO,"small maps clamp camera to zero rather than a negative offset")
	game.free()

func same_tick_net_regression() -> void:
	# Explicit inherited defect: Dictionary age reset used int zero, so batching
	# toggle+A+B left the fish wire invalid forever after commit. Keep strict float
	# validation; fix only the producer's reset, not any Authority/wire allowlist.
	var game:=World.new(); var receiver:=World.new()
	game.reset_world({"seed":75401,"ruleset":"duel","npc_count":3,"rules":{"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
	receiver.reset_world({"seed":1})
	game.angler.x=234.0; game.angler.previous_anchor=game.angler.anchor()
	game.fish=Vector2(1000,320); game.fish_before=game.fish
	for bait: Dictionary in game.baits: bait.active=false
	var events: Array=[{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}]
	game.advance_tick({}, {"net_events":events,"auto_net":false})
	check(game.net_state=="warning" and not game.net_action.observing and game.net_action.age is float and game.net_action.age==0.0,"same-tick toggle/A/B retains float age at commit")
	for tick in 120:
		if tick%30==0:
			var packet:=Protocol.unpack_state(Protocol.pack_state(FishWire.capture(game)))
			check(FishWire.valid(receiver,packet) and FishWire.apply(receiver,packet),"compressed fish wire accepts same-tick committed net tick "+str(tick))
			check(receiver.restore_snapshot(game.capture_snapshot()) and AnglerWire.valid(receiver,AnglerWire.capture(game)),"authority and angler paths retain batched-net acceptance")
			var malformed:=packet.duplicate(true); malformed.state.net_action.age=0
			var before: Dictionary=receiver.capture_snapshot()
			check(not FishWire.apply(receiver,malformed) and receiver.capture_snapshot()==before,"malformed integer age still fails fish guard before mutation")
		game.advance_tick({}, {"auto_net":false})
	game.free(); receiver.free()

# This independent pre-abstraction node oracle deliberately retains the literal
# filter; production must derive it from the selected map rather than import it.
func legacy_route_nodes(anchor: Vector2, obstacles: Array) -> Array[Vector2]:
	var nodes: Array[Vector2]=[anchor]
	for solid: Dictionary in obstacles:
		var polygon:=PackedVector2Array(solid.points)
		for index in polygon.size():
			var vertex:=polygon[index]
			var incoming: Vector2=(vertex-polygon[posmod(index-1,polygon.size())]).normalized()
			var outgoing: Vector2=(polygon[(index+1)%polygon.size()]-vertex).normalized()
			var first:=Vector2(incoming.y,-incoming.x)
			var second:=Vector2(outgoing.y,-outgoing.x)
			var bisector: Vector2=(first+second).normalized()
			var point: Vector2=vertex+bisector*(1.5/maxf(0.16,bisector.dot(first)))
			if point.y>309 or point.x<9 or point.x>631: continue
			var buried:=false
			for other: Dictionary in obstacles:
				if Geometry2D.is_point_in_polygon(point,PackedVector2Array(other.points)): buried=true; break
			if not buried: nodes.append(point)
	return nodes

func route_obstacle(rect: Rect2) -> Array:
	return [{"points":[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]}]

func rope_routing_policy() -> void:
	var pond: RefCounted=Context.load_map().context
	var game:=world(0)
	var pond_limits:=Rope.routing_limits(pond)
	var fixture_limits:=Rope.routing_limits(game.map_context)
	check(pond_limits==Vector3(9,631,309),"pond detour limits remain exactly the inherited western/shallow policy")
	check(fixture_limits.x==43 and fixture_limits.y<400 and fixture_limits.z<240,"detour policy derives from shifted and smaller fixture water")
	# Full golden routes recorded from unchanged 7efe59b-era Rope before the
	# parameterization. Node filtering/order also uses the independent old oracle.
	var cases: Array=[
		[Rect2(80,200,20,30),PackedVector2Array([Vector2(50,215),Vector2(78.5,198.5),Vector2(101.5,198.5),Vector2(130,215)])],
		[Rect2(460,150,30,40),PackedVector2Array([Vector2(430,170),Vector2(458.5,148.5),Vector2(491.5,148.5),Vector2(520,170)])],
		[Rect2(220,240,40,30),PackedVector2Array([Vector2(190,255),Vector2(218.5,238.5),Vector2(261.5,238.5),Vector2(290,255)])],
	]
	for entry: Array in cases:
		var rect: Rect2=entry[0]
		var obstacles:=route_obstacle(rect)
		var anchor:=Vector2(rect.position.x-30,rect.get_center().y)
		var end:=Vector2(rect.end.x+30,rect.get_center().y)
		check(Rope.solve(anchor,end,obstacles,pond_limits)==entry[1],"pond route/tie-break output matches frozen literal-limit oracle "+str(rect))
		check(Rope._fixed_nodes==legacy_route_nodes(anchor,obstacles),"pond detour node values/order match independent old formula "+str(rect))
		check(Rope.solve(anchor,end,obstacles,fixture_limits)==(entry[1] if rect==Rect2(80,200,20,30) else PackedVector2Array()),"fixture excludes nodes outside its own routing policy "+str(rect))
		check(Rope._cache_limits==fixture_limits,"same obstacle hash and anchor cannot reuse another map's filtered-node cache")
		check(Rope.solve(anchor,end,obstacles,pond_limits)==entry[1] and Rope._fixed_nodes==legacy_route_nodes(anchor,obstacles),"pond cache re-entry restores its exact route and ordered nodes")
	# A translated-water map supplies a positive witness beyond BOTH historical
	# x=631 and y=309 cutoffs; this does not register a playable extra map.
	var shifted:=Fixture.create()
	var offset:=Vector2(700,100)
	shifted.meta.id="fixture_shifted_routing"
	shifted.bounds.size+=offset; shifted.bounds.floor_y+=offset.y
	shifted.bounds.water.position+=offset; shifted.bounds.net_area.position+=offset
	for index in shifted.bounds.vegetation_drag_zones.size(): shifted.bounds.vegetation_drag_zones[index].position+=offset
	shifted.anchors.home+=offset; shifted.anchors.player_spawn+=offset
	for index in shifted.bait_sites.size(): shifted.bait_sites[index]+=offset
	for feature: Dictionary in shifted.interaction_features:
		for index in feature.shape.points.size(): feature.shape.points[index]+=offset
	shifted.meta.content_hash=Definition.content_hash(shifted)
	var loaded:=Context.from_definition(shifted)
	check(loaded.valid,"translated-water routing fixture validates without registration")
	if loaded.valid:
		var shifted_limits:=Rope.routing_limits(loaded.context)
		var obstacles:=route_obstacle(Rect2(940,312,30,18))
		var anchor:=Vector2(910,321); var end:=Vector2(1000,321)
		check(Rope.solve(anchor,end,obstacles,pond_limits).is_empty(),"old window demonstrably rejects translated obstacle")
		var route:=Rope.solve(anchor,end,obstacles,shifted_limits)
		check(route.size()==4 and route[1].x>631 and route[1].y>309,"selected shifted map admits valid detour nodes past both old cutoffs")
		check(not route.is_empty() and route[0]==anchor and route[-1]==end,"translated detour retains endpoints and complete route")
		var all_clear:=not route.is_empty()
		for index in range(1,route.size()): all_clear=all_clear and Rope.clear(route[index-1],route[index],obstacles)
		check(all_clear,"translated route remains collision-clear under unchanged silhouette solver")
		check(Rope.solve(anchor,end,obstacles,pond_limits).is_empty() and Rope.solve(anchor,end,obstacles,shifted_limits)==route,"same geometry/anchor cache isolates both maps in both directions")
	# Real production call follows the same selected policy when direct net lift
	# is obstructed. Fixture bottom detour nodes are outside its shallow window.
	check(game.Net._manual_net_exit(game,Vector2(314,287)).is_empty() and Rope._cache_limits==fixture_limits,"obstructed fixture net exit passes its map policy into Rope.solve")
	game.free()
