extends RefCounted

const Rules = preload("res://scripts/game_rules.gd")

# Value-only commands shared by local input, AI and future network input.
static func vector(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 and value.is_finite() else fallback

static func number(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

static func flag(command: Dictionary, key: String) -> bool:
	return command.get(key,false)==true

static func fish(command: Dictionary, previous_aim: Vector2, previous_power: float) -> Dictionary:
	return {
		"move":vector(command.get("move"),Vector2.ZERO).limit_length(1),
		"aim":vector(command.get("aim"),previous_aim).normalized(),
		"power":clampf(number(command.get("power"),previous_power),0.1,1),
		"suck":flag(command,"suck"),"dash":flag(command,"dash"),
		"slow":flag(command,"slow"),"qte":flag(command,"qte"),"home":flag(command,"home"),
		"qte_at_age":clampf(number(command.get("qte_at_age"),-1),-1,Rules.MAX_QTE_AGE)
	}

static func angler(command: Dictionary, previous_cursor: Vector2) -> Dictionary:
	var events: Array[Dictionary]=[]
	var source: Variant=command.get("net_events",[])
	if source is Array:
		for event in source:
			if not event is Dictionary: continue
			if event.get("kind","") in ["cancel","suspend"]: events.append({"kind":event.kind})
			elif event.get("kind","")=="point" and event.get("point") is Vector2 and event.point.is_finite():
				events.append({"kind":"point","point":event.point})
	return {
		"walk":clampf(number(command.get("walk"),0),-1,1),
		"target":vector(command.get("target"),previous_cursor),
		"deploy":flag(command,"deploy"),"reel":flag(command,"reel"),"release":flag(command,"release"),
		"untangle":flag(command,"untangle"),
		"qte_condition_valid":command.get("qte_condition_valid",true)==true,
		"net_hold":flag(command,"net_hold"),"drag":flag(command,"drag"),"net_events":events,
		"auto_reel":flag(command,"auto_reel"),"auto_net":flag(command,"auto_net"),
		"qte":flag(command,"qte"),"qte_at_age":clampf(number(command.get("qte_at_age"),-1),-1,Rules.MAX_QTE_AGE)
	}
