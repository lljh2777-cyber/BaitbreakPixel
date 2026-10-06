extends "res://tools/watergen/decorative_fauna_layer.gd"
## M02/A art-space habitats only. Not MapContext anchors or new NPC objects.
## Share the existing pixel atlas and explicit-time behavior; only placement differs.
func _init() -> void:
	super()
	residents = [
		{"id": "shrimp-root-foot", "kind": "shrimp", "anchor": Vector2(380, 375), "travel": 6.0, "slope": 0.25, "period": 21.0, "phase": 2.0},
		{"id": "shrimp-channel", "kind": "shrimp", "anchor": Vector2(660, 412), "travel": 7.0, "slope": 0.04, "period": 25.0, "phase": 8.0},
		{"id": "shrimp-right-silt", "kind": "shrimp", "anchor": Vector2(1038, 414), "travel": 6.0, "slope": -0.20, "period": 23.0, "phase": 13.0},
		{"id": "snail-root", "kind": "snail", "anchor": Vector2(278, 169), "travel": 0.0, "slope": 0.0, "period": 16.0, "phase": 1.0},
		{"id": "snail-right-stone", "kind": "snail", "anchor": Vector2(1124, 358), "travel": 0.0, "slope": 0.0, "period": 19.0, "phase": 5.0}
	]
	schools = [
		{"id": "school-beyond-roots", "anchor": Vector2(480, 339), "amplitude": Vector2(12, 3), "period": 31.0, "phase": 0.3, "direction": 1, "offsets": [Vector2(-30, -3), Vector2(-12, -12), Vector2(-7, 6), Vector2(13, -4), Vector2(27, 10)]},
		{"id": "school-distant-stump", "anchor": Vector2(1100, 250), "amplitude": Vector2(11, 3), "period": 37.0, "phase": 2.1, "direction": -1, "offsets": [Vector2(-27, -6), Vector2(-12, 9), Vector2(1, -12), Vector2(14, 1), Vector2(31, 12)]}
	]
