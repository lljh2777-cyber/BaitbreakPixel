extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const State=preload("res://scripts/npc_fish_state.gd")
const Layout=preload("res://scripts/pond_layout.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("NPC_ENTITIES_FAIL | "+label)

func by_id(world: Node2D) -> Dictionary:
	var result: Dictionary={}
	for npc: Dictionary in world.npc_fishes: result[npc.fish_id]=npc.duplicate(true)
	return result

func legal_spawn(world: Node2D, npc: Dictionary) -> bool:
	var position: Vector2=npc.position
	if not Layout.fish_bounds(State.RADIUS).has_point(position) or position.distance_to(Layout.HOME)<=80: return false
	for solid: Dictionary in Layout.SOLIDS:
		if Layout.touches(position,State.RADIUS,PackedVector2Array(solid.points)): return false
	for bait: Dictionary in world.baits:
		if bait.active and position.distance_to(bait.pos)<45: return false
	for other: Dictionary in world.npc_fishes:
		if other.fish_id!=npc.fish_id and other.active and position.distance_to(other.position)<36: return false
	return true

func _initialize() -> void:
	var a:=World.new(); var b:=World.new()
	a.reset_world()
	check(a.npc_fishes.size()==3 and a.next_fish_id==5,"default three NPCs reserve IDs 2 through 4")
	for count: int in [-1,0,3,6,7,999]:
		a.reset_world({"npc_count":count})
		check(a.npc_fishes.size()==clampi(count,0,6),"NPC count is bounded: "+str(count))
	for mode: String in ["survival","duel"]:
		for seed_value in 128:
			a.reset_world({"seed":seed_value,"ruleset":mode,"npc_count":6})
			b.reset_world({"seed":seed_value,"ruleset":mode,"npc_count":6})
			check(a.npc_fishes==b.npc_fishes,"same seed reproduces complete spawn state mode=%s seed=%d" % [mode,seed_value])
			var identities: Dictionary={1:true}; var seeds: Dictionary={}
			for npc: Dictionary in a.npc_fishes:
				check(not identities.has(npc.fish_id) and npc.fish_id>=2,"NPC ID cannot alias player or another NPC")
				identities[npc.fish_id]=true
				check(not seeds.has(npc.brain_seed) and npc.brain_seed==State.derive_seed(seed_value,npc.fish_id),"each stable ID has its own deterministic seed")
				seeds[npc.brain_seed]=true
				check(legal_spawn(a,npc),"legal spawn avoids home, active bait, body overlap and solid geometry mode=%s seed=%d id=%d" % [mode,seed_value,npc.fish_id])
				check(State.valid(npc,a.next_fish_id),"fresh authority record validates")
			check(a.fish_id==1 and a.hook_target_fish_id==-1 and a.next_fish_id==8,"player ID and reserved hook target stay inert")
	var full: Dictionary=a.capture_snapshot()
	check(a.spawn_npc()==-1 and a.capture_snapshot()==full,"full capacity rejects spawn without consuming any ID or RNG")
	a.reset_world({"seed":918,"npc_count":6}); b.reset_world({"seed":918,"npc_count":6})
	var old_ids:=by_id(a)
	a.npc_fishes.remove_at(2); b.npc_fishes.remove_at(2)
	check(a.spawn_npc()==8 and b.spawn_npc()==8 and a.next_fish_id==9,"remove then spawn never reuses removed identity")
	check(not by_id(a).has(4),"removed identity is gone")
	for identity in old_ids:
		if identity!=4: check(by_id(a)[identity]==old_ids[identity],"surviving record untouched by remove/spawn")
	check(legal_spawn(a,a.npc_fishes[-1]),"replacement spawn remains legal")
	b.npc_fishes.reverse()
	for tick in 600:
		var command: Dictionary={"move":Vector2.RIGHT.rotated(float(tick)*0.009),"aim":Vector2.RIGHT,"suck":tick%80<20}
		a.advance_tick(command,{}); b.advance_tick(command,{})
		check(by_id(a)==by_id(b),"array reorder preserves exact per-ID decisions and movement tick="+str(tick))
	check(a.fish==b.fish and a.rng.state==b.rng.state,"reordering never changes player or world RNG")
	a.reset_world({"seed":918,"npc_count":3})
	check(a.next_fish_id==5 and by_id(a).keys()==[2,3,4],"new round resets only its own fish namespace")
	a.free(); b.free()
	print("PHASE03_NPC_ENTITIES_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
