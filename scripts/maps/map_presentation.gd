extends RefCounted

# Public render data is exported once per immutable context. Cache identity is the
# context, never its gameplay hash (visual-only edits intentionally share hashes).
# Weak source references let finished rounds leave the cache on the next install.
# All cached containers, including polygon point Arrays, are recursively read-only.
const Context = preload("res://scripts/maps/map_context.gd")
static var _cache: Dictionary = {}
static var _default_context: RefCounted
var _source: WeakRef
var _scalars: Dictionary = {}
var _solids: Array[Dictionary] = []
var _plants: Array[Dictionary] = []
var _wood_groups: Array = []
var _plant_indexes: Dictionary = {}
var _solid_groups: Array[String] = []

var context: RefCounted:
	get: return _source.get_ref()
	set(_value): pass
var size: Vector2:
	get: return _scalars.size
	set(_value): pass
var water: Rect2:
	get: return _scalars.water
	set(_value): pass
var floor_y: float:
	get: return _scalars.floor_y
	set(_value): pass
var home: Vector2:
	get: return _scalars.home
	set(_value): pass
var surface_y: float:
	get: return water.position.y-13.0
	set(_value): pass
var visual_profile_id: String:
	get: return _scalars.visual_profile_id
	set(_value): pass
var solids: Array[Dictionary]:
	get: return _solids
	set(_value): pass
var plants: Array[Dictionary]:
	get: return _plants
	set(_value): pass
var wood_groups: Array:
	get: return _wood_groups
	set(_value): pass

static func for_context(source: RefCounted) -> RefCounted:
	assert(source != null,"Presentation requires an installed MapContext")
	var identity := source.get_instance_id()
	if _cache.has(identity) and _cache[identity].context == source: return _cache[identity]
	for key in _cache.keys():
		if _cache[key].context == null: _cache.erase(key)
	var result := new()
	result._initialize(source)
	_cache[identity] = result
	return result

# Explicit built-in selection retained only for historical no-world art tools.
# Live rendering always passes its display world's installed context instead.
static func default_map() -> RefCounted:
	if _default_context == null:
		var loaded := Context.load_map()
		assert(loaded.valid,"Registered presentation map must validate")
		_default_context = loaded.context
	return for_context(_default_context)

func _initialize(source: RefCounted) -> void:
	if _source != null: return
	_source = weakref(source)
	var metadata: Dictionary = source.presentation
	_scalars = {"size":source.size,"water":source.water,"floor_y":source.floor_y,
		"home":source.home,"visual_profile_id":metadata.visual_profile_id,"floor_profile":source.floor_profile}
	_wood_groups = metadata.wood_groups
	var visuals: Dictionary = {}
	for visual: Dictionary in source.visual_features: visuals[visual.id] = visual
	for target: Dictionary in source.interaction_targets:
		var visual: Dictionary = visuals[target.presentation_ref]
		var entry: Dictionary = visual.legacy.duplicate(true)
		entry.feature_id = target.id
		entry.target_index = target.compatibility_index
		entry.bounds = target.bounds
		entry.shore_visible = target.capabilities.shore_visible
		if visual.kind == "plant":
			# Art styling remains presentation data; gameplay identity is explicit.
			var bounds: Rect2 = target.bounds
			entry.x = entry.get("x",bounds.get_center().x)
			entry.y = entry.get("y",bounds.end.y)
			entry.width = entry.get("width",maxf(1,bounds.size.x-6))
			entry.height = entry.get("height",bounds.size.y)
			entry.kind = entry.get("kind","ribbon")
			entry.stems = entry.get("stems",3)
			entry.back = entry.get("back",false)
			_plant_indexes[entry.target_index] = _plants.size()
			_plants.append(entry)
		else:
			# The silhouette always comes from public map geometry, not a texture.
			entry.points = Array(target.polygon)
			if source.has_relief:
				entry["visible_polygons"]=[]
				for polygon in Geometry2D.clip_polygons(target.polygon,Context.Bed.polygon(source.floor_profile,source.size)):
					entry.visible_polygons.append(Array(polygon))
			entry.kind = target.kind
			entry.seed = entry.get("seed",1)
			_solids.append(entry)
			_solid_groups.append(target.fade_group_id)
	for value in [_scalars,_solids,_plants,_wood_groups,_plant_indexes,_solid_groups]:
		Context._freeze_containers(value)

func solid_fade_group(solid_index: int) -> String:
	return _solid_groups[solid_index]

func plant_target_index(plant_index: int) -> int:
	return int(_plants[plant_index].target_index) if plant_index>=0 and plant_index<_plants.size() else -1

func plant_index_for_target(target_index: int) -> int:
	return int(_plant_indexes.get(target_index,-1))

func plant_for_target(target_index: int) -> Dictionary:
	var index := plant_index_for_target(target_index)
	return _plants[index] if index>=0 else {}

# Called only when a view changes contexts. Identical round resets retain their
# prepared textures; distinct visual metadata cannot alias via gameplay hashes.
func matches(other: RefCounted) -> bool:
	return other != null and _scalars == other._scalars and _solids == other.solids and _plants == other.plants and _wood_groups == other.wood_groups and _solid_groups == other._solid_groups
