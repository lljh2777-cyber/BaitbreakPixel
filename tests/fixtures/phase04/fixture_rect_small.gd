extends RefCounted

# Authored test-only 800x360 map. It is deliberately not a MapRegistry entry and
# export_presets excludes tests/. No player selection or generated gameplay map.
const Definition=preload("res://scripts/maps/map_definition.gd")
const SIZE:=Vector2(800,360)
const WATER:=Rect2(42,54,716,268)
const FLOOR:=324.0
const NET_AREA:=Rect2(68,80,664,208)
const SPAWN:=Vector2(88,288)
const HOME:=Vector2(710,300)
const SITES: Array[Vector2]=[Vector2(170,130),Vector2(290,120),Vector2(450,140),Vector2(650,160),Vector2(270,270),Vector2(560,260)]
const FEATURE_IDS: Array[String]=["fixture_wood","fixture_stone","fixture_grass"]
const RECTS: Array[Rect2]=[Rect2(300,170,28,86),Rect2(504,288,35,36),Rect2(610,264,24,60)]

static func create() -> Dictionary:
	var definition: Dictionary={
		"meta":{"id":"fixture_rect_small","revision":1,"contract_version":1,"content_hash":""},
		"bounds":{"size":SIZE,"water":WATER,"floor_y":FLOOR,"net_area":NET_AREA,"vegetation_drag_zones":[RECTS[2]]},
		"anchors":{"player_spawn":SPAWN,"home":HOME},"bait_sites":SITES.duplicate(),
		"interaction_features":[],"visual_features":[],
		"presentation":{"visual_profile_id":"fixture_only","wood_groups":[]},
	}
	for index in FEATURE_IDS.size():
		var rect:=RECTS[index]
		var id:=FEATURE_IDS[index]
		var kind: String=["wood","stone","grass"][index]
		var polygon:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		definition.interaction_features.append({
			"id":id,"kind":kind,"compatibility_index":index,"shape":{"type":"polygon","points":polygon},
			"capabilities":{"fish_passable":true,"net_blocking":index<2,"rope_anchor":true,"contact_fade":true,
				"grass_binding":index==2,"shore_visible":true,"npc_spawn_blocking":index<2,"fish_occluding":index<2},
			"fade_group_id":id,"presentation_ref":id,
		})
		var art: Dictionary={"kind":kind,"seed":index+1,"name":id,"points":Array(polygon)}
		if index==2:
			art={"x":rect.get_center().x,"y":FLOOR,"height":rect.size.y,"width":rect.size.x-6,"kind":"fern","stems":4,"back":false}
		definition.visual_features.append({"id":id,"kind":"plant" if index==2 else "solid","legacy":art})
	definition.meta.content_hash=Definition.content_hash(definition)
	return definition
