extends RefCounted
const Suspicion=preload("res://scripts/fish_suspicion.gd")
var use_caution := false
# Benchmark control shared by A/B; ordinary legacy AI remains unchanged.
var commit_meal := false
var beliefs: Dictionary={}
var belief_bands: Dictionary={}
var belief_focus := -1
const Observation=preload("res://scripts/fish_observation.gd")
var observation: Dictionary={}

# Outputs the same movement/suction/QTE commands as keyboard and mouse input.
# It never writes fish position, stamina, score, hook state or QTE results.
var rng := RandomNumberGenerator.new()
var food_target := -1
var approach_side := -1.0
var hold_point := Vector2.ZERO
var qte_kind := ""
var qte_last_age := -1.0
var qte_press_at := 0.0
var qte_fired := false
var decision_age := 0.0
var escape_target := -1
var state := "觅食"
var hook_reaction := 0.0
var was_hooked := false
var evade_memory := 0.0

func reset(seed_value: int = 2719) -> void:
	observation.clear()
	beliefs.clear(); belief_bands.clear(); belief_focus=-1
	rng.seed=seed_value
	food_target=-1
	escape_target=-1
	qte_kind=""
	qte_last_age=-1
	qte_fired=false
	decision_age=0
	state="觅食"
	was_hooked=false
	hook_reaction=0
	evade_memory=0

func hold(game: Node2D, point: Vector2) -> Vector2:
	var speed: float = game.rule("swim_speed")*game.fatigue_factor()*game.vegetation_drag(game.fish)*game.effort_multiplier("fish")
	return ((point-game.fish)*4-game.line_pull_velocity()-game.water_velocity(game.fish))/maxf(1,speed)

func _judge(game: Node2D) -> bool:
	if game.qte.is_empty() and game.effort_checks.fish.active: return game.effort_ai_press("fish")
	if game.qte.is_empty():
		qte_kind=""
		qte_last_age=-1
		return false
	if game.qte!=qte_kind or game.qte_age<qte_last_age:
		qte_kind=game.qte
		qte_fired=false
		var skill: float = game.rule("ai_entry_skill") if qte_kind=="entry" else game.rule("ai_escape_skill")
		qte_press_at=game.qte_zone+(rng.randf_range(game.qte_width*0.18,game.qte_width*0.72) if rng.randf()<skill else -rng.randf_range(0.06,0.13))
	qte_last_age=game.qte_age
	if not qte_fired and game.qte_progress()>=qte_press_at:
		qte_fired=true
		return true
	return false

