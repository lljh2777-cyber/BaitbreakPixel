extends SceneTree
const Materials = preload("res://scripts/watergen/water_cover_materials.gd")
const View = preload("res://scripts/pond_view.gd")
const Map = preload("res://scripts/watergen/adapters/pond_v2_context.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("WG5_MATERIAL_PASS | ", label)
	else: failed += 1; push_error("WG5_MATERIAL_FAIL | " + label)

func unchanged_mask(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size(): return false
	var first := a.get_data()
	var second := b.get_data()
	for byte in range(3, first.size(), 4):
		if first[byte] != second[byte]: return false
	return true

func exercise() -> Array:
	var geometry := Map.authority_bytes()
	var view := View.new()
	var props := View.Art.scene_props()
	var plants: Array = []
	var kinds: Array[String] = []
	for prop in props: kinds.append(View.Layout.SOLIDS[prop.targets[0]].kind)
	for index in View.Layout.PLANTS.size():
		var frames: Array[Dictionary] = []
		for frame in 8: frames.append(view._make_plant_layer(frame * TAU / 12.0, index))
		plants.append(frames)
	var materials := Materials.new()
	view.cover_materials = materials
	check(not materials.prepare([], [], []) and materials.texture_count == 0, "incomplete input cannot activate a partial material set")
	check(materials.prepare(props, plants, kinds), "complete public sprite set prepares")
	var ids: Array = []
	var references: Array = []
	for index in props.size():
		var source: Image = props[index].texture.get_image()
		var original := source.get_data()
		var styled: Dictionary = materials.props[index]
		var image: Image = styled.texture.get_image()
		var repeated := Materials.finish(source, kinds[index], styled.position, styled.targets[0])
		check(unchanged_mask(source, image) and props[index].position == styled.position and props[index].targets == styled.targets, "prop union mask, crop and fade members unchanged " + str(index))
		check(original != image.get_data() and original == source.get_data(), "prop material changes RGB without mutating source " + str(index))
		check(repeated.get_data() == image.get_data(), "prop material deterministic " + str(index))
		ids.append(styled.texture.get_instance_id()); references.append(weakref(styled.texture))
	var poses := 0
	for index in plants.size():
		var valid: bool = materials.plant_frames[index].size() == 8
		for frame in 8:
			var source: Dictionary = plants[index][frame]
			var styled: Dictionary = materials.plant_frames[index][frame]
			valid = valid and source.position == styled.position and unchanged_mask(source.texture.get_image(), styled.texture.get_image())
			ids.append(styled.texture.get_instance_id()); references.append(weakref(styled.texture))
			poses += 1
		check(valid, "all eight plant silhouettes, roots and crops unchanged " + str(index))
	check(poses == 176 and materials.texture_count == props.size() + poses, "one bounded finish per existing sprite and plant pose")
	var count := materials.texture_count
	var elapsed := materials.preparation_us
	for index in 20: materials.prepare(props, plants, kinds)
	var retained: Array = []
	for prop in materials.props: retained.append(prop.texture.get_instance_id())
	for frames in materials.plant_frames:
		for sprite in frames: retained.append(sprite.texture.get_instance_id())
	check(retained == ids and materials.texture_count == count and materials.preparation_us == elapsed, "twenty prepares reuse exactly the same textures")
	check(Map.authority_bytes() == geometry, "all authority geometry and target ordering remain unchanged")
	view.free()
	return references

func _initialize() -> void:
	# The helper's local sprite Dictionaries must also leave scope, otherwise
	# the test itself retains the final textures after freeing the owner.
	var references := exercise()
	var alive := 0
	for reference in references:
		if reference.get_ref() != null: alive += 1
	check(alive == 0, "material textures release with their owning view cache")
	print("WG5_MATERIAL | passed=", passed, " | failed=", failed)
	quit(1 if failed else 0)
