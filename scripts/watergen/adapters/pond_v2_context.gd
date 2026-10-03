extends RefCounted
## This adapter is the only watergen contract component allowed to read Layout.
const Layout = preload("res://scripts/pond_layout.gd")
const Contract = preload("res://scripts/watergen/public_map_context.gd")

static func point(value: Vector2) -> Array:
	return [int(value.x) if value.x == floor(value.x) else value.x, int(value.y) if value.y == floor(value.y) else value.y]

static func rectangle(value: Rect2) -> Array:
	return point(value.position) + point(value.size)

static func authority_bytes() -> PackedByteArray:
	return var_to_bytes([Layout.SIZE, Layout.FLOOR, Layout.HOME, Layout.SPAWN, Layout.WATER, Layout.NET_AREA, Layout.BAIT_SITES, Layout.SOLIDS, Layout.PLANTS, Layout.GRASS, Layout.WOOD_GROUPS, Layout.interaction_targets()])

static func build(source_commit: String) -> Dictionary:
	var covers: Array = []
	var targets := Layout.interaction_targets()
	for index in targets.size():
		var target: Dictionary = targets[index]
		var polygon: Array = []
		for vertex in target.polygon: polygon.append(point(vertex))
		var source: Dictionary = {}
		if index < Layout.SOLIDS.size():
			var solid: Dictionary = Layout.SOLIDS[index]
			source = {"seed": int(solid.seed), "name": String(solid.get("name", ""))}
		else:
			var plant: Dictionary = Layout.PLANTS[index - Layout.SOLIDS.size()]
			for key in ["x", "y", "height", "width", "kind", "stems", "back"]: source[key] = plant[key]
		covers.append({"legacy_target_index": index, "kind": String(target.kind), "polygon_px": polygon, "bounds_px": rectangle(target.bounds), "fade_group": int(target.get("fade_group", index)), "source": source})
	var bait_sites: Array = []
	var grass_rects: Array = []
	var protected: Array = [
		{"purpose": "home", "rect_px": rectangle(Rect2(Layout.HOME - Vector2(32, 32), Vector2(64, 64)))},
		{"purpose": "spawn", "rect_px": rectangle(Rect2(Layout.SPAWN - Vector2(24, 24), Vector2(48, 48)))}]
	for site in Layout.BAIT_SITES:
		bait_sites.append(point(site))
		protected.append({"purpose": "candidate_bait", "rect_px": rectangle(Rect2(site - Vector2(24, 24), Vector2(48, 48)))})
	for rect in Layout.GRASS: grass_rects.append(rectangle(rect))
	var context := {
		"format": "baitbreak-public-map-context", "schema_version": 1, "map_id": "pond_v2", "source_commit": source_commit,
		"world_size_px": point(Layout.SIZE), "viewport_size_px": [640, 360], "water_rect_px": rectangle(Layout.WATER),
		"floor_y_px": int(Layout.FLOOR), "visual_surface_y_px": 55, "home_px": point(Layout.HOME), "spawn_px": point(Layout.SPAWN),
		"net_area_px": rectangle(Layout.NET_AREA), "bait_sites_px": bait_sites, "legacy_grass_rects_px": grass_rects,
		"wood_groups": Layout.WOOD_GROUPS.duplicate(true), "static_cover_records": covers, "protected_regions": protected}
	context["map_public_digest"] = Contract.digest(context)
	return context
