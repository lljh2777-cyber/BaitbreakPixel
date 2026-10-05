extends RefCounted

# Immutable per-round Authority data. Use the checked factories, then install once
# before world actors/RNG setup. No public setter can replace a round's geometry.
const Registry = preload("res://scripts/maps/map_registry.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const Geometry = preload("res://scripts/maps/map_geometry.gd")
static var _registered_context: RefCounted = null

# Godot read-only Array/Dictionary does NOT freeze nested packed arrays. Therefore
# collection getters and lookup records are detached setup/export snapshots, not
# hot-path views. World caches the target/blocker exports once per installation.
# Internal validated geometry/bounds/lookups remain private and are never exposed.
# Scalar getters and geometry queries allocate no polygon and consume no RNG.
var _data: Dictionary = {}
var _source: Dictionary = {}
var map_source: Dictionary:
	get: return _source.duplicate(true)
	set(_value): pass
var routing_profile: String:
	get: return "generated_pond_v1" if _source.get("kind")=="generated" else "legacy_pond"
	set(_value): pass
var _bait_sites: Array[Vector2] = []
var _vegetation_drag_zones: Array[Rect2] = []
var _features: Array[Dictionary] = []
var _visuals: Array[Dictionary] = []
var _targets: Array[Dictionary] = []
var _net_blockers: Array[Dictionary] = []
var _npc_spawn_blockers: Array[Dictionary] = []
var _fish_occluders: Array[Dictionary] = []
var _features_by_id: Dictionary = {}
var _targets_by_id: Dictionary = {}
var _bounds_by_id: Dictionary = {}

var id: String:
	get: return _data.meta.id
	set(_value): pass
var revision: int:
	get: return _data.meta.revision
	set(_value): pass
var contract_version: int:
	get: return _data.meta.contract_version
	set(_value): pass
var content_hash: String:
	get: return _data.meta.content_hash
	set(_value): pass
var map_ref: Dictionary:
	get: return _data.meta.duplicate(true)
	set(_value): pass
var size: Vector2:
	get: return _data.bounds.size
	set(_value): pass
var water: Rect2:
	get: return _data.bounds.water
	set(_value): pass
var floor_y: float:
	get: return _data.bounds.floor_y
	set(_value): pass
var net_area: Rect2:
	get: return _data.bounds.net_area
	set(_value): pass
var player_spawn: Vector2:
	get: return _data.anchors.player_spawn
	set(_value): pass
var home: Vector2:
	get: return _data.anchors.home
	set(_value): pass
var bait_sites: Array[Vector2]:
	get: return _bait_sites.duplicate(true)
	set(_value): pass
var vegetation_drag_zones: Array[Rect2]:
	get: return _vegetation_drag_zones.duplicate(true)
	set(_value): pass
var interaction_features: Array[Dictionary]:
	get: return _features.duplicate(true)
	set(_value): pass
var visual_features: Array[Dictionary]:
	get: return _visuals.duplicate(true)
	set(_value): pass
var presentation: Dictionary:
	get: return _data.presentation.duplicate(true)
	set(_value): pass
var interaction_targets: Array[Dictionary]:
	get: return _targets.duplicate(true)
	set(_value): pass
var net_blockers: Array[Dictionary]:
	get: return _net_blockers.duplicate(true)
	set(_value): pass
var npc_spawn_blockers: Array[Dictionary]:
	get: return _npc_spawn_blockers.duplicate(true)
	set(_value): pass
var fish_occluders: Array[Dictionary]:
	get: return _fish_occluders.duplicate(true)
	set(_value): pass

static func load_map(map_id: String = Registry.DEFAULT_MAP_ID, map_revision: int = Registry.DEFAULT_REVISION) -> Dictionary:
	var loaded := Registry.load_map(map_id,map_revision)
	if not loaded.valid:
		return {"valid":false,"errors":loaded.errors.duplicate(),"context":null}
	return from_definition(loaded.definition)

# Snapshot/network entry: resolve the exact reference against built-in data.
# No fallback to the current/default context and no remote geometry are allowed.
static func load_ref(value: Variant) -> Dictionary:
	var validation := Registry.validate_ref(value)
	if not validation.valid:
		return {"valid":false,"errors":validation.errors.duplicate(),"context":null}
	if _registered_context == null:
		var loaded := Registry.load_ref(value)
		if not loaded.valid:
			return {"valid":false,"errors":loaded.errors.duplicate(),"context":null}
		var built := from_definition(loaded.definition)
		if not built.valid: return built
		_registered_context = built.context
	return {"valid":true,"errors":[],"context":_registered_context}

# Also permits validated, unregistered definitions for isolated tests. This does
# not register a map, add selection UI, or change snapshot/network acceptance.
static func from_definition(value: Variant, source: Dictionary = {}) -> Dictionary:
	var validation := Validator.validate(value)
	if not validation.valid:
		return {"valid":false,"errors":validation.errors.duplicate(),"context":null}
	var context := new()
	context._initialize(value,source)
	return {"valid":true,"errors":[],"context":context}

func _initialize(definition: Dictionary, source: Dictionary) -> void:
	# Protect against accidental reinitialization of an existing round context.
	if not _data.is_empty(): return
	_data = definition.duplicate(true)
	_source=source.duplicate(true) if not source.is_empty() else {"kind":"built_in","id":id,"revision":revision}
	_freeze_containers(_source)
	_bait_sites.assign(_data.bait_sites)
	_vegetation_drag_zones.assign(_data.bounds.vegetation_drag_zones)
	_features.assign(_data.interaction_features)
	_visuals.assign(_data.visual_features)
	_targets = Geometry.interaction_targets(_data)
	_net_blockers = Geometry.capability_targets(_targets,"net_blocking")
	_npc_spawn_blockers = Geometry.capability_targets(_targets,"npc_spawn_blocking")
	_fish_occluders = Geometry.capability_targets(_targets,"fish_occluding")
	for feature: Dictionary in _data.interaction_features:
		_features_by_id[feature.id] = feature
	for target: Dictionary in _targets:
		_targets_by_id[target.id] = target
		_bounds_by_id[target.id] = target.bounds
	for cache in [_data,_bait_sites,_vegetation_drag_zones,_features,_visuals,_targets,_net_blockers,_npc_spawn_blockers,_fish_occluders,
		_features_by_id,_targets_by_id,_bounds_by_id]:
		_freeze_containers(cache)

func fish_bounds(radius: float) -> Rect2:
	return water.grow(-radius)

func has_feature(feature_id: String) -> bool:
	return _features_by_id.has(feature_id)

func feature_by_id(feature_id: String) -> Dictionary:
	return _features_by_id.get(feature_id,{}).duplicate(true)

func target_by_id(feature_id: String) -> Dictionary:
	return _targets_by_id.get(feature_id,{}).duplicate(true)

func feature_bounds(feature_id: String) -> Rect2:
	return _bounds_by_id.get(feature_id,Rect2())

func target_count() -> int:
	return _targets.size()

# ID-based queries operate on the once-built internal packed geometry. Unknown
# identities fail closed instead of selecting a different compatibility index.
func touches_feature(feature_id: String, point: Vector2, radius: float) -> bool:
	if not _targets_by_id.has(feature_id): return false
	return Geometry.touches(point,radius,_targets_by_id[feature_id].polygon)

func nearest_feature_boundary(feature_id: String, point: Vector2) -> Vector2:
	if not _targets_by_id.has(feature_id): return Vector2(INF,INF)
	return Geometry.nearest_boundary(point,_targets_by_id[feature_id].polygon)

func coil_at(feature_id: String, contact: Vector2) -> Dictionary:
	if not _targets_by_id.has(feature_id): return {}
	return Geometry.coil_at(_targets_by_id[feature_id],contact)

static func _freeze_containers(value: Variant) -> void:
	if value is Dictionary:
		if value.is_read_only(): return
		for child in value.values(): _freeze_containers(child)
		value.make_read_only()
	elif value is Array:
		if value.is_read_only(): return
		for child in value: _freeze_containers(child)
		value.make_read_only()
