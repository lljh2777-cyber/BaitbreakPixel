extends SceneTree
const Resolver = preload("res://scripts/maps/map_resolver.gd")
const Adapter = preload("res://scripts/watergen/watergen_public_adapter.gd")
const Plan = preload("res://scripts/watergen/water_ecology_plan.gd")
const Baker = preload("res://scripts/watergen/water_ecology_baker.gd")
const Atmosphere = preload("res://scripts/watergen/water_dynamic_generator.gd")
const World = preload("res://scripts/world_simulation.gd")
const Fish = preload("res://scripts/fish_brain.gd")
const Angler = preload("res://scripts/angler_brain.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG62_CONTRACT_PASS | ", label)
	else: failed += 1; push_error("WG62_CONTRACT_FAIL | " + label)

func plain(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not key is String or not plain(value[key]): return false
		return true
	if value is Array:
		for item in value:
			if not plain(item): return false
		return true
	return value is String or value is int or value is bool or (value is float and is_finite(value))

func run() -> void:
	var all_species: Dictionary = {}
	var previous_roots: Array = []
	for seed: int in [42, 2166, 1346, 296, 0, 2147483647]:
		var context: RefCounted = Resolver.resolve(Resolver.generated(seed)).context
		var before: Array = [context.interaction_targets, context.net_blockers, context.vegetation_drag_zones, context.bait_sites, context.map_ref, context.map_source]
		var public := Adapter.build(context)
		var input_bytes := var_to_bytes(public)
		var result := Plan.generate(public, 713284)
		check(result.ok and plain(result.plan), "pure-value flora plan " + str(seed))
		check(result == Plan.generate(public, 713284), "repeat plan " + str(seed))
		check(result.plan.patches != Plan.generate(public, 42).plan.patches, "visual seed changes flora without map change " + str(seed))
		var anchors_ok := true
		var zones_ok := true
		var roots: Array = []
		for patch: Dictionary in result.plan.patches:
			all_species[patch.kind] = true
			roots.append(patch.root_px)
			for rect in Plan.quiet_regions(public): zones_ok = zones_ok and not Plan.footprint(patch).intersects(rect)
			if patch.anchor_target >= 0:
				var record: Dictionary = public.static_cover_records[patch.anchor_target]
				var y := Plan.surface(record, patch.root_px[0], patch.kind == "filament_algae" and patch.growth == 1)
				anchors_ok = anchors_ok and absf(patch.root_px[1] - y - (1 if patch.kind == "moss_patch" else 0)) < 0.01
				anchors_ok = anchors_ok and record.kind in ["wood", "stone"]
			else: anchors_ok = anchors_ok and absf(patch.root_px[1] - context.floor_y) <= 2
		check(anchors_ok, "roots lie on real polygon surfaces or true floor " + str(seed))
		check(zones_ok, "complete plant footprint avoids public clear zones " + str(seed))
		check(result.plan.patches.size() > 8 and result.plan.patches.size() <= Plan.MAX_PATCHES, "nonempty bounded communities " + str(seed))
		if not previous_roots.is_empty(): check(roots != previous_roots, "different authority map repositions communities")
		previous_roots = roots
		var sparse: Dictionary = Plan.generate(public, 713284, "low").plan
		var dense: Dictionary = Plan.generate(public, 713284, "high").plan
		check(sparse.patches.size() <= result.plan.patches.size() and result.plan.patches.size() <= dense.patches.size(), "density increases within budget " + str(seed))
		var baked := Baker.bake(result.plan)
		var repeat := Baker.bake(Plan.generate(public, 713284).plan)
		check(baked.ok and baked.image.get_data() == repeat.image.get_data(), "RGBA repeat by direct bytes " + str(seed))
		check(baked.image.get_width() == 1024 and baked.image.get_height() <= 2048, "one bounded atlas " + str(seed))
		var moss_clipped := true
		for patch: Dictionary in baked.patches:
			if patch.kind != "moss_patch": continue
			var r: Array = patch.region_px
			var polygon := Plan.polygon(public.static_cover_records[patch.anchor_target])
			for y in range(r[3]):
				for x in range(r[2]):
					if baked.image.get_pixel(r[0] + x, r[1] + y).a > 0:
						moss_clipped = moss_clipped and Geometry2D.is_point_in_polygon(Vector2(x + patch.origin_px[0], y + patch.origin_px[1]), polygon)
		check(moss_clipped, "moss stays within existing stone/wood silhouette " + str(seed))
		check(var_to_bytes(public) == input_bytes and before == [context.interaction_targets, context.net_blockers, context.vegetation_drag_zones, context.bait_sites, context.map_ref, context.map_source], "targets/order/net/drag/baits/source and public inputs unchanged " + str(seed))
	check(all_species.size() == 6, "six intended plant categories represented")
	var map := Adapter.build(Resolver.resolve(Resolver.generated(42)).context)
	for seed in [-1, 2147483648, 42.0, "42", null]: check(not Plan.generate(map, seed).ok, "bad visual seed rejected")
	check(not Plan.generate(map, 42, "enormous").ok and not Plan.generate({}, 42).ok, "bad density/map rejected")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	var atmosphere := Atmosphere.generate(map, profile, 713284)
	Plan.generate(map, 713284, "high")
	check(atmosphere == Atmosphere.generate(map, profile, 713284), "flora density does not perturb existing atmosphere streams")
	# Exercise real gameplay commands with flora generated on only one side.
	var a := World.new(); var b := World.new()
	var config := {"map_source": Resolver.generated(42), "seed": 73501, "challenge": true}
	check(a.reset_world(config) and b.reset_world(config), "paired true generated worlds reset")
	var players := [Fish.new(), Fish.new()]
	var opponent := Angler.new()
	for player in players: player.reset(73674)
	var same := true
	for tick in 1800:
		if tick % 300 == 0:
			var before := a.capture_snapshot()
			Plan.generate(Adapter.build(a.map_context), 713284 + tick, ["low", "medium", "high"][(tick / 300) % 3])
			same = same and a.capture_snapshot() == before
		a.advance_tick(players[0].command(a, World.TICK_SECONDS), opponent.command(a, World.TICK_SECONDS))
		b.advance_tick(players[1].command(b, World.TICK_SECONDS), opponent.command(b, World.TICK_SECONDS))
		same = same and a.capture_snapshot() == b.capture_snapshot()
	check(same, "1800 real gameplay ticks preserve full state, NPC/world RNG, hooks, winding, net and score")
	a.free(); b.free()
	print("WG62_CONTRACT | passed=%d | failed=%d" % [passed, failed])
	quit(1 if failed else 0)
