extends RefCounted

# Pure, fail-closed validation of the P4 map data contract. No world, RNG,
# resource loading from map data, error logging, normalization, or input writes.
const Definition = preload("res://scripts/maps/map_definition.gd")
# Current reset/refill lifecycle owns four active bait slots. A map can expose
# more ordered sites; pond_v2 keeps its six exact sites in the golden fixture.
const MIN_BAIT_SITES := 4
const MAX_FEATURES := 256
const MAX_POLYGON_POINTS := 128
const MAX_CONTAINER_ITEMS := 1024
const MAX_VALUE_NODES := 32768
const MAX_DEPTH := 16
const MAX_STRING_LENGTH := 4096
const MAX_MAP_EXTENT := 1000000.0
const TOP_KEYS := ["meta", "bounds", "anchors", "bait_sites", "interaction_features", "visual_features", "presentation"]
const FEATURE_KEYS := ["id", "kind", "compatibility_index", "shape", "capabilities", "fade_group_id", "presentation_ref"]
const CAPABILITY_KEYS := ["fish_passable", "net_blocking", "rope_anchor", "contact_fade", "grass_binding", "shore_visible", "npc_spawn_blocking", "fish_occluding"]

static func validate(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	var budget: Array[int] = [MAX_VALUE_NODES]
	if not _plain(value, "$", [], budget, 0, errors):
		return _result(errors)
	if not _keys(value, TOP_KEYS, "$", errors):
		return _result(errors)
	var definition: Dictionary = value
	_validate_meta(definition.meta, errors)
	var bounds_ok := _validate_bounds(definition.bounds, errors)
	_validate_anchors(definition.anchors, definition.bounds if bounds_ok else {}, errors)
	_validate_bait_sites(definition.bait_sites, definition.bounds if bounds_ok else {}, errors)
	var visual_ids := _validate_visuals(definition.visual_features, errors)
	_validate_features(definition.interaction_features, definition.bounds if bounds_ok else {}, visual_ids, errors)
	_validate_presentation(definition.presentation, errors)
	# Never pass malformed shapes, cycles, objects, or unknown fields to the hasher.
	if errors.is_empty() and Definition.content_hash(definition) != definition.meta.content_hash:
		errors.append("$.meta.content_hash: authority content does not match its declared hash")
	return _result(errors)

static func _result(errors: Array[String]) -> Dictionary:
	return {"valid": errors.is_empty(), "errors": errors}

static func _plain(value: Variant, path: String, ancestors: Array, budget: Array[int], depth: int, errors: Array[String]) -> bool:
	budget[0] -= 1
	if budget[0] < 0 or depth > MAX_DEPTH:
		errors.append(path + ": value tree exceeds validation limits")
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			if is_finite(value): return true
		TYPE_STRING, TYPE_STRING_NAME:
			if value.length() <= MAX_STRING_LENGTH: return true
		TYPE_VECTOR2:
			if value.is_finite(): return true
		TYPE_RECT2:
			if value.position.is_finite() and value.size.is_finite() and value.end.is_finite(): return true
		TYPE_COLOR:
			if is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a): return true
		TYPE_ARRAY, TYPE_DICTIONARY:
			# Empty Object-typed containers can still retain a Script reference in
			# their type metadata. Only built-in value element types belong here.
			if value is Array and value.get_typed_builtin() == TYPE_OBJECT:
				errors.append(path + ": object-typed arrays are not map data")
				return false
			if value is Dictionary and (value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT):
				errors.append(path + ": object-typed dictionaries are not map data")
				return false
			if value.size() > MAX_CONTAINER_ITEMS:
				errors.append(path + ": container exceeds validation limits")
				return false
			for ancestor in ancestors:
				if is_same(value, ancestor):
					errors.append(path + ": cyclic containers are not map data")
					return false
			ancestors.append(value)
			if value is Dictionary:
				for key in value:
					if not (key is String or key is StringName) or key.length() > MAX_STRING_LENGTH:
						errors.append(path + ": dictionary keys must be bounded strings")
						ancestors.pop_back()
						return false
					if not _plain(value[key], path + "." + String(key), ancestors, budget, depth + 1, errors):
						ancestors.pop_back()
						return false
			else:
				for index in value.size():
					if not _plain(value[index], "%s[%d]" % [path, index], ancestors, budget, depth + 1, errors):
						ancestors.pop_back()
						return false
			ancestors.pop_back()
			return true
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			if value.size() > MAX_CONTAINER_ITEMS:
				errors.append(path + ": packed array exceeds validation limits")
				return false
			for index in value.size():
				if not _plain(value[index], "%s[%d]" % [path, index], ancestors, budget, depth + 1, errors): return false
			return true
	errors.append(path + ": unsupported, non-finite, or oversized value")
	return false

