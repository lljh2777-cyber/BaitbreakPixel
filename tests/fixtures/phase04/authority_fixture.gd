extends RefCounted

# Test-only authored map, intentionally absent from MapRegistry and export presets.
# All spatial values differ from pond_v2. Capabilities deliberately cross kinds:
# wood does not block nets, grass does, and spawn/occlusion/fade/rope are independent.
# fish_passable=false is a future gameplay extension, not P4.2 collision behavior.
const Definition = preload("res://scripts/maps/map_definition.gd")
const SIZE := Vector2(800, 380)
const WATER := Rect2(110, 92, 650, 258)
const FLOOR := 354.0
const NET_AREA := Rect2(145, 120, 555, 200)
const SPAWN := Vector2(145, 310)
const HOME := Vector2(715, 320)
const SITES := [Vector2(190, 160), Vector2(340, 170), Vector2(490, 140), Vector2(640, 165), Vector2(370, 290), Vector2(620, 280)]
const RECTS := [Rect2(260, 210, 30, 45), Rect2(430, 210, 30, 45), Rect2(540, 210, 30, 45), Rect2(650, 210, 25, 45), Rect2(750, 338, 40, 32)]
const KINDS := ["wood", "grass", "stone", "grass", "stone"]
const IDS := ["unfaded_anchor", "grass_net", "spawn_only", "grass_occluder", "edge_anchor"]

static func create() -> Dictionary:
	var result := {
		"meta":{"id":"authority_fixture", "revision":1, "contract_version":1, "content_hash":""},
		"bounds":{"size":SIZE, "water":WATER, "floor_y":FLOOR, "net_area":NET_AREA, "vegetation_drag_zones":[Rect2(200, 280, 30, 50)]},
		"anchors":{"player_spawn":SPAWN, "home":HOME},
		"bait_sites":SITES.duplicate(), "interaction_features":[], "visual_features":[],
		"presentation":{"visual_profile_id":"test_only_unrelated_art", "wood_groups":[]},
	}
	for index in RECTS.size():
		var rect: Rect2 = RECTS[index]
		var id: String = IDS[index]
		result.interaction_features.append({
			"id":id, "kind":KINDS[index], "compatibility_index":index,
			"shape":{"type":"polygon", "points":PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])},
			"capabilities":{"fish_passable":true, "net_blocking":index == 1, "rope_anchor":index in [0, 3, 4], "contact_fade":index in [1, 3, 4], "grass_binding":false, "shore_visible":false, "npc_spawn_blocking":index == 2, "fish_occluding":index == 3},
			"fade_group_id":id, "presentation_ref":"visual_%d" % index,
		})
		# Metadata intentionally has no gameplay polygon, plant location or seed.
		result.visual_features.append({"id":"visual_%d" % index, "kind":"plant" if index % 2 == 0 else "solid", "legacy":{"name":"fixture artwork %d" % index, "visual_seed":9000 + index}})
	seal(result)
	return result

static func seal(value: Dictionary) -> void:
	value.meta.content_hash = Definition.content_hash(value)
