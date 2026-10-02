extends RefCounted

# Only adds bounded movement pressure. It never changes suction or button inputs.
static func sample(observation: Dictionary, satiety: float, rules: Dictionary) -> Dictionary:
	var drive:=0.0
	if rules.hunger_enabled:
		drive=pow(clampf(1.0-satiety/float(rules.instinct_start_threshold),0,1),2)
	var nearest: Dictionary={}
	var distance:=INF
	for bait: Dictionary in observation.perceived_baits:
		if not bait.food_position is Vector2: continue
		var candidate: float=Vector2(observation.self.position).distance_squared_to(bait.food_position)
		if candidate<distance: distance=candidate; nearest=bait
	var bias:=Vector2.ZERO
	if not nearest.is_empty():
		var direction: Vector2=(Vector2(nearest.food_position)-Vector2(observation.self.position)).normalized()
		bias=direction*minf(0.45,minf(float(rules.instinct_max_strength),drive*float(rules.instinct_strength)*float(rules.instinct_max_strength)))
	return {"drive":drive,"bias":bias,"bait_id":int(nearest.bait_id) if not nearest.is_empty() else -1}

static func combine(player_input: Vector2, bias: Vector2) -> Vector2:
	# A unit opposing input always retains at least 55% of its direction.
	return (player_input.limit_length(1)+bias.limit_length(0.45)).limit_length(1)