static func _keys(value: Variant, expected: Array, path: String, errors: Array[String]) -> bool:
	if not value is Dictionary:
		errors.append(path + ": expected a dictionary")
		return false
	if value.size() != expected.size():
		errors.append(path + ": missing or unknown fields")
		return false
	for key in expected:
		if not value.has(key):
			errors.append(path + ": missing field " + key)
			return false
	return true

static func _id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 128

static func _validate_meta(value: Variant, errors: Array[String]) -> void:
	if not _keys(value, ["id", "revision", "contract_version", "content_hash"], "$.meta", errors): return
	if not _id(value.id): errors.append("$.meta.id: expected a nonempty bounded string")
	if not value.revision is int or value.revision <= 0: errors.append("$.meta.revision: expected a positive integer")
	if not value.contract_version is int or value.contract_version != 1: errors.append("$.meta.contract_version: unsupported contract")
	if not value.content_hash is String or value.content_hash.length() != 64:
		errors.append("$.meta.content_hash: expected 64 lowercase hexadecimal characters")
	else:
		for character in value.content_hash:
			if not character in "0123456789abcdef":
				errors.append("$.meta.content_hash: expected 64 lowercase hexadecimal characters")
				break

static func _positive_rect(value: Variant) -> bool:
	return value is Rect2 and value.size.x > 0.0 and value.size.y > 0.0

