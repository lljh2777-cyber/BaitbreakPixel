extends SceneTree

const World = preload("res://scripts/world_simulation.gd")
const Context = preload("res://scripts/maps/map_context.gd")
const Geometry = preload("res://scripts/maps/map_geometry.gd")
const Validator = preload("res://scripts/maps/map_validator.gd")
const Fixture = preload("res://tests/fixtures/phase04/authority_fixture.gd")
const FishBrain = preload("res://scripts/fish_brain.gd")
const AnglerBrain = preload("res://scripts/angler_brain.gd")
const Observation = preload("res://scripts/fish_observation.gd")
const NPC = preload("res://scripts/npc_fish_state.gd")
const NPCHook = preload("res://scripts/npc_hook.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("MAP_AUTHORITY_FAIL | " + label)

func world(config: Dictionary = {}) -> Node2D:
	var result := World.new()
	var selected := {"seed":1917, "npc_count":0, "water_strength":0.0}
	selected.merge(config, true)
	check(result.reset_world(selected, Fixture.create()), "fixture round initialized")
	return result

func fingerprint(game: Node2D) -> PackedByteArray:
	# Inspect actual state without pretending schema15 supports nondefault maps.
	var state := {}
	for property: Dictionary in game.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var name: String = property.name
		if name in ["map_errors", "map_context", "_map_context", "angler", "rng"]: continue
		var value: Variant = game.get(name)
		if value is Object: continue
		state[name] = value
	state.rng = [game.rng.seed, game.rng.state]
	state.map_ref = game.map_context.map_ref
	var angler_state := {}
	for property: Dictionary in game.angler.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = game.angler.get(property.name)
			if not value is Object: angler_state[property.name] = value
	state.angler = angler_state
	return var_to_bytes(state)

func initialization_and_atomicity() -> void:
	var definition := Fixture.create()
	check(Validator.validate(definition).valid, "fixture is legal contract-v1 data")
	var game := world()
	check(game.map_context.id == "authority_fixture", "fixture is selected, never a silent pond fallback")
	check(game.map_context.size == Fixture.SIZE and game.map_context.water == Fixture.WATER and game.map_context.floor_y == Fixture.FLOOR, "different dimensions and shifted water installed")
	check(game.fish == Fixture.SPAWN and game.fish_before == Fixture.SPAWN, "spawn installed before round entity initialization")
	check(game.targets.size() == 5 and game.target_opacity.size() == 5, "fixture target/opacity ABI initialized together")
	for index in game.targets.size():
		check(game.targets[index].id == Fixture.IDS[index] and game.targets[index].compatibility_index == index, "target identity and authored order %d" % index)
		check(game.targets[index].bounds == Fixture.RECTS[index], "target authority geometry ignores unrelated presentation %d" % index)
	for bait: Dictionary in game.baits:
		check(bait.pos in Fixture.SITES and bait.home == bait.pos, "initial bait uses fixture's ordered shuffled sites")
	var context: Variant = game.map_context
	game.map_context = Context.load_map().context
	check(is_same(game.map_context, context), "public property cannot replace a running round context")
	context.water = Rect2(0, 0, 2, 2)
	context.home = Vector2.ZERO
	check(context.water == Fixture.WATER and context.home == Fixture.HOME, "public scalar writes cannot change round geometry")
	game.advance_tick({"move":Vector2.RIGHT}, {})
	var before := fingerprint(game)
	for invalid: Variant in [false, {}, {"meta":{}}, "unknown"]:
		check(not game.reset_world({"seed":9999, "npc_count":6}, invalid), "malformed map reset rejected")
		check(not game.map_errors.is_empty() and is_same(game.map_context, context) and fingerprint(game) == before, "invalid map leaves context, world, angler and all RNG state unchanged")
	var wrong_hash := Fixture.create()
	wrong_hash.anchors.home += Vector2.ONE
	check(not game.reset_world({"seed":9999}, wrong_hash) and fingerprint(game) == before, "authority hash mismatch rejected before mutation")
	for config: Dictionary in [{"map_id":"not_registered"}, {"map_revision":99}, {"map_id":7}, {"map_revision":"1"}]:
		check(not game.reset_world(config) and fingerprint(game) == before, "invalid registry selection is atomic: " + str(config))
	check(game.reset_world({"seed":1917, "npc_count":0}, definition), "valid map starts new round after rejected attempts")
	check(game.simulation_tick == 0 and game.fish == Fixture.SPAWN and game.map_errors.is_empty(), "successful reset installs complete clean round")
	definition.anchors.home = Vector2(130, 120)
	definition.bait_sites[0] = Vector2(130, 130)
	definition.interaction_features[0].shape.points[0] = Vector2(120, 100)
	check(game.map_context.home == Fixture.HOME and game.targets[0].polygon[0] == Vector2(260, 210), "post-reset caller mutation cannot alter active map or target cache")
	var exported: Array = game.map_context.interaction_targets
	exported[0].polygon[0] = Vector2(-999, -999)
	check(game.map_context.interaction_targets[0].polygon[0] == Vector2(260, 210) and game.targets[0].polygon[0] == Vector2(260, 210), "packed polygon export cannot mutate context or round cache")
	game.free()

func spatial_authority() -> void:
	var game := world()
	game.move_fish(Vector2(-9999, -9999))
	check(game.fish == Vector2(122, 104), "free fish clamps shifted left/top water bounds")
	game.move_fish(Vector2(9999, 9999))
	check(game.fish == Vector2(748, 338), "free fish clamps changed right/bottom water bounds")
	game.hooked = game.HookState.HOOKED
	game.move_fish(Vector2(-9999, -9999))
	check(game.fish == Vector2(127, 109), "hooked fish uses larger radius in fixture water")
	game.hooked = game.HookState.FREE
	game.score = game.food_target()
	game.fish = Fixture.HOME
	check(game.can_home(), "home arrival uses fixture anchor")
	game.fish = Vector2(60, 401)
	check(not game.can_home(), "legacy home no longer completes home gate")
	game.fish = Fixture.HOME - Vector2(70, 0)
	var brain := FishBrain.new()
	brain.reset(14)
	var command: Dictionary = brain.command(game, game.TICK_SECONDS)
	check(command.move == Vector2.RIGHT, "fish AI navigates towards fixture home")
	game.fish = Fixture.HOME
	check(brain.command(game, game.TICK_SECONDS).home, "fish AI requests home at fixture anchor")
	check(game.vegetation_drag(Vector2(215, 300)) == game.rule("vegetation_speed"), "fixture standalone drag zone slows swimming")
	check(game.vegetation_drag(Vector2(145, 400)) == 1.0 and game.vegetation_drag(Vector2(660, 230)) == 1.0, "old grass and rope grass do not invent drag zones")
	var bait: Dictionary = game.baits[0]
	bait.pos = Vector2(-100, -100)
	bait.suction_offset = Vector2.ZERO
	game._step_bait_suction(bait, game.TICK_SECONDS, false)
	check(bait.pos == Vector2(117, 99), "bait suction uses fixture water inset")
	bait.pos = Vector2(9999, 9999)
	game._step_bait_suction(bait, game.TICK_SECONDS, false)
	check(bait.pos == Vector2(753, 343), "bait suction right/bottom fixture clamp")
	game.free()

func capabilities_and_coils() -> void:
	var game := world()
	game.rules.net_sight = 2000.0
	game.rules.net_reach = 2000.0
	check(not game.Net.manual_net_blocked(game, Vector2(275, 230)), "wood with net_blocking=false does not block")
	check(game.Net.manual_net_blocked(game, Vector2(445, 230)), "grass with net_blocking=true blocks")
	check(not game._collision(Vector2(275, 230), NPC.RADIUS) and game._collision(Vector2(555, 230), NPC.RADIUS), "NPC spawn exclusion uses its own capability")
	check(not game._collision(Vector2(445, 230), NPC.RADIUS), "net blocker does not implicitly block NPC spawn")
	check(game.Net.visibility(game, Vector2(662, 230)) == 0.0, "grass with fish_occluding=true occludes")
	check(game.Net.visibility(game, Vector2(445, 230)) > 0.0 and game.Net.visibility(game, Vector2(555, 230)) > 0.0, "net/spawn blocking does not implicitly occlude fish")
	check(is_equal_approx(game.Net.visibility(game, Vector2(215, 300)), 0.42), "independent drag zone applies legacy net visibility multiplier")
	check(game.Net.reachable(game, Vector2(160, 140)) and not game.Net.reachable(game, Vector2(100, 140)), "net reach uses changed net area")
	check(not game.Net.reachable(game, Vector2(700, 250)), "net area retains half-open right edge")
	check(not game.Net._net_reaches_fish(game, Vector2(470, 230), Vector2(410, 230)), "net lane cannot reach through capability blocker")
	check(game.Net._net_reaches_fish(game, Vector2(310, 230), Vector2(240, 230)), "net lane crosses nonblocking wood")
	game.net_action.a = Vector2(360, 230)
	var plan: Dictionary = game.Net.preview(game, Vector2(510, 230))
	check(plan.valid and plan.blocked and plan.b.x < 430, "net preview truncates against fixture blocker")
	game.fish = Vector2(275, 230)
	game._update_contacts(0.25)
	check(game.contact_target == 0 and game.target_opacity[0] == 1.0, "rope anchor can be selected without contact fade")
	game.fish = Vector2(445, 230)
	game._update_contacts(0.25)
	check(game.contact_target == -1 and game.target_opacity[1] == game.rule("cover_opacity"), "fade-only grass is not offered as rope anchor")
	game.hooked = game.HookState.HOOKED
	game.bound_bait = 0
	game.hook_target_fish_id = 1
	game.contact_target = 1
	check(not game._begin_wrap(), "stale caller target cannot start wrapping nonanchor")
	game.contact_target = 0
	game.fish = Vector2(275, 230)
	check(game._begin_wrap(), "fixture anchor starts normal wrap QTE")
	game._commit_wrap()
	check(game.wraps.size() == 1 and game.wraps[0].target == 0, "successful wrap keeps fixture compatibility index")
	if not game.wraps.is_empty():
		var coil: Dictionary = game.wraps[0]
		check(coil.center == Vector2(275, 230) and coil.radii == Vector2(19, 6), "fixture wood coil uses actual polygon width and kind")
		check(coil.loop.size() == 65 and coil.entry == Vector2(275, 224), "fixture coil retains original sample count and entry")
	game.free()

func npc_authority() -> void:
	for mode: String in ["survival", "duel"]:
		for seed_value in [2, 7, 19, 91, 1917, 2048, 5001, 9999]:
			var game := world({"seed":seed_value, "ruleset":mode, "npc_count":6, "npc_foraging_enabled":false})
			var repeat := world({"seed":seed_value, "ruleset":mode, "npc_count":6, "npc_foraging_enabled":false})
			check(game.npc_fishes == repeat.npc_fishes and game.rng.state == repeat.rng.state, "fixture NPC generation deterministic across fresh rounds")
			check(game.npc_fishes.size() >= 3, "nondefault ecology regions generate viable NPCs")
			for npc: Dictionary in game.npc_fishes:
				check(Rect2(120, 102, 630, 238).has_point(npc.position), "NPC spawned inside fixture inset water")
				check(Vector2(npc.position).distance_to(Fixture.HOME) > 80.0 and not game._collision(npc.position, NPC.RADIUS), "NPC spawn respects fixture home and exclusion flags")
				for bait: Dictionary in game.baits:
					check(not bait.active or Vector2(npc.position).distance_to(bait.pos) >= 45.0, "NPC avoids fixture bait sites")
			if not game.npc_fishes.is_empty():
				var npc: Dictionary = game.npc_fishes[0]
				npc.position = Vector2(9999, 9999)
				npc.decision_age = 1.0
				game._tick_npc_fishes(game.TICK_SECONDS)
				check(Vector2(npc.position).is_equal_approx(Vector2(749.999, 339.999)), "NPC movement uses fixture right/bottom bounds")
				npc.position = Vector2(-999, -999)
				game._tick_npc_fishes(game.TICK_SECONDS)
				check(npc.position == Vector2(120, 102), "NPC movement uses fixture left/top bounds")
			game.free()
			repeat.free()

func observation_authority() -> void:
	var game := world()
	game.fish = Vector2(122, 150)
	for bait: Dictionary in game.baits:
		bait.active = false
		for grain: Dictionary in bait.grains: grain.eaten = true
	var bait: Dictionary = game.baits[0]
	var outside: Dictionary = bait.grains[0]
	var inside: Dictionary = bait.grains[1]
	outside.eaten = false; outside.free = true; outside.pos = Vector2(105, 150)
	inside.eaten = false; inside.free = true; inside.pos = Vector2(145, 150)
	var observation := Observation.build(game, false)
	check(Observation.food_position(observation, bait.bait_id) == Vector2(145, 150), "nearer loose grain outside fixture water is not food target")
	inside.eaten = true
	observation = Observation.build(game, false)
	check(not Observation.food_position(observation, bait.bait_id).is_finite(), "legacy-water-only grain is never accepted as fixture food")
	var brain := FishBrain.new()
	brain.reset(88)
	check(brain.command(game, game.TICK_SECONDS).move == Vector2.ZERO, "fish AI waits when only old-map food is available")
	game.free()

func angler_and_navigation() -> void:
	var game := world({"ruleset":"duel"})
	check(game.angler.x == 308.0 and game.angler.cursor == Vector2(334, 204) and game.angler.anchor() == Vector2(334, 72), "angler initialized after fixture water was installed")
	game.angler.update(game, 0.0, {"target":Vector2(-999, -999)})
	check(game.angler.cursor == Vector2(132, 104), "angler cursor changed left/top clamp")
	game.angler.update(game, 0.0, {"target":Vector2(9999, 9999)})
	check(game.angler.cursor == Vector2(738, 335), "angler cursor changed right/bottom clamp")
	game.angler.x = -999.0
	game.angler.update(game, 0.0, {})
	check(game.angler.x == 120.0, "angler walk clamps shifted left bank")
	game.angler.x = 9999.0
	game.angler.update(game, 0.0, {})
	check(game.angler.x == 716.0, "angler walk clamps shifted right bank")
	check(game.angler.cast(game, Vector2(-999, -999)) and game.angler.cast_to == Vector2(140, 124), "angler cast clamps changed left/top water margins")
	game.angler.casting = false; game.angler.cast_cooldown = 0.0
	check(game.angler.cast(game, Vector2(9999, 9999)) and game.angler.cast_to == Vector2(730, 325), "angler cast clamps changed right/floor margins")
	game.angler.casting = false
	var bait: Dictionary = game.baits[0]
	bait.active = true
	game.angler.free_line_length = 100000.0
	game.rules.line_free_max = 100000.0
	for pair: Array in [[Vector2(-999, -999), Vector2(122, 103)], [Vector2(9999, 9999), Vector2(748, 340)]]:
		bait.pos = pair[0]
		game.angler.step_free_hook(game, 0, 0.0)
		check(bait.pos == pair[1], "free hook clamps fixture bounds " + str(pair[1]))
		game.angler.surface_live = false
		bait.pos = pair[0]
		game.angler.step_tackle_feedback(game, 0.0)
		check(game.angler.surface_x == pair[1].x, "surface feedback uses fixture horizontal limits")
	game.angler.x = 400.0
	game.elapsed = 0.0
	var angler_brain := AnglerBrain.new()
	check(angler_brain.command(game, game.TICK_SECONDS).walk == 0.0, "angler patrol midpoint uses changed map width")
	game.hooked = game.HookState.HOOKED
	game.bound_bait = 0
	game.fish = Vector2(715, 320)
	var fish_brain := FishBrain.new()
	fish_brain.reset(92)
	fish_brain.was_hooked = true
	var command: Dictionary = fish_brain.command(game, game.TICK_SECONDS)
	check(fish_brain.escape_target == 4, "fish AI selects authored edge anchor by ordered fixture geometry")
	check(Vector2(command.move).is_equal_approx((Vector2(738, 329) - game.fish).normalized() * 0.72), "fish AI target center clamps to fixture water/floor")
	game.fish = Vector2(445, 270)
	fish_brain.decision_age = 0.0
	fish_brain.command(game, game.TICK_SECONDS)
	check(fish_brain.escape_target == 0, "fish AI skips closer nonanchor grass and spawn-only stone")
	game.hooked = game.HookState.FREE
	game.net_state = "sweep"
	game.manual_net = false
	game.net_from = Vector2(180, 160); game.net_to = Vector2(180, 240); game.net_pos = Vector2(180, 200)
	game.fish = Vector2(170, 200)
	command = fish_brain.command(game, game.TICK_SECONDS)
	check(command.move == Vector2.RIGHT, "fish AI net evasion rejects old-left-edge escape destination")
	game.net_state = "wait"
	var path: PackedVector2Array = game.Net._manual_net_exit(game, Vector2(350, 160))
	check(path == PackedVector2Array([Vector2(350, 160), Vector2(350, 29)]), "unobstructed net lift ends at shifted surface policy")
	game.free()

func npc_hook_and_recovery() -> void:
	var game := world({"npc_count":3})
	var npc: Dictionary = game.npc_fishes[0]
	game.baits[0].hook = true; game.baits[0].active = true
	check(NPCHook.enter(game, 0, npc), "fixture NPC can acquire line through existing hook lifecycle")
	npc.position = Vector2(9999, 9999)
	NPCHook.step(game, 0.0)
	check(Vector2(npc.position).is_equal_approx(Vector2(749.999, 339.999)), "hooked NPC uses fixture right/bottom clamp")
	npc.position = Vector2(-999, -999)
	NPCHook.step(game, 0.0)
	check(npc.position == Vector2(120, 102), "hooked NPC uses shifted left/top clamp")
	game.npc_hook.phase = "landing"
	game.npc_hook.landing_age = 0.0
	game.npc_hook.landing_from = Vector2(250, 150)
	var destination := Vector2(game.line_anchor(0).x, 63)
	NPCHook.step(game, game.rule("landing_lift") * 0.5)
	check(Vector2(npc.position).is_equal_approx(Vector2(250, 150).lerp(destination, 0.25)), "NPC landing endpoint follows fixture surface")
	game.free()
	game = world()
	game.bound_bait = 0; game.hooked = game.HookState.HOOKED
	game.landing = true; game.landing_age = 0.0; game.landing_from = Vector2(250, 150)
	game._step_landing(game.rule("landing_lift"))
	check(game.fish == Fixture.HOME + Vector2(0, -14), "practice landing returns to fixture home")
	game.net_state = "caught"; game.net_age = 0.0; game.net_retract_duration = 1.0
	game.net_return_from = Vector2(300, 200); game.net_from = Vector2(300, 150); game.net_park = Vector2(300, 29)
	game._advance_net(2.0, game.fish, game.fish)
	check(game.fish == Fixture.HOME + Vector2(0, -14), "practice net recovery returns to fixture home")
	game.free()

func grouped_capabilities_and_visual_purity() -> void:
	var grouped := Fixture.create()
	grouped.interaction_features[1].fade_group_id = Fixture.IDS[3]
	grouped.interaction_features[4].fade_group_id = Fixture.IDS[3]
	Fixture.seal(grouped)
	var game := World.new()
	check(game.reset_world({"npc_count":0}, grouped), "cross-kind shared fade group is legal")
	game.fish = Vector2(445, 230)
	game._update_contacts(0.25)
	check(game.target_opacity[1] == game.rule("cover_opacity") and game.target_opacity[3] == game.target_opacity[1] and game.target_opacity[4] == game.target_opacity[1], "authored grass/stone shared fade group ignores kind and visual groups")
	game.free()
	var original := Fixture.create()
	var cosmetic := original.duplicate(true)
	cosmetic.presentation.visual_profile_id = "different_art"
	cosmetic.presentation.wood_groups = [[9001, 9003]]
	cosmetic.visual_features.reverse()
	for visual: Dictionary in cosmetic.visual_features:
		visual.legacy.visual_seed = -77
		visual.legacy.name = "changed illustration only"
		visual.legacy.points = [Vector2.ZERO, Vector2.ONE, Vector2(999, 999)]
	for feature: Dictionary in cosmetic.interaction_features:
		feature.presentation_ref = "visual_4"
	check(Validator.validate(cosmetic).valid and cosmetic.meta.content_hash == original.meta.content_hash, "independent presentation changes retain exact authority hash")
	var a := World.new(); var b := World.new()
	check(a.reset_world({"seed":555, "npc_count":3}, original) and b.reset_world({"seed":555, "npc_count":3}, cosmetic), "both visual variants initialize same authority")
	for tick in 120:
		var command := {"move":Vector2.RIGHT.rotated(float(tick) * 0.023), "aim":Vector2.RIGHT, "suck":tick % 10 < 4}
		a.advance_tick(command, {}); b.advance_tick(command, {})
		check(a.fish == b.fish and a.npc_fishes == b.npc_fishes and a.baits == b.baits and a.rng.state == b.rng.state, "cosmetics cannot change authority/RNG tick %d" % tick)
		check(Observation.build(a, false) == Observation.build(b, false), "cosmetics cannot change fish observation tick %d" % tick)
	a.free(); b.free()

func _initialize() -> void:
	initialization_and_atomicity()
	spatial_authority()
	capabilities_and_coils()
	npc_authority()
	observation_authority()
	angler_and_navigation()
	npc_hook_and_recovery()
	grouped_capabilities_and_visual_purity()
	print("PHASE04_MAP_AUTHORITY_TESTS | passed=%d | failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
