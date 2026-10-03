extends RefCounted
## Preview samples only. No production View/world is instantiated.
## Public fish/gauge art reused; food facets/colors mirror pond_view.gd at
## 4e8a7b9011b65e53e1971cf3ddcba38880fbd6c8, with fixed, synthetic public offsets.
const Art = preload("res://scripts/pixel_art.gd")
const Gauge = preload("res://scripts/hook_gauge.gd")
const Food = preload("res://scripts/food_profile.gd")
var fish := Art.fish()
var gauge := Gauge.metal_texture()
var bobber := Gauge.bobber_texture()
var font := ThemeDB.fallback_font

func label(view: CanvasItem, p: Vector2, text: String) -> void:
	view.draw_string(font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("102b30"))
	view.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff0cd"))

func draw_samples(view: CanvasItem) -> void:
	# Fixed screen positions make the same samples comparable on every background.
	var mouth := Vector2(247, 180)
	view.draw_colored_polygon(PackedVector2Array([mouth, mouth + Vector2(90, 38), mouth + Vector2(90, -38)]), Color(0.67, 0.94, 0.81, 0.12))
	view.draw_texture(fish, Vector2(224, 174))
	for side in [-1, 0, 1]: view.draw_rect(Rect2(mouth + Vector2(3, side * 2), Vector2.ONE), Color("ffd379"))
	label(view, Vector2(221, 165), "fish / intake / cone")
	view.draw_polyline(PackedVector2Array([Vector2(490, 72), Vector2(483, 104), Vector2(480, 156), Vector2(477, 216)]), Color(0.85, 0.91, 0.85, 0.7), 1)
	label(view, Vector2(496, 92), "1 px line")
	var kinds := ["cluster", "worm", "chunk"]
	var positions := [Vector2(318, 145), Vector2(390, 188), Vector2(477, 216)]
	for kind_index in 3:
		var kind: String = kinds[kind_index]
		var center: Vector2 = positions[kind_index]
		for index in 30:
			var layer := index / 10
			var legacy := Vector2(cos(index * 2.4), sin(index * 2.4)) * (3 + layer * 3)
			var offset := Food.grain_offset(kind, legacy, index, 30, layer)
			var shade := clampf(0.48 - (offset.x + offset.y) / 22.0, 0, 1)
			var color := Color("a26c3f").lerp(Color("f1d798"), shade)
			if kind == "worm": color = Color("986137").lerp(Color("d6b375"), shade)
			elif kind == "chunk": color = Color("aa7137").lerp(Color("efd091"), shade)
			if index % 3 == 0: color = color.lightened(0.13)
			var point := (center + offset).round()
			var size := Vector2(2, 2) if layer < 2 else Vector2.ONE
			if kind == "worm": size = Vector2(2, 2) if layer < 2 else Vector2(2, 1)
			elif kind == "chunk": size = Vector2(3, 2) if layer < 2 else Vector2(2, 2)
			view.draw_rect(Rect2(point, size), color.darkened(0.18))
			view.draw_rect(Rect2(point, Vector2(1 if kind == "worm" or (kind == "cluster" and index % 2 == 0) else 2, 1)), color)
		label(view, center + Vector2(-18, -22), kind)
	for index in 18:
		var point := Vector2(291 + index * 5, 259 + posmod(index * 17, 13))
		var size: Vector2 = [Vector2.ONE, Vector2(2, 1), Vector2(2, 2)][index % 3]
		view.draw_rect(Rect2(point, size), Color(["cfab75", "c49c64", "d6b579"][index % 3]).lightened(0.15))
	label(view, Vector2(290, 250), "old mixed loose grains")
	var origin := Vector2(10, 122)
	view.draw_rect(Rect2(origin, Vector2(176, 200)), Color("103e57"))
	view.draw_texture(gauge, origin + Vector2(0, -12))
	var zone := Gauge.section(0.4, 0.57)
	for index in zone.size(): zone[index] += origin + Vector2(0, -12)
	view.draw_polyline(zone, Color("082818"), 10)
	view.draw_polyline(zone, Color("157432"), 8)
	view.draw_polyline(zone, Color("63ed4d"), 5)
	view.draw_texture(bobber, origin + Vector2(0, -12) + Gauge.point(0.49) - Vector2(8, 8))
	label(view, origin + Vector2(12, 19), "QTE - public art sample")
	label(view, origin + Vector2(12, 185), "Static fixture / no game state")
