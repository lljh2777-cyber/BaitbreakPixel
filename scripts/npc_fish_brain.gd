extends RefCounted

# Only public perception/environment, own memory and an NPC-local RNG enter here.
# No World reference, truth, food mutation, or authority RNG access.
const Suspicion=preload("res://scripts/fish_suspicion.gd")
const FoodProfile=preload("res://scripts/food_profile.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const SEEK_BELOW := 82.0
const REST_ABOVE := 94.0
const FEED_PERIOD := 1.6
const SOCIAL_DISTANCE := 160.0
const DANGER_DISTANCE := 150.0
const DANGER_TICKS := 45
const HESITATE_MOTION := 3.0
const FLEE_MOTION := 18.0
const COMPETE_SATIETY := 60.0

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
	var social_enabled:=bool(environment.get("social_enabled",true))
	_update_social(intent,observation,memory,environment,delta,appetite,social_enabled)
	if intent.state in ["HESITATE","FLEE"]: return intent
	var continuing: bool=memory.get("behavior_state","WANDER") in ["APPROACH_FOOD","FEED","COMPETE","HESITATE"]
	if satiety>=(REST_ABOVE if continuing else SEEK_BELOW):
		intent.social_compete_left=0.0
		return intent
	var competing: Dictionary={}
	if social_enabled and satiety<=(COMPETE_SATIETY+5.0 if float(memory.get("social_compete_left",0.0))>0.0 else COMPETE_SATIETY):
		competing=_contested_food(observation,rules)
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
		if competing.has(id): cost-=lerpf(18.0,42.0,appetite)
		# A brief observed contest keeps its target through a feeder's rest pulse.
		if id==old_target and float(intent.social_compete_left)>0.0: cost-=18.0
		if cost<best or is_equal_approx(cost,best) and (selected.is_empty() or id<int(selected.bait_id)):
			best=cost; selected=bait
	if selected.is_empty():
		intent.social_compete_left=0.0
		return intent
	var target:=int(selected.bait_id)
	intent.target_bait_id=target
	if competing.has(target): intent.social_compete_left=State.COMPETE_SECONDS
	elif target!=old_target or satiety>COMPETE_SATIETY+5.0: intent.social_compete_left=0.0
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
	intent.state="COMPETE" if float(intent.social_compete_left)>0.0 else "APPROACH_FOOD"
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

# The social layer uses the same perception surface as feeding, plus visible
# feeding actions and realized public danger events. It never infers certainty.
# Timers advance only on decisions; steady cues are edge-latched, not renewed.
static func _update_social(intent: Dictionary, observation: Dictionary, memory: Dictionary, environment: Dictionary, delta: float, appetite: float, enabled: bool) -> void:
	var dt:=maxf(0.0,delta)
	intent.social_reaction_left=maxf(0.0,float(memory.get("social_reaction_left",0.0))-dt) if enabled else 0.0
	intent.social_recovery_left=maxf(0.0,float(memory.get("social_recovery_left",0.0))-dt) if enabled else 0.0
	intent.social_origin=Vector2(memory.get("social_origin",Vector2.ZERO)) if enabled else Vector2.ZERO
	intent.social_bait_id=int(memory.get("social_bait_id",-1)) if enabled else -1
	intent.social_motion_level=0
	intent.social_danger_tick=int(memory.get("social_danger_tick",-1)) if enabled else -1
	intent.social_compete_left=maxf(0.0,float(memory.get("social_compete_left",0.0))-dt) if enabled else 0.0
	if not enabled: return
	var self_state: Dictionary=observation.self
	var position: Vector2=self_state.position
	var strongest: Dictionary={}
	var nearest:=INF
	for bait: Dictionary in observation.perceived_baits:
		if not bait.food_position is Vector2 or not Vector2(bait.food_position).is_finite(): continue
		var distance:=position.distance_to(bait.food_position)
		if distance>SOCIAL_DISTANCE: continue
		var hints: Dictionary=bait.get("hints",{})
		var motion: Dictionary=hints.get("motion",{})
		var speed: float=(Vector2(motion.get("velocity",Vector2.ZERO))-Vector2(motion.get("water_drift",Vector2.ZERO))).length() if not motion.is_empty() else 0.0
		# A suction offset, loose food or a quiet appearance is not danger evidence.
		var level:=2 if speed>=FLEE_MOTION else (1 if speed>=HESITATE_MOTION or bool(hints.get("disturbances",{}).get("recent_motion",false)) else 0)
		if level>int(intent.social_motion_level) or level==int(intent.social_motion_level) and level>0 and (distance<nearest or is_equal_approx(distance,nearest) and (strongest.is_empty() or int(bait.bait_id)<int(strongest.bait_id))):
			intent.social_motion_level=level
			strongest=bait
			nearest=distance
	var danger: Dictionary={}
	var latest:=int(intent.social_danger_tick)
	var tick:=int(observation.tick)
	for event: Dictionary in observation.get("social_cues",{}).get("danger_events",[]):
		var event_tick:=int(event.get("tick",-1))
		var point: Variant=event.get("position",null)
		if event_tick<0 or event_tick>tick or tick-event_tick>DANGER_TICKS or event_tick<=latest: continue
		if not point is Vector2 or not point.is_finite() or position.distance_to(point)>DANGER_DISTANCE: continue
		danger=event; latest=event_tick
	var previous_state:=String(memory.get("behavior_state","WANDER"))
	var reaction:=previous_state if float(intent.social_reaction_left)>0.0 and previous_state in ["HESITATE","FLEE"] else ""
	if not danger.is_empty():
		intent.social_danger_tick=latest
		_start_reaction(intent,"FLEE",danger.position,-1,State.FLEE_SECONDS)
		reaction="FLEE"
	else:
		var level:=int(intent.social_motion_level)
		var new_motion:=level>int(memory.get("social_motion_level",0))
		var escalation:=level==2 and reaction=="HESITATE"
		if level>0 and new_motion and (float(intent.social_recovery_left)<=0.0 or escalation):
			reaction="FLEE" if level==2 else "HESITATE"
			_start_reaction(intent,reaction,strongest.food_position,int(strongest.bait_id),State.FLEE_SECONDS if level==2 else lerpf(0.84,0.60,appetite))
	if reaction.is_empty():
		intent.social_reaction_left=0.0
		intent.social_origin=Vector2.ZERO
		intent.social_bait_id=-1
		return
	intent.state=reaction
	intent.social_compete_left=0.0
	intent.suck=false
	var source: Vector2=intent.social_origin
	var toward: Vector2=(source-position).normalized()
	if toward.length_squared()<0.001: toward=Vector2(self_state.aim)
	if reaction=="FLEE":
		intent.move=_escape_direction(position,-toward,environment.bounds,int(self_state.fish_id))
		intent.aim=intent.move
		intent.target_bait_id=-1
		return
	# An investigating fish briefly circles/slows and looks at the observed source.
	# A disappeared source keeps only this short-lived position, never a food claim.
	var handedness:=1.0 if int(self_state.fish_id)%2==0 else -1.0
	var lateral:=toward.orthogonal()*handedness
	var move: Vector2=lateral*0.22-toward*clampf((44.0-position.distance_to(source))/70.0,-0.08,0.13)-Vector2(self_state.velocity)/State.SPEED*0.25
	move=move.limit_length(0.32)
	var bounds: Rect2=environment.bounds
	intent.move=((position+move*20.0).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)-position)/20.0
	intent.aim=toward
	for bait: Dictionary in observation.perceived_baits:
		if int(bait.bait_id)!=int(intent.social_bait_id) or not bait.food_position is Vector2 or not Vector2(bait.food_position).is_finite(): continue
		intent.target_bait_id=int(bait.bait_id)
		intent.focus_bait_id=int(bait.bait_id)
		intent.caution_state=intent.bands.get(int(bait.bait_id),"CALM")
		intent.risk_tolerance=Suspicion.tolerance(self_state,bait)
		break

