extends RefCounted

# Pure value rules: no scene tree, profile I/O, input, or presentation state.
const Catalog = preload("res://scripts/rules_catalog.gd")
const VERSION := 1
const QTE_KINDS := ["entry","slack","wrap","fish_effort","angler_effort","untangle"]
const LEGACY_PROPERTIES := ["water_strength","practice_line_sensitivity","practice_line_force","practice_effort_frequency","practice_effort_window","practice_effort_boost","practice_effort_weak","slack_hold_seconds","mouth_window_seconds","break_hold_seconds"]
const MAX_QTE_AGE := 10.3 # Validation ceiling, not a gameplay duration.

static func defaults() -> Dictionary:
	var values := {}
	for item in Catalog.ITEMS: values[item.id]=item.value
	return values

static func normalize(input: Dictionary) -> Dictionary:
	var values := defaults()
	for item in Catalog.ITEMS:
		var raw: Variant=input.get(item.id,item.value)
		if item.value is bool:
			if raw is bool: values[item.id]=raw
		elif (raw is float or raw is int) and is_finite(float(raw)):
			values[item.id]=float(String.num(snappedf(clampf(float(raw),item.min,item.max),item.step),6))
			if is_equal_approx(values[item.id],item.value): values[item.id]=item.value
	# Keep dependent values playable. The editor reports every adjustment.
	values.tension_high=maxf(values.tension_high,values.tension_low+0.05)
	values.untangle_max=maxf(values.untangle_max,values.untangle_min+0.05)
	values.line_free_max=minf(values.line_free_max,values.line_max)
	values.cast_depth=minf(values.cast_depth,values.line_free_max)
	values.net_capture_min=minf(values.net_capture_min,values.net_capture_base)
	var supply: float=4.0*values.bait_points
	values.food_goal=minf(values.food_goal,supply)
	values.practice_goal=minf(values.practice_goal,supply)
	for kind in QTE_KINDS:
		var prefix: String="qte_"+kind+"_"
		values[prefix+"window"]=minf(values[prefix+"window"],values[prefix+"sweep"]*0.8)
		values[prefix+"zone"]=minf(values[prefix+"zone"],maxf(0.1,0.9-values[prefix+"window"]/values[prefix+"sweep"]))
	return values

static func valid(values: Variant) -> bool:
	if not values is Dictionary or values.size()!=Catalog.ITEMS.size(): return false
	for item in Catalog.ITEMS:
		if not values.has(item.id): return false
		var value: Variant=values[item.id]
		if item.value is bool:
			if not value is bool: return false
		elif not (value is float or value is int) or not is_finite(float(value)) or value<item.min-0.000001 or value>item.max+0.000001: return false
	var normalized := normalize(values)
	for key in values:
		if values[key] is bool:
			if values[key]!=normalized[key]: return false
		elif not is_equal_approx(float(values[key]),float(normalized[key])): return false
	return true

static func qte(values: Dictionary, kind: String) -> Dictionary:
	var prefix := "qte_"+kind+"_"
	return {"lead":float(values[prefix+"lead"]),"sweep":float(values[prefix+"sweep"]),"window":float(values[prefix+"window"]),
		"random":bool(values[prefix+"random"]),"zone":float(values[prefix+"zone"])}

static func changed(values: Dictionary) -> Dictionary:
	var result := {}
	for item in Catalog.ITEMS:
		if item.value is bool:
			if values.get(item.id,item.value)!=item.value: result[item.id]=values[item.id]
		elif not is_equal_approx(float(values.get(item.id,item.value)),item.value): result[item.id]=values[item.id]
	return result

static func legacy(config: Dictionary) -> Dictionary:
	# One-time old profile/config migration and compatibility for existing probes.
	var values: Dictionary=config.get("rules",{}).duplicate(true) if config.get("rules",{}) is Dictionary else {}
	var aliases := {"slack_hold":"slack_hold","break_hold":"break_hold","water_strength":"water_strength","line_sensitivity":"line_response","line_force":"line_force"}
	for old in aliases:
		if config.has(old): values[aliases[old]]=config[old]
	if config.has("mouth_window"):
		values.qte_entry_window=config.mouth_window
		values.qte_slack_window=config.mouth_window
	for role in ["fish","angler"]:
		for field in ["frequency","window","boost","weak"]:
			var old: String="effort_"+field
			if config.has(old): values[("qte_"+role+"_effort_window") if field=="window" else role+"_effort_"+field]=config[old]
	return normalize(values)

static func document(values: Dictionary) -> Dictionary:
	return {"format":"baitbreak-rules","version":VERSION,"values":normalize(values)}

static func parse_document(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("format")!="baitbreak-rules" or data.get("version")!=VERSION or not data.get("values") is Dictionary: return {"error":"规则文件格式或版本不支持"}
	var known := defaults()
	for key in data.values:
		if not known.has(key): return {"error":"未知选项："+str(key)}
		var raw: Variant=data.values[key]
		if known[key] is bool:
			if not raw is bool: return {"error":"开关值无效："+str(key)}
		elif not (raw is float or raw is int) or not is_finite(float(raw)): return {"error":"数值无效："+str(key)}
	return {"values":normalize(data.values)}

static func parse_text(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text)!=OK: return {"error":"JSON 格式有误（第 %d 行）：%s" % [parser.get_error_line()+1,parser.get_error_message()]}
	return parse_document(parser.data)
