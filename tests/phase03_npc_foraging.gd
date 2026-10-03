extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Profile=preload("res://scripts/food_profile.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_FORAGING_FAIL | "+label)

func fixture(kind: String, actor: String="npc") -> Node2D:
	var world:=World.new()
	world.reset_world({"seed":32619,"npc_count":1,"npc_foraging_enabled":true,
		"rules":{"water_strength":0.0,"satiety_decay":0.0,"instinct_max_strength":0.0,"timer_enabled":false}})
	world.fish=Vector2(1100,300); world.fish_before=world.fish; world.aim=Vector2.RIGHT; world.satiety=20.0
	var npc: Dictionary=world.npc_fishes[0]
	npc.position=Vector2(650,200); npc.aim=Vector2.RIGHT; npc.intent_aim=Vector2.RIGHT
	npc.velocity=Vector2.ZERO; npc.steering=Vector2.ZERO; npc.feeding=true; npc.power=0.65
	npc.behavior_state="FEED"; npc.bite_cooldown=0.0; npc.satiety=20.0; npc.decision_age=0.12
	if actor=="player":
		world.fish=npc.position; world.fish_before=world.fish; npc.position=Vector2(1100,300); npc.active=false
	var origin: Vector2=world.mouth() if actor=="player" else State.observer(npc,world.rules).mouth
	for bait: Dictionary in world.baits:
		bait.active=false; bait.hook=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	var bait: Dictionary=world._make_bait(1,900,kind)
	bait.bait_id=world.baits[1].bait_id; bait.hook=false; bait.tackle=false; bait.active=true
	bait.pos=origin+Vector2(8,0); bait.home=bait.pos; bait.angle=0.0; bait.tip_before=bait.pos+Vector2(2,1)
	world.baits[1]=bait
	npc.target_bait_id=bait.bait_id
	for index in bait.grains.size():
		var grain: Dictionary=bait.grains[index]
		grain.eaten=index>=12; grain.free=true; grain.offset=Vector2.ZERO
		grain.pos=origin+Vector2(8.0+index*0.05,0); grain.points=1.0
	return world

func eaten_count(bait: Dictionary) -> int:
	var count:=0
	for grain: Dictionary in bait.grains:
		if grain.eaten: count+=1
	return count

func capacities_and_accounting() -> void:
	for kind: String in Profile.TYPES:
		var expected: int={"cluster":4,"worm":6,"chunk":8}[kind]
		for actor: String in ["npc","player"]:
			var world:=fixture(kind,actor)
			var npc: Dictionary=world.npc_fishes[0]
			var before:=eaten_count(world.baits[1])
			var consumed: bool=world._attempt_bite(npc) if actor=="npc" else world._attempt_bite()
			check(consumed and eaten_count(world.baits[1])-before==expected,"shared whole-grain 4/6/8 automatic Bite capacity "+actor+" "+kind)
			check(world.rule("bite_range")==10.0 and is_equal_approx(world.rule("bite_cooldown"),0.8),"shared default radius and cooldown remain 10 px / 0.8 seconds "+actor+" "+kind)
			var nutrition: float=expected*world.rule("satiety_food_value")*float(Profile.get_profile(kind).satiety_scale)
			if actor=="npc":
				check(world.score==0.0 and world.satiety==20.0 and is_equal_approx(npc.satiety,minf(100.0,20.0+nutrition)),"only NPC receives genuine typed satiety; player score/satiety untouched "+kind)
				check(world.round_stats.npc_food_consumed==expected and world.round_stats.npc_food_by_type[kind]==expected and world.round_stats.npc_feeding_events==1,"NPC stats count actual food and one successful batch "+kind)
				check(world.round_stats.food_consumed==0.0 and world.round_stats.bite_successes==0,"NPC Bite does not pollute player intake metrics "+kind)
				check(is_equal_approx(npc.bite_cooldown,0.8) and not world._attempt_bite(npc),"NPC continuous mouth contact respects shared cooldown "+kind)
			else:
				check(world.score==expected and is_equal_approx(world.satiety,minf(100.0,20.0+nutrition)),"player keeps existing score and profile satiety "+kind)
				check(world.round_stats.npc_food_consumed==0.0 and world.round_stats.food_by_type[kind]==expected,"player intake has no NPC attribution "+kind)
				check(is_equal_approx(world.bite_cooldown,0.8) and not world._attempt_bite(),"player automatic Bite cooldown unchanged "+kind)
			var stats: Dictionary=world.round_stats.duplicate(true)
			var score: float=world.score
			var satiety: float=npc.satiety
			world._consume_grain(world.baits[1].grains[0],false,"bite",npc)
			world._consume_grain(world.baits[1].grains[0],false,"bite")
			check(world.round_stats==stats and world.score==score and npc.satiety==satiety,"already eaten grain cannot transfer or duplicate ownership "+actor+" "+kind)
			world.free()

