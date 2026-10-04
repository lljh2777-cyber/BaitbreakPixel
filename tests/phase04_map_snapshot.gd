extends SceneTree

const World = preload("res://scripts/world_simulation.gd")
const Snapshot = preload("res://scripts/world_snapshot.gd")
const Registry = preload("res://scripts/maps/map_registry.gd")
const Context = preload("res://scripts/maps/map_context.gd")
const NPC = preload("res://scripts/npc_fish_state.gd")
const NPCPublic = preload("res://scripts/npc_fish_public_state.gd")
const Fixture = preload("res://tests/fixtures/phase04/authority_fixture.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error("MAP_SNAPSHOT_FAIL | " + label)

func _init() -> void:
	ref_contract()
	roundtrip_and_replay()
	adversarial_atomicity()
	fixture_transition()
	public_adapter()
	geometry_and_rng()
	print("PHASE04_MAP_SNAPSHOT | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)

func make_world(fixture: bool = false) -> Node2D:
	var game := World.new()
	check(game.reset_world({"seed":816427,"ruleset":"duel","npc_count":3},Fixture.create() if fixture else null),"test round initialized")
	return game

func copy(snapshot: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(snapshot))

func bytes(game: Node2D) -> PackedByteArray:
	return var_to_bytes(game.capture_snapshot())

func reject_unchanged(game: Node2D, value: Dictionary, label: String) -> void:
	var before := bytes(game)
	var context: RefCounted = game.map_context
	var targets: Array = game.targets
	var target: Dictionary = game.targets[0]
	var net: Array = game.map_net_blockers
	var rig: RefCounted = game.angler
	var rig_context: RefCounted = rig._map_context
	var limits: Rect2 = rig._hook_bounds
	var diagnostics: Array = game.map_errors.duplicate(true)
	check(not game.restore_snapshot(value),label + " rejected")
	check(bytes(game) == before and is_same(context,game.map_context) and is_same(targets,game.targets) and is_same(target,game.targets[0]) and is_same(net,game.map_net_blockers),label + " leaves authority, RNG and geometry unchanged")
	check(is_same(rig,game.angler) and is_same(rig_context,game.angler._map_context) and limits == game.angler._hook_bounds and diagnostics == game.map_errors,label + " leaves rig caches and diagnostics unchanged")

func invalid_refs(reference: Dictionary) -> Array:
	var result: Array = [null,false,1,"pond_v2",[],{}]
	for key: String in reference:
		var missing := reference.duplicate(true)
		missing.erase(key)
		result.append(missing)
	var extra := reference.duplicate(true)
	extra.geometry = []
	result.append(extra)
	for entry: Array in [["id","unknown"],["id","authority_fixture"],["id",&"pond_v2"],["id",9],["id",""],
		["revision",2],["revision",0],["revision",1.0],["revision",true],["revision","1"],
		["contract_version",2],["contract_version",0],["contract_version",1.0],["contract_version",false],
		["content_hash","0".repeat(64)],["content_hash",reference.content_hash.to_upper()],["content_hash",""],["content_hash",[]],
		["id",{"id":"pond_v2"}],["revision",[]],["content_hash",RefCounted.new()]]:
		var changed := reference.duplicate(true)
		changed[entry[0]] = entry[1]
		result.append(changed)
	var named_key := reference.duplicate(true)
	named_key.erase("id")
	named_key[&"id"] = "pond_v2"
	result.append(named_key)
	var wrong_key := reference.duplicate(true)
	wrong_key.erase("id")
	wrong_key[1] = "pond_v2"
	result.append(wrong_key)
	var object_values: Dictionary[String,Object] = {}
	var object_keys: Dictionary[Object,String] = {}
	result.append(object_values)
	result.append(object_keys)
	return result

func ref_contract() -> void:
	var reference: Dictionary = Registry.available_refs()[0]
	check(Registry.validate_ref(reference).valid,"registry accepts its exact reference")
	check(Context.load_ref(reference).valid,"context resolves validated reference")
	for value in invalid_refs(reference):
		var checked := Registry.validate_ref(value)
		var loaded := Registry.load_ref(value)
		var context := Context.load_ref(value)
		check(not checked.valid and not checked.errors.is_empty(),"malformed/mismatched reference rejected with error")
		check(not loaded.valid and loaded.definition.is_empty() and not context.valid and context.context == null,"failed reference exposes no partial map or fallback")
	var loaded := Registry.load_ref(reference)
	loaded.definition.meta.id = "corrupted_export"
	loaded.definition.interaction_features[0].shape.points[0] = Vector2.ZERO
	loaded.definition.bounds.water = Rect2()
	check(Registry.validate_ref(reference).valid and Registry.load_ref(reference).definition.meta == reference,"cached registry identity cannot be mutated through exports")
	check(Registry.load_ref(reference).definition.interaction_features[0].shape.points[0] == Vector2(326,174),"cached registry packed geometry cannot be mutated through exports")
	var first := Context.load_ref(reference)
	var second := Context.load_ref(reference)
	check(is_same(first.context,second.context),"repeated wire ref validation reuses immutable context without rehash/rebuild")

func roundtrip_and_replay() -> void:
	var source := make_world()
	var target := make_world()
	for tick in 180: source.advance_tick({"move":Vector2.RIGHT.rotated(tick*0.04),"suck":tick%7<3},{"walk":sin(tick*0.03)})
	var snapshot: Dictionary = source.capture_snapshot()
	check(snapshot.size() == 7 and snapshot.schema == 16 and snapshot.map_ref == source.map_context.map_ref and not snapshot.has("map_id"),"schema16 exact map_ref envelope replaces map_id")
	check(not snapshot.state.has("targets") and not snapshot.state.has("map_context") and not snapshot.map_ref.has("geometry"),"snapshot carries no map geometry")
	var context: RefCounted = target.map_context
	var targets: Array = target.targets
	check(target.restore_snapshot(snapshot) and bytes(source) == bytes(target),"capture restore capture remains byte exact")
	check(is_same(target.map_context,context) and is_same(target.targets,targets),"same-map restore preserves installed context and cache identities")
	var rng_before: int = target.rng.state
	for attempt in 4: check(target.restore_snapshot(snapshot),"repeated idempotent restore succeeds")
	check(target.rng.state == rng_before and bytes(source) == bytes(target),"repeated restore consumes no gameplay RNG")
	var identical := true
	for tick in 240:
		var fish := {"move":Vector2.RIGHT.rotated(tick*0.07),"aim":Vector2.RIGHT,"suck":tick%9<4,"dash":tick%57<8}
		var angler := {"walk":sin(tick*0.02),"reel":tick%90<30,"release":tick%90>70}
		source.advance_tick(fish,angler)
		target.advance_tick(fish,angler)
		if bytes(source) != bytes(target): identical = false; break
	check(identical,"restored pond replay and private NPC RNG remain byte exact for 240 ticks")
	snapshot.map_ref.id = "caller_mutated"
	snapshot.state.baits[0].pos = Vector2.ZERO
	check(target.map_context.id == "pond_v2" and target.baits[0].pos != Vector2.ZERO,"restore detaches map and mutable authority from input")
	source.free(); target.free()

func adversarial_atomicity() -> void:
	var game := make_world()
	var snapshot: Dictionary = game.capture_snapshot()
	for value in invalid_refs(snapshot.map_ref):
		var bad := copy(snapshot)
		bad.map_ref = value
		reject_unchanged(game,bad,"invalid map_ref")
	var bad := copy(snapshot)
	bad.erase("map_ref")
	bad.map_id = "pond_v2"
	bad.schema = 15
	reject_unchanged(game,bad,"schema15 explicitly unsupported")
	for schema in [16.0,"16",15,17]:
		bad = copy(snapshot); bad.schema = schema
		reject_unchanged(game,bad,"schema exact int/version")
	bad = copy(snapshot); bad.geometry = {"water":Vector2.ZERO}
	reject_unchanged(game,bad,"injected top-level map geometry")
	bad = copy(snapshot); bad.state.targets = []
	reject_unchanged(game,bad,"injected state geometry")
	bad = copy(snapshot); bad.state.counted["object"] = RefCounted.new()
	reject_unchanged(game,bad,"nested Object")
	var object_array: Array[RefCounted] = []
	bad = copy(snapshot); bad.state.counted["typed"] = object_array
	reject_unchanged(game,bad,"empty Object-typed array")
	var script_array: Array[World] = []
	bad = copy(snapshot); bad.state.counted["typed"] = script_array
	reject_unchanged(game,bad,"empty script-typed array")
	var object_dict: Dictionary[String,RefCounted] = {}
	bad = copy(snapshot); bad.state.counted["typed"] = object_dict
	reject_unchanged(game,bad,"empty Object-typed dictionary")
	var cycle: Dictionary = {}; cycle.self = cycle
	bad = copy(snapshot); bad.state.counted["cycle"] = cycle
	reject_unchanged(game,bad,"cyclic dictionary")
	cycle.clear()
	var array_cycle: Array = []; array_cycle.append(array_cycle)
	bad = copy(snapshot); bad.state.counted["cycle"] = array_cycle
	reject_unchanged(game,bad,"cyclic array")
	array_cycle.clear()
	var deep: Dictionary = {}; var cursor: Dictionary = deep
	for depth in 40: cursor.next = {}; cursor = cursor.next
	bad = copy(snapshot); bad.state.counted["deep"] = deep
	reject_unchanged(game,bad,"excessively nested value tree")
	bad = copy(snapshot); bad.state.fish = Vector2(NAN,0)
	reject_unchanged(game,bad,"nonfinite authority")
	var wrong_array: Array[Vector2] = []
	wrong_array.resize(game.targets.size()); wrong_array.fill(Vector2.ZERO)
	bad = copy(snapshot); bad.state.target_opacity = wrong_array
	reject_unchanged(game,bad,"wrong typed property array rejected before assignment")
	var untyped_array: Array = []; untyped_array.resize(game.targets.size()); untyped_array.fill("bad")
	bad = copy(snapshot); bad.state.target_opacity = untyped_array
	reject_unchanged(game,bad,"wrong untyped property array rejected before assignment")
	bad = copy(snapshot); bad.state.net_capture = "late_failure"
	reject_unchanged(game,bad,"invalid final authority field")
	game.free()

func fixture_transition() -> void:
	var fixture := make_world(true)
	var source := make_world()
	var original: Dictionary = fixture.capture_snapshot()
	check(original.map_ref.id == "authority_fixture" and original.map_ref == fixture.map_context.map_ref,"fixture capture reports real map identity")
	reject_unchanged(fixture,original,"unregistered fixture snapshot")
	reject_unchanged(source,original,"fixture cannot masquerade as pond")
	var valid: Dictionary = source.capture_snapshot()
	var bad := copy(valid); bad.state.wrap_target = source.targets.size()
	reject_unchanged(fixture,bad,"resolved pond target index checked before fixture transition")
	bad = copy(valid); bad.state.target_opacity.resize(fixture.targets.size())
	reject_unchanged(fixture,bad,"target opacity checked against resolved map rather than current fixture")
	bad = copy(valid); bad.rig.surface_x = source.map_context.size.x+1.0
	reject_unchanged(fixture,bad,"rig surface bound checked against resolved map")
	bad = copy(valid); bad.state.public_hook_cue = {"tick":0,"position":Vector2(-1,-1)}
	reject_unchanged(fixture,bad,"hook cue checked against resolved map water")
	check(fixture.restore_snapshot(valid),"registered pond restores over a current unregistered fixture")
	check(bytes(source) == bytes(fixture) and fixture.targets == source.targets and fixture.targets.size() == 40,"map transition installs local pond geometry and exact state together")
	check(is_same(fixture.map_context,fixture.angler._map_context) and fixture.angler._hook_bounds == source.angler._hook_bounds and fixture._npc_spawn_regions == source._npc_spawn_regions,"map transition refreshes rig bounds and NPC geometry caches")
	var identical := true
	for tick in 180:
		var fish := {"move":Vector2.RIGHT,"suck":tick%11<5}
		source.advance_tick(fish,{"walk":0.3}); fixture.advance_tick(fish,{"walk":0.3})
		if bytes(source) != bytes(fixture): identical = false; break
	check(identical,"fixture-to-pond replay is byte exact, including RNG")
	fixture.free(); source.free()

func public_adapter() -> void:
	var source := make_world()
	var target := make_world(true)
	var public: Dictionary = source.capture_snapshot()
	public.state.npc_fishes = NPCPublic.capture(source.npc_fishes,source.hook_target_fish_id,source.npc_hook)
	public.state.npc_hook = NPCPublic.capture_hook(source.npc_hook)
	check(not target.restore_snapshot(public),"public NPC payload is never accepted as authority replay")
	check(Snapshot.restore_angler_presentation(target,public),"explicit public angler restore adapter remains available")
	check(target.map_context.map_ref == source.map_context.map_ref and target.npc_fishes == public.state.npc_fishes,"public adapter installs local map without manufacturing private NPC brains")
	check(not target.npc_fishes[0].has("brain_rng_state") and not target.npc_fishes[0].has("target_bait_id"),"public adapter retains hidden-state boundary")
	source.free(); target.free()

func geometry_and_rng() -> void:
	var pond: RefCounted = Context.load_map().context
	check(NPCPublic.landing_bounds(pond.water) == Rect2(18,39,1244,382),"public landing bounds preserve exact pond y39 and old extent")
	var npc := NPC.fresh(2,1,Vector2(300,39),Vector2.RIGHT,1)
	npc.behavior_state = "LANDING"
	check(NPC.valid(npc,3,pond.water),"private landing validator preserves original lower edge39")
	npc.position.y = 38.99
	check(not NPC.valid(npc,3,pond.water),"private landing validator rejects below old boundary")
	var reference: Dictionary = pond.map_ref
	seed(39841); var expected := randf()
	seed(39841)
	for attempt in 5:
		Registry.validate_ref(reference); Registry.load_ref(reference); Context.load_ref(reference)
		Registry.validate_ref({"id":"unknown"})
	check(randf() == expected,"map_ref validation and resolution consume zero global RNG")
	var source := make_world()
	var target := make_world(true)
	var snapshot: Dictionary = source.capture_snapshot()
	seed(2749); expected = randf()
	seed(2749)
	check(target.restore_snapshot(snapshot),"RNG probe restores complete state")
	var bad := copy(snapshot); bad.map_ref.revision = 99
	check(not target.restore_snapshot(bad),"RNG probe rejects bad ref")
	check(randf() == expected,"valid and rejected map restores consume zero global RNG")
	check(target.reset_world({"seed":816427,"ruleset":"duel","npc_count":3,"map_ref":reference}) and bytes(source) == bytes(target),"round config map_ref uses exact local registry geometry and unchanged RNG sequence")
	var before := bytes(target)
	bad = reference.duplicate(true); bad.contract_version = 2
	check(not target.reset_world({"map_ref":bad}) and bytes(target) == before,"round config mismatched ref rejects before world mutation")
	source.free(); target.free()
