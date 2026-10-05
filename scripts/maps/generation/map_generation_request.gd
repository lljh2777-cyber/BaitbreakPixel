extends RefCounted

# Recipe only. Presentation seeds, world RNG and remote geometry are not inputs.
const GENERATOR_ID := "generated_pond"
const GENERATOR_VERSION := 1
const PROFILE := "balanced_pond_v1"
const MAX_SEED := 2147483647
const KEYS := ["generator_id","generator_version","map_seed","gameplay_profile","map_contract_version"]

static func create(map_seed: int) -> Dictionary:
	return {"generator_id":GENERATOR_ID,"generator_version":GENERATOR_VERSION,
		"map_seed":map_seed,"gameplay_profile":PROFILE,"map_contract_version":1}

static func validate(value: Variant) -> Dictionary:
	var errors: Array[String]=[]
	if not value is Dictionary: return {"valid":false,"errors":["request must be a dictionary"]}
	if value.get_typed_key_builtin()==TYPE_OBJECT or value.get_typed_value_builtin()==TYPE_OBJECT:
		return {"valid":false,"errors":["request must not retain Objects"]}
	if value.size()!=KEYS.size(): errors.append("request requires exactly five fields")
	for key in value:
		if not key is String or key not in KEYS: errors.append("unknown or non-String request key")
	if not value.get("generator_id") is String or value.generator_id!=GENERATOR_ID: errors.append("unsupported generator")
	if not value.get("generator_version") is int or value.generator_version!=GENERATOR_VERSION: errors.append("unsupported generator version")
	if not value.get("gameplay_profile") is String or value.gameplay_profile!=PROFILE: errors.append("unsupported gameplay profile")
	if not value.get("map_contract_version") is int or value.map_contract_version!=1: errors.append("unsupported map contract")
	if not value.get("map_seed") is int or value.map_seed<0 or value.map_seed>MAX_SEED: errors.append("map_seed must be an integer in 0..2147483647")
	return {"valid":errors.is_empty(),"errors":errors}

static func source(value: Variant) -> Dictionary:
	if not validate(value).valid: return {}
	return {"kind":"generated","generator_id":value.generator_id,"generator_version":value.generator_version,
		"gameplay_profile":value.gameplay_profile,"map_seed":value.map_seed}
