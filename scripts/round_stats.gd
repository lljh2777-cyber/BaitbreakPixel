extends RefCounted

static func fresh() -> Dictionary:
	return {"fish_good":0,"fish_total":0,"angler_good":0,"angler_total":0,
		"wrap_good":0,"unwrap_good":0,"breaks":0,"slips":0,"danger_seconds":0.0,"hooked_seconds":0.0,
		"round_duration":0.0,"food_consumed":0.0,"feeding_attempts":0,"feeding_aborts":0,
		"bait_approaches":0,"bait_retreats":0,"hook_contacts":0,"hook_events":0,"successful_escapes":0,
		"instinct_trigger_count":0,"instinct_total_duration":0.0,"satiety_min":100.0,"satiety_mean":100.0,
		"satiety_integral":0.0,"critical_satiety_seconds":0.0,"caution_low_seconds":0.0,"caution_medium_seconds":0.0,"caution_high_seconds":0.0}

static func record(stats: Dictionary, role: String, good: bool) -> void:
	stats[role+"_total"]+=1
	if good: stats[role+"_good"]+=1

static func rate(stats: Dictionary, role: String) -> String:
	var total: int=stats[role+"_total"]
	return "—（未判定）" if total==0 else "%d%%（%d/%d）" % [roundi(100.0*stats[role+"_good"]/total),stats[role+"_good"],total]

static func valid(stats: Dictionary) -> bool:
	for key in fresh():
		if not stats.has(key) or typeof(stats[key])!=typeof(fresh()[key]) or stats[key]<0: return false
	return stats.fish_good<=stats.fish_total and stats.angler_good<=stats.angler_total

# Sampling uses observed transitions and final authority counters, never drives play.
static func before(world: Node2D) -> Dictionary:
	return {"elapsed":world.elapsed,"feeding":world.feeding,"score":world.score,"hooks":world.hook_count,
		"near":_near_ids(world),"instinct":float(world.get("instinct_drive") if world.get("instinct_drive")!=null else 0.0)}

static func _near_ids(world: Node2D) -> Array:
	var ids: Array=[]
	for bait in world.baits:
		if bait.active and world.fish.distance_to(bait.pos)<60: ids.append(bait.bait_id)
	return ids

static func sample(world: Node2D, previous: Dictionary) -> void:
	var dt: float=world.elapsed-float(previous.elapsed)
	if dt<=0: return
	var stats: Dictionary=world.round_stats
	stats.round_duration=world.elapsed
	stats.food_consumed=world.score
	stats.hook_contacts=world.hook_count
	stats.hook_events=world.hook_count
	stats.successful_escapes=world.escape_count
	if world.feeding and not previous.feeding: stats.feeding_attempts+=1
	if previous.feeding and not world.feeding and world.score==previous.score: stats.feeding_aborts+=1
	var near:=_near_ids(world)
	for id in near:
		if not id in previous.near: stats.bait_approaches+=1
	for id in previous.near:
		if not id in near: stats.bait_retreats+=1
	var satiety: float=world.get("satiety") if world.get("satiety")!=null else 100.0
	stats.satiety_min=minf(stats.satiety_min,satiety)
	stats.satiety_integral+=satiety*dt
	stats.satiety_mean=stats.satiety_integral/maxf(world.elapsed,0.0001)
	if satiety<=25: stats.critical_satiety_seconds+=dt
	var instinct: float=world.get("instinct_drive") if world.get("instinct_drive")!=null else 0.0
	if instinct>0:
		stats.instinct_total_duration+=dt
		if previous.instinct<=0: stats.instinct_trigger_count+=1
	var caution: String=world.get("caution_state") if world.get("caution_state")!=null else "CALM"
	stats[{"CALM":"caution_low_seconds","UNEASY":"caution_medium_seconds","ALARMED":"caution_high_seconds"}.get(caution,"caution_low_seconds")]+=dt
