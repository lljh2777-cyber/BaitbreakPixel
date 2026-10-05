extends RefCounted
## Small CPU patches, one shared GPU atlas after preparation. No per-frame images.
const Plan = preload("res://scripts/watergen/water_ecology_plan.gd")
const Raster = preload("res://scripts/watergen/water_raster.gd")
const Atlas = preload("res://scripts/watergen/water_dynamic_baker.gd")

static func bake(plan: Dictionary) -> Dictionary:
	if plan.get("version") != Plan.VERSION or plan.get("world_size_px") != [1280, 480] or plan.get("patches", []).size() > Plan.MAX_PATCHES:
		return {"ok": false, "code": "FLORA_PLAN"}
	var patches: Array = []
	for patch: Dictionary in plan.patches:
		var box := Plan.footprint(patch)
		var origin := Vector2(floorf(box.position.x), floorf(box.position.y))
		var image := Image.create(ceili(box.size.x) + 1, ceili(box.size.y) + 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		_paint(image, patch, origin)
		var animated: bool = patch.kind in ["broad_leaf", "low_grass", "filament_algae", "branch_algae"]
		patches.append({"id": patch.id, "kind": patch.kind, "anchor_target": patch.anchor_target, "image": image, "origin_px": [origin.x, origin.y], "root_y": patch.root_px[1], "height": patch.height, "growth": patch.growth, "phase": patch.phase, "amplitude": 1.6 if animated else 0.0, "omega": 0.52 if patch.kind == "filament_algae" else 0.38, "layer": "bed" if patch.kind == "carpet_algae" else "plants"})
	var atlas := Atlas._atlas(patches)
	if atlas.get_height() > 2048: return {"ok": false, "code": "FLORA_ATLAS_BUDGET"}
	for patch: Dictionary in patches: patch.erase("image")
	return {"ok": true, "image": atlas, "patches": patches}

static func _paint(image: Image, patch: Dictionary, origin: Vector2) -> void:
	var root := Vector2(patch.root_px[0], patch.root_px[1]) - origin
	var rng := Plan.stream(patch.seed, "paint/" + patch.kind, 0)
	var muted: bool = patch.density == "low"
	var stem := Color("31685e")
	var leaf := Color("4c826c")
	var light := Color("73a18a")
	stem.a = 0.72 if not muted else 0.54
	leaf.a = 0.79 if not muted else 0.59
	light.a = 0.64 if not muted else 0.50
	if patch.kind in ["moss_patch", "carpet_algae"]:
		_mat(image, patch, origin, rng)
		return
	var count: int = {"filament_algae": 7, "low_grass": 9, "broad_leaf": 5, "branch_algae": 5}[patch.kind]
	for index in count:
		var spread := 0.15 if patch.kind == "broad_leaf" else 0.24
		var start := root + Vector2(rng.randf_range(-patch.width * spread, patch.width * spread), 0)
		var height: float = patch.height * rng.randf_range(0.57, 1.0)
		var lean := rng.randf_range(-patch.width * 0.21, patch.width * 0.21)
		var points := PackedVector2Array([start])
		for step in range(1, 13):
			var t := step / 12.0
			var wave := sin(t * 6.0 + index * 2.0) * t * (2.8 if patch.kind == "filament_algae" else 1.0)
			points.append(start + Vector2(lean * t * t + wave, patch.growth * height * t))
		for step in range(1, points.size()):
			Raster.line(image, points[step - 1], points[step], stem if index % 2 else leaf)
			if patch.kind == "low_grass" and step < 8: Raster.line(image, points[step - 1] + Vector2.RIGHT, points[step] + Vector2.RIGHT, stem)
		match patch.kind:
			"broad_leaf":
				for level in [5, 9]:
					for side in [-1, 1]:
						var p := points[level]
						var tip := p + Vector2(side * rng.randf_range(6, 10), -rng.randf_range(7, 12))
						var mid := p.lerp(tip, 0.5)
						Raster.polygon(image, PackedVector2Array([p, mid + Vector2(side * 5, 3), tip, mid + Vector2(-side * 3, -4)]), leaf)
						Raster.line(image, p, tip, light if side > 0 else stem)
			"branch_algae":
				for level in [4, 7, 10]:
					var p := points[level]
					for side in [-1, 1]:
						Raster.line(image, p, p + Vector2(side * (5 - level * 0.25), -3), leaf)
			"filament_algae":
				for level in [5, 9]:
					var p := points[level]
					Raster.line(image, p, p + Vector2(3 * sin(index), patch.growth * 3), light)

static func _mat(image: Image, patch: Dictionary, origin: Vector2, rng: RandomNumberGenerator) -> void:
	var root := Vector2(patch.root_px[0], patch.root_px[1]) - origin
	var moss: bool = patch.kind == "moss_patch"
	var polygon := PackedVector2Array()
	for point: Array in patch.clip_polygon_px: polygon.append(Vector2(point[0], point[1]))
	for y in image.get_height():
		for x in image.get_width():
			var dx: float = (x - root.x) / (patch.width * 0.5)
			var dy: float = (y - root.y - patch.height * 0.35) / (patch.height * 0.65)
			var noise := rng.randf()
			if dx * dx + dy * dy > 0.80 + noise * 0.28: continue
			if moss and not Geometry2D.is_point_in_polygon(Vector2(x, y) + origin, polygon): continue
			var color := Color("35594f").lerp(Color("729176"), 0.22 + noise * 0.48)
			color.a = (0.58 if moss else 0.64) * (0.80 if patch.density == "low" else 1.0)
			image.set_pixel(x, y, color)
	if not moss:
		for index in 18:
			var x := root.x + rng.randf_range(-patch.width * 0.4, patch.width * 0.4)
			var p := Vector2(x, root.y + rng.randf_range(0, 2))
			Raster.line(image, p, p + Vector2(rng.randf_range(-2, 2), -rng.randf_range(2, 5)), Color(0.28, 0.46, 0.36, 0.64))
