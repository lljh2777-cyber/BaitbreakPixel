extends RefCounted
const Base = preload("res://scripts/watergen/water_visual_baker.gd")
const Generator = preload("res://scripts/watergen/water_dynamic_generator.gd")
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")
const Foliage = preload("res://scripts/watergen/water_foliage.gd")

static func shifted(object: Dictionary, offset: Vector2) -> Dictionary:
	var result := object.duplicate(true)
	if result.has("x"): result.x += offset.x
	if result.has("y"): result.y += offset.y
	if result.has("stems"):
		for stem in result.stems: stem.x += offset.x; stem.y += offset.y
	return result

static func bake(plan: Dictionary) -> Dictionary:
	var version: String = plan.get("generator_version", "")
	var spec: String = Generator.RASTER_SPEC if version == Generator.VERSION else Generator.LEGACY_RASTER_SPEC
	if not version in [Generator.VERSION, Generator.LEGACY_VERSION] or plan.get("world_size_px") != [1280, 480] or plan.get("raster_spec") != spec:
		return {"ok": false, "code": "PLAN_VERSION_OR_SIZE"}
	# Internal plans only; also bound all allocations before creating any image.
	for layer in plan.layers:
		var pad := Frame.padding(plan.parallax_compensation[layer.name])
		if pad.x > 196 or pad.y > 40 or layer.origin_px != [-pad.x, -pad.y] or layer.size_px != [1280 + pad.x * 2, 480 + pad.y * 2]:
			return {"ok": false, "code": "RASTER_BOUNDS"}
	var layers: Dictionary = {}
	var animations: Array = []
	for layer in plan.layers:
		var image := Image.create(layer.size_px[0], layer.size_px[1], false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var offset := -Vector2(layer.origin_px[0], layer.origin_px[1])
		match layer.name:
			"water": Base._water(image, layer, plan)
			"floor": Base._floor(image, layer, plan)
		for object in layer.objects:
			var local := shifted(object, offset)
			match object.kind:
				"clump":
					if object.get("rich", false): Foliage.clump(image, local, layer.name, plan.palette)
					else: Base._clump(image, local, layer.name, plan.palette)
				"pad": Base._pad(image, local, plan.palette)
				"root": Base._root(image, local, plan.palette)
				"gravel": Base._gravel(image, local, plan.palette)
				"shadow": Base._shadow(image, local, plan.palette)
				"mote":
					var color := Color(plan.palette.haze_light).lerp(Color(plan.palette.water_deep), 0.38)
					color.a = object.alpha
					Raster.pixel(image, local.x, local.y, color)
				"animated_stem": animations.append(_stem(object, layer.name, plan.palette))
				"animated_root": animations.append(_root(object, layer.name, plan.palette))
				"canopy": Foliage.canopy(image, local, layer.name, plan.palette)
				"animated_canopy": animations.append(_canopy(object, layer.name, plan.palette))
				"leaf_litter": Foliage.litter(image, local, plan.palette)
		layers[layer.name] = {"image": image, "origin_px": layer.origin_px.duplicate(), "rgba_sha256": Raster.digest(image)}
	var result := {"ok": true, "code": "OK", "layers": layers, "animations": animations}
	if version == Generator.VERSION: result["animation_atlas"] = _atlas(animations)
	return result

static func _atlas(animations: Array) -> Image:
	# One GPU texture for all small patches avoids frequent texture changes.
	var x := 2
	var y := 2
	var row_height := 0
	for animation in animations:
		var image: Image = animation.image
		if x + image.get_width() + 2 > 1024:
			x = 2
			y += row_height + 4
			row_height = 0
		animation["region_px"] = [x, y, image.get_width(), image.get_height()]
		x += image.get_width() + 4
		row_height = maxi(row_height, image.get_height())
	var atlas := Image.create(1024, maxi(4, y + row_height + 2), false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for animation in animations:
		var image: Image = animation.image
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(animation.region_px[0], animation.region_px[1]))
	return atlas

static func _stem(object: Dictionary, layer: String, palette: Dictionary) -> Dictionary:
	var stem: Dictionary = object.stem
	# A conservative crop includes lean, leaves, line width and both sway extremes.
	var margin := 28 if object.get("rich", false) else 20
	var left := floori(stem.x - absf(stem.lean) - margin)
	var top := floori(stem.y - stem.height - 12)
	var width := ceili(absf(stem.lean) * 2 + margin * 2 + 2)
	var height := ceili(stem.height + 18)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var clump := shifted({"contrast": object.contrast, "stems": [stem]}, Vector2(-left, -top))
	if object.get("rich", false):
		clump["tint"] = object.tint
		Foliage.clump(image, clump, layer, palette)
	else: Base._clump(image, clump, layer, palette)
	return _animation(object, layer, image, [left, top])

static func _animation(object: Dictionary, layer: String, image: Image, origin: Array) -> Dictionary:
	var result := {"id": object.id, "layer": layer, "image": image, "origin_px": origin, "root_y": object.root_y, "height": object.height, "phase": object.phase, "rgba_sha256": Raster.digest(image)}
	for key in ["amplitude", "omega", "growth"]:
		if object.has(key): result[key] = object[key]
	return result

static func _root(object: Dictionary, layer: String, palette: Dictionary) -> Dictionary:
	var left := floori(object.x - object.width - 24)
	var top := floori(object.y)
	var image := Image.create(ceili(object.width * 2 + 50), ceili(object.length + 18), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	Base._root(image, shifted(object, Vector2(-left, -top)), palette)
	return _animation(object, layer, image, [left, top])

static func _canopy(object: Dictionary, layer: String, palette: Dictionary) -> Dictionary:
	# Include the widest leaf, branch lean and both sway extremes in the crop.
	var half_width := ceili(object.width + absf(object.lean) + 52)
	var left := floori(object.x) - half_width
	var top := floori(object.y) - 2
	var image := Image.create(half_width * 2 + 2, ceili(object.length + 42), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	Foliage.canopy(image, shifted(object, Vector2(-left, -top)), layer, palette)
	return _animation(object, layer, image, [left, top])
