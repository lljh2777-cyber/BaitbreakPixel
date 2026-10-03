extends SceneTree

# OFFLINE ONLY. The real authority decides first. This harness subsequently joins
# bait truth to a detached diagnostic row; no labels are passed back to any actor.
const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")
const FORMAT:="phase03-social-diagnostics-v1"
const VERSION:=1
var rows: Array=[]
var episodes: Array=[]
var matched_pairs:=0
var mismatched_pairs:=0
var unlabeled:=0

func source_hashes() -> Dictionary:
	var result: Dictionary={}
	var paths: Array[String]=["res://tools/phase03_social_diagnostics.gd","res://tools/phase02_feeding_policy.gd"]
	var directory:=DirAccess.open("res://scripts")
	for name in directory.get_files():
		if name.ends_with(".gd"): paths.append("res://scripts/"+name)
	paths.sort()
	for path in paths: result[path]=FileAccess.get_sha256(path)
	return result

func _initialize() -> void:
	var count:=6
	var first_seed:=63301
	var max_ticks:=1800
	var output:="res://artifacts/p33-social-diagnostic.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): first_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--max-ticks="): max_ticks=int(arg.get_slice("=",1))
		if arg.begins_with("--output="): output=arg.substr(9)
	if count<4 or count>20 or max_ticks<60 or max_ticks>7200:
		push_error("Require 4..20 seeds and 60..7200 bounded real ticks"); quit(2); return
	if FileAccess.file_exists(output):
		push_error("Refusing to replace existing diagnostic evidence: "+output); quit(2); return
	var hashes:=source_hashes()
	var started:=Time.get_ticks_msec()
	for index in count:
		var split:="train" if index<count/2 else "heldout"
		run_natural(first_seed+index,split,max_ticks)
		print("SOCIAL_DIAGNOSTIC_PROGRESS | seed=",first_seed+index," rows=",rows.size())
	# Fixed, separately identified counterfactual intervention family; never pooled
	# with natural-gameplay estimates or historical P3.2 competition outcomes.
	for index in 4: run_counterfactual(63201+index,"train" if index<2 else "heldout")
	var stable:=hashes==source_hashes()
	var report: Dictionary={"format":FORMAT,"harness_version":VERSION,"source_hashes":hashes,"source_stable":stable,
		"natural_seeds":count,"first_seed":first_seed,"max_ticks":max_ticks,"tick_seconds":World.TICK_SECONDS,
		"sample_every_ticks":18,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"matched_counterfactual_pairs":matched_pairs,"mismatched_counterfactual_pairs":mismatched_pairs,"unlabeled_samples":unlabeled,
		"rows":rows,"episodes":episodes,"methodology":{
			"truth_boundary":"Truth is joined only after production authority decisions. Rows never enter observation, AI, render, network or replay state.",
			"natural":"Real default survival challenge, three NPCs, unchanged detached P2 Mixed player and AnglerBrain; all bounded seeds/outcomes retained.",
			"counterfactual":"4 fixed seeds x 3 hunger levels x 5 scenes x 12 actual NPC decision updates x 2 labels; shared bait physics held constant intentionally. Full NPC records including intent, memory and RNG must match each label pair.",
			"association":"Current target, then live social_bait_id when available, else nearest publicly observed food. Fallback is an association, not proof that this food caused the reaction.",
			"witness_window":"Separate predictive from witnessed-result rows whenever this NPC retained a witnessed danger tick within 45 visible-event ticks plus the production social-recovery duration. Counterfactual visible_outcome rows are always in the witnessed family.",
			"classifier":"Behavior state is private offline instrumentation, an optimistic recognition proxy. Real players see movement, never these state tags.",
			"limits":"Small diagnostic, temporally correlated repeated samples, seed-grouped train/heldout split; no human win-rate, cue-classifier generalization or P3.2 replacement claim. Insufficient classes must not be called safe. P3.4 NPC hooks remain unimplemented."}}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Cannot write "+output); quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SOCIAL_DIAGNOSTIC_RESULT | rows=",rows.size()," pairs=",matched_pairs," mismatches=",mismatched_pairs," source_stable=",stable," output=",output)
	quit(0 if stable and mismatched_pairs==0 else 1)

func run_natural(seed_value: int, split: String, max_ticks: int) -> void:
	var world:=World.new()
	world.reset_world({"npc_hook_enabled":false,"seed":seed_value,"challenge":true,"ruleset":"survival","npc_count":3,"npc_foraging_enabled":true,"npc_social_enabled":true})
	var player:=Policy.new(); player.reset("Mixed",world.rules)
	var opponent:=Opponent.new()
	for tick in max_ticks:
		world.advance_tick(player.command(Observation.build(world,false),World.TICK_SECONDS),opponent.command(world,World.TICK_SECONDS))
		if tick%18==0:
			for npc: Dictionary in world.npc_fishes:
				if npc.active: record(world,npc,"natural",split,str(seed_value),seed_value,"natural")
		if world.match_over: break
	episodes.append({"dataset":"natural","seed":seed_value,"split":split,"ticks":world.simulation_tick,
		"completed":world.match_over,"winner":world.winner_role,"reason":world.reason,"player_food":world.score,
		"npc_food":world.round_stats.npc_food_consumed,"hook_events":world.round_stats.hook_events,
		"npc_hook_count":null,"wrong_catches":null})
	world.free()

