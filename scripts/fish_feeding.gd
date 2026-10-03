extends RefCounted

# Shared physical mouth contract. Callers supply geometry, never hook truth.
const FoodProfile=preload("res://scripts/food_profile.gd")
const Suction=preload("res://scripts/suction_feel.gd")

static func mouth(position: Vector2, aim: Vector2) -> Vector2:
	return position+aim*10.0

static func strength(point: Vector2, origin: Vector2, aim: Vector2, rules: Dictionary) -> float:
	var local:=point-origin
	var depth:=local.dot(aim)
	var side:=absf(local.cross(aim))
	if depth<0 or depth>float(rules.suction_range) or side>float(rules.suction_mouth)+depth*float(rules.suction_spread): return 0.0
	return Suction.distance_gain(depth/float(rules.suction_range))*(1-0.2*side/(float(rules.suction_mouth)+depth*float(rules.suction_spread)))

static func candidates(baits: Array, counted: Dictionary, origin: Vector2, radius: float) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	for bait: Dictionary in baits:
		for order in bait.grains.size():
			var grain: Dictionary=bait.grains[order]
			if grain.eaten or counted.has(grain.id) or (not bait.active and not grain.free): continue
			var distance:=origin.distance_squared_to(Vector2(grain.pos))
			if distance<=radius*radius:
				found.append({"distance":distance,"bait_id":int(bait.bait_id),"order":order,"grain":grain})
	found.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.distance!=b.distance: return a.distance<b.distance
		if a.bait_id!=b.bait_id: return a.bait_id<b.bait_id
		return a.order<b.order)
	return found

static func bite_selection(candidates: Array[Dictionary], capacity: float) -> Array[Dictionary]:
	var selected: Array[Dictionary]=[]
	for candidate: Dictionary in candidates:
		var cost:=1.0/float(FoodProfile.get_profile(candidate.grain.visual_kind).bite_efficiency)
		if cost>capacity+0.000001: break # Stable nearest-first; never skip expensive food.
		capacity-=cost
		selected.append(candidate.grain)
	return selected