static func _start_reaction(intent: Dictionary, reaction: String, position: Vector2, bait_id: int, seconds: float) -> void:
	intent.state=reaction
	intent.social_reaction_left=seconds
	intent.social_recovery_left=State.SOCIAL_RECOVERY_SECONDS
	intent.social_origin=position
	intent.social_bait_id=bait_id

static func _escape_direction(position: Vector2, away: Vector2, bounds: Rect2, fish_id: int) -> Vector2:
	var destination: Vector2=(position+away*100.0).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)
	if destination.distance_to(position)>=20.0: return (destination-position).normalized()
	# At a bank, take the available tangent instead of continuously swimming out.
	var left: Vector2=(position+away.orthogonal()*100.0).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)-position
	var right: Vector2=(position-away.orthogonal()*100.0).clamp(bounds.position,bounds.end-Vector2.ONE*0.001)-position
	var tangent:=left if left.length_squared()>right.length_squared() or is_equal_approx(left.length_squared(),right.length_squared()) and fish_id%2==0 else right
	return tangent.normalized() if tangent.length_squared()>0.001 else Vector2.RIGHT

static func _contested_food(observation: Dictionary, rules: Dictionary) -> Dictionary:
	var result: Dictionary={}
	var self_state: Dictionary=observation.self
	var reach:=minf(64.0,maxf(18.0,float(rules.suction_range)+14.0))
	for other: Dictionary in observation.get("social_cues",{}).get("feeding_fish",[]):
		if int(other.get("fish_id",-1))==int(self_state.fish_id) or not bool(other.get("feeding",false)): continue
		var position: Variant=other.get("position",null)
		var mouth: Variant=other.get("mouth",null)
		if not position is Vector2 or not position.is_finite() or not mouth is Vector2 or not mouth.is_finite(): continue
		if Vector2(self_state.position).distance_to(position)>SOCIAL_DISTANCE: continue
		for bait: Dictionary in observation.perceived_baits:
			if bait.food_position is Vector2 and Vector2(bait.food_position).is_finite() and Vector2(mouth).distance_to(bait.food_position)<=reach:
				result[int(bait.bait_id)]=true
	return result

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
