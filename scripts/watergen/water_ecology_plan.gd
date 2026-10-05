extends RefCounted
## WG-6.2: read-only public geometry -> decorative communities, never targets.
## No VisualTerrainPlan dependency: roots follow the installed generated map.
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Seed = preload("res://scripts/watergen/water_visual_seed.gd")
const VERSION := "wg-6.2-flora-v1"
const KINDS := ["filament_algae", "carpet_algae", "low_grass", "broad_leaf", "moss_patch", "branch_algae"]
const DENSITIES := ["low", "medium", "high"]
const MAX_PATCHES := 128

static func stream(seed: int, habitat: String, index: int) -> RandomNumberGenerator:
	return Seed.stream(seed, "flora", VERSION + "/" + habitat, index)

static func polygon(record: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in record.polygon_px: result.append(Vector2(p[0], p[1]))
	return result

static func surface(record: Dictionary, x: float, underside := false) -> float:
	var points := polygon(record)
	var hits: Array[float] = []
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		if is_equal_approx(a.x, b.x): continue
		if x < minf(a.x, b.x) or x > maxf(a.x, b.x): continue
		hits.append(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	if hits.is_empty(): return NAN
	hits.sort()
	return hits[-1] if underside else hits[0]

static func quiet_regions(map: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for region: Dictionary in map.protected_regions:
		var r: Array = region.rect_px
		result.append(Rect2(r[0], r[1], r[2], r[3]).grow(20 if region.purpose == "candidate_bait" else 40))
	# A visual clear band, not new Authority geometry or a navigation constraint.
	result.append(Rect2(140, 120, 1040, 145))
	return result

static func footprint(patch: Dictionary) -> Rect2:
	var root := Vector2(patch.root_px[0], patch.root_px[1])
	var width: float = patch.width + 10.0
	return Rect2(root.x - width * 0.5, root.y - patch.height - 3 if patch.growth < 0 else root.y - 3, width, patch.height + 9)

static func _append(plan: Dictionary, community: Dictionary, kind: String, root: Vector2, seed: int, slot: int, quiet: Array[Rect2], growth := -1) -> void:
	var rng := stream(seed, community.id + "/" + kind, slot)
	var width: float = rng.randf_range(22, 42)
	var height: float = rng.randf_range(18, 31)
	match kind:
		"broad_leaf": width = rng.randf_range(29, 46); height = rng.randf_range(35, 61)
		"carpet_algae": width = rng.randf_range(36, 64); height = rng.randf_range(4, 8)
		"moss_patch": width = rng.randf_range(15, 29); height = rng.randf_range(5, 10); growth = 1
		"branch_algae": width = rng.randf_range(15, 26); height = rng.randf_range(12, 23)
	var patch := {"id": community.id + "/" + kind + "/" + str(slot), "community_id": community.id, "habitat": community.habitat, "kind": kind, "root_px": [root.x, root.y], "width": width, "height": height, "growth": growth, "anchor_target": community.anchor_target, "density": community.density, "phase": rng.randf_range(0, TAU), "seed": int(rng.seed), "clip_polygon_px": community.get("clip_polygon_px", []).duplicate(true)}
	var bounds := footprint(patch)
	if bounds.position.x < 8 or bounds.end.x > 1272 or bounds.position.y < 70 or bounds.end.y > 477: return
	for region in quiet:
		if bounds.intersects(region): return
	if plan.patches.size() < MAX_PATCHES:
		plan.patches.append(patch)
		community.patch_ids.append(patch.id)

static func _community(plan: Dictionary, id: String, habitat: String, anchor: int, density: String) -> Dictionary:
	var result := {"id": id, "habitat": habitat, "anchor_target": anchor, "density": density, "patch_ids": []}
	plan.communities.append(result)
	return result

static func generate(map: Variant, visual_seed: Variant, density := "medium") -> Dictionary:
	if not Seed.valid(visual_seed) or density not in DENSITIES: return {"ok": false, "code": "FLORA_SETTINGS"}
	if not Map.validate(map).ok or map.world_size_px != [1280, 480]: return {"ok": false, "code": "PUBLIC_MAP"}
	var plan := {"format": "baitbreak-decorative-ecology-plan", "version": VERSION, "map_id": map.map_id, "visual_seed": visual_seed, "density": density, "world_size_px": [1280, 480], "communities": [], "patches": []}
	var quiet := quiet_regions(map)
	var count: int = {"low": 1, "medium": 2, "high": 3}[density]
	var solids: Array[Rect2] = []
	for record: Dictionary in map.static_cover_records:
		var target: int = record.legacy_target_index
		var r: Array = record.bounds_px
		var bounds := Rect2(r[0], r[1], r[2], r[3])
		if record.kind != "grass": solids.append(bounds)
		if record.kind == "grass":
			var group := _community(plan, "grass-edge/" + str(target), "grass_edge", -1, "medium")
			for side in [-1, 1]:
				var root := Vector2(bounds.get_center().x + side * (bounds.size.x * 0.5 + 14), map.floor_y_px)
				_append(plan, group, "low_grass", root, visual_seed, side + 1, quiet)
				if count >= 2: _append(plan, group, "filament_algae", root + Vector2(side * 7, 1), visual_seed, side + 1, quiet)
			continue
		var habitat: String = "stone" if record.kind == "stone" else "wood"
		var group := _community(plan, habitat + "/" + str(target), habitat, target, "high")
		group["clip_polygon_px"] = record.polygon_px.duplicate(true)
		# Fixed slots give density changes a stable prefix rather than moving roots.
		for slot in count:
			var rng := stream(visual_seed, group.id + "/anchor", slot)
			var u: float = [0.45, 0.72, 0.24][slot] + rng.randf_range(-0.045, 0.045)
			var x := bounds.position.x + bounds.size.x * u
			var y := surface(record, x)
			if not is_finite(y): continue
			_append(plan, group, "moss_patch", Vector2(x, y + 1), visual_seed, slot, quiet)
			if habitat == "wood":
				_append(plan, group, "branch_algae", Vector2(x, y), visual_seed, slot, quiet)
				var bottom := surface(record, x, true)
				if bottom < map.floor_y_px - 40:
					_append(plan, group, "filament_algae", Vector2(x, bottom), visual_seed, slot, quiet, 1)
	# Derive bed openings from actual stone/wood footprints. No invented hills.
	solids.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
	var gaps: Array[Vector2] = []
	var cursor := 145.0
	for solid in solids:
		var left := maxf(145, solid.position.x - 14)
		if left - cursor >= 40: gaps.append(Vector2(cursor, left))
		cursor = maxf(cursor, solid.end.x + 14)
	if cursor < 1215: gaps.append(Vector2(cursor, 1260))
	for index in gaps.size():
		var gap := gaps[index]
		var middle := (gap.x + gap.y) * 0.5
		var band := "low" if middle > 460 and middle < 860 else "high" if middle < 460 else "medium"
		var group := _community(plan, "bed-gap/" + str(index), "bed", -1, band)
		var sites := mini(count + 1, maxi(1, int((gap.y - gap.x) / 90)))
		for slot in sites:
			var rng := stream(visual_seed, group.id + "/anchor", slot)
			var x := lerpf(gap.x + 20, gap.y - 20, (slot + 0.5) / sites) + rng.randf_range(-5, 5)
			var root := Vector2(x, map.floor_y_px + 2)
			_append(plan, group, "carpet_algae", root, visual_seed, slot, quiet)
			_append(plan, group, "low_grass", root + Vector2(-9, -2), visual_seed, slot, quiet)
			if band != "low" or slot == 0: _append(plan, group, "broad_leaf", root + Vector2(12, -2), visual_seed, slot, quiet)
	# Reject grass-edge offshoots that land inside unrelated real solid silhouettes.
	var kept: Array = []
	for patch: Dictionary in plan.patches:
		var blocked := false
		if patch.habitat == "grass_edge":
			for record: Dictionary in map.static_cover_records:
				if record.kind != "grass" and Geometry2D.is_point_in_polygon(Vector2(patch.root_px[0], patch.root_px[1] - 2), polygon(record)): blocked = true
		if not blocked: kept.append(patch)
		else:
			for group: Dictionary in plan.communities:
				if group.id == patch.community_id: group.patch_ids.erase(patch.id)
	plan.patches = kept
	plan.communities = plan.communities.filter(func(group: Dictionary): return not group.patch_ids.is_empty())
	return {"ok": true, "plan": plan}
