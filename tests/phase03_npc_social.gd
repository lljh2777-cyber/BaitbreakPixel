extends SceneTree

# Production authority integration. Hook labels are used only by assertions after
# observations/decisions; no diagnostic label enters the NPC perception contract.
const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("NPC_SOCIAL_PASS | ",label)
	else: failed+=1; push_error("NPC_SOCIAL_FAIL | "+label)

func fixture(seed_value: int=63201, satiety: float=20.0) -> Node2D:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"npc_count":1,"npc_foraging_enabled":true,"npc_social_enabled":true,
		"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	world.fish=Vector2(1100,300); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT
	npc.intent_aim=Vector2.RIGHT; npc.steering=Vector2.ZERO; npc.decision_age=0.0; npc.satiety=satiety
	for bait: Dictionary in world.baits:
		bait.active=false; bait.hook=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	var food: Dictionary=world.baits[1]
	food.active=true; food.hook=false; food.tackle=false; food.pos=Vector2(690,200); food.home=food.pos
	food.angle=0.0; food.suction_offset=Vector2.ZERO; food.motion_velocity=Vector2.ZERO; food.last_disturbance_tick=-1000
	for index in food.grains.size():
		var grain: Dictionary=food.grains[index]
		grain.eaten=index>=12; grain.free=true; grain.pos=food.pos+Vector2(index*0.05,0); grain.points=1.0
	return world

func social_observation(world: Node2D) -> Dictionary:
	return Observation.build_social_for(world,State.observer(world.npc_fishes[0],world.rules),false)

