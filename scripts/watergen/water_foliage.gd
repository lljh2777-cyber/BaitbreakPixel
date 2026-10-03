extends RefCounted
## Pixel silhouettes with grouped leaf masses. Shares the existing line kernel.
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Base = preload("res://scripts/watergen/water_visual_baker.gd")

static func clump(image: Image, object: Dictionary, layer: String, palette: Dictionary) -> void:
	var base := Color(palette.plant_far).lerp(Color(palette.haze_light), object.get("tint", 0.08))
	if layer == "distance": base = base.lerp(Color(palette.water_shallow), 0.30)
	elif layer == "terrain": base = base.lerp(Color(palette.silt_light), 0.13)
	elif layer == "foreground": base = Color(palette.foreground_dark)
	base.a = object.contrast * (0.68 if layer == "distance" else 0.84)
	var shade := base.darkened(0.12)
	var light := base.lerp(Color(palette.haze_light), 0.09)
	light.a = base.a
	for stem in object.stems:
		var root := Base._stem_point(stem, 0)
		if stem.kind == "ribbon":
			# Long tapered blades: two sides form one mass, not many floating strokes.
			for fan in [-1, 0, 1]:
				var previous := root
				var previous_width := 0.0
				for index in range(1, 17):
					var t := index / 16.0
					var p := Base._stem_point(stem, t) + Vector2(fan * sin(t * PI * 0.7) * 14, absf(fan) * t * 9)
					var width: float = sin(t * PI) * (3.0 if layer == "distance" else 2.5)
					Raster.polygon(image, PackedVector2Array([previous + Vector2(previous_width, 0), p + Vector2(width, 0), p - Vector2(width, 0), previous - Vector2(previous_width, 0)]), base if fan == 0 else shade)
					previous = p
					previous_width = width
		else:
			var previous := root
			for index in range(1, 19):
				var t := index / 18.0
				var p := Base._stem_point(stem, t)
				Raster.line(image, previous, p, shade)
				previous = p
				if index < 3 or index > 16: continue
				for side in [-1, 1]:
					var length: float = minf(23, stem.height * 0.22) * pow(sin(t * PI), 0.7) * (0.85 + sin(index + stem.phase) * 0.12)
					var tip := p + Vector2(side * length, -length * 0.65)
					Raster.polygon(image, PackedVector2Array([p + Vector2(0, 2), p + Vector2(side * length * 0.7, 0), tip, p + Vector2(side * length * 0.25, -4)]), light if index % 4 == 0 else base)
					if layer != "distance": Raster.line(image, p, tip, shade)

static func canopy(image: Image, object: Dictionary, layer: String, palette: Dictionary) -> void:
	var near := layer == "foreground"
	var base := Color(palette.foreground_dark) if near else Color(palette.plant_far).lerp(Color(palette.water_shallow), 0.44)
	base.a = object.contrast
	var shade := base.darkened(0.10)
	var light := base.lerp(Color(palette.haze_light), 0.05)
	light.a = base.a
	# Snap local geometry before translation so atlas crops and full layers
	# rasterize identically at pixel boundaries, regardless of world position.
	var root := Vector2(object.x, object.y).round()
	for fan in [-1, 0, 1]:
		var previous := root + Vector2(fan * 8, 0)
		var reach: float = 0.80 + 0.20 * sin(object.phase + fan * 1.9)
		for index in range(1, 19):
			var t := index / 18.0
			var p := root + Vector2(fan * (8 + object.width * sin(t * 2.1) * t * 0.8) + object.lean * t * t + sin(t * 4 + object.phase + fan) * t * 14, object.length * t * reach).round()
			Raster.line(image, previous, p, shade)
			previous = p
			# Alternate attachments and stagger branches, avoiding a repeated lattice.
			if index < 3 or index > 15 or (index + fan) % 2 == 0: continue
			var side := -1 if (index / 2 + fan) % 2 == 0 else 1
			var length: float = (31 if near else 25) * pow(sin(t * PI), 0.65) * (0.9 + sin(index + object.phase) * 0.12)
			var delta := Vector2(side * length, length * (1.35 if object.leaf == "ribbon" else 0.50))
			var normal := Vector2(-delta.y, delta.x).normalized()
			var width: float = length * (0.32 if object.leaf == "broad" else 0.10 if object.leaf == "ribbon" else 0.19)
			Raster.polygon(image, PackedVector2Array([p, p + (delta * 0.32 + normal * width).round(), p + (delta * 0.70 + normal * width * 0.85).round(), p + delta.round(), p + (delta * 0.58 - normal * width).round(), p + (delta * 0.20 - normal * width * 0.6).round()]), light if index % 3 == 0 else base)
			if near: Raster.line(image, p, p + (delta * 0.8).round(), shade)

static func litter(image: Image, object: Dictionary, palette: Dictionary) -> void:
	var p := Vector2(object.x, object.y)
	var w: float = object.width
	var tip := p + Vector2(w, object.lean)
	var base := Color(palette.silt_dark).lerp(Color(palette.plant_far), object.shade)
	Raster.polygon(image, PackedVector2Array([p, p + Vector2(w * 0.5, -2), tip, p + Vector2(w * 0.5, 2)]), base)
	Raster.line(image, p + Vector2(1, 0), tip, base.lightened(0.045))
