extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Brain=preload("res://scripts/npc_fish_brain.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Observation=preload("res://scripts/fish_observation.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_RNG_FAIL | "+label)

func legacy_authority(world: Node2D) -> Dictionary:
	var result: Dictionary=world.capture_snapshot()
	result.state.erase("npc_fishes"); result.state.erase("next_fish_id")
	return result

func stimulus(world: Node2D, tick: int) -> void:
	# Exercise existing randomized hook, QTE and refill paths in identical worlds.
	if tick==30: world._enter_hook(1)
	if tick==80 and world.hooked!=world.HookState.HOOKED: world._attach_hook()
	if tick==150: world._open_qte("slack")
	if tick==210 and world.hooked!=world.HookState.FREE: world._release_hook(false)
	if tick in [250,410]: world.refill_hook_bait(0)
	if tick==320: world._enter_hook(3)
	if tick==380 and world.hooked!=world.HookState.FREE: world._release_hook(true)

func trace(mode: String, seed_value: int) -> void:
	var worlds: Array=[]
	for count: int in [0,3,6]:
		var w:=World.new()
		w.reset_world({"seed":seed_value,"ruleset":mode,"npc_count":count,"rules":{"hunger_enabled":false,"timer_enabled":false}})
		worlds.append(w)
	check(legacy_authority(worlds[0])==legacy_authority(worlds[1]) and legacy_authority(worlds[0])==legacy_authority(worlds[2]),"initial bait truth, IDs, player fields and RNG identical at 0/3/6")
	var saw_hook:=false; var saw_qte:=false; var saw_refill:=false
	for tick in 480:
		for w in worlds: stimulus(w,tick)
		var direction:=Vector2.RIGHT.rotated(float(tick)*0.023)
		var fish: Dictionary={"move":direction,"aim":direction,"suck":tick%70<23,"dash":tick%90<11,"qte":tick in [55,177,351]}
		var angler: Dictionary={"walk":float((tick/80)%3-1),"reel":tick%135<45,"release":tick%135>=90,"target":Vector2(650+sin(tick*0.01)*100,250)}
		for w in worlds: w.advance_tick(fish,angler)
		var reference:=legacy_authority(worlds[0])
		for index in [1,2]:
			check(reference==legacy_authority(worlds[index]),"all non-NPC authority including RNG matches mode=%s seed=%d count=%d tick=%d" % [mode,seed_value,worlds[index].npc_fishes.size(),tick])
			saw_hook=saw_hook or worlds[index].round_stats.hook_events>0
			saw_qte=saw_qte or worlds[index].qte_id>0
			saw_refill=saw_refill or worlds[index].next_bait_id>5
	check(saw_hook and saw_qte and saw_refill,"RNG-isolation trace actually covered hook attachment, randomized QTE, and fresh bait identities")
	for w in worlds: w.free()

func hidden_truth_checks() -> void:
	var a:=World.new(); var b:=World.new()
	a.reset_world({"seed":928,"npc_count":3}); b.reset_world({"seed":928,"npc_count":3})
	for bait: Dictionary in a.baits: bait.hook=false
	for bait: Dictionary in b.baits: bait.hook=true
	var npc: Dictionary=a.npc_fishes[0]
	for offset: Vector2 in [Vector2(25,0),Vector2(100,0),Vector2(250,0)]:
		for w in [a,b]:
			var bait: Dictionary=w.baits[0]
			bait.active=true; bait.pos=Vector2(npc.position)+offset; bait.suction_offset=Vector2.ZERO
			for grain: Dictionary in bait.grains: grain.pos=bait.pos+Vector2(grain.offset)
		var before_a:=legacy_authority(a); var before_b:=legacy_authority(b)
		for tick in 120:
			# Only NPC tick advances: all public environmental physics remain identical.
			var own: Dictionary=State.observer(a.npc_fishes[0],a.rules)
			check(Observation.build_for(a,own,false)==Observation.build_for(b,own,false),"hidden hook truth cannot alter NPC public perception")
			a._tick_npc_fishes(1.0/60); b._tick_npc_fishes(1.0/60)
			check(a.npc_fishes==b.npc_fishes,"equal public states yield exact NPC decisions despite opposing hidden hook truth")
		check(before_a==legacy_authority(a) and before_b==legacy_authority(b),"NPC movement cannot mutate bait, hook, scores, player scalar authority or world RNG")
	# Decision API receives detached public data, own state and local RNG only.
	var source:=FileAccess.get_file_as_string("res://scripts/npc_fish_brain.gd")
	for forbidden: String in ["world.",".hook", "truth_events", "_enter_hook", "_attach_hook", "refill_hook_bait"]:
		check(not source.contains(forbidden),"brain has no hidden-world/Hook access: "+forbidden)
	a.free(); b.free()

func _initialize() -> void:
	for mode: String in ["survival","duel"]:
		for seed_value: int in [17,928,8231]: trace(mode,seed_value)
	hidden_truth_checks()
	print("PHASE03_NPC_RNG_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
