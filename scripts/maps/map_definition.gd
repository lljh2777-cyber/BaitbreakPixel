extends RefCounted

# Value-only contract. It is not a Resource, scene, RNG owner or world controller.
# canonical/content_hash accept structurally validated contract-v1 definitions;
# untrusted callers must use MapValidator before calling these low-level helpers.
const CONTRACT_VERSION := 1
const CAPABILITY_KEYS: Array[String] = [
	"fish_passable", "net_blocking", "rope_anchor", "contact_fade",
	"grass_binding", "shore_visible", "npc_spawn_blocking", "fish_occluding",
]

static func canonical(definition: Dictionary) -> String:
	var bounds: Dictionary = definition.bounds
	var anchors: Dictionary = definition.anchors
	var drag: Array = []
	for zone: Rect2 in bounds.vegetation_drag_zones: drag.append(_rect(zone))
	var baits: Array = []
	for position: Vector2 in definition.bait_sites: baits.append(_point(position))
	var features: Array = []
	# Array order is semantic while old target indexes exist. Never sort by ID here.
	for feature: Dictionary in definition.interaction_features:
		var points: Array = []
		for point: Vector2 in feature.shape.points: points.append(_point(point))
		var capabilities: Array = []
		for key: String in CAPABILITY_KEYS: capabilities.append(feature.capabilities[key])
		features.append([feature.id,feature.kind,feature.compatibility_index,
			feature.shape.type,points,capabilities,feature.fade_group_id])
	# Fixed positional grammar; no Dictionary iteration, engine Variant hash or
	# locale/decimal rounding participates. Identity/revision are checked separately.
	var authority: Array = [definition.meta.contract_version,
		[_point(bounds.size),_rect(bounds.water),_real(bounds.floor_y),_rect(bounds.net_area),drag],
		[_point(anchors.player_spawn),_point(anchors.home)],baits,features]
	return "baitbreak-map-contract-v1\n" + JSON.stringify(authority)

static func content_hash(definition: Dictionary) -> String:
	return canonical(definition).sha256_text()

static func map_ref(definition: Dictionary) -> Dictionary:
	return definition.meta.duplicate(true)

static func _real(value: float) -> String:
	# encode_double is explicitly little-endian IEEE-754. Numeric int/float inputs
	# normalize to the same 64-bit value; -0 is equivalent to +0 in geometry.
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,0.0 if value == 0.0 else value)
	return bytes.hex_encode()

static func _point(value: Vector2) -> Array:
	return [_real(value.x),_real(value.y)]

static func _rect(value: Rect2) -> Array:
	return [_point(value.position),_point(value.size)]
