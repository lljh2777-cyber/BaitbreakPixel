extends RefCounted

const PondV2 = preload("res://scripts/maps/pond_v2_map.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const DEFAULT_MAP_ID := "pond_v2"
const DEFAULT_REVISION := 1

# Closed built-in registry: no test fixture, generated map or file loader is exposed.
# A failed lookup/validation returns an explicit error and no partial definition.
static func load_map(map_id: String = DEFAULT_MAP_ID, revision: int = DEFAULT_REVISION) -> Dictionary:
	if map_id != DEFAULT_MAP_ID or revision != DEFAULT_REVISION:
		return {"valid":false,"errors":["unknown map id or revision"],"definition":{}}
	var definition := PondV2.create()
	var validation := Validator.validate(definition)
	if not validation.valid:
		return {"valid":false,"errors":validation.errors.duplicate(),"definition":{}}
	return {"valid":true,"errors":[],"definition":definition.duplicate(true)}

static func available_refs() -> Array[Dictionary]:
	var loaded := load_map()
	if not loaded.valid: return []
	return [loaded.definition.meta.duplicate(true)]
