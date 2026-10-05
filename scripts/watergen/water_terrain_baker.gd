extends RefCounted
## CPU-only static terrain raster. Uploads belong to the preview's existing cache.
const Terrain = preload("res://scripts/watergen/water_visual_terrain.gd")
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Base = preload("res://scripts/watergen/water_visual_baker.gd")
const Frame = preload("res://scripts/watergen/water_visual_frame.gd")

static func bake(plan: Dictionary, palette: Dictionary, far_parallax: Array) -> Dictionary:
	if plan.get("generator_version") != Terrain.VERSION or plan.get("world_size_px") != [1280, 480]: return {"ok": false, "code": "TERRAIN_VERSION"}
	var pad := Frame.padding(far_parallax)
	if pad.x > 196 or pad.y > 40: return {"ok": false, "code": "TERRAIN_BOUNDS"}
	var far := Image.create(1280 + pad.x * 2, 480 + pad.y * 2, false, Image.FORMAT_RGBA8)
	var bed := Image.create(1280, 480, false, Image.FORMAT_RGBA8)
	far.fill(Color.TRANSPARENT)
	bed.fill(Color.TRANSPARENT)
	_paint_surface(far, plan, palette, "far", pad)
	_paint_surface(bed, plan, palette, "middle", Vector2i.ZERO)
	_shelves(bed, plan, palette)
	_paint_surface(bed, plan, palette, "near", Vector2i.ZERO)
	return {"ok": true, "far": far, "bed": bed}

static func _paint_surface(image: Image, plan: Dictionary, palette: Dictionary, depth: String, pad: Vector2i) -> void:
	var far := depth == "far"
	var near := depth == "near"
	var dark := Color(palette.water_deep).lerp(Color(palette.silt_dark), 0.48 if far else 0.83)
	var light := Color(palette.silt_light).lerp(Color(palette.water_deep), 0.60 if far else 0.36)
	var phase: float = plan.terrain_regions[Terrain.DEPTHS.find(depth)].phase
	var channel: Dictionary = plan.sediment_channels[0]
	for ix in image.get_width():
		var x := ix - pad.x
		var rim := Terrain.surface_y(plan, depth, x)
		for iy in range(maxi(0, floori(rim) + pad.y), image.get_height()):
			var y := iy - pad.y
			var distance := y - rim
			var coarse := Base._noise(Vector2(x / 61.0, y / 18.0), phase)
			var grain := Base._noise(Vector2(x / 5.0, y / 2.0), phase + 1.0)
			var band := sin(distance * 0.105 + coarse * 3.4 + x * 0.004)
			var shoulder := (1.0 - smoothstep(6, 32, distance)) * 0.12
			var shade := roundf((0.21 + coarse * 0.27 + grain * 0.17 + band * 0.075 + shoulder) * 20.0) / 20.0
			var color := dark.lerp(light, shade)
			if not far:
				var progress := clampf((y - channel.y) / 111.0, 0, 1)
				var channel_x: float = channel.x + sin(progress * 2.6 + channel.phase) * channel.bend * progress
				var width: float = channel.width * (0.35 + progress * 1.2)
				var weight := 1.0 - smoothstep(width * 0.35, width, absf(x - channel_x))
				color = color.lerp(Color(palette.water_deep), weight * channel.shade)
			# Soft flooded edges, muted terraces; no hard collision-looking silhouette.
			var fade := smoothstep(0, 9 if far else 5, distance)
			# Ordered coverage bands keep the softened rim in the pixel-art language.
			var dither := float(posmod(x + y * 3, 4)) / 4.0
			fade = floorf(fade * 8.0 + dither) / 8.0
			color.a = fade * (0.72 if far else 0.93 if not near else 0.72)
			if near: color = color.darkened(0.10)
			var underneath := image.get_pixel(ix, iy)
			image.set_pixel(ix, iy, underneath.blend(color))

static func _shelves(image: Image, plan: Dictionary, palette: Dictionary) -> void:
	for shelf in plan.stone_shelves:
		var left := floori(shelf.x - shelf.width * 0.5)
		var right := ceili(shelf.x + shelf.width * 0.5)
		var base := Terrain.surface_y(plan, "middle", shelf.x) + 20.0
		var rng := Terrain.stream(plan.visual_seed, "shelf-raster", shelf.seed)
		var tilt := rng.randf_range(-4, 4)
		for x in range(maxi(0, left), mini(1280, right)):
			var u := (x - left) / float(right - left)
			var cap := sin(u * PI)
			var top: float = base - shelf.height * minf(1.0, cap * 2.5) + floorf(tilt * u / 2.0) * 2.0
			for y in range(maxi(0, floori(top)), mini(480, ceili(base + 7))):
				var v := clampf((y - top) / maxf(1, base - top), 0, 1)
				var tint: float = 0.36 + (1.0 - v) * shelf.shade
				var rock := Color(palette.silt_dark).lerp(Color(palette.silt_light), tint).lerp(Color(palette.water_deep), 0.30)
				if y - top < 4: rock = rock.lerp(Color(palette.silt_light), 0.12)
				rock.a = cap * smoothstep(0, 2, y - top) * (1.0 - smoothstep(base, base + 7, y)) * 0.78
				if posmod(y + floori(sin(x * 0.055) * 2), 9) == 0: rock = rock.darkened(0.055)
				image.set_pixel(x, y, image.get_pixel(x, y).blend(rock))
