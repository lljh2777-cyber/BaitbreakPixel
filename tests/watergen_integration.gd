extends SceneTree
const Appearance = preload("res://scripts/watergen/pond_water_appearance.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const World = preload("res://scripts/world_simulation.gd")
class RejectCache extends Appearance.Cache:
	func generate(_map: Dictionary, _profile: Dictionary, _seed: int) -> Dictionary:
		return {"ok":false, "code":"TEST_PREPARE_FAILURE"}
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG3_CONTRACT_PASS | ", label)
	else: failed += 1; push_error("WG3_CONTRACT_FAIL | " + label)

func remember_textures(bundle: Dictionary, references: Dictionary) -> void:
	for layer in bundle.layers.values():
		references[layer.texture.get_instance_id()] = weakref(layer.texture)
	for animation in bundle.animations:
		references[animation.texture.get_instance_id()] = weakref(animation.texture)

func _initialize() -> void:
	var appearance := Appearance.new()
	check(not appearance.enabled and appearance.bundle.is_empty(), "default legacy allocates no generated textures")
	check(appearance.preset_id == "fern" and appearance.visual_seed() == 713284, "approved fern seed remains the default choice")
	check(appearance.choose_preset("lily") and not appearance.enabled and appearance.cache.plan_count == 0, "choosing while disabled does not generate or enable")
	check(not appearance.choose_preset("unknown") and appearance.preset_id == "lily", "unknown preset leaves selection unchanged")
	appearance.choose_preset("fern")
	for role in ["fish", "angler", "observer", "preview"]:
		for shared in [false, true]:
			for connected in [false, true]:
				check(Appearance.eligible(role, shared, connected) == (role == "fish" and not shared and not connected), "local fish eligibility %s %s %s" % [role, shared, connected])
	var w := World.new()
	w.reset_world({"seed":8231})
	var before: PackedByteArray = var_to_bytes(w.capture_snapshot())
	var geometry := Appearance.Adapter.authority_bytes()
	check(appearance.select(true) and Appearance.complete(appearance.bundle), "all six layers ready before activation")
	check(before == var_to_bytes(w.capture_snapshot()) and geometry == Appearance.Adapter.authority_bytes(), "preparation preserves complete authority, RNG and target geometry")
	var key: String = appearance.bundle.cache_key
	for bait in w.baits: bait.hook = not bait.hook; bait.hook_id += 991
	w.rng.seed = 985131
	var other := Appearance.new()
	check(other.select(true) and other.bundle.cache_key == key, "private hook truth and simulation seed cannot affect visual key")
	for name in appearance.bundle.layers:
		check(appearance.bundle.layers[name].rgba_sha256 == other.bundle.layers[name].rgba_sha256, "private truth cannot affect layer " + name)
	var counts := [appearance.cache.plan_count, appearance.cache.bake_count, appearance.cache.upload_count, appearance.cache.texture_count]
	for index in 20: appearance.select(false); appearance.select(true)
	check(counts == [appearance.cache.plan_count, appearance.cache.bake_count, appearance.cache.upload_count, appearance.cache.texture_count], "twenty option toggles reuse prepared bundle")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Appearance.PROFILE_PATH))
	invalid["private_hook"] = true
	check(not appearance.select(true, invalid) and not appearance.enabled and appearance.bundle.is_empty(), "invalid configuration clears active bundle for complete legacy fallback")
	check(not appearance.select(true, []) and appearance.last_code == "PROFILE_TYPE", "non-dictionary profile safely falls back")
	check(appearance.select(true), "valid retry recovers after fallback")
	var partial: Dictionary = appearance.bundle.duplicate(true)
	partial.layers.erase("foreground")
	check(not Appearance.complete(partial), "partial six-layer bundle rejected")
	check(Appearance.Adapter.build(Appearance.SOURCE_COMMIT).map_public_digest == "ce6bd84149877c461f1765497b7aa7b58fe8e80abf74965e45b406824ac31b1d", "integration baseline retains frozen public geometry")
	partial.clear()
	var switch_state: PackedByteArray = var_to_bytes(w.capture_snapshot())
	var references: Dictionary = {}
	var keys: Dictionary = {}
	var signatures: Dictionary = {}
	var bounded := true
	var repeatable := true
	for index in 20:
		var preset: Dictionary = Appearance.PRESETS[index % Appearance.PRESETS.size()]
		if not appearance.choose_preset(preset.id): bounded = false; break
		remember_textures(appearance.bundle, references)
		var alive := 0
		for reference in references.values():
			if reference.get_ref() != null: alive += 1
		bounded = bounded and alive <= 14 and appearance.cache.bundles.size() <= 2
		var signature: String = appearance.bundle.layers.distance.rgba_sha256
		if keys.has(preset.id):
			repeatable = repeatable and keys[preset.id] == appearance.bundle.cache_key and signatures[preset.id] == signature
		keys[preset.id] = appearance.bundle.cache_key
		signatures[preset.id] = signature
	check(bounded, "twenty preset changes retain at most two bundles and fourteen live textures")
	var distinct: Dictionary = {}
	for signature in signatures.values(): distinct[signature] = true
	check(keys.size() == 4 and distinct.size() == 4 and repeatable, "four presets change visuals and reproduce after cache eviction")
	check(var_to_bytes(w.capture_snapshot()) == switch_state and geometry == Appearance.Adapter.authority_bytes(), "preset switching preserves all world state, RNG and geometry")
	var active_key: String = appearance.bundle.cache_key
	check(not appearance.choose_preset("unknown") and appearance.enabled and appearance.bundle.cache_key == active_key, "invalid selection cannot damage active appearance")
	var uploads: int = appearance.cache.upload_count
	appearance.choose_preset("lily"); appearance.choose_preset("root")
	check(appearance.cache.upload_count == uploads, "returning to either recent preset uses cached textures")
	appearance.select(false); appearance.choose_preset("fern"); appearance.select(true)
	check(appearance.visual_seed() == 713284 and appearance.bundle.cache_key == keys.fern, "re-enabling prepares the pending preset rather than a stale bundle")
	var valid_cache = appearance.cache
	appearance.cache = RejectCache.new()
	check(not appearance.choose_preset("root") and not appearance.enabled and appearance.bundle.is_empty() and appearance.preset_id == "fern", "failed preset preparation atomically falls back and restores selection")
	appearance.cache = valid_cache
	check(appearance.select(true) and appearance.bundle.cache_key == keys.fern, "failed preset change can recover using the prior cached choice")
	w.free()
	print("WG3_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
