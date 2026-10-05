extends RefCounted

const VERSION := 1
const MapContext=preload("res://scripts/maps/map_context.gd")
# Peers must share the exact build and validated built-in MapRef before play.
const BUILD := "0.28.0"
const DEFAULT_PORT := 24712
const MAX_PACKET := 196608
const MAX_STATE := 1048576
const MAX_EVENTS := 512
const Commands = preload("res://scripts/game_commands.gd")

static func safe_values(value: Variant, depth: int = 0) -> bool:
	if depth>12: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return true
		TYPE_STRING,TYPE_STRING_NAME: return value.length()<=4096
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR2: return value.is_finite() and absf(value.x)<100000 and absf(value.y)<100000
		TYPE_PACKED_BYTE_ARRAY: return value.size()<=MAX_PACKET
		TYPE_ARRAY,TYPE_PACKED_VECTOR2_ARRAY:
			if value is Array and value.is_typed() and value.get_typed_builtin()==TYPE_OBJECT: return false
			if value.size()>8192: return false
			for item in value:
				if not safe_values(item,depth+1): return false
			return true
		TYPE_DICTIONARY:
			if value.get_typed_key_builtin()==TYPE_OBJECT or value.get_typed_value_builtin()==TYPE_OBJECT: return false
			if value.size()>8192: return false
			for key in value:
				if not (key is String or key is StringName or key is int) or not safe_values(value[key],depth+1): return false
			return true
	return false

static func encode(message: Dictionary) -> PackedByteArray:
	var data := var_to_bytes(message)
	return data if data.size()<=MAX_PACKET else PackedByteArray()

static func decode(data: PackedByteArray) -> Dictionary:
	if data.size()<4 or data.size()>MAX_PACKET: return {}
	var value: Variant=bytes_to_var(data) # Object decoding is deliberately disabled.
	return value if value is Dictionary and safe_values(value) else {}

static func pack_state(snapshot: Dictionary) -> Dictionary:
	var raw := var_to_bytes(snapshot)
	if raw.size()>MAX_STATE: return {}
	return {"size":raw.size(),"data":raw.compress(FileAccess.COMPRESSION_DEFLATE)}

static func unpack_state(packet: Dictionary) -> Dictionary:
	if not packet.get("size") is int or packet.size<=0 or packet.size>MAX_STATE: return {}
	if not packet.get("data") is PackedByteArray or packet.data.size()>MAX_PACKET: return {}
	var raw: PackedByteArray=packet.data.decompress(packet.size,FileAccess.COMPRESSION_DEFLATE)
	if raw.size()!=packet.size: return {}
	var value: Variant=bytes_to_var(raw)
	return value if value is Dictionary and safe_values(value) else {}

# Map bounds are an explicit input: wire sanitization must never silently use
# another round's default pond geometry. No map lookup/hash runs per input tick.
static func input(role: String, raw: Dictionary, context: MapContext) -> Dictionary:
	if role=="fish":
		var clean := Commands.fish(raw,Vector2.RIGHT,0.35)
		clean.qte_at_age=-1.0 # Never trust a client's claimed timing or success.
		return clean
	var clean := Commands.angler(raw,context.water.position+Vector2(224,112))
	clean.qte_at_age=-1.0
	clean.qte_condition_valid=true # Authority derives conditions from its own history.
	clean.auto_reel=false
	clean.auto_net=false
	clean.target=clean.target.clamp(Vector2.ZERO,context.size)
	if clean.net_events.size()>MAX_EVENTS: clean.net_events.resize(MAX_EVENTS)
	return clean

static func neutral(role: String, world: Node2D) -> Dictionary:
	return {"aim":world.aim,"power":world.power} if role=="fish" else {"target":world.angler.cursor}