func mixed_profile_budget() -> void:
	for actor: String in ["npc","player"]:
		var world:=fixture("cluster",actor)
		for index in world.baits[1].grains.size(): world.baits[1].grains[index].visual_kind="worm" if index<3 else "cluster"
		var before:=eaten_count(world.baits[1])
		var taken: bool=world._attempt_bite(world.npc_fishes[0]) if actor=="npc" else world._attempt_bite()
		var typed: Dictionary=world.round_stats.npc_food_by_type if actor=="npc" else world.round_stats.food_by_type
		check(taken and eaten_count(world.baits[1])-before==5,"mixed old loose grains spend their own shared efficiency budget "+actor)
		check(typed.worm==3.0 and typed.cluster==2.0 and typed.chunk==0.0,"mixed shared Bite preserves genuine grain-type attribution "+actor)
		world.free()

func geometry_and_priority() -> void:
	for actor: String in ["npc","player"]:
		for distance: float in [10.0,10.01]:
			var world:=fixture("cluster",actor)
			var npc: Dictionary=world.npc_fishes[0]
			var origin: Vector2=world.mouth() if actor=="player" else State.observer(npc,world.rules).mouth
			for grain: Dictionary in world.baits[1].grains: grain.eaten=true
			var grain: Dictionary=world.baits[1].grains[0]
			grain.eaten=false; grain.pos=origin+Vector2(distance,0)
			var consumed: bool=world._attempt_bite(npc) if actor=="npc" else world._attempt_bite()
			check(consumed==(distance==10.0) and grain.eaten==consumed,"same inclusive mouth-radius boundary "+actor+" distance="+str(distance))
			world.free()
	var world:=fixture("cluster")
	var npc: Dictionary=world.npc_fishes[0]
	world.fish=npc.position; world.fish_before=world.fish; world.aim=npc.aim
	for index in world.baits[1].grains.size(): world.baits[1].grains[index].eaten=index>=1
	var grain: Dictionary=world.baits[1].grains[0]
	check(world._attempt_bite(),"player can claim contested grain")
	check(not world._attempt_bite(npc) and world.score==1.0 and world.round_stats.npc_food_consumed==0.0,"same-tick competing mouths cannot duplicate the real grain")
	world.free()
	world=fixture("worm"); npc=world.npc_fishes[0]
	npc.active=false
	check(not world._attempt_bite(npc),"inactive NPC cannot eat")
	npc.active=true; npc.feeding=false; npc.behavior_state="APPROACH_FOOD"
	check(not world._attempt_bite(npc),"NPC approach without feed intent cannot eat")
	npc.behavior_state="FEED"
	check(world._attempt_bite(npc),"Bite-preferred NPC FEED intent works without a suction command")
	npc.bite_cooldown=0.0; npc.feeding=true; world.npc_foraging_enabled=false
	check(not world._attempt_bite(npc),"PassiveNPC cannot eat through shared automatic Bite")
	world.free()

