extends RefCounted

# P2.2 establishes identity and physical silhouettes, not P2.3 feeding balance.
# Multipliers intentionally remain neutral; no profile is a danger label.
const VERSION := 1
const TYPES: Array[String] = ["cluster", "worm", "chunk"]
const PROFILES := {
	"cluster": {"id":"cluster", "visual_kind":"cluster", "shape_hint":"grain_cluster", "smell_hint":"grain", "suction_efficiency":1.0, "bite_efficiency":1.0, "satiety_scale":1.0, "fragmentation":1.0},
	"worm": {"id":"worm", "visual_kind":"worm", "shape_hint":"slender_curved", "smell_hint":"savory", "suction_efficiency":1.0, "bite_efficiency":1.0, "satiety_scale":1.0, "fragmentation":1.0},
	"chunk": {"id":"chunk", "visual_kind":"chunk", "shape_hint":"solid_chunk", "smell_hint":"rich", "suction_efficiency":1.0, "bite_efficiency":1.0, "satiety_scale":1.0, "fragmentation":1.0},
}

static func valid_type(value: Variant) -> bool:
	return value is String and value in TYPES

static func get_profile(kind: String) -> Dictionary:
	return PROFILES[kind].duplicate(true) if valid_type(kind) else {}

static func roll(rng: RandomNumberGenerator) -> String:
	return TYPES[rng.randi_range(0,TYPES.size()-1)]

static func shuffled(rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String]=TYPES.duplicate()
	for index in range(result.size()-1,0,-1):
		var other:=rng.randi_range(0,index)
		var swap:=result[index]; result[index]=result[other]; result[other]=swap
	return result

static func grain_offset(kind: String, legacy: Vector2, particle: int, count: int, layer: int) -> Vector2:
	# Same 44 edible units and layer order. Positions, not just paint, form the
	# silhouette so mouth contact always matches the food the player sees.
	if kind=="worm":
		var along: float=float(particle)/maxi(1,count-1)*2.0-1.0
		var length_scale: float=[7.0,5.0,2.0][layer]
		return Vector2(along*length_scale,sin(along*PI)*1.5+(-0.7 if particle%2==0 else 0.7)).round()
	if kind=="chunk":
		var angle:=TAU*float(particle)/count
		var direction:=Vector2.from_angle(angle)
		var half_size: float=[5.0,3.0,1.0][layer]
		return (direction/maxf(absf(direction.x),absf(direction.y))*Vector2(half_size,half_size*0.8)).round()
	return legacy
