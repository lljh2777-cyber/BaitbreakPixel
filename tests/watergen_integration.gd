extends SceneTree
const Appearance = preload("res://scripts/watergen/pond_water_appearance.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const World = preload("res://scripts/world_simulation.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG3_CONTRACT_PASS | ", label)
	else: failed += 1; push_error("WG3_CONTRACT_FAIL | " + label)

func _initialize() -> void:
	var appearance := Appearance.new()
	check(not appearance.enabled and appearance.bundle.is_empty(), "default legacy allocates no generated textures")
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
	w.free()
	print("WG3_CONTRACT | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