func shared_suction_physics() -> void:
	for kind: String in Profile.TYPES:
		var player:=fixture(kind,"player"); var npc_world:=fixture(kind)
		for world in [player,npc_world]:
			world.rules.hook_suction=0.0; world.power=0.65
			var origin: Vector2=world.mouth() if world==player else State.observer(world.npc_fishes[0],world.rules).mouth
			var bait: Dictionary=world.baits[1]
			bait.pos=origin+Vector2(25,0); bait.home=bait.pos
			for grain: Dictionary in bait.grains:
				grain.free=false; grain.offset=Vector2.ZERO; grain.pos=bait.pos
		var pending: Array[Dictionary]=[]
		player._step_bait(1,World.TICK_SECONDS,true,player.mouth(),true,pending)
		npc_world._step_npc_feeding(World.TICK_SECONDS)
		check(player.baits[1].grains==npc_world.baits[1].grains and player.baits[1].budget==npc_world.baits[1].budget,"actual player/NPC paths share exact attached peel and release budget "+kind)
		check(float(npc_world.baits[1].grains[0].progress)>0.0,"NPC suction physically advances attached grain peel "+kind)
		for world in [player,npc_world]: world.baits[1].grains[0].free=true
		var before: Vector2=npc_world.baits[1].grains[0].pos
		player._step_bait(1,World.TICK_SECONDS,true,player.mouth(),true,pending)
		npc_world._step_npc_feeding(World.TICK_SECONDS)
		check(player.baits[1].grains[0].pos==npc_world.baits[1].grains[0].pos and before.distance_to(npc_world.baits[1].grains[0].pos)>0.0,"actual NPC/player transport uses same typed suction field "+kind)
		player.free(); npc_world.free()
	var world:=fixture("cluster")
	var npc: Dictionary=world.npc_fishes[0]
	world._attempt_bite(npc)
	for tick in 47: world._tick_npc_fishes(World.TICK_SECONDS)
	npc.behavior_state="FEED"
	check(npc.bite_cooldown>0.0 and not world._attempt_bite(npc),"NPC Bite is still blocked before 48 real 60 Hz cooldown steps")
	world._tick_npc_fishes(World.TICK_SECONDS)
	check(npc.bite_cooldown<=0.000001,"NPC cooldown integrates the same 0.8-second interval")
	world.free()

func distant_feeders_do_not_accelerate() -> void:
	for scenario: String in ["near_npc_remote_npc","near_player_remote_npc","near_npc_remote_player"]:
		var actor:="player" if scenario=="near_player_remote_npc" else "npc"
		var baseline:=fixture("cluster",actor); var remote:=fixture("cluster",actor)
		for world in [baseline,remote]:
			world.rules.hook_suction=0.0; world.power=0.65
			var origin: Vector2=world.mouth() if actor=="player" else State.observer(world.npc_fishes[0],world.rules).mouth
			var bait: Dictionary=world.baits[1]
			bait.pos=origin+Vector2(25,0); bait.home=bait.pos
			for grain: Dictionary in bait.grains:
				grain.free=false; grain.offset=Vector2.ZERO; grain.pos=bait.pos
		if scenario=="near_npc_remote_npc":
			remote.spawn_npc()
			var extra: Dictionary=remote.npc_fishes[-1]
			extra.position=Vector2(200,200); extra.aim=Vector2.LEFT; extra.intent_aim=Vector2.LEFT
			extra.feeding=true; extra.power=0.65; extra.behavior_state="FEED"; extra.target_bait_id=remote.baits[1].bait_id
		elif scenario=="near_player_remote_npc":
			remote.npc_fishes[0].active=true
			remote.npc_fishes[0].position=Vector2(200,200)
			remote.npc_fishes[0].aim=Vector2.LEFT
		var equal:=true
		var progressed:=false
		for tick in 180:
			for world in [baseline,remote]:
				var sucking: bool=actor=="player" or world==remote and scenario=="near_npc_remote_player"
				world._step_bait(1,World.TICK_SECONDS,sucking,world.mouth())
				world._step_npc_feeding(World.TICK_SECONDS)
			equal=equal and baseline.baits==remote.baits and baseline.score==remote.score and baseline.round_stats==remote.round_stats
			progressed=progressed or baseline.baits[1].grains[0].progress>0.0
		check(equal,"out-of-range actor cannot credit release budget, accelerate peel or alter ownership: "+scenario)
		check(progressed,"remote-feeder isolation comparison exercises real near-field peeling: "+scenario)
		baseline.free(); remote.free()

func passive_authority(world: Node2D) -> Dictionary:
	var snapshot: Dictionary=world.capture_snapshot()
	for key: String in ["npc_fishes","next_fish_id","npc_foraging_enabled"]: snapshot.state.erase(key)
	return snapshot

