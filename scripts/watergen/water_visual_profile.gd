extends RefCounted
const Canonical = preload("res://scripts/watergen/public_map_context.gd")
const VERSION := "wg-1.0"
const LAYERS := ["water", "distance", "surface", "terrain", "floor", "foreground"]
const PALETTE := ["water_shallow", "water_deep", "haze_light", "plant_far", "silt_dark", "silt_light", "foreground_dark"]
const BEAM_LIMITS := {"count_range": [0, 8, true], "width_px_range": [1, 100, false], "depth_px_range": [1, 420, false], "lean_px_range": [-160, 160, false], "intensity_range": [0, 0.12, false]}
const CLUMP_LIMITS := {"far_clump_count_range": 32, "middle_clump_count_range": 24, "surface_pad_count_range": 16, "foreground_clump_count_range": 12}

static func fail(code: String) -> Dictionary:
	return {"ok": false, "code": code, "diagnostic": "Visual profile rejected: " + code}

static func keys(value: Variant, expected: Array) -> bool:
	return Canonical._keys(value, expected)

static func number(value: Variant, low: float, high: float, integer := false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and (not integer or float(value) == floor(float(value)))

static func interval(value: Variant, low: float, high: float, integer := false) -> bool:
	return value is Array and value.size() == 2 and number(value[0], low, high, integer) and number(value[1], low, high, integer) and value[0] <= value[1]

static func validate(value: Variant) -> Dictionary:
	if not keys(value, ["format", "schema_version", "profile_id", "generator_version", "palette", "beams", "composition", "parallax_compensation"]): return fail("FIELDS")
	if value.format != "baitbreak-water-visual-profile" or not number(value.schema_version, 1, 1, true) or value.generator_version != VERSION: return fail("VERSION")
	var id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]{2,63}$")
	if not value.profile_id is String or id_pattern.search(value.profile_id) == null: return fail("PROFILE_ID")
	if not keys(value.palette, PALETTE): return fail("PALETTE_FIELDS")
	var color_pattern := RegEx.create_from_string("^#[0-9A-Fa-f]{6}$")
	for color in value.palette.values():
		if not color is String or color_pattern.search(color) == null: return fail("COLOR")
	if not keys(value.beams, BEAM_LIMITS.keys()): return fail("BEAM_FIELDS")
	for field in BEAM_LIMITS:
		var limit: Array = BEAM_LIMITS[field]
		if not interval(value.beams[field], limit[0], limit[1], limit[2]): return fail("BEAM_RANGE_" + field)
	if not keys(value.composition, CLUMP_LIMITS.keys() + ["open_center_x_fraction", "gravel_count", "mote_count"]): return fail("COMPOSITION_FIELDS")
	for field in CLUMP_LIMITS:
		if not interval(value.composition[field], 0, CLUMP_LIMITS[field], true): return fail("CLUMP_RANGE_" + field)
	var center: Variant = value.composition.open_center_x_fraction
	if not interval(center, 0, 1) or center[0] == center[1]: return fail("OPEN_CENTER")
	if not number(value.composition.gravel_count, 0, 400, true) or not number(value.composition.mote_count, 0, 128, true): return fail("DETAIL_BUDGET")
	if not keys(value.parallax_compensation, LAYERS): return fail("PARALLAX_FIELDS")
	for field in LAYERS:
		var offset: Variant = value.parallax_compensation[field]
		if not offset is Array or offset.size() != 2: return fail("PARALLAX_VECTOR")
		# Nonzero values require WG-2's padded canvases. Reject, never silently ignore.
		if not number(offset[0], 0, 0) or not number(offset[1], 0, 0): return fail("PARALLAX_REQUIRES_WG2")
	return {"ok": true, "code": "OK", "diagnostic": ""}

static func digest(profile: Dictionary) -> String:
	return Canonical.canonical(profile).sha256_text()
