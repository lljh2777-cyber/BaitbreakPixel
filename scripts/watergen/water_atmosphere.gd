extends RefCounted
## WG-2.1 pure composition pass. Named streams do not depend on detail budgets.
const Seed = preload("res://scripts/watergen/water_visual_seed.gd")
const RECIPES := [
	{"id": "fern_garden", "label": "蕨叶庭", "height": 1.08, "hue": 0.0, "leaf": "fern"},
	{"id": "ribbon_cove", "label": "长叶湾", "height": 1.28, "hue": -0.018, "leaf": "ribbon"},
	{"id": "lily_canopy", "label": "浮叶荫", "height": 0.90, "hue": -0.035, "leaf": "fern"},
	{"id": "root_curtain", "label": "垂根岸", "height": 1.02, "hue": 0.024, "leaf": "ribbon"}
]

static func stream(seed: int, kind: String, index := 0) -> RandomNumberGenerator:
	return Seed.stream(seed, "wg-2.1-atmosphere", kind, index)

static func enrich(plan: Dictionary, map: Dictionary, composition: Dictionary) -> void:
	var seed: int = plan.visual_seed
	var recipe: Dictionary = RECIPES[seed % RECIPES.size()]
	var rng := stream(seed, "composition")
	var dominant := -1 if rng.randf() < 0.5 else 1
	var opening := rng.randf_range(390, 560) if dominant > 0 else rng.randf_range(710, 880)
	var left_limit: float = 1280 * composition.open_center_x_fraction[0]
	var right_limit: float = 1280 * composition.open_center_x_fraction[1]
	plan["atmosphere"] = {"recipe": recipe.id, "label": recipe.label, "dominant_side": dominant, "light_opening_x": opening, "layout_version": "wg-2.1", "animated_budget": 18}
	for key in ["water_shallow", "water_deep", "plant_far", "foreground_dark"]:
		var c := Color(plan.palette[key])
		plan.palette[key] = "#" + Color.from_hsv(fposmod(c.h + recipe.hue, 1), c.s, c.v).to_html(false)
	for layer in plan.layers:
		for index in layer.objects.size():
			var object: Dictionary = layer.objects[index]
			var local := stream(seed, layer.name + "/" + object.kind, index)
			if object.kind == "beam":
				# A clustered opening, not regularly spaced identical columns.
				object.x = opening + local.randf_range(-240, 240)
			elif object.kind == "clump":
				var center := 0.0
				for stem in object.stems: center += stem.x
				center /= object.stems.size()
				var side := dominant if index % 3 != 2 else -dominant
				var margin := 30.0 if layer.name == "distance" else -20.0 if layer.name == "terrain" else 90.0
				var x := local.randf_range(18, maxf(18, left_limit - margin)) if side < 0 else local.randf_range(minf(1262, right_limit + margin), 1262)
				object["rich"] = true
				object["tint"] = local.randf_range(0.04, 0.12)
				for stem_index in object.stems.size():
					var stem: Dictionary = object.stems[stem_index]
					stem.x += x - center
					stem.kind = recipe.leaf if stem_index % 3 != 2 else ("ribbon" if recipe.leaf == "fern" else "fern")
					if layer.name == "distance": stem.height = minf(328, stem.height * recipe.height * 1.13)
					elif layer.name == "terrain": stem.height *= 1.25 if recipe.id != "lily_canopy" else 0.95
					stem.lean = absf(stem.lean) * -side * (1.5 if recipe.leaf == "ribbon" else 1.0)
				# Keep public interaction guides quiet, without hard rectangular holes.
				for region in map.protected_regions:
					var r: Array = region.rect_px
					if Rect2(r[0], r[1], r[2], r[3]).grow(24).has_point(Vector2(x, object.stems[0].y - object.stems[0].height * 0.5)): object.contrast = minf(object.contrast, 0.5)
			elif object.kind == "pad":
				var side := dominant if index % 4 != 3 else -dominant
				object.x = local.randf_range(20, maxf(20, left_limit - 16)) if side < 0 else local.randf_range(minf(1260, right_limit + 16), 1260)
				object.width *= 1.4 if recipe.id == "lily_canopy" else 1.08
				object.depth *= 1.25
				object.stem_length = minf(365, object.stem_length * (0.95 if recipe.id == "lily_canopy" else 0.72))
			elif object.kind == "root":
				object.x = local.randf_range(14, 340) if dominant < 0 else local.randf_range(940, 1266)
				object.length *= 1.7 if recipe.id == "root_curtain" else 0.8
				object.width *= 1.6 if recipe.id == "root_curtain" else 1.0
		if layer.name == "floor":
			# Low contrast, leaf-sized material shapes: no food-like golden specks.
			for index in 22:
				var local := stream(seed, "leaf_litter", index)
				layer.objects.append({"id": "floor/leaf_litter/" + str(index), "kind": "leaf_litter", "x": local.randf_range(8, 1272), "y": local.randf_range(441, 474), "width": local.randf_range(7, 16), "lean": local.randf_range(-3, 3), "shade": local.randf_range(0.08, 0.22)})

static func animate(layer: Dictionary, seed: int) -> void:
	var maximum: int = {"distance": 6, "terrain": 8, "foreground": 2, "surface": 2}.get(layer.name, 0)
	var additions: Array = []
	var retained: Array = []
	for object in layer.objects:
		if additions.size() < maximum and object.kind == "clump":
			var stem: Dictionary = object.stems.pop_front()
			var rng := stream(seed, object.id + "/motion")
			additions.append({"id": object.id + "/sway", "kind": "animated_stem", "contrast": object.contrast, "tint": object.tint, "rich": true, "stem": stem, "root_y": stem.y, "height": stem.height, "phase": stem.phase, "amplitude": 4.0 if layer.name == "distance" else 3.0, "omega": rng.randf_range(0.38, 0.72), "growth": -1})
		elif additions.size() < maximum and object.kind == "root":
			var animation: Dictionary = object.duplicate(true)
			animation.kind = "animated_root"
			animation["root_y"] = object.y
			animation["height"] = object.length
			animation["amplitude"] = 3.0
			animation["omega"] = stream(seed, object.id + "/motion").randf_range(0.32, 0.52)
			animation["growth"] = 1
			additions.append(animation)
			continue
		retained.append(object)
	layer.objects = retained + additions