static func _contains_rect(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x and inner.position.y >= outer.position.y and inner.end.x <= outer.end.x and inner.end.y <= outer.end.y

static func _contains_point(bounds: Rect2, point: Vector2) -> bool:
	# Polygon vertices may lie exactly on an outer edge. Spawn/bait use the
	# engine's half-open water containment, matching the current runtime.
	return point.x >= bounds.position.x and point.y >= bounds.position.y and point.x <= bounds.end.x and point.y <= bounds.end.y

static func _validate_bounds(value: Variant, errors: Array[String]) -> bool:
	if not _keys(value, ["size", "water", "floor_y", "net_area", "vegetation_drag_zones"], "$.bounds", errors): return false
	var before := errors.size()
	if not value.size is Vector2 or value.size.x <= 0.0 or value.size.y <= 0.0 or value.size.x > MAX_MAP_EXTENT or value.size.y > MAX_MAP_EXTENT:
		errors.append("$.bounds.size: expected finite positive map dimensions within limits")
	if not _positive_rect(value.water): errors.append("$.bounds.water: expected a positive Rect2")
	if not _positive_rect(value.net_area): errors.append("$.bounds.net_area: expected a positive Rect2")
	if not (value.floor_y is float or value.floor_y is int): errors.append("$.bounds.floor_y: expected a finite number")
	if not value.vegetation_drag_zones is Array or value.vegetation_drag_zones.size() > MAX_FEATURES:
		errors.append("$.bounds.vegetation_drag_zones: expected a bounded Array of Rect2")
	if errors.size() != before: return false
	var map_rect := Rect2(Vector2.ZERO, value.size)
	if not _contains_rect(map_rect, value.water): errors.append("$.bounds.water: outside map bounds")
	if not _contains_rect(value.water, value.net_area): errors.append("$.bounds.net_area: outside water bounds")
	if value.floor_y < value.water.end.y or value.floor_y > value.size.y:
		errors.append("$.bounds.floor_y: must be between the water bottom and map bottom")
	for index in value.vegetation_drag_zones.size():
		var zone: Variant = value.vegetation_drag_zones[index]
		if not _positive_rect(zone) or not _contains_rect(map_rect, zone):
			errors.append("$.bounds.vegetation_drag_zones[%d]: expected a positive rectangle inside the map" % index)
	return errors.size() == before

static func _validate_anchors(value: Variant, bounds: Dictionary, errors: Array[String]) -> void:
	if not _keys(value, ["player_spawn", "home"], "$.anchors", errors): return
	for key in ["player_spawn", "home"]:
		if not value[key] is Vector2:
			errors.append("$.anchors." + key + ": expected Vector2")
		elif not bounds.is_empty() and not bounds.water.has_point(value[key]):
			errors.append("$.anchors." + key + ": outside water bounds")

static func _validate_bait_sites(value: Variant, bounds: Dictionary, errors: Array[String]) -> void:
	if not value is Array or value.size() < MIN_BAIT_SITES or value.size() > MAX_FEATURES:
		errors.append("$.bait_sites: expected an ordered Array with at least %d sites, within limits" % MIN_BAIT_SITES)
		return
	var seen: Dictionary = {}
	for index in value.size():
		var point: Variant = value[index]
		if not point is Vector2:
			errors.append("$.bait_sites[%d]: expected Vector2" % index)
			continue
		if seen.has(point): errors.append("$.bait_sites[%d]: duplicate site" % index)
		seen[point] = true
		if not bounds.is_empty() and not bounds.water.has_point(point): errors.append("$.bait_sites[%d]: outside water bounds" % index)

static func _validate_visuals(value: Variant, errors: Array[String]) -> Dictionary:
	var ids: Dictionary = {}
	if not value is Array or value.size() > MAX_FEATURES:
		errors.append("$.visual_features: expected a bounded ordered Array")
		return ids
	for index in value.size():
		var entry: Variant = value[index]
		var path := "$.visual_features[%d]" % index
		if not _keys(entry, ["id", "kind", "legacy"], path, errors): continue
		if not _id(entry.id):
			errors.append(path + ".id: expected a nonempty bounded string")
		elif ids.has(entry.id):
			errors.append(path + ".id: duplicate visual identity")
		else: ids[entry.id] = true
		if not entry.kind is String or not entry.kind in ["solid", "plant"]: errors.append(path + ".kind: unsupported visual kind")
		if not entry.legacy is Dictionary: errors.append(path + ".legacy: expected value-only dictionary")
	return ids

static func _validate_features(value: Variant, bounds: Dictionary, visual_ids: Dictionary, errors: Array[String]) -> void:
	if not value is Array or value.size() > MAX_FEATURES:
		errors.append("$.interaction_features: expected a bounded ordered Array")
		return
	var features: Dictionary = {}
	for index in value.size():
		var entry: Variant = value[index]
		var path := "$.interaction_features[%d]" % index
		if not _keys(entry, FEATURE_KEYS, path, errors): continue
		if not _id(entry.id): errors.append(path + ".id: expected a nonempty bounded string")
		elif features.has(entry.id): errors.append(path + ".id: duplicate interaction identity")
		else: features[entry.id] = entry
		if not entry.kind is String or not entry.kind in ["wood", "stone", "grass"]: errors.append(path + ".kind: unsupported interaction kind")
		if not entry.compatibility_index is int or entry.compatibility_index != index: errors.append(path + ".compatibility_index: must match stable array position")
		_validate_shape(entry.shape, bounds, path + ".shape", errors)
		if _keys(entry.capabilities, CAPABILITY_KEYS, path + ".capabilities", errors):
			for key in CAPABILITY_KEYS:
				if not entry.capabilities[key] is bool: errors.append(path + ".capabilities." + key + ": expected bool")
		if not _id(entry.fade_group_id): errors.append(path + ".fade_group_id: expected a feature identity")
		if not _id(entry.presentation_ref) or not visual_ids.has(entry.presentation_ref): errors.append(path + ".presentation_ref: missing visual feature")
	for feature_id in features:
		var feature: Dictionary = features[feature_id]
		if not feature.fade_group_id is String or not features.has(feature.fade_group_id):
			errors.append("$.interaction_features." + feature_id + ".fade_group_id: missing interaction feature")
			continue
		var group: Dictionary = features[feature.fade_group_id]
		if not group.fade_group_id is String or group.fade_group_id != feature.fade_group_id:
			errors.append("$.interaction_features." + feature_id + ".fade_group_id: group must refer to its own representative")
		if feature.fade_group_id != feature_id:
			if not feature.capabilities is Dictionary or not group.capabilities is Dictionary: continue
			if not feature.capabilities.get("contact_fade") is bool or not group.capabilities.get("contact_fade") is bool or not feature.capabilities.contact_fade or not group.capabilities.contact_fade:
				errors.append("$.interaction_features." + feature_id + ".fade_group_id: shared groups require contact_fade")

static func _validate_shape(value: Variant, bounds: Dictionary, path: String, errors: Array[String]) -> void:
	if not _keys(value, ["type", "points"], path, errors): return
	if not value.type is String or value.type != "polygon": errors.append(path + ".type: expected polygon")
	if not value.points is PackedVector2Array or value.points.size() < 3 or value.points.size() > MAX_POLYGON_POINTS:
		errors.append(path + ".points: expected 3 to %d packed polygon vertices" % MAX_POLYGON_POINTS)
		return
	var polygon: PackedVector2Array = value.points
	var area := 0.0
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		if a == b: errors.append(path + ".points: duplicate consecutive vertices or zero-length edge")
		area += float(a.x) * float(b.y) - float(b.x) * float(a.y)
		if not bounds.is_empty() and not _contains_point(Rect2(Vector2.ZERO, bounds.size), a): errors.append(path + ".points: vertex outside map bounds")
	if absf(area) <= 0.000001: errors.append(path + ".points: polygon has zero area")
	for first in polygon.size():
		var next_first := (first + 1) % polygon.size()
		for second in range(first + 1, polygon.size()):
			var next_second := (second + 1) % polygon.size()
			if next_first == second or next_second == first: continue
			if _segments_intersect(polygon[first], polygon[next_first], polygon[second], polygon[next_second]):
				errors.append(path + ".points: polygon edges self-intersect")
				return

static func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (float(b.x) - a.x) * (float(c.y) - a.y) - (float(b.y) - a.y) * (float(c.x) - a.x)

static func _on_segment(a: Vector2, b: Vector2, point: Vector2) -> bool:
	return point.x >= minf(a.x, b.x) and point.x <= maxf(a.x, b.x) and point.y >= minf(a.y, b.y) and point.y <= maxf(a.y, b.y)

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := _cross(a, b, c)
	var ab_d := _cross(a, b, d)
	var cd_a := _cross(c, d, a)
	var cd_b := _cross(c, d, b)
	if ((ab_c > 0.0 and ab_d < 0.0) or (ab_c < 0.0 and ab_d > 0.0)) and ((cd_a > 0.0 and cd_b < 0.0) or (cd_a < 0.0 and cd_b > 0.0)): return true
	return (ab_c == 0.0 and _on_segment(a, b, c)) or (ab_d == 0.0 and _on_segment(a, b, d)) or (cd_a == 0.0 and _on_segment(c, d, a)) or (cd_b == 0.0 and _on_segment(c, d, b))

static func _validate_presentation(value: Variant, errors: Array[String]) -> void:
	if not _keys(value, ["visual_profile_id", "wood_groups"], "$.presentation", errors): return
	if not _id(value.visual_profile_id): errors.append("$.presentation.visual_profile_id: expected a nonempty bounded string")
	if not value.wood_groups is Array or value.wood_groups.size() > MAX_FEATURES:
		errors.append("$.presentation.wood_groups: expected a bounded Array")
		return
	for index in value.wood_groups.size():
		var group: Variant = value.wood_groups[index]
		if not group is Array or group.is_empty() or group.size() > MAX_FEATURES:
			errors.append("$.presentation.wood_groups[%d]: expected a nonempty bounded Array of seed IDs" % index)
			continue
		var seen: Dictionary = {}
		for seed_id in group:
			if not seed_id is int or seed_id <= 0:
				errors.append("$.presentation.wood_groups[%d]: expected positive integer seed IDs" % index)
			elif seen.has(seed_id): errors.append("$.presentation.wood_groups[%d]: duplicate seed ID" % index)
			else: seen[seed_id] = true