func fixture(seed_value: int, satiety: float, scene: String) -> Node2D:
	var world:=World.new()
	world.reset_world({"npc_hook_enabled":false,"seed":seed_value,"npc_count":1,"npc_foraging_enabled":true,"npc_social_enabled":true,
		"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	world.fish=Vector2(1100,300); world.fish_before=world.fish; world.aim=Vector2.RIGHT
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=Vector2(650,200); npc.velocity=Vector2.ZERO; npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT
	npc.steering=Vector2.ZERO; npc.decision_age=0.0; npc.satiety=satiety
	for bait: Dictionary in world.baits:
		bait.active=false; bait.hook=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	var bait: Dictionary=world.baits[1]
	bait.active=true; bait.hook=false; bait.tackle=false; bait.pos=Vector2(690,200); bait.home=bait.pos; bait.angle=0.0
	bait.suction_offset=Vector2.ZERO; bait.motion_velocity=Vector2(90,0) if scene=="motion" else (Vector2(6,0) if scene=="mild_motion" else Vector2.ZERO); bait.last_disturbance_tick=-1000
	for index in bait.grains.size():
		var grain: Dictionary=bait.grains[index]
		grain.eaten=index>=12; grain.free=true; grain.pos=bait.pos+Vector2(index*0.05,0); grain.points=1.0
	if scene=="feeding":
		world.fish=Vector2(690,220); world.fish_before=world.fish; world.aim=Vector2.UP; world.feeding=true
	if scene=="visible_outcome": world.public_hook_cue={"tick":0,"position":Vector2(700,200)}
	return world

func run_counterfactual(seed_value: int, split: String) -> void:
	for hunger: float in [70.0,20.0,5.0]:
		for scene: String in ["quiet","mild_motion","motion","feeding","visible_outcome"]:
			var safe:=fixture(seed_value,hunger,scene); var hooked:=fixture(seed_value,hunger,scene); hooked.baits[1].hook=true
			var episode:="%d/%s/%d" % [seed_value,scene,int(hunger)]
			for decision in 12:
				for world in [safe,hooked]:
					world.simulation_tick=decision*7
					if scene=="motion": world.baits[1].last_disturbance_tick=world.simulation_tick
				var a:=Observation.build_social_for(safe,State.observer(safe.npc_fishes[0],safe.rules),false)
				var b:=Observation.build_social_for(hooked,State.observer(hooked.npc_fishes[0],hooked.rules),false)
				safe._tick_npc_fishes(State.DECISION_SECONDS); hooked._tick_npc_fishes(State.DECISION_SECONDS)
				matched_pairs+=1
				if a!=b or safe.npc_fishes!=hooked.npc_fishes: mismatched_pairs+=1
				for world in [safe,hooked]: record(world,world.npc_fishes[0],"counterfactual",split,episode,seed_value,scene,decision)
			safe.free(); hooked.free()

func record(world: Node2D, npc: Dictionary, dataset: String, split: String, episode: String, seed_value: int, scene: String, decision: int=-1) -> void:
	var perception:=Observation.build_social_for(world,State.observer(npc,world.rules),false)
	var id:=int(npc.target_bait_id)
	var association:="target"
	if world.bait_slot(id)<0:
		id=int(npc.get("social_bait_id",-1)); association="social_memory"
	if world.bait_slot(id)<0:
		association="nearest_visible_food"; var best:=INF
		for bait: Dictionary in perception.perceived_baits:
			if bait.food_position is Vector2 and float(bait.distance)<best:
				id=int(bait.bait_id); best=float(bait.distance)
	var slot: int=world.bait_slot(id)
	if slot<0: unlabeled+=1; return
	# This is the only truth read. It happens after decisions and is only serialized
	# into this offline output. Neither the ID selection nor any behavior sees it.
	var label: bool=bool(world.baits[slot].hook)
	rows.append({"dataset":dataset,"split":split,"episode":episode,"seed":seed_value,"scene":scene,
		"decision":decision,"tick":world.simulation_tick,"fish_id":int(npc.fish_id),"bait_id":id,"association":association,
		"state":String(npc.behavior_state),"feeding":bool(npc.feeding),"satiety":float(npc.satiety),
		"speed":Vector2(npc.velocity).length(),"hook_truth":label,"npc_food_so_far":world.round_stats.npc_food_consumed,
		"feeding_cues":perception.social_cues.feeding_fish.size(),"danger_cues":perception.social_cues.danger_events.size(),
		"witnessed_danger_recent":int(npc.get("social_danger_tick",-1))>=0 and int(world.simulation_tick)-int(npc.get("social_danger_tick",-1))<=int(ceil(State.SOCIAL_RECOVERY_SECONDS*60.0))+45})
