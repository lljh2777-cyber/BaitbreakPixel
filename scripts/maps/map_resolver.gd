extends RefCounted

# The sole production recipe boundary. Never accepts remote polygon data.
const Context=preload("res://scripts/maps/map_context.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Contract=preload("res://scripts/maps/map_definition.gd")
const CACHE_LIMIT:=16
static var _contexts: Dictionary={}

static func classic() -> Dictionary:
	return {"kind":"built_in","id":Registry.DEFAULT_MAP_ID,"revision":Registry.DEFAULT_REVISION}

static func woodland() -> Dictionary:
	return {"kind":"built_in","id":Registry.Woodland.ID,"revision":1}

static func generated(seed: int, version: int=1) -> Dictionary:
	return Request.source(Request.create(seed,version))

static func resolve_ref(source: Variant, reference: Variant) -> Dictionary:
	if not Registry._ref_shape_error(reference).is_empty(): return _error("invalid map_ref")
	return resolve(source,reference)

# A cheap scalar comparison against a previously validated immutable identity.
# No regeneration or content hashing occurs on network ticks.
static func same_source(value: Variant, selected: Dictionary) -> bool:
	if not value is Dictionary or value.size()!=selected.size(): return false
	if value.get_typed_key_builtin()==TYPE_OBJECT or value.get_typed_value_builtin()==TYPE_OBJECT: return false
	for key in value:
		if not key is String or not selected.has(key) or typeof(value[key])!=typeof(selected[key]) or value[key]!=selected[key]: return false
	return true

static func resolve(source: Variant, expected_ref: Variant=null) -> Dictionary:
	if expected_ref!=null and not Registry._ref_shape_error(expected_ref).is_empty(): return _error("invalid map_ref")
	if not source is Dictionary or source.get_typed_key_builtin()==TYPE_OBJECT or source.get_typed_value_builtin()==TYPE_OBJECT: return _error("map_source must be plain data")
	if not source.get("kind") is String: return _error("map_source kind must be a String")
	for key in source:
		if not key is String: return _error("map_source keys must be Strings")
	if source.get("kind")=="built_in":
		if source.size()!=3 or not source.get("id") is String or not source.get("revision") is int: return _error("invalid built-in source")
		var built:=Registry.load_map(source.id,source.revision)
		if not built.valid: return _error("unknown built-in map")
		if expected_ref!=null and expected_ref!=built.definition.meta: return _error("map source/reference mismatch")
		return Context.load_ref(built.definition.meta)
	if source.get("kind")!="generated" or source.size()!=5: return _error("unsupported map source")
	var request:Dictionary=source.duplicate()
	request.erase("kind")
	request["map_contract_version"]=Request.contract(request.get("generator_version"))
	var checked:=Request.validate(request)
	if not checked.valid: return _error("unsupported generation recipe: "+str(checked.errors))
	var key:String="%s:%d:%s:%d" % [request.generator_id,request.generator_version,request.gameplay_profile,request.map_seed]
	var context:RefCounted=_contexts.get(key)
	if context==null:
		var result:=Generator.generate(request)
		if not result.valid: return _error("generation failed: "+str(result.errors))
		var loaded:=Context.from_definition(result.definition,source)
		if not loaded.valid: return loaded
		context=loaded.context
		if _contexts.size()>=CACHE_LIMIT: _contexts.erase(_contexts.keys()[0])
		_contexts[key]=context
	if expected_ref!=null and context.map_ref!=expected_ref: return _error("generated content hash or identity mismatch")
	return {"valid":true,"errors":[],"context":context}

static func _error(message: String) -> Dictionary:
	return {"valid":false,"errors":[message],"context":null}
