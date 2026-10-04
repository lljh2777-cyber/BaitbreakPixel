extends RefCounted

const PondV2 = preload("res://scripts/maps/pond_v2_map.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const DEFAULT_MAP_ID := "pond_v2"
const DEFAULT_REVISION := 1
static var _validated_definition: Dictionary = {}

# Closed built-in registry: no test fixture, generated map or file loader is exposed.
# A failed lookup/validation returns an explicit error and no partial definition.
static func load_map(map_id: String = DEFAULT_MAP_ID, revision: int = DEFAULT_REVISION) -> Dictionary:
	if map_id != DEFAULT_MAP_ID or revision != DEFAULT_REVISION:
		return {"valid":false,"errors":["unknown map id or revision"],"definition":{}}
	var validation := _ensure_definition()
	if not validation.valid: return {"valid":false,"errors":validation.errors.duplicate(),"definition":{}}
	return {"valid":true,"errors":[],"definition":_validated_definition.duplicate(true)}

# Built-in script data cannot change during the process. Cache once; packet
# identity checks never rehash or reconstruct polygons on the tick path.
static func _ensure_definition() -> Dictionary:
	if not _validated_definition.is_empty(): return {"valid":true,"errors":[]}
	var definition := PondV2.create()
	var validation := Validator.validate(definition)
	if validation.valid: _validated_definition = definition.duplicate(true)
	return validation

static func available_refs() -> Array[Dictionary]:
	var loaded := load_map()
	if not loaded.valid: return []
	return [loaded.definition.meta.duplicate(true)]

# A MapRef is an identity claim, never a source of geometry. Validate its complete
# scalar shape before any lookup; objects, nested containers and typed Object
# metadata must never reach serialization or coercion at the trust boundary.
static func load_ref(value: Variant) -> Dictionary:
	var validation := validate_ref(value)
	if not validation.valid: return {"valid":false,"errors":validation.errors,"definition":{}}
	return load_map(value.id,value.revision)

static func validate_ref(value: Variant) -> Dictionary:
	var error := _ref_shape_error(value)
	if not error.is_empty(): return {"valid":false,"errors":[error]}
	if value.id != DEFAULT_MAP_ID or value.revision != DEFAULT_REVISION:
		return {"valid":false,"errors":["unknown map id or revision"]}
	var validation := _ensure_definition()
	if not validation.valid: return validation
	var local: Dictionary = _validated_definition.meta
	if value.contract_version != local.contract_version:
		return {"valid":false,"errors":["unsupported map contract version"]}
	if value.content_hash != local.content_hash:
		return {"valid":false,"errors":["map content hash does not match local authority"]}
	return {"valid":true,"errors":[]}

static func _ref_shape_error(value: Variant) -> String:
	if not value is Dictionary: return "map_ref must be a dictionary"
	if value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT:
		return "map_ref must not contain Object type metadata"
	if value.size() != 4: return "map_ref must have exactly four fields"
	for key in value:
		if not key is String or key not in ["id","revision","contract_version","content_hash"]:
			return "map_ref contains an unknown or non-String key"
	if not value.get("id") is String or value.id.is_empty() or value.id.length() > 64:
		return "map_ref id must be a bounded nonempty String"
	if not value.get("revision") is int or value.revision <= 0:
		return "map_ref revision must be a positive int"
	if not value.get("contract_version") is int or value.contract_version <= 0:
		return "map_ref contract_version must be a positive int"
	if not value.get("content_hash") is String or value.content_hash.length() != 64:
		return "map_ref content_hash must be a 64-character String"
	for character in value.content_hash:
		if character not in "0123456789abcdef": return "map_ref content_hash must be lowercase hexadecimal"
	return ""
