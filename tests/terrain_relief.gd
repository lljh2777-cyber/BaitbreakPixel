extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Validator=preload("res://scripts/maps/map_validator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const Bed=preload("res://scripts/maps/pond_bed.gd")
const Adapter=preload("res://scripts/watergen/watergen_public_adapter.gd")
var generator_version:=2
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("RELIEF_FAIL | "+label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# Independent polygon distance oracle verifies circle clearance at vertices
	# and slopes, not just the height at the circle centre.
	var ramp:=PackedVector2Array([Vector2(0,420),Vector2(160,340),Vector2(320,420)])
	var poly:=Bed.polygon(ramp,Vector2(320,480))
	for radius in [2.0,12.0,17.0,26.0]:
		for x in range(32,289,7):
			var p:=Vector2(x,Bed.limit(ramp,x,radius))
			check(absf(World.MapGeometry.nearest_boundary(p,poly).distance_to(p)-radius)<0.001,"circle tangent to real slope")
	for seed in [0,1,2,6,8,9,42,64,144,296,1346,2166,73501,123456789,2147483647]:
		var result:=Generator.generate(Request.create(seed,generator_version))
		check(result.valid,"generate relief %d: %s" % [seed,str(result.errors)])
		if not result.valid:
			print(result.diagnostics)
			continue
		var again:=Generator.generate(Request.create(seed,generator_version))
		check(var_to_bytes(result.definition)==var_to_bytes(again.definition),"versioned deterministic geometry")
		var forged: Dictionary=result.definition.duplicate(true)
		forged.bounds.floor_profile[8].y-=1
		check(not Validator.validate(forged).valid,"terrain participates in content identity")
		forged.meta.content_hash=Definition.content_hash(forged)
		check(Validator.validate(forged).valid,"legal edited terrain validates with new identity")
		forged.bounds.floor_profile[8].x=forged.bounds.floor_profile[7].x
		check(not Validator.validate(forged).valid,"vertical/duplicate segments rejected")
		var g:=World.new()
		check(g.reset_world({"map_source":Resolver.generated(seed,generator_version),"seed":423,"challenge":true,"rules":{"hunger_enabled":false,"timer_enabled":false}}),"real world installs relief")
		var context: RefCounted=g.map_context
		check(context.has_relief and context.contract_version==2 and g.npc_fishes.size()==3,"terrain and NPC setup")
		check(context.floor_at(60)==433 and not context.bed_blocked(context.home,20),"home stays clear")
		var exported: PackedVector2Array=context.floor_profile
		exported[0].y=0
		check(context.floor_at(0)==433,"heightfield getter detached")
		var public_map:=Adapter.build(context)
		check(Adapter.Contract.validate(public_map).ok and public_map.schema_version==3,"public ground is validated data")
		for x in range(32,1249,32):
			g.fish=Vector2(x,250)
			g.move_fish(Vector2(0,300))
			check(not context.bed_blocked(g.fish,12),"fish cannot dive through ground")
			check(g.Net.manual_net_blocked(g,Vector2(x,context.floor_at(x)-5)),"net footprint stops on bed")
			var point:=Vector2(x,context.floor_at(x)-1)
			var blocked:=g.Net._manual_net_lane_clear(g,point,point+Vector2(30,0))
			check(not blocked,"net preview rejects buried sweep")
		# A long movement crosses multiple crests without tunnelling.
		g.fish=Vector2(170,410); g.move_fish(Vector2(950,0))
		check(not context.bed_blocked(g.fish,12) and g.fish.y<380,"swept movement climbs rather than crosses ground")
		for x in [160,360,560,760,960,1140]:
			check(g.Net._manual_net_exit(g,Vector2(x,175)).size()>=2,"clear net lift to surface")
		# Test actual detached food drift and tackle sinking at a crest.
		var peak:=Vector2(0,480)
		for p: Vector2 in context.floor_profile:
			if p.y<peak.y: peak=p
		var bait: Dictionary=g.baits[0]
		var grain: Dictionary=bait.grains[0]
		grain.free=true; grain.eaten=false; grain.pos=peak+Vector2(0,20)
		g._step_bait(0,1.0/60,false,g.mouth())
		check(not context.bed_blocked(grain.pos,2),"free food rests above slope")
		g.fish=context.player_spawn
		for tick in 360:
			g.advance_tick({"move":Vector2.RIGHT if tick<240 else Vector2.DOWN,"aim":Vector2.RIGHT},{})
			check(not context.bed_blocked(g.fish,12),"live fish stays outside ground")
			for npc: Dictionary in g.npc_fishes:
				check(not context.bed_blocked(npc.position,World.NPCFishState.RADIUS),"NPC stays outside ground")
		var copy:=World.new(); copy.reset_world()
		check(copy.restore_snapshot(g.capture_snapshot()),"snapshot rebuilds versioned terrain")
		check(copy.map_context.map_ref==context.map_ref and copy.capture_snapshot()==g.capture_snapshot(),"restored authority is exact")
		copy.free(); g.free()
	var legacy:=Resolver.resolve(Resolver.generated(42,1))
	check(legacy.valid and not legacy.context.has_relief and legacy.context.contract_version==1,"v1 remains available")
	for bad_version in [true,"2",{},[]]:
		var request:=Request.create(42,2); request.generator_version=bad_version
		check(not Request.validate(request).valid,"bad recipe version type rejected cleanly")
		var public_map:=Adapter.build(legacy.context); public_map.schema_version=bad_version
		check(not Adapter.Contract.validate(public_map).ok,"bad public version type rejected cleanly")
	print("TERRAIN_RELIEF | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
