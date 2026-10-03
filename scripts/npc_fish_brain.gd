extends RefCounted

# Only public perception/environment, own memory and an NPC-local RNG enter here.
# No World reference, truth, hook assignment, food mutation, or authority RNG access.
static func decide(observation: Dictionary, memory: Dictionary, environment: Dictionary, _rules: Dictionary, delta: float, local_rng: RandomNumberGenerator) -> Dictionary:
	var self_state: Dictionary=observation.self
	var heading: Vector2=memory.wander_heading
	var turn_age:=maxf(0.0,float(memory.turn_age)-delta)
	if turn_age<=0:
		heading=heading.rotated(local_rng.randf_range(-0.85,0.85)).normalized()
		turn_age=local_rng.randf_range(1.6,3.8)
	var position: Vector2=self_state.position
	var bounds: Rect2=environment.bounds
	var projected:=position+Vector2(self_state.velocity)*0.9
	var avoidance:=Vector2.ZERO
	var margin:=65.0
	avoidance.x=clampf((bounds.position.x+margin-projected.x)/margin,0,1)-clampf((projected.x-bounds.end.x+margin)/margin,0,1)
	avoidance.y=clampf((bounds.position.y+margin-projected.y)/margin,0,1)-clampf((projected.y-bounds.end.y+margin)/margin,0,1)
	# Keep a coherent cruise direction after turning away, instead of jittering
	# against the boundary while an old target continues to pull outward.
	if avoidance.length()>0.05: heading=heading.lerp(avoidance.normalized(),0.28).normalized()
	var separation:=Vector2.ZERO
	for neighbor: Dictionary in environment.neighbors:
		if int(neighbor.fish_id)==int(self_state.fish_id): continue
		var offset:=position-Vector2(neighbor.position)
		var distance:=offset.length()
		var radius:=55.0 if int(neighbor.fish_id)==1 else 38.0
		if distance<radius:
			# Coincident fish separate deterministically without index dependence.
			var direction:=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(float(self_state.fish_id)*2.399963)
			separation+=direction*(1.0-distance/radius)
	var steer: Vector2=(heading+avoidance*2.6+separation*1.4).normalized()
	return {"move":steer,"aim":steer,"suck":false,"state":"WANDER","target_bait_id":-1,
		"wander_heading":heading,"turn_age":turn_age}
