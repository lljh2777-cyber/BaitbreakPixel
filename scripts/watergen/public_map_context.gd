extends RefCounted
## Pure-value public map contract. No Layout, world, scene or RNG dependency.
const KEYS := ["format", "schema_version", "map_id", "source_commit", "world_size_px", "viewport_size_px", "water_rect_px", "floor_y_px", "visual_surface_y_px", "home_px", "spawn_px", "net_area_px", "bait_sites_px", "legacy_grass_rects_px", "wood_groups", "static_cover_records", "protected_regions", "map_public_digest"]

static func floor_at(map: Dictionary, x: float) -> float:
	var points: Array=map.get("floor_profile_px",[])
	if points.is_empty(): return map.floor_y_px
	for i in range(points.size()-1):
		if x<=points[i+1][0]: return lerpf(points[i][1],points[i+1][1],clampf((x-points[i][0])/(points[i+1][0]-points[i][0]),0,1))
	return points[-1][1]

static func canonical(value: Variant) -> String:
	return JSON.stringify(_numbers(value), "", true, true)

static func _numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Array:
		var result: Array = []
		for item in value: result.append(_numbers(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _numbers(value[key])
		return result
	return value

static func digest(context: Dictionary) -> String:
	var fields := context.duplicate(true)
	fields.erase("source_commit")
	fields.erase("map_public_digest")
	return canonical(fields).sha256_text()

static func _keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 100000.0

static func _vector(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size: return false
	for item in value:
		if not _number(item): return false
	return true

static func _rect(value: Variant) -> bool:
	return _vector(value, 4) and value[2] > 0 and value[3] > 0

static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length: return false
	for index in value.length():
		if not value[index] in "0123456789abcdef": return false
	return true

static func _error(code: String) -> Dictionary:
	return {"ok": false, "code": code, "diagnostic": "PublicMapContext rejected: " + code}

static func validate(value: Variant) -> Dictionary:
	var fields:=KEYS.duplicate()
	if value is Dictionary and value.get("schema_version") is int and value.schema_version==3: fields.append("floor_profile_px")
	if not _keys(value, fields): return _error("FIELDS")
	if value.format != "baitbreak-public-map-context" or not value.schema_version is int or value.schema_version not in [2,3] or not value.map_id is String or value.map_id.is_empty() or value.map_id.length()>64: return _error("VERSION")
	if not _hex(value.source_commit, 40) or not _hex(value.map_public_digest, 64): return _error("METADATA")
	for key in ["world_size_px", "viewport_size_px"]:
		if not _vector(value[key], 2): return _error("SIZE")
		for item in value[key]:
			if not item is int or item <= 0 or item > 8192: return _error("SIZE")
	for index in 2:
		if value.viewport_size_px[index] > value.world_size_px[index]: return _error("VIEWPORT")
	for key in ["water_rect_px", "net_area_px"]:
		if not _rect(value[key]): return _error("RECT")
	for key in ["floor_y_px", "visual_surface_y_px"]:
		if not _number(value[key]) or value[key] < 0 or value[key] > value.world_size_px[1]: return _error("HEIGHT")
	for key in ["home_px", "spawn_px"]:
		if not _vector(value[key], 2): return _error("POINT")
	for key in ["bait_sites_px", "legacy_grass_rects_px", "wood_groups", "static_cover_records", "protected_regions"]:
		if not value[key] is Array or value[key].size() > 256: return _error("OBJECT_BUDGET")
	if value.static_cover_records.is_empty(): return _error("EMPTY_MAP")
	for point in value.bait_sites_px:
		if not _vector(point, 2): return _error("BAIT_SITE")
	for rect in value.legacy_grass_rects_px:
		if not _rect(rect): return _error("GRASS_RECT")
	var wood_seeds: Array = []
	for index in value.static_cover_records.size():
		var record: Variant = value.static_cover_records[index]
		if not _keys(record, ["legacy_target_index", "kind", "polygon_px", "bounds_px", "fade_group", "source"]): return _error("COVER_FIELDS")
		if not record.legacy_target_index is int or record.legacy_target_index != index: return _error("TARGET_ORDER")
		if not record.kind in ["wood", "stone", "grass"] or not _rect(record.bounds_px): return _error("COVER")
		if not record.fade_group is int or record.fade_group < 0 or record.fade_group >= value.static_cover_records.size(): return _error("FADE_GROUP")
		if not record.polygon_px is Array or record.polygon_px.size() < 3 or record.polygon_px.size() > 64: return _error("POLYGON")
		for point in record.polygon_px:
			if not _vector(point, 2): return _error("POLYGON_POINT")
		if record.kind == "grass":
			if not _keys(record.source, ["x", "y", "height", "width", "kind", "stems", "back"]): return _error("PLANT_FIELDS")
			for key in ["x", "y", "height", "width", "stems"]:
				if not _number(record.source[key]): return _error("PLANT_NUMBER")
			if record.source.height <= 0 or record.source.width <= 0 or not record.source.stems is int or record.source.stems < 1 or record.source.stems > 64: return _error("PLANT_SIZE")
			if not record.source.back is bool or not record.source.kind in ["ribbon", "fern"]: return _error("PLANT_KIND")
		else:
			if not _keys(record.source, ["seed", "name"]): return _error("SOLID_FIELDS")
			if not record.source.seed is int or record.source.seed < 0 or not record.source.name is String or record.source.name.length() > 64: return _error("SOLID_SOURCE")
			if record.kind == "wood": wood_seeds.append(record.source.seed)
	var grouped: Array = []
	for group in value.wood_groups:
		if not group is Array or group.is_empty() or group.size() > 256: return _error("WOOD_GROUP")
		for seed_value in group:
			if not seed_value is int or not seed_value in wood_seeds or seed_value in grouped: return _error("WOOD_MEMBER")
			grouped.append(seed_value)
	for region in value.protected_regions:
		if not _keys(region, ["purpose", "rect_px"]) or not region.purpose in ["home", "spawn", "candidate_bait"] or not _rect(region.rect_px): return _error("PROTECTED_REGION")
	if value.schema_version==3:
		var points: Variant=value.floor_profile_px
		if not points is Array or points.size()<2 or points.size()>129: return _error("BED_PROFILE")
		for i in points.size():
			if not _vector(points[i],2): return _error("BED_POINT")
			if points[i][1]<value.water_rect_px[1]+120 or points[i][1]>value.floor_y_px: return _error("BED_DEPTH")
			if i>0 and (points[i][0]-points[i-1][0]<8 or absf(points[i][1]-points[i-1][1])>(points[i][0]-points[i-1][0])*0.9): return _error("BED_SLOPE")
		if points[0][0]!=0 or points[-1][0]!=value.world_size_px[0]: return _error("BED_SPAN")
	if digest(value) != value.map_public_digest: return _error("DIGEST")
	return {"ok": true, "code": "OK", "diagnostic": ""}
