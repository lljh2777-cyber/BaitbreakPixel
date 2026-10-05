extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Fish=preload("res://scripts/fish_network_observation.gd")
const Angler=preload("res://scripts/angler_network_observation.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATED_SNAPSHOT_FAIL | "+label)
func _initialize()->void:
	for seed:int in [0,42,2166,1346,296,2147483647]:
		var g:=World.new(); var copy:=World.new()
		check(g.reset_world({"map_source":Resolver.generated(seed),"seed":5417,"npc_count":3,"ruleset":"duel"}),"generated world")
		for tick in 120: g.advance_tick({"move":Vector2.RIGHT,"suck":true},{"walk":0.3})
		var saved:Dictionary=g.capture_snapshot()
		check(saved.schema==17 and saved.map_source==Resolver.generated(seed) and saved.size()==8,"schema17 recipe envelope")
		Resolver._contexts.clear() # Simulates cold startup, not just same-process cache reuse.
		check(copy.restore_snapshot(saved) and copy.capture_snapshot()==saved,"cold regeneration restores entire authority")
		for tick in 120:
			var command:Dictionary={"move":Vector2.RIGHT.rotated(tick*0.03),"suck":tick%40<20,"bite":tick%30==0}
			g.advance_tick(command,{}); copy.advance_tick(command,{})
		check(g.capture_snapshot()==copy.capture_snapshot(),"restored gameplay and all RNG continue exactly")
		for mutation:String in ["seed","generator","version","profile","hash","missing-source","missing-ref","null-ref","geometry","visual-seed","old-schema","named-kind"]:
			var bad:Dictionary=saved.duplicate(true)
			match mutation:
				"seed": bad.map_source.map_seed=1
				"generator": bad.map_source.generator_id="unknown"
				"version": bad.map_source.generator_version=2
				"profile": bad.map_source.gameplay_profile="unknown"
				"hash": bad.map_ref.content_hash="0".repeat(64)
				"missing-source": bad.erase("map_source")
				"missing-ref": bad.erase("map_ref")
				"null-ref": bad.map_ref=null
				"geometry": bad.map_source["polygons"]=[]
				"visual-seed": bad.map_source["visual_seed"]=4
				"old-schema": bad.schema=16
				"named-kind": bad.map_source.kind=&"generated"
			var before:PackedByteArray=var_to_bytes(copy.capture_snapshot()); var context:RefCounted=copy.map_context
			check(not copy.restore_snapshot(bad) and var_to_bytes(copy.capture_snapshot())==before and copy.map_context==context,"atomic reject "+mutation)
		for wire in [Fish,Angler]:
			var public:Dictionary=wire.capture(g)
			check(wire.apply(copy,public) and copy.map_context.map_source==g.map_context.map_source,"both public roles resolve generated source")
			if wire==Fish: check(not public.has("rng_state") and not public.state.baits[0].has("hook"),"recipe adds no fish hook truth or RNG")
			var before:PackedByteArray=var_to_bytes(copy.capture_snapshot())
			public.map_source.map_seed=1
			check(not wire.apply(copy,public) and var_to_bytes(copy.capture_snapshot())==before,"public source mismatch is atomic")
		g.free(); copy.free()
	print("PHASE05_SNAPSHOT | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
