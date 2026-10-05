extends RefCounted
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")

static func bake(plan: Dictionary) -> Dictionary:
	# ScenePlan is an internal output of the validated generator, not an external file loader.
	if plan.get("format") != "baitbreak-water-scene-plan" or plan.get("generator_version") != Profile.VERSION or plan.get("world_size_px") != [1280, 480]:
		return {"ok": false, "code": "PLAN_VERSION_OR_SIZE"}
	var palette: Dictionary = plan.palette
	var layers: Dictionary = {}
	for description in plan.layers:
		var image := Image.create(plan.world_size_px[0], plan.world_size_px[1], false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		match description.name:
			"water": _water(image, description, plan)
			"floor": _floor(image, description, plan)
		for object in description.objects:
			match object.kind:
				"clump": _clump(image, object, description.name, palette)
				"pad": _pad(image, object, palette)
				"root": _root(image, object, palette)
				"gravel": _gravel(image, object, palette)
				"shadow": _shadow(image, object, palette)
				"mote":
					var color := Color(palette.haze_light).lerp(Color(palette.water_deep), 0.38)
					color.a = object.alpha
					Raster.pixel(image, object.x, object.y, color)
		layers[description.name] = {"image": image, "origin_px": description.origin_px.duplicate()}
	return {"ok": true, "code": "OK", "layers": layers}

static func _water(image: Image, layer: Dictionary, plan: Dictionary) -> void:
	var shallow := Color(plan.palette.water_shallow)
	var deep := Color(plan.palette.water_deep)
	var haze := Color(plan.palette.haze_light)
	for y in image.get_height():
		var depth := clampf((y - plan.surface_y) / float(plan.floor_y - plan.surface_y), 0, 1)
		var base := shallow.lerp(deep, pow(depth, 0.82))
		for x in image.get_width():
			var field := (sin(x * 0.008 + y * 0.005 + layer.phase) + sin(x * 0.017 - y * 0.008)) * 0.005
			var grain := (float(posmod(x * 374761 + y * 668265, 104729)) / 104729.0 - 0.5) * 0.002
			var color := Color(base.r + field + grain, base.g + field + grain, base.b + field + grain, 1)
			if y < plan.surface_y:
				color = shallow.lerp(haze, 0.64)
				var bank: float = plan.surface_y - 5 - roundf(sin(x * 0.012) * 3 + sin(x * 0.04) * 1.5)
				if y > bank: color = shallow.lerp(haze, 0.35)
			image.set_pixel(x, y, color)
	for beam in layer.objects:
		for y in range(int(plan.surface_y), mini(image.get_height(), int(plan.surface_y + beam.depth))):
			var progress: float = (y - plan.surface_y) / float(beam.depth)
			var center: float = beam.x + beam.lean * progress + sin(progress * 5.7 + beam.phase) * 3
			var width: float = beam.width * (0.7 + 0.65 * progress)
			var fade: float = beam.intensity * pow(1 - progress, 1.8)
			for x in range(maxi(0, floori(center - width)), mini(image.get_width(), ceili(center + width))):
				var edge := maxf(0, 1 - absf(x - center) / width)
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(haze, fade * edge * edge))

static func _floor(image: Image, layer: Dictionary, plan: Dictionary) -> void:
	var dark := Color(plan.palette.silt_dark)
	var light := Color(plan.palette.silt_light)
	for x in image.get_width():
		var rim: float = plan.floor_y - 30 + sin(x * 0.011 + layer.phase) * 10 + sin(x * 0.031) * 3
		for y in range(maxi(0, floori(rim)), image.get_height()):
			var depth := clampf((y - rim) / maxf(1, plan.floor_y - rim), 0, 1)
			var coarse := _noise(Vector2(x / 37.0, y / 12.0), layer.phase)
			var fine := _noise(Vector2(x / 5.0, y / 3.0), layer.phase + 1)
			var shade := roundf((0.17 + coarse * 0.20 + fine * 0.1) * 24) / 24.0
			var color := dark.lerp(light, shade)
			color.a = depth * depth * 0.9 if y < plan.floor_y else 1.0
			image.set_pixel(x, y, color)

static func _hash(x: int, y: int, phase: float) -> float:
	var value: int = (x * 374761 + y * 668265 + int(phase * 9137)) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	value = value ^ (value >> 16)
	return float(value) / 2147483647.0

static func _noise(p: Vector2, phase: float) -> float:
	var x := floori(p.x)
	var y := floori(p.y)
	var tx := smoothstep(0, 1, p.x - x)
	var ty := smoothstep(0, 1, p.y - y)
	return lerpf(lerpf(_hash(x, y, phase), _hash(x + 1, y, phase), tx), lerpf(_hash(x, y + 1, phase), _hash(x + 1, y + 1, phase), tx), ty)

static func _shadow(image: Image, object: Dictionary, palette: Dictionary) -> void:
	var dark := Color(palette.foreground_dark)
	for y in range(int(object.y) - 4, int(object.y) + 6):
		for x in range(maxi(0, floori(object.x - object.radius)), mini(image.get_width(), ceili(object.x + object.radius))):
			var d: float = pow((x - object.x) / maxf(1, object.radius), 2) + pow((y - object.y) / 5.0, 2)
			if d < 1:
				var base := image.get_pixel(x, y)
				var color := base.lerp(dark, (1 - d) * 0.55)
				color.a = base.a
				image.set_pixel(x, y, color)