func command(game: Node2D, delta: float) -> Dictionary:
	observation=Observation.build(game,false)
	if use_caution:
		var interpretation:=Suspicion.update(beliefs,belief_bands,observation,delta,game.rules,belief_focus)
		beliefs=interpretation["values"]; belief_bands=interpretation.bands; belief_focus=interpretation.focus_bait_id
	var result := {"move":Vector2.ZERO,"aim":game.aim,"power":game.rule("suction_initial"),"suck":false,"dash":false,"slow":false,"qte":false,"home":false}
	if game.landing or game.net_state=="caught": state="被捕获"; return result
	result.qte=_judge(game)
	if game.hooked==game.HookState.MOUTH: state="尝试吐钩"; return result
	var net_alert: bool=game.net_state=="sweep" or (game.net_state=="warning" and game.net_age>minf(0.15,game.net_warning_seconds()*0.3))
	if net_alert and (Geometry2D.is_point_in_polygon(game.fish,game.net_warning_outline()) or game.fish.distance_to(game.net_pos)<65): evade_memory=0.8
	else: evade_memory=maxf(0,evade_memory-delta)
	if net_alert and evade_memory>0:
		var start: Vector2=game.net_pos if game.manual_net else game.net_from
		var direction: Vector2=(game.net_to-start).normalized()
		if direction.length_squared()<0.01: direction=Vector2.from_angle(game.net_angle)
		var normal := direction.orthogonal()
		var projection: Vector2=Geometry2D.get_closest_point_to_segment(game.fish,start,game.net_to)
		var sign_side := signf((game.fish-projection).dot(normal))
		if sign_side==0: sign_side=-1
		var safe := projection+normal*sign_side*85
		if safe.y<game.map_context.water.position.y+15 or safe.y>game.map_context.floor_y-23 or safe.x<game.map_context.water.position.x+20 or safe.x>game.map_context.water.end.x-20: safe=projection-normal*sign_side*85
		result.move=(safe-Vector2(game.fish)).normalized() if game.fish.distance_to(safe)>7 else Vector2.ZERO
		result.dash=game.stamina_ratio()>0.45 and game.net_state=="sweep"
		state="躲避抄网"
		return result
	if game.hooked!=game.HookState.HOOKED: was_hooked=false
	if game.hooked==game.HookState.HOOKED:
		if not was_hooked:
			was_hooked=true
			hook_reaction=game.rule("ai_reaction")
		hook_reaction=maxf(0,hook_reaction-delta)
		if hook_reaction>0:
			state="察觉拉力"
			return result
		if game.qte=="wrap":
			result.move=hold(game,hold_point).limit_length(1)
			state="抗拉缠线"
		elif not game.wraps.is_empty():
			result.move=hold(game,Vector2(game.wraps[-1].entry)-game.aim*10).limit_length(1)
			state="靠近线圈松线"
		elif game.qte=="slack":
			result.move=(game.line_anchor(game.bound_bait)-game.mouth()).normalized()*0.35
			state="保持松线吐钩"
		elif game.contact_target>=0 and game.wrap_retry<=0:
			hold_point=game.fish
			result.qte=true
			result.move=hold(game,hold_point).limit_length(1)
			state="寻找缠线机会"
		elif game.stamina_ratio()<0.18:
			result.move=game.line_pull_velocity().normalized()*0.12
			state="恢复体力"
		else:
			decision_age-=delta
			if decision_age<=0 or escape_target<0:
				decision_age=0.5
				var distance := INF
				for index in game.targets.size():
					if not game.targets[index].capabilities.rope_anchor or game.target_is_wrapped(index): continue
					var point: Vector2=game.targets[index].bounds.get_center().clamp(game.map_context.water.position+Vector2(20,22),Vector2(game.map_context.water.end.x-22,game.map_context.floor_y-25))
					var candidate: float=game.fish.distance_squared_to(point)
					if candidate<distance: distance=candidate; escape_target=index
			if game.tension>game.rule("tension_high")-0.02 and game.stamina_ratio()>0.45:
				result.move=-game.line_pull_velocity().normalized()
				result.dash=true
				state="挣扎拉线"
			elif escape_target>=0:
				var destination: Vector2=game.targets[escape_target].bounds.get_center().clamp(game.map_context.water.position+Vector2(20,22),Vector2(game.map_context.water.end.x-22,game.map_context.floor_y-25))
				result.move=(destination-Vector2(game.fish)).normalized()*0.72
				state="游向掩体"
		return result
	if game.score>=game.food_target()-0.001:
		result.move=(game.map_context.home-Vector2(game.fish)).normalized() if game.fish.distance_to(game.map_context.home)>8 else Vector2.ZERO
		result.home=game.can_home() and not game.returning
		state="带食物回巢"
		return result
	decision_age-=delta
	if (decision_age<=0 and not (commit_meal and game.feeding)) or food_target<0 or not food_position(game,food_target).is_finite():
		decision_age=0.6
		var best := INF
		var selected := -1
		for perceived: Dictionary in observation.perceived_baits:
			var index: int=perceived.bait_id
			var point := food_position(game,index)
			if not point.is_finite(): continue
			var value: float=game.fish.distance_to(point)
			if use_caution:
				value+=maxf(0,float(beliefs.get(index,0.0))-Suspicion.tolerance(observation.self,perceived))*220.0
			if value<best: best=value; selected=index
		if selected!=food_target and selected>=0: approach_side=-1 if game.fish.x<food_position(game,selected).x else 1
		food_target=selected
	if food_target<0: state="等待食物"; return result
	var bait_position := food_position(game,food_target)
	var attached: bool=Observation.find(observation,food_target).get("has_attached_food",false)
	var approach_distance := minf(22.0,game.rule("suction_range")*0.5)
	if use_caution:
		var target_observation:=Observation.find(observation,food_target)
		var effective: float=maxf(0,float(beliefs.get(food_target,0.0))-Suspicion.tolerance(observation.self,target_observation))
		approach_distance=minf(game.rule("suction_range")*0.78,approach_distance+12.0*effective)
	var destination := bait_position+Vector2(approach_side*approach_distance,0)
	# Once a loose grain is in range, hold position instead of backing away from
	# the very grain being pulled towards the mouth.
	if not attached and game.fish.distance_to(bait_position)<game.rule("suction_range"):
		destination=game.fish
		if game.fish.distance_to(bait_position)<12: destination=game.fish-(bait_position-Vector2(game.fish)).normalized()*4
	var difference := destination-Vector2(game.fish)
	result.move=(difference*3-game.water_velocity(game.fish))/game.rule("swim_speed")/game.vegetation_drag(game.fish)
	result.move=Vector2(result.move).limit_length(1)
	result.aim=(bait_position-Vector2(game.fish)).normalized()
	result.suck=game.fish.distance_to(destination)<12
	state="吸食饵料" if result.suck else "寻找食物"
	return result

func food_position(game: Node2D, bait_id: int) -> Vector2:
	if observation.is_empty() or observation.tick!=game.simulation_tick:
		observation=Observation.build(game,false)
	return Observation.food_position(observation,bait_id)
