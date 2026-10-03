extends RefCounted

# Only public perception/environment, own memory and an NPC-local RNG enter here.
# No World reference, truth, food mutation, or authority RNG access.
const Suspicion=preload("res://scripts/fish_suspicion.gd")
const FoodProfile=preload("res://scripts/food_profile.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const SEEK_BELOW := 82.0
const REST_ABOVE := 94.0
const FEED_PERIOD := 1.6

static func decide(observation: Dictionary, memory: Dictionary, environment: Dictionary, rules: Dictionary, delta: float, local_rng: RandomNumberGenerator) -> Dictionary:
	# Always run the same cruise clock and local random draws. Disabling foraging
	# is exactly the original movement-only path, including its return shape.
	var intent:=_wander(observation,memory,environment,delta,local_rng)
	if not bool(environment.get("foraging_enabled",false)): return intent
	if Vector2(intent.aim).length_squared()<0.000001: intent.aim=Vector2(observation.self.aim)
	var interpretation:=Suspicion.update(memory.get("suspicion_by_bait",{}),memory.get("caution_by_bait",{}),observation,delta,rules,int(memory.get("focus_bait_id",-1)))
	for key in interpretation: intent[key]=interpretation[key]
	intent.power=float(rules.suction_initial)
	var self_state: Dictionary=observation.self
	var satiety:=clampf(float(self_state.satiety),0.0,100.0)
	var appetite:=1.0-satiety/100.0
	var continuing: bool=memory.get("behavior_state","WANDER") in ["APPROACH_FOOD","FEED"]
	if satiety>=(REST_ABOVE if continuing else SEEK_BELOW): return intent
	var selected: Dictionary={}
	var best:=INF
	var old_target:=int(memory.get("target_bait_id",-1))
	for bait: Dictionary in observation.perceived_baits:
		if not bait.food_position is Vector2 or not Vector2(bait.food_position).is_finite(): continue
		var distance: float=Vector2(self_state.position).distance_to(bait.food_position)
		# Appetite controls how far a fish commits and how much uncertain motion
		# it accepts. No food type or apparent stillness proves safety.
		if distance>lerpf(140.0,540.0,appetite): continue
		var id:=int(bait.bait_id)
		var risk:=Suspicion.tolerance(self_state,bait)
		var concern:=maxf(0.0,float(interpretation.values.get(id,0.0))-risk)
		if concern>lerpf(0.18,0.58,appetite): continue
		var kind:=observed_kind(bait)
		var appeal: float={"cluster":1.0,"worm":1.10,"chunk":1.15}.get(kind,1.0)
		var cost:=distance/appeal+concern*180.0-(12.0 if id==old_target else 0.0)
		if cost<best or is_equal_approx(cost,best) and (selected.is_empty() or id<int(selected.bait_id)):
			best=cost; selected=bait
	if selected.is_empty(): return intent
	var target:=int(selected.bait_id)
	intent.target_bait_id=target
	intent.focus_bait_id=target
	intent.risk_tolerance=Suspicion.tolerance(self_state,selected)
	intent.caution_state=interpretation.bands.get(target,"CALM")
	var position: Vector2=self_state.position
	var food: Vector2=selected.food_position
	var heading: Vector2=(food-position).normalized()
	if heading.length_squared()<0.001: heading=Vector2(self_state.aim)
	var kind:=observed_kind(selected)
	var use_suction: bool=not bool(selected.get("has_attached_food",false)) or kind in ["cluster","unknown"]
	# Only public shape/smell cues influence the bite-versus-suction preference.
	# Both actions still go through the shared physical reach/intake authority.
	var standoff:=minf(26.0,float(rules.suction_range)*0.6) if use_suction else minf(5.0,float(rules.bite_range)*0.5)
	var mouth_offset: float=Vector2(self_state.mouth).distance_to(position)
	var destination:=food-heading*(mouth_offset+standoff)
	var bounds: Rect2=environment.bounds
	destination=destination.clamp(bounds.position,bounds.end-Vector2.ONE*0.001)
	# Loose food is already travelling to the mouth; don't back away from it.
	if use_suction and not bool(selected.get("has_attached_food",false)) and position.distance_to(food)<mouth_offset+standoff:
		destination=position
	var offset:=destination-position
	var neighbors:=_separation(position,int(self_state.fish_id),environment.neighbors)
	# Preserve body-space separation without overpowering approach at a shared
	# food source. The mouth can aim independently of this lateral correction.
	var lateral:=neighbors-heading*neighbors.dot(heading)
	var wanted:=offset*2.0-Vector2(self_state.velocity)*0.55+lateral*12.0
	intent.move=(wanted/State.SPEED).limit_length(1.0)
	intent.aim=heading
	intent.state="APPROACH_FOOD"
	var mouth: Vector2=self_state.mouth
	var to_food:=food-mouth
	var aligned: bool=Vector2(self_state.aim).dot(heading)>0.90
	var in_reach: bool=to_food.length()<float(rules.suction_range)*0.86 if use_suction else to_food.length()<=float(rules.bite_range)+2.0
	if offset.length()<10.0 and aligned and in_reach:
		# A hungry fish spends more of each cycle eating; the authority still owns
		# the same bite cooldown. Rest windows keep the approach position/target.
		var phase:=fposmod(float(observation.tick)/60.0+float(self_state.fish_id)*0.37,FEED_PERIOD)
		if phase<FEED_PERIOD*lerpf(0.25,0.95,appetite):
			intent.state="FEED"
			intent.suck=use_suction
	return intent

static func observed_kind(bait: Dictionary) -> String:
	var hints: Dictionary=bait.get("hints",{})
	# Read only the profile's public identity cues; distant food remains unknown.
	for kind: String in FoodProfile.TYPES:
		var profile:=FoodProfile.get_profile(kind)
		if hints.get("shape_hint","")==profile.shape_hint and hints.get("smell_hint","")==profile.smell_hint: return kind
	return "unknown"

static func _separation(position: Vector2, fish_id: int, neighbors: Array) -> Vector2:
	var separation:=Vector2.ZERO
	for neighbor: Dictionary in neighbors:
		if int(neighbor.fish_id)==fish_id: continue
		var offset:=position-Vector2(neighbor.position)
		var distance:=offset.length()
		var radius:=55.0 if int(neighbor.fish_id)==1 else 38.0
		if distance<radius:
			var direction:=offset/distance if distance>0.001 else Vector2.RIGHT.rotated(float(fish_id)*2.399963)
			separation+=direction*(1.0-distance/radius)
	return separation

static func _wander(observation: Dictionary, memory: Dictionary, environment: Dictionary, delta: float, local_rng: RandomNumberGenerator) -> Dictionary:
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
	var separation:=_separation(position,int(self_state.fish_id),environment.neighbors)
	var steer: Vector2=(heading+avoidance*2.6+separation*1.4).normalized()
	return {"move":steer,"aim":steer,"suck":false,"state":"WANDER","target_bait_id":-1,
		"wander_heading":heading,"turn_age":turn_age}
