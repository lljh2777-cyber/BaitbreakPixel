extends RefCounted

# A wire/presentation schema, deliberately separate from authoritative replay snapshots.
# Copy only listed public facts, including inside every nested record. A new simulation
# property never becomes fish-visible merely because it was added to Snapshot.capture.
const Rules=preload("res://scripts/game_rules.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Effort=preload("res://scripts/effort_check.gd")
const Stats=preload("res://scripts/round_stats.gd")
const FORMAT := "fish-presentation"
const SCHEMA := 1
const MAP_ID := "pond_v2"
const STATE_FIELDS := [
	"fish_id","rod_id","rules","net_action","qte_timing","fish","manual_net",
	"net_trail","net_return_path","net_exit_path","net_route","velocity","aim","power",
	"stamina","satiety","instinct_drive","caution_state","sprinting","sprint_exhausted",
	"fish_before","hooked","bound_bait","rope_path","rope_length","tension","reel_speed",
	"qte_width","qte_result_width","latched","high_age","landing_age","landing","landing_from",
	"resisting","feeding","line_catches","qte","qte_age","qte_zone","qte_origin",
	"qte_result","qte_result_kind","qte_result_zone","qte_result_progress","qte_result_age","qte_result_good",
	"target_opacity","contact_target","wrap_target","wrap_retry","wraps","fish_line_length",
	"untangle_phase","untangle_target","untangle_age","untangle_cooldown","result_flash","result_good",
	"baits","cycle_slot","cycle_phase","score","last_eat_at","clock","elapsed","started","challenge",
	"returning","home_age","reason","notice","notice_age","hook_count","escape_count",
	"net_state","net_age","net_recovery","net_count","net_from","net_to","net_pos","net_pulse","net_kind",
	"net_blocked","net_return_from","net_catch_offset","net_dodges","net_catches","net_angle","net_park",
	"net_retract_duration","net_splash","net_splash_at","net_last_position","net_motion","net_warning_shape",
	"ruleset","match_over","winner_role","match_paused","simulation_tick","qte_id","qte_grace_seconds",
	"effort_checks","round_stats","net_capture",
]
const RIG_FIELDS := [
	"x","spool","casting","cast_age","cast_from","cast_to","net_cooldown","net_held",
	"free_reel_speed","line_sway","surface_x","surface_velocity","surface_live","reel_phase",
	"release_phase","reel_hand_mode","reel_hand_amount","rod_load","rod_lift",
]
const NET_FIELDS := ["observing","age","has_a","a","admitted","rim_hit","impulse","slow_age"]
const QTE_FIELDS := ["lead","sweep","window","random","zone"]
const EFFORT_FIELDS := ["active","id","kind","message","age","zone","width","multiplier","effect_age","result_age","good","progress","boost","weak","lead","sweep","boost_seconds","weak_seconds"]
const OPPONENT_EFFORT_FIELDS := ["multiplier","effect_age"]
const STAT_FIELDS := [
	"fish_good","fish_total","angler_good","angler_total","wrap_good","unwrap_good","breaks","slips",
	"danger_seconds","hooked_seconds","round_duration","food_consumed","feeding_attempts","feeding_aborts",
	"feeding_session_start","bait_approaches","bait_retreats","hook_contacts","hook_events","successful_escapes",
	"instinct_trigger_count","instinct_total_duration","satiety_min","satiety_mean","satiety_integral",
	"critical_satiety_seconds","caution_low_seconds","caution_medium_seconds","caution_high_seconds",
]
const WRAP_FIELDS := ["center","radii","entry","loop","progress","target"]
const BAIT_FIELDS := ["bait_id","active","pos","angle","suction_offset","grains","motion_velocity","last_disturbance_tick","attachment_anchor"]
const GRAIN_FIELDS := ["id","offset","pos","layer","fleck","free","eaten"]
const CONFIG_FIELDS := ["rules","ruleset","challenge","qte_grace"]

static func _pick(source: Dictionary, fields: Array) -> Dictionary:
	var result: Dictionary={}
	for key in fields: result[key]=source[key]
	return result

static func public_config(config: Dictionary) -> Dictionary:
	return {"rules":Rules.normalize(config.get("rules",{})),"ruleset":"duel","challenge":true,"qte_grace":clampf(float(config.get("qte_grace",0.25)),0,0.25)}

static func config_valid(config: Dictionary) -> bool:
	return _keys(config,CONFIG_FIELDS) and Rules.valid(config.rules) and config.ruleset=="duel" and config.challenge==true and (config.qte_grace is float or config.qte_grace is int) and config.qte_grace>=0 and config.qte_grace<=0.25

static func capture(world: Node2D) -> Dictionary:
	var state: Dictionary={}
	var rig: Dictionary={}
	for key in STATE_FIELDS: state[key]=world.get(key)
	for key in RIG_FIELDS: rig[key]=world.angler.get(key)
	state.rules=Rules.normalize(world.rules)
	state.net_action=_pick(world.net_action,NET_FIELDS)
	state.qte_timing=_pick(world.qte_timing,QTE_FIELDS)
	state.effort_checks={}
	state.effort_checks.fish=_pick(world.effort_checks.fish,EFFORT_FIELDS)
	# The opponent's realized force is public, their next/check target timing is not.
	state.effort_checks.angler=_pick(world.effort_checks.angler,OPPONENT_EFFORT_FIELDS)
	state.round_stats=_pick(world.round_stats,STAT_FIELDS)
	state.wraps=[]
	for wrap in world.wraps: state.wraps.append(_pick(wrap,WRAP_FIELDS))
	state.baits=[]
	for index in world.baits.size():
		var bait: Dictionary=world.baits[index]
		var facts:=Observation._facts(bait,world.fish)
		var visual:=Observation._visual(bait,facts)
		var grains: Array[Dictionary]=[]
		for grain in bait.grains:
			if grain.eaten or (not grain.free and not bait.active): continue
			grains.append(_pick(grain,GRAIN_FIELDS))
		visual.grains=grains
		# Invisible reserves have no position, motion, hidden home or future food.
		if facts.visible_count==0 and not bait.active: visual.pos=Vector2.ZERO
		visual.motion_velocity=Vector2(bait.motion_velocity) if facts.visible_count>0 else Vector2.ZERO
		visual.last_disturbance_tick=int(world.simulation_tick) if facts.visible_count>0 and int(world.simulation_tick)-int(bait.last_disturbance_tick)<=60 else -1000
		visual.attachment_anchor=world.line_anchor(index) if world.bound_bait==index else Vector2(visual.pos)
		state.baits.append(visual)
	# The flashing warning is visible; upcoming cycle timing and reserve order are not.
	state.cycle_slot=world.cycle_slot if world.cycle_phase=="warning" else -1
	return bytes_to_var(var_to_bytes({"format":FORMAT,"schema":SCHEMA,"map_id":MAP_ID,"role":"fish","state":state,"rig":rig}))

static func _keys(values: Dictionary, fields: Array) -> bool:
	if values.size()!=fields.size(): return false
	for key in fields:
		if not values.has(key): return false
	return true

static func _record(values: Variant, reference: Dictionary, fields: Array) -> bool:
	if not values is Dictionary or not _keys(values,fields): return false
	for key in fields:
		if typeof(values[key])!=typeof(reference[key]): return false
	return true

static func _properties(object: Object, values: Dictionary, fields: Array) -> bool:
	if not _keys(values,fields): return false
	for key in fields:
		if typeof(object.get(key))!=typeof(values[key]): return false
	return true

static func valid(world: Node2D, snapshot: Dictionary) -> bool:
	if not _keys(snapshot,["format","schema","map_id","role","state","rig"]): return false
	if snapshot.format!=FORMAT or snapshot.schema!=SCHEMA or snapshot.map_id!=MAP_ID or snapshot.role!="fish" or not Protocol.safe_values(snapshot): return false
	if not snapshot.state is Dictionary or not snapshot.rig is Dictionary: return false
	var state: Dictionary=snapshot.state
	var rig: Dictionary=snapshot.rig
	if not _properties(world,state,STATE_FIELDS) or not _properties(world.angler,rig,RIG_FIELDS): return false
	if not Rules.valid(state.rules): return false
	if not _record(state.qte_timing,Rules.qte(Rules.defaults(),"entry"),QTE_FIELDS): return false
	if state.qte_timing.lead<0 or state.qte_timing.lead>2 or state.qte_timing.sweep<0.5 or state.qte_timing.sweep>8: return false
	if state.qte_timing.window<0.04 or state.qte_timing.window>2 or state.qte_timing.window>state.qte_timing.sweep*0.8+0.000001 or state.qte_timing.zone<0.099 or state.qte_timing.zone>0.9: return false
	if not _record(state.net_action,world.Net.fresh(),NET_FIELDS): return false
	if state.net_action.age<0 or state.net_action.slow_age<0 or state.net_action.impulse.length()>1000: return false
	if state.fish_id<=0 or state.rod_id<=0 or state.simulation_tick<0: return false
	if not state.caution_state in ["CALM","UNEASY","ALARMED"] or state.instinct_drive<0 or state.instinct_drive>1: return false
	if state.satiety<0 or state.satiety>100 or state.stamina<0 or state.stamina>state.rules.stamina_max: return false
	if state.power<0 or state.power>1 or state.tension<0 or state.tension>1: return false
	if state.elapsed<0 or state.clock<0 or state.last_eat_at < -10 or state.last_eat_at>state.elapsed+0.000001: return false
	if not state.ruleset in ["survival","duel"] or not state.winner_role in ["","fish","angler"] or state.match_over!=(state.winner_role!=""): return false
	if state.hooked<0 or state.hooked>2 or state.bound_bait < -1 or state.bound_bait>=4 or (state.hooked!=0 and state.bound_bait<0): return false
	if state.qte_id<0 or not state.qte in ["","entry","slack","wrap"] or not state.qte_result_kind in ["","entry","slack","wrap"]: return false
	if state.qte_age<0 or state.qte_age>10.3 or state.qte_width<=0 or state.qte_width>0.8 or state.qte_result_width<=0 or state.qte_result_width>0.8: return false
	if not state.net_state in ["wait","rest","prepare","warning","sweep","miss","withdraw","caught"] or not state.net_kind in ["sweep","drop"]: return false
	if state.net_capture<0 or state.net_capture>1 or state.net_retract_duration<=0: return false
	if state.target_opacity.size()!=world.targets.size(): return false
	for opacity in state.target_opacity:
		if not opacity is float or opacity<0 or opacity>1: return false
	for key in ["wrap_target","contact_target","untangle_target"]:
		if state[key]< -1 or state[key]>=world.targets.size(): return false
	if not state.untangle_phase in ["","check","unwind","recover"] or state.untangle_age<0 or state.untangle_age>10.3 or state.untangle_cooldown<0: return false
	if not state.cycle_phase in ["","warning","refill"] or state.cycle_slot< -1 or state.cycle_slot>=4: return false
	if state.cycle_phase!="warning" and state.cycle_slot!=-1: return false
	if not _keys(state.effort_checks,["fish","angler"]): return false
	if not _record(state.effort_checks.fish,Effort.fresh(),EFFORT_FIELDS): return false
	var check:=Effort.fresh()
	check.merge(state.effort_checks.fish,true)
	if not Effort.valid(check): return false
	if not _record(state.effort_checks.angler,Effort.fresh(),OPPONENT_EFFORT_FIELDS): return false
	var opponent: Dictionary=state.effort_checks.angler
	if opponent.multiplier<0.1 or opponent.multiplier>2.5 or opponent.effect_age<0 or opponent.effect_age>6: return false
	if not _record(state.round_stats,Stats.fresh(),STAT_FIELDS) or not Stats.valid(state.round_stats): return false
	if state.wraps.size()>world.targets.size(): return false
	var wrap_ids: Dictionary={}
	for wrap in state.wraps:
		if not _record(wrap,{"center":Vector2.ZERO,"radii":Vector2.ONE,"entry":Vector2.ZERO,"loop":PackedVector2Array(),"progress":0.0,"target":0},WRAP_FIELDS): return false
		if wrap.target<0 or wrap.target>=world.targets.size() or wrap_ids.has(wrap.target) or wrap.loop.size()<2 or wrap.loop.size()>512 or wrap.progress<0 or wrap.progress>1 or wrap.radii.x<=0 or wrap.radii.y<=0: return false
		wrap_ids[wrap.target]=true
	if state.untangle_phase in ["check","unwind"]:
		if state.hooked!=2 or state.wraps.is_empty() or state.wraps[-1].target!=state.untangle_target: return false
	if state.baits.size()!=4: return false
	var bait_ids: Dictionary={}
	var grain_ids: Dictionary={}
	for bait in state.baits:
		if not _record(bait,{"bait_id":1,"active":false,"pos":Vector2.ZERO,"angle":0.0,"suction_offset":Vector2.ZERO,"grains":[],"motion_velocity":Vector2.ZERO,"last_disturbance_tick":0,"attachment_anchor":Vector2.ZERO},BAIT_FIELDS): return false
		if bait.bait_id<=0 or bait_ids.has(bait.bait_id) or bait.suction_offset.length()>78.001 or bait.grains.size()>2048 or bait.last_disturbance_tick>state.simulation_tick: return false
		bait_ids[bait.bait_id]=true
		for grain in bait.grains:
			if not _record(grain,{"id":"","offset":Vector2.ZERO,"pos":Vector2.ZERO,"layer":0,"fleck":0,"free":false,"eaten":false},GRAIN_FIELDS): return false
			if grain.id.is_empty() or grain.id.length()>64 or grain_ids.has(grain.id) or grain.layer<0 or grain.layer>2 or grain.fleck<0 or grain.fleck>4: return false
			if grain.eaten or (not bait.active and not grain.free): return false
			grain_ids[grain.id]=true
	if rig.surface_x<0 or rig.surface_x>world.Layout.SIZE.x or absf(rig.surface_velocity)>10000: return false
	if not rig.reel_hand_mode in [-1,0,1] or rig.reel_hand_amount<0 or rig.reel_hand_amount>1: return false
	if rig.reel_phase<0 or rig.reel_phase>=TAU or rig.release_phase<0 or rig.release_phase>=TAU: return false
	if rig.rod_load<0 or rig.rod_load>1 or rig.rod_lift<0 or rig.rod_lift>1: return false
	return true

static func apply(world: Node2D, snapshot: Dictionary) -> bool:
	# Never call authoritative restore with invented secret fields. Validation is
	# complete before the first mutation, and application has no gameplay side effects.
	if not valid(world,snapshot): return false
	var detached: Dictionary=bytes_to_var(var_to_bytes(snapshot))
	var opponent:=Effort.fresh()
	opponent.wait=0.0
	opponent.merge(detached.state.effort_checks.angler,true)
	detached.state.effort_checks.angler=opponent
	for key in STATE_FIELDS:
		if world.get(key) is Array: world.get(key).assign(detached.state[key])
		else: world.set(key,detached.state[key])
	for key in RIG_FIELDS: world.angler.set(key,detached.rig[key])
	# A game adapter may previously have generated an offline round. Do not retain
	# its unrelated secrets alongside a network-only presentation.
	world.truth_events.clear()
	world.suspicion_by_bait.clear()
	world.caution_by_bait.clear()
	world.risk_tolerance=0.0
	world.focus_bait_id=-1
	world.supply_queue.clear()
	world.counted.clear()
	world.next_bait_id=1
	world.next_hook_id=1
	world.bait_batch=0
	world.cycle_age=0.0
	world.rng.seed=0
	world.rng.state=0
	return true
