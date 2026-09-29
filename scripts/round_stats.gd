extends RefCounted

static func fresh() -> Dictionary:
	return {"fish_good":0,"fish_total":0,"angler_good":0,"angler_total":0,
		"wrap_good":0,"breaks":0,"slips":0,"danger_seconds":0.0,"hooked_seconds":0.0}

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
