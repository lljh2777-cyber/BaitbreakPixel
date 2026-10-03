extends RefCounted

# Shared render/wire projection. Only contact-derived hook outcomes are public;
# food targets, decisions, struggle phase and all private timers stay authoritative.
const Layout=preload("res://scripts/pond_layout.gd")
const FIELDS: Array[String] = ["fish_id","position","velocity","aim","visual_variant","animation_state"]
const HOOK_FIELDS: Array[String] = ["phase"]
const RESULT_FIELDS: Array[String] = ["tick","fish_id","result","position"]
const MAX_FISH := 6
const VARIANTS := 3
const BODY_RADIUS := 10.0
const MAX_SPEED := 38.0
const MAX_HOOK_SPEED := 150.0

static func capture(states: Array, target_id: int=-1, hook: Dictionary={}) -> Array[Dictionary]:
	var visible: Array[Dictionary]=[]
	for state: Dictionary in states:
		if not bool(state.get("active",true)): continue
		# Existing public records must survive a second render-only projection.
		var animation: String=String(state.get("animation_state","swim"))
		if int(state.fish_id)==target_id and hook.get("phase","") in ["hooked","landing"]:
			animation=String(hook.phase)
		visible.append({"fish_id":int(state.fish_id),"position":Vector2(state.position),
			"velocity":Vector2(state.velocity),"aim":Vector2(state.aim),
			"visual_variant":int(state.visual_variant),"animation_state":animation})
	visible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.fish_id<b.fish_id)
	return visible

static func capture_hook(hook: Dictionary) -> Dictionary:
	return {"phase":String(hook.get("phase",""))}

static func capture_result(result: Dictionary) -> Dictionary:
	var visible: Dictionary={}
	for key: String in RESULT_FIELDS: visible[key]=result[key]
	return visible

static func _keys(record: Dictionary, fields: Array[String]) -> bool:
	if record.size()!=fields.size(): return false
	for key: String in fields:
		if not record.has(key): return false
	return true

static func landing_bounds() -> Rect2:
	var bounds:=Layout.fish_bounds(BODY_RADIUS)
	return Rect2(bounds.position.x,39.0,bounds.size.x,bounds.end.y-39.0)

static func valid_result(result: Variant, tick: int) -> bool:
	if not result is Dictionary or not _keys(result,RESULT_FIELDS): return false
	if not result.tick is int or not result.fish_id is int or not result.result is String or not result.position is Vector2 or not result.position.is_finite(): return false
	if result.tick==-1:
		return result.fish_id==-1 and result.result=="" and result.position==Vector2.ZERO
	return result.tick>=0 and result.tick<=tick and result.fish_id>=2 and result.result in ["hooked","escaped","broken","captured"] and landing_bounds().has_point(result.position)

static func valid_hook_state(state: Dictionary) -> bool:
	if not state.get("hook_target_fish_id") is int or not state.get("npc_hook") is Dictionary: return false
	if not _keys(state.npc_hook,HOOK_FIELDS) or not state.npc_hook.phase is String or state.npc_hook.phase not in ["","hooked","landing"]: return false
	if not valid_result(state.get("public_npc_hook_result"),int(state.simulation_tick)): return false
	var target: int=state.hook_target_fish_id
	if target < -1 or target==0: return false
	if target==-1 and (state.hooked!=0 or state.npc_hook.phase!="" or state.bound_bait!=-1): return false
	if target==1 and (state.hooked==0 or state.npc_hook.phase!=""): return false
	if target>1 and (state.hooked!=0 or state.npc_hook.phase==""): return false
	if target>1 and (state.landing or not state.qte.is_empty() or not state.wraps.is_empty()): return false
	if target!=-1 and state.bound_bait<0: return false
	var found: bool=false
	for npc: Dictionary in state.npc_fishes:
		if npc.fish_id==target:
			found=true
			if npc.animation_state!=state.npc_hook.phase: return false
		elif npc.animation_state!="swim": return false
	return target<=1 or found

static func valid(states: Variant, player_id: int = 1) -> bool:
	if not states is Array or states.size()>MAX_FISH: return false
	var identities: Dictionary={}
	for state in states:
		if not state is Dictionary or not _keys(state,FIELDS): return false
		if not state.fish_id is int or state.fish_id<2 or state.fish_id==player_id or identities.has(state.fish_id): return false
		if not state.animation_state is String or state.animation_state not in ["swim","hooked","landing"]: return false
		var bounds: Rect2=landing_bounds() if state.animation_state=="landing" else Layout.fish_bounds(BODY_RADIUS)
		if not state.position is Vector2 or not state.position.is_finite() or not bounds.has_point(state.position): return false
		var max_speed: float=MAX_SPEED if state.animation_state=="swim" else MAX_HOOK_SPEED
		if not state.velocity is Vector2 or not state.velocity.is_finite() or state.velocity.length()>max_speed+0.001: return false
		if not state.aim is Vector2 or not state.aim.is_finite() or absf(state.aim.length_squared()-1.0)>0.002: return false
		if not state.visual_variant is int or state.visual_variant<0 or state.visual_variant>=VARIANTS: return false
		identities[state.fish_id]=true
	return true
