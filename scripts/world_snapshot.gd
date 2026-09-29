extends RefCounted

# Explicit, versioned value schema. Local views, input sources and profiles are excluded.
const SCHEMA := 4
const MAP_ID := "pond_v1"
const WORLD_FIELDS: Array[String] = [
	"fish",
	"net_aim",
	"manual_net",
	"net_trail",
	"net_return_path",
	"net_exit_path",
	"net_route",
	"net_route_next",
	"velocity",
	"aim",
	"power",
	"stamina",
	"sprinting",
	"sprint_exhausted",
	"stamina_delay",
	"water_strength",
	"fish_before",
	"hooked",
	"bound_bait",
	"hook_cooldown",
	"rope_path",
	"rope_length",
	"tension",
	"reel_speed",
	"practice_line_sensitivity",
	"practice_line_force",
	"slack_hold_seconds",
	"mouth_window_seconds",
	"break_hold_seconds",
	"qte_width",
	"qte_result_width",
	"bait_batch",
	"latched",
	"high_age",
	"low_age",
	"retry_age",
	"landing_age",
	"landing",
	"landing_from",
	"resisting",
	"feeding",
	"line_catches",
	"qte",
	"qte_age",
	"qte_zone",
	"qte_origin",
	"qte_result",
	"qte_result_kind",
	"qte_result_zone",
	"qte_result_progress",
	"qte_result_age",
	"qte_result_good",
	"target_opacity",
	"contact_target",
	"wrap_target",
	"wrap_retry",
	"wraps",
	"fish_line_length",
	"result_flash",
	"result_good",
	"baits",
	"supply_queue",
	"cycle_slot",
	"cycle_age",
	"cycle_phase",
	"score",
	"counted",
	"clock",
	"elapsed",
	"started",
	"challenge",
	"returning",
	"home_age",
	"reason",
	"notice",
	"notice_age",
	"hook_count",
	"escape_count",
	"net_state",
	"net_age",
	"net_wait",
	"net_recovery",
	"net_queued",
	"net_count",
	"net_from",
	"net_to",
	"net_pos",
	"net_pulse",
	"net_kind",
	"net_blocked",
	"net_return_from",
	"net_catch_offset",
	"net_dodges",
	"net_catches",
	"net_angle",
	"net_park",
	"net_retract_duration",
	"net_splash",
	"net_splash_at",
	"net_last_position",
	"net_motion",
	"net_warning_shape",
	"ruleset",
	"match_over",
	"winner_role",
	"match_paused",
	"simulation_tick",
	"qte_id",
	"qte_grace_seconds",
	"effort_checks",
	"practice_effort_frequency",
	"practice_effort_window",
	"practice_effort_boost",
	"practice_effort_weak",
	"round_stats",
	"net_capture",
]
const RIG_FIELDS: Array[String] = [
	"x",
	"cursor",
	"spool",
	"auto_reel",
	"auto_net",
	"casting",
	"cast_age",
	"cast_from",
	"cast_to",
	"cast_index",
	"cast_cooldown",
	"net_cooldown",
	"net_held",
	"dragging",
	"needs_neutral",
	"hook_velocity",
	"free_line_length",
	"free_reel_speed",
	"previous_anchor",
	"anchor_before",
	"line_sway",
	"sway_speed",
]

static func capture(world: Node2D) -> Dictionary:
	var state: Dictionary={}
	var rig: Dictionary={}
	for key in WORLD_FIELDS: state[key]=world.get(key)
	for key in RIG_FIELDS: rig[key]=world.angler.get(key)
	# Variant serialization also detaches packed arrays and nested grain/wrap data.
	return bytes_to_var(var_to_bytes({"schema":SCHEMA,"map_id":MAP_ID,"state":state,"rig":rig,"rng_seed":world.rng.seed,"rng_state":world.rng.state}))

static func plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR2: return value.is_finite()
		TYPE_ARRAY,TYPE_PACKED_VECTOR2_ARRAY:
			for item in value:
				if not plain(item): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName or key is int) or not plain(value[key]): return false
			return true
	return false

