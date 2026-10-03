extends RefCounted

# Shared render/wire projection. Never send authority records or branch on AI
# decisions here: visual variants are cosmetic and P3.1 has only ambient swimming.
const Layout=preload("res://scripts/pond_layout.gd")
const FIELDS: Array[String] = ["fish_id","position","velocity","aim","visual_variant","animation_state"]
const MAX_FISH := 6
const VARIANTS := 3
# P3.1 public movement envelope; no authority/brain module is imported here.
const BODY_RADIUS := 10.0
const MAX_SPEED := 38.0

static func capture(states: Array) -> Array[Dictionary]:
	var visible: Array[Dictionary]=[]
	for state: Dictionary in states:
		if not bool(state.get("active",true)): continue
		visible.append({"fish_id":int(state.fish_id),"position":Vector2(state.position),
			"velocity":Vector2(state.velocity),"aim":Vector2(state.aim),
			"visual_variant":int(state.visual_variant),"animation_state":"swim"})
	visible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.fish_id<b.fish_id)
	return visible

static func valid(states: Variant, player_id: int = 1) -> bool:
	if not states is Array or states.size()>MAX_FISH: return false
	var identities: Dictionary={}
	for state in states:
		if not state is Dictionary or state.size()!=FIELDS.size(): return false
		for key: String in FIELDS:
			if not state.has(key): return false
		if not state.fish_id is int or state.fish_id<2 or state.fish_id==player_id or identities.has(state.fish_id): return false
		if not state.position is Vector2 or not state.position.is_finite() or not Layout.fish_bounds(BODY_RADIUS).has_point(state.position): return false
		if not state.velocity is Vector2 or not state.velocity.is_finite() or state.velocity.length()>MAX_SPEED+0.001: return false
		if not state.aim is Vector2 or not state.aim.is_finite() or absf(state.aim.length_squared()-1.0)>0.002: return false
		if not state.visual_variant is int or state.visual_variant<0 or state.visual_variant>=VARIANTS: return false
		if not state.animation_state is String or state.animation_state!="swim": return false
		identities[state.fish_id]=true
	return true