static func _stem_point(stem: Dictionary, t: float) -> Vector2:
	return Vector2(stem.x + stem.lean * t * t + sin(t * 3.1 + stem.phase) * t * 3, stem.y - stem.height * t)

static func _clump(image: Image, object: Dictionary, layer: String, palette: Dictionary) -> void:
	var base := Color(palette.plant_far).lerp(Color(palette.water_deep), 0.12)
	if layer == "terrain": base = Color(palette.plant_far).lerp(Color(palette.silt_light), 0.19)
	if layer == "foreground": base = Color(palette.foreground_dark)
	base.a = object.contrast * (0.62 if layer == "distance" else 0.88)
	var dark := base.darkened(0.13)
	var tip := base.lerp(Color(palette.haze_light), 0.045)
	tip.a = base.a
	for stem in object.stems:
		var previous := _stem_point(stem, 0)
		for index in range(1, 25):
			var t := index / 24.0
			var point := _stem_point(stem, t)
			Raster.line(image, previous, point, base)
			if index < 13: Raster.line(image, previous + Vector2(1, 0), point + Vector2(1, 0), dark)
			previous = point
		if stem.kind == "ribbon":
			for side in [-1, 1]:
				var root := _stem_point(stem, 0.08)
				var top := _stem_point(stem, 0.86) + Vector2(side * 9, 9)
				Raster.polygon(image, PackedVector2Array([root, root + Vector2(side * 7, -stem.height * 0.4), top, root + Vector2(side * 3, -stem.height * 0.42)]), base)
		else:
			for index in range(2, 12):
				var t := index / 13.0
				var anchor := _stem_point(stem, t)
				for side in [-1, 1]:
					var length: float = (1 - t * 0.65) * minf(13, stem.height * 0.16) * (0.8 + 0.2 * sin(index * 2 + stem.phase + side))
					var leaf := anchor + Vector2(side * length, -length * 0.75)
					Raster.polygon(image, PackedVector2Array([anchor + Vector2(0, 2), anchor + Vector2(side * length * 0.65, -1), leaf, anchor + Vector2(side * 2, -3)]), tip if index % 3 == 0 else base)

static func _pad(image: Image, pad: Dictionary, palette: Dictionary) -> void:
	var stem_color := Color(palette.plant_far).lerp(Color(palette.silt_light), 0.25)
	stem_color.a = 0.68
	var root := Vector2(pad.x, pad.y)
	var previous := root
	for index in range(1, 41):
		var t := index / 40.0
		var point := root + Vector2(pad.lean * t * t + sin(t * 4 + pad.phase) * t * 4, pad.stem_length * t)
		Raster.line(image, previous, point, stem_color)
		previous = point
	var leaf := PackedVector2Array()
	for index in 14:
		var angle := index * TAU / 14.0
		leaf.append(root + Vector2(cos(angle) * pad.width, sin(angle) * pad.depth))
	var base := Color(palette.plant_far).lerp(Color(palette.silt_light), 0.44)
	Raster.polygon(image, leaf, base)
	Raster.polygon(image, PackedVector2Array([root + Vector2(-pad.width + 4, -2), root + Vector2(-pad.width * 0.3, -pad.depth + 1), root + Vector2(pad.width * 0.5, -pad.depth + 2), root + Vector2(pad.width - 4, -1), root + Vector2(2, -1)]), base.lightened(0.13))
	Raster.line(image, root + Vector2(-pad.width * 0.6, 1), root + Vector2(pad.width * 0.7, 1), base.darkened(0.18))
	Raster.line(image, root, root + Vector2(pad.width * 0.7, -pad.depth * 0.5), base.darkened(0.16))

static func _root(image: Image, root: Dictionary, palette: Dictionary) -> void:
	var color := Color(palette.silt_light).lerp(Color(palette.water_shallow), 0.65)
	color.a = 0.5
	for strand in 9:
		var x: float = root.x + sin(strand * 2.3 + root.phase) * root.width
		var previous := Vector2(x, root.y)
		for index in range(1, 18):
			var t := index / 17.0
			var point := Vector2(x + sin(t * 6 + strand) * t * 11, root.y + root.length * (0.75 + 0.25 * sin(strand)) * t)
			Raster.line(image, previous, point, color)
			if index % 4 == 0: Raster.line(image, point, point + Vector2(sin(strand) * 7, 9), color)
			previous = point

static func _gravel(image: Image, stone: Dictionary, palette: Dictionary) -> void:
	var color := Color(palette.silt_dark).lerp(Color(palette.silt_light), 0.25 + stone.shade * 0.13)
	var p := Vector2(stone.x, stone.y)
	var w: float = stone.width
	var h: float = stone.height
	Raster.polygon(image, PackedVector2Array([p + Vector2(-1, 1), p + Vector2(0, -h), p + Vector2(w * 0.5, -h - 1), p + Vector2(w, 0), p + Vector2(w - 1, 2)]), color.darkened(0.12))
	Raster.line(image, p + Vector2(0, -h), p + Vector2(w * 0.5, -h - 1), color)
