extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Adapter=preload("res://scripts/watergen/watergen_public_adapter.gd")
const Generator=preload("res://scripts/watergen/water_dynamic_generator.gd")
const Terrain=preload("res://scripts/watergen/water_visual_terrain.gd")
const Fish=preload("res://scripts/fish_brain.gd")
const Angler=preload("res://scripts/angler_brain.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("WATERGEN_BOUNDARY_FAIL | "+label)
func _initialize()->void:
	var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	var terrain:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/terrain_profiles.json")).fern
	for map_seed:int in [42,1346,2166]:
		var a:=World.new(); var b:=World.new()
		var config:Dictionary={"map_source":Resolver.generated(map_seed),"seed":73501,"challenge":true}
		check(a.reset_world(config) and b.reset_world(config),"same map and simulation seeds")
		var before:PackedByteArray=var_to_bytes(a.capture_snapshot())
		var public:=Adapter.build(a.map_context)
		check(Adapter.Contract.validate(public).ok,"generalized public contract accepts generated map")
		check(public.keys()==Adapter.Contract.KEYS,"strict public map allowlist excludes world/actor secrets")
		for record:Dictionary in public.static_cover_records:
			var target:Dictionary=a.targets[record.legacy_target_index]
			check(record.kind==target.kind and record.polygon_px.size()==target.polygon.size(),"cover targets match authority")
			for index in record.polygon_px.size(): check(record.polygon_px[index]==Adapter.point(target.polygon[index]),"exact visual interaction silhouette")
		var one:=Generator.generate(public,profile,42)
		var two:=Generator.generate(public,profile,713284)
		check(one.ok and two.ok and one.plan.layers!=two.plan.layers,"visual seed changes scenery")
		check(Generator.generate(public,profile,42)==one,"visual stream deterministic")
		check(Terrain.generate(public,terrain,42).ok,"relief uses public map")
		check(before==var_to_bytes(a.capture_snapshot()),"visual generation preserves every authority field and RNG")
		var players:Array=[Fish.new(),Fish.new()]; var opponent:=Angler.new()
		for player in players: player.reset(73674)
		var identical:=true
		for tick in 22200:
			if a.match_over: break
			a.advance_tick(players[0].command(a,World.TICK_SECONDS),opponent.command(a,World.TICK_SECONDS))
			b.advance_tick(players[1].command(b,World.TICK_SECONDS),opponent.command(b,World.TICK_SECONDS))
			# Full state includes main and NPC RNG, hook assignments and realized events.
			if tick%60==0: identical=identical and a.capture_snapshot()==b.capture_snapshot()
		check(a.match_over and b.match_over and identical and a.capture_snapshot()==b.capture_snapshot(),"different visual seeds preserve complete round and RNG evolution")
		a.free(); b.free()
	print("PHASE05_WATERGEN_BOUNDARY | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