static func fields_match(object: Object, values: Dictionary, fields: Array[String]) -> bool:
	for key in fields:
		if not values.has(key) or typeof(object.get(key))!=typeof(values[key]): return false
	return true

static func record_matches(values: Dictionary, reference: Dictionary, excluded: String = "") -> bool:
	for key in reference:
		if key==excluded: continue
		if not values.has(key): return false
		if (reference[key] is int or reference[key] is float) and (values[key] is int or values[key] is float): continue
		if typeof(values[key])!=typeof(reference[key]): return false
	return true

static func restore(world: Node2D, snapshot: Dictionary) -> bool:
	if snapshot.get("schema")!=SCHEMA or snapshot.get("map_id")!=MAP_ID or not plain(snapshot): return false
	if not snapshot.get("state") is Dictionary or not snapshot.get("rig") is Dictionary: return false
	if not snapshot.get("rng_seed") is int or not snapshot.get("rng_state") is int: return false
	var state: Dictionary=snapshot.state
	if not fields_match(world,state,WORLD_FIELDS) or not fields_match(world.angler,snapshot.rig,RIG_FIELDS): return false
	if not state.ruleset in ["survival","duel"] or state.simulation_tick<0: return false
	if not state.winner_role in ["","fish","angler"] or state.match_over!=(state.winner_role!=""): return false
	if state.hooked<0 or state.hooked>2 or state.bound_bait < -1 or state.bound_bait>=4: return false
	if state.baits.size()!=4 or state.net_route_next<1 or state.net_route_next>maxi(1,state.net_route.size()): return false
	if state.target_opacity.size()!=world.targets.size(): return false
	if state.hooked!=0 and state.bound_bait<0: return false
	if state.qte_id<0 or not state.qte in ["","entry","slack","wrap"]: return false
	for role in ["fish","angler"]:
		if not world.Effort.valid(state.effort_checks.get(role)): return false
	if not world.Stats.valid(state.round_stats) or state.net_capture<0 or state.net_capture>1: return false
	if state.practice_effort_frequency<0.5 or state.practice_effort_frequency>2 or state.practice_effort_window<0.12 or state.practice_effort_window>0.5: return false
	if state.practice_effort_boost<1.1 or state.practice_effort_boost>1.8 or state.practice_effort_weak<0.3 or state.practice_effort_weak>0.9: return false
	if not state.net_state in ["wait","rest","prepare","warning","sweep","miss","withdraw","caught"]: return false
	if state.wrap_target < -1 or state.wrap_target>=world.targets.size(): return false
	if state.contact_target < -1 or state.contact_target>=world.targets.size(): return false
	if state.wraps.size()>world.targets.size() or state.baits.size()!=4: return false
	var bait_reference: Dictionary=world._make_bait(0)
	for bait in state.baits:
		if not bait is Dictionary or not bait.get("grains") is Array or bait.grains.size()>2048: return false
		if not record_matches(bait,bait_reference,"grains"): return false
		for grain in bait.grains:
			if not grain is Dictionary or not record_matches(grain,bait_reference.grains[0]): return false
			if not grain.id is String or grain.id.is_empty() or grain.id.length()>64: return false
	for wrap in state.wraps:
		if not wrap is Dictionary: return false
		if not record_matches(wrap,{"center":Vector2.ZERO,"radii":Vector2.ONE,"entry":Vector2.ZERO,"loop":PackedVector2Array(),"progress":0.0,"target":0}): return false
		if not wrap.target is int or wrap.target<0 or wrap.target>=world.targets.size() or wrap.loop.size()<2 or wrap.loop.size()>512: return false
	# Validate before mutating, and never fire sound/result/profile side effects on restore.
	var detached: Dictionary=bytes_to_var(var_to_bytes(snapshot))
	for key in WORLD_FIELDS: world.set(key,detached.state[key])
	for key in RIG_FIELDS: world.angler.set(key,detached.rig[key])
	world.rng.seed=detached.rng_seed
	world.rng.state=detached.rng_state
	return true