func has_private_tag(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["hook","hook_id","hook_truth","target_bait_id","suspicion_by_bait","caution_by_bait","risk_tolerance","behavior_state","brain_rng_state","brain_seed","social_cues","public_hook_cue"]: return true
			if has_private_tag(value[key]): return true
	elif value is Array:
		for item in value:
			if has_private_tag(item): return true
	return false

func cue_boundary_checks() -> void:
	var world:=fixture()
	var npc: Dictionary=world.npc_fishes[0]
	check(not Observation.build(world,false).has("social_cues") and not Observation.build_for(world,State.observer(npc,world.rules),false).has("social_cues"),"legacy player and ordinary observer builders gain no social or private fields")
	world.fish=Vector2(690,220); world.fish_before=world.fish; world.aim=Vector2.UP; world.feeding=true
	var near:=social_observation(world)
	check(near.social_cues.feeding_fish.size()==1 and near.social_cues.feeding_fish[0].fish_id==1,"NPC sees nearby player's genuine visible feeding action")
	world.feeding=false
	check(social_observation(world).social_cues.feeding_fish.is_empty(),"nearby fish presence/private intent alone is not a feeding cue")
	world.feeding=true; world.fish=Vector2(1100,300)
	check(social_observation(world).social_cues.feeding_fish.is_empty(),"remote feeding action is outside social perception")
	world.baits[1].hook=true
	check(social_observation(world).social_cues.danger_events.is_empty(),"hidden bait hook flag alone creates no public danger event")
	world.fish=Vector2(690,220); world.fish_before=world.fish
	world._enter_hook(1)
	check(social_observation(world).social_cues.danger_events.is_empty(),"mouth contact before actual attachment does not invent hooked-fish outcome")
	world._attach_hook()
	var actual:=social_observation(world)
	check(actual.social_cues.danger_events.size()==1,"actual local player attachment creates observable outcome evidence")
	if not actual.social_cues.danger_events.is_empty():
		check(actual.social_cues.danger_events[0].keys().size()==2 and actual.social_cues.danger_events[0].has("tick") and actual.social_cues.danger_events[0].has("position"),"danger evidence contains only public tick/location, no bait truth or target identity")
	var saved:=actual.duplicate(true)
	if not actual.social_cues.danger_events.is_empty(): actual.social_cues.danger_events[0].position=Vector2.ZERO
	check(social_observation(world)==saved,"social observation mutations cannot edit authoritative public-event memory")
	npc.position=Vector2(300,200)
	check(social_observation(world).social_cues.danger_events.is_empty(),"actual but remote hook outcome is not omniscient NPC evidence")
	npc.position=Vector2(650,200); world.simulation_tick+=46
	check(social_observation(world).social_cues.danger_events.is_empty(),"local outcome expires after bounded 45-tick observation window")
	world.free()

func private_feelings_isolation() -> void:
	var baseline:=fixture(); var changed:=fixture()
	var npc: Dictionary=changed.npc_fishes[0]
	npc.behavior_state="FLEE"; npc.suspicion_by_bait={int(changed.baits[1].bait_id):0.95}
	npc.caution_by_bait={int(changed.baits[1].bait_id):"ALARMED"}; npc.caution_state="ALARMED"
	npc.risk_tolerance=0.55; npc.brain_rng_state+=7; npc.social_secret={"hook_truth":true}
	check(Observation.build(baseline,true)==Observation.build(changed,true),"player perception remains byte-equivalent under arbitrary NPC private feelings")
	check(NPCPublic.capture(baseline.npc_fishes)==NPCPublic.capture(changed.npc_fishes),"render projection never turns NPC private state into labels, color, animation or intent tags")
	check(FishWire.capture(baseline)==FishWire.capture(changed) and AnglerWire.capture(baseline)==AnglerWire.capture(changed),"both role payloads remain unchanged under NPC private-feeling contamination")
	check(not has_private_tag(FishWire.capture(changed).state.npc_fishes) and not has_private_tag(AnglerWire.capture(changed).state.npc_fishes),"both wire NPC records exclude social evidence, hook truth and private behavior tags")
	# Hold the next decision pending so different private memories cannot yet cause
	# genuine visible movement/food divergence; exercise the actual player update.
	baseline.npc_fishes[0].decision_age=0.12; changed.npc_fishes[0].decision_age=0.12
	baseline.advance_tick({},{}); changed.advance_tick({},{})
	check(baseline.suspicion_by_bait==changed.suspicion_by_bait and baseline.caution_by_bait==changed.caution_by_bait and baseline.caution_state==changed.caution_state,"actual player suspicion update does not incorporate NPC private alarm")
	baseline.free(); changed.free()

func hidden_truth_counterfactuals() -> void:
	var matched:=0; var decisions_equal:=true; var observations_equal:=true
	var safe_avoidance:=false; var hooked_approach:=false; var hungry_risk:=false; var competed:=false
	for hunger: float in [70.0,20.0,5.0]:
		for scene: String in ["quiet","mild_motion","motion","feeding","visible_outcome"]:
			var safe:=fixture(63201,hunger); var hooked:=fixture(63201,hunger)
			for world in [safe,hooked]:
				if scene=="motion": world.baits[1].motion_velocity=Vector2(90,0)
				if scene=="mild_motion": world.baits[1].motion_velocity=Vector2(6,0)
				if scene=="feeding":
					world.fish=Vector2(690,220); world.fish_before=world.fish; world.aim=Vector2.UP; world.feeding=true
				if scene=="visible_outcome":
					world.public_hook_cue={"tick":0,"position":Vector2(700,200)}
			hooked.baits[1].hook=true
			# Advance the real NPC authority only. Bait physics are intentionally held
			# equal: a causal hidden-label test must stop before actual hook effects.
			for decision in 12:
				for world in [safe,hooked]:
					world.simulation_tick=decision*7
					if scene=="motion": world.baits[1].last_disturbance_tick=world.simulation_tick
				observations_equal=observations_equal and social_observation(safe)==social_observation(hooked)
				safe._tick_npc_fishes(State.DECISION_SECONDS); hooked._tick_npc_fishes(State.DECISION_SECONDS)
				decisions_equal=decisions_equal and safe.npc_fishes==hooked.npc_fishes
				var state: String=safe.npc_fishes[0].behavior_state
				safe_avoidance=safe_avoidance or state in ["HESITATE","FLEE"]
				hooked_approach=hooked_approach or state in ["APPROACH_FOOD","FEED","COMPETE"]
				hungry_risk=hungry_risk or hunger==5.0 and scene=="motion" and state in ["APPROACH_FOOD","FEED","COMPETE"]
				competed=competed or state=="COMPETE"
				matched+=1
			safe.free(); hooked.free()
	check(matched==180 and observations_equal,"180 paired live NPC observations remain identical when only bait hook truth is flipped")
	check(decisions_equal,"same visible scenes yield identical NPC behavior, target, movement, feeding, memory and RNG before physics diverges")
	check(safe_avoidance,"legal public cues can produce hesitation/fleeing on truly unhooked food (false positive witness)")
	check(hooked_approach,"NPC can approach or feed on truly hooked food (false negative witness)")
	check(hungry_risk,"starving NPC can continue a food attempt despite motion evidence")
	check(competed,"genuine nearby feeding action can elicit competition through production NPC authority")

func genuine_feeding_pair() -> void:
	var safe:=fixture(); var hooked:=fixture(); hooked.baits[1].hook=true
	var equal:=true
	for tick in 600:
		safe.advance_tick({},{}); hooked.advance_tick({},{})
		equal=equal and safe.npc_fishes==hooked.npc_fishes and safe.baits[1].grains==hooked.baits[1].grains
	check(equal and safe.hooked==World.HookState.FREE and hooked.hooked==World.HookState.FREE,"full 60 Hz quiet counterfactual continues through real food physics without hidden hook-dependent NPC actions")
	check(safe.round_stats.npc_food_consumed>0 and safe.round_stats.npc_food_consumed==hooked.round_stats.npc_food_consumed,"counterfactual includes genuine autonomous intake, not only static intent checks")
	check(safe.rule("bite_range")==10.0 and is_equal_approx(safe.rule("bite_cooldown"),0.8) and State.DEFAULT_COUNT==3,"social extension preserves 10 px Bite, 0.8 s cooldown and default population three")
	safe.free(); hooked.free()

func _initialize() -> void:
	cue_boundary_checks(); private_feelings_isolation(); hidden_truth_counterfactuals(); genuine_feeding_pair()
	print("PHASE03_NPC_SOCIAL_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