func isolation_and_replay() -> void:
	var zero:=World.new(); var passive:=World.new()
	zero.reset_world({"seed":38129,"npc_count":0,"npc_foraging_enabled":false})
	passive.reset_world({"seed":38129,"npc_count":6,"npc_foraging_enabled":false})
	var same:=true
	for tick in 480:
		var direction:=Vector2.RIGHT.rotated(tick*0.019)
		for world in [zero,passive]:
			if tick in [160,360]: world.refill_hook_bait(0)
			world.advance_tick({"move":direction,"aim":direction,"suck":tick%71<25},{})
		same=same and passive_authority(zero)==passive_authority(passive)
	check(same,"NoNPC/PassiveNPC have identical non-NPC authority and main RNG throughout motion and fresh rehangs")
	check(passive.round_stats.npc_food_consumed==0.0,"PassiveNPC experiment control has no resource consumption")
	zero.free(); passive.free()
	var source:=World.new(); var same_seed:=World.new(); var restored:=World.new()
	for world in [source,same_seed]: world.reset_world({"seed":83239,"npc_count":3,"npc_foraging_enabled":true,"challenge":true,"rules":{"timer_enabled":false,"hunger_enabled":false}})
	var deterministic:=true
	for tick in 1200:
		for world in [source,same_seed]: world.advance_tick({}, {})
		deterministic=deterministic and source.capture_snapshot()==same_seed.capture_snapshot()
	check(deterministic,"ForagingNPC full authority and local RNG replay deterministically with same seed")
	check(source.round_stats.npc_food_consumed>0.0,"determinism exercise includes actual autonomous NPC intake")
	restored.reset_world()
	check(restored.restore_snapshot(source.capture_snapshot()),"running foraging state restores with cooldown, intent and local RNG")
	var replayed:=true
	for tick in 720:
		var command: Dictionary={"move":Vector2.RIGHT.rotated(tick*0.016),"suck":tick%101<18}
		source.advance_tick(command,{}); restored.advance_tick(command,{})
		replayed=replayed and var_to_bytes(source.capture_snapshot())==var_to_bytes(restored.capture_snapshot())
	check(replayed,"snapshot continuation stays byte-identical across actual competition and lifecycle progress")
	source.free(); same_seed.free(); restored.free()

func hidden_truth_pair() -> void:
	var safe:=fixture("cluster"); var hooked:=fixture("cluster")
	for world in [safe,hooked]:
		var npc: Dictionary=world.npc_fishes[0]
		npc.position-=Vector2(45,0); npc.behavior_state="WANDER"; npc.feeding=false; npc.target_bait_id=-1; npc.decision_age=0.0
		for grain: Dictionary in world.baits[1].grains:
			grain.free=false; grain.offset=Vector2.ZERO
	safe.baits[1].hook=false; hooked.baits[1].hook=true
	var observations_equal:=true; var decisions_equal:=true; var physics_equal:=true
	for tick in 900:
		var left: Dictionary=Observation.build_for(safe,State.observer(safe.npc_fishes[0],safe.rules),false)
		var right: Dictionary=Observation.build_for(hooked,State.observer(hooked.npc_fishes[0],hooked.rules),false)
		observations_equal=observations_equal and left==right
		safe.advance_tick({},{}); hooked.advance_tick({},{})
		decisions_equal=decisions_equal and safe.npc_fishes==hooked.npc_fishes
		physics_equal=physics_equal and safe.baits[1].grains==hooked.baits[1].grains and safe.baits[1].pos==hooked.baits[1].pos
	check(observations_equal,"opposite hidden hook flags produce exact NPC observations while physical cues match")
	check(decisions_equal,"opposite hidden hook flags produce exact targets, movement/aim/feed intents, suspicion and local RNG")
	check(physics_equal and safe.hooked==safe.HookState.FREE and hooked.hooked==hooked.HookState.FREE,"paired test remains before physical hook divergence; distant player avoids contact")
	print("HIDDEN_TRUTH_TRACE | npc_food=",safe.round_stats.npc_food_consumed," state=",safe.npc_fishes[0].behavior_state," mouth=",State.observer(safe.npc_fishes[0],safe.rules).mouth," target=",safe.baits[1].pos," progress=",safe.baits[1].grains[0].progress)
	check(safe.round_stats.npc_food_consumed>0.0 and safe.round_stats.npc_food_consumed==hooked.round_stats.npc_food_consumed,"hidden-truth equivalence spans genuine autonomous food consumption, not only idle patrol")
	safe.free(); hooked.free()

func _initialize() -> void:
	capacities_and_accounting(); mixed_profile_budget(); geometry_and_priority(); shared_suction_physics(); distant_feeders_do_not_accelerate(); isolation_and_replay(); hidden_truth_pair()
	print("PHASE03_NPC_FORAGING_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
