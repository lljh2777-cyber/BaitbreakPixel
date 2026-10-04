extends RefCounted

# Built-in contract-v1 data copied value-for-value from frozen 0.25.5 pond_v2.
# Independent of the legacy facade: no runtime consumer is migrated in P4.1.
const Definition = preload("res://scripts/maps/map_definition.gd")

const SIZE := Vector2(1280,480)
const FLOOR := 433.0
const HOME := Vector2(60,401)
const SPAWN := Vector2(66,385)
const WATER := Rect2(8,68,1264,363)
const NET_AREA := Rect2(30,85,1220,315)
const BAIT_SITES: Array[Vector2] = [Vector2(220,170),Vector2(450,230),Vector2(680,175),Vector2(880,255),Vector2(1070,190),Vector2(1160,315)]

# Connected wood shares display opacity, while every part keeps its own geometry.
const WOOD_GROUPS: Array = [[1,4,5,6,11,12],[7,15],[17,18]]

# Root snag / fallen timber / stone shoal / reed margin, with open water between.
# Fish pass through cover; the same silhouettes stop the net and anchor coils.
const SOLIDS: Array = [
	{"kind":"wood","seed":1,"name":"枯木","points":[Vector2(326,174),Vector2(339,168),Vector2(348,176),Vector2(350,239),Vector2(365,317),Vector2(385,396),Vector2(379,433),Vector2(329,433),Vector2(322,378),Vector2(326,301),Vector2(321,237)]},
	{"kind":"stone","seed":2,"points":[Vector2(163,433),Vector2(169,416),Vector2(188,404),Vector2(210,408),Vector2(227,421),Vector2(231,433)]},
	{"kind":"stone","seed":3,"points":[Vector2(696,433),Vector2(689,410),Vector2(703,382),Vector2(731,367),Vector2(754,375),Vector2(771,407),Vector2(767,433)]},
	{"kind":"wood","seed":4,"points":[Vector2(335,318),Vector2(286,267),Vector2(270,255),Vector2(263,245),Vector2(268,242),Vector2(291,253),Vector2(347,299)]},
	{"kind":"wood","seed":5,"points":[Vector2(350,271),Vector2(391,231),Vector2(409,218),Vector2(418,220),Vector2(410,232),Vector2(360,290)]},
	{"kind":"wood","seed":6,"points":[Vector2(344,432),Vector2(314,405),Vector2(279,405),Vector2(255,426),Vector2(244,431),Vector2(253,410),Vector2(278,393),Vector2(319,392),Vector2(365,433)]},
	{"kind":"wood","seed":7,"name":"倒木","points":[Vector2(480,430),Vector2(487,412),Vector2(508,402),Vector2(636,358),Vector2(657,363),Vector2(667,378),Vector2(648,393),Vector2(523,430)]},
	{"kind":"stone","seed":8,"points":[Vector2(6,433),Vector2(8,413),Vector2(25,401),Vector2(45,410),Vector2(51,433)]},
	{"kind":"stone","seed":9,"points":[Vector2(755,430),Vector2(764,413),Vector2(784,405),Vector2(806,414),Vector2(815,433)]},
	{"kind":"stone","seed":10,"points":[Vector2(830,433),Vector2(821,407),Vector2(832,382),Vector2(854,371),Vector2(879,379),Vector2(893,407),Vector2(889,433)]},
	{"kind":"wood","seed":11,"points":[Vector2(302,213),Vector2(305,207),Vector2(334,225),Vector2(330,235)]},
	{"kind":"wood","seed":12,"points":[Vector2(343,253),Vector2(368,225),Vector2(374,225),Vector2(373,233),Vector2(351,264)]},
	{"kind":"stone","seed":13,"points":[Vector2(778,413),Vector2(783,395),Vector2(798,385),Vector2(817,391),Vector2(823,407),Vector2(816,417)]},
	{"kind":"stone","seed":14,"points":[Vector2(874,433),Vector2(892,420),Vector2(920,419),Vector2(936,431)]},
	{"kind":"wood","seed":15,"name":"断枝","points":[Vector2(602,382),Vector2(583,345),Vector2(580,314),Vector2(585,310),Vector2(591,335),Vector2(617,375)]},
	{"kind":"stone","seed":16,"points":[Vector2(1040,433),Vector2(1049,422),Vector2(1068,419),Vector2(1085,425),Vector2(1090,433)]},
	{"kind":"wood","seed":17,"points":[Vector2(1192,433),Vector2(1211,391),Vector2(1217,363),Vector2(1226,359),Vector2(1230,367),Vector2(1227,400),Vector2(1210,433)]},
	{"kind":"wood","seed":18,"points":[Vector2(1214,409),Vector2(1186,390),Vector2(1170,365),Vector2(1174,360),Vector2(1194,379),Vector2(1221,391)]}
]

const GRASS: Array[Rect2] = [Rect2(135,363,30,70),Rect2(951,346,34,87),Rect2(1118,337,42,96)]
const PLANTS: Array = [
	{"x":100,"y":433,"height":75,"width":24,"kind":"ribbon","stems":5,"back":true},
	{"x":150,"y":433,"height":70,"width":30,"kind":"fern","stems":6,"back":false},
	{"x":244,"y":433,"height":31,"width":19,"kind":"ribbon","stems":4,"back":false},
	{"x":287,"y":433,"height":46,"width":18,"kind":"fern","stems":4,"back":true},
	{"x":377,"y":433,"height":49,"width":27,"kind":"ribbon","stems":5,"back":true},
	{"x":414,"y":433,"height":32,"width":17,"kind":"fern","stems":4,"back":false},
	{"x":521,"y":411,"height":25,"width":20,"kind":"fern","stems":4,"back":false},
	{"x":618,"y":375,"height":28,"width":16,"kind":"ribbon","stems":4,"back":true},
	{"x":674,"y":433,"height":43,"width":21,"kind":"ribbon","stems":5,"back":false},
	{"x":739,"y":379,"height":25,"width":14,"kind":"fern","stems":3,"back":true},
	{"x":809,"y":433,"height":28,"width":16,"kind":"fern","stems":3,"back":false},
	{"x":856,"y":382,"height":20,"width":15,"kind":"ribbon","stems":3,"back":false},
	{"x":910,"y":433,"height":55,"width":28,"kind":"fern","stems":6,"back":true},
	{"x":950,"y":433,"height":108,"width":32,"kind":"ribbon","stems":6,"back":true},
	{"x":967,"y":433,"height":87,"width":34,"kind":"fern","stems":7,"back":false},
	{"x":1001,"y":433,"height":69,"width":25,"kind":"ribbon","stems":5,"back":true},
	{"x":1050,"y":433,"height":46,"width":26,"kind":"fern","stems":5,"back":false},
	{"x":1104,"y":433,"height":103,"width":32,"kind":"ribbon","stems":6,"back":true},
	{"x":1138,"y":433,"height":96,"width":42,"kind":"fern","stems":8,"back":false},
	{"x":1182,"y":433,"height":74,"width":26,"kind":"ribbon","stems":5,"back":true},
	{"x":1238,"y":433,"height":115,"width":29,"kind":"ribbon","stems":6,"back":true},
	{"x":1254,"y":433,"height":55,"width":23,"kind":"fern","stems":5,"back":false}
]

# Stable semantic identities are authored explicitly, never generated from an index.
const SOLID_IDS: Array[String] = [
	"wood_root_trunk", "stone_west_shoal", "stone_mid_shoal", "wood_root_left_branch",
	"wood_root_right_branch", "wood_root_base", "wood_fallen_log", "stone_home_bank",
	"stone_mid_low", "stone_east_shoal", "wood_root_upper_twig", "wood_root_lower_twig",
	"stone_mid_peak", "stone_east_low", "wood_fallen_branch", "stone_reed_bank",
	"wood_far_trunk", "wood_far_branch",
]
const PLANT_IDS: Array[String] = [
	"grass_home_ribbon", "grass_west_fern", "grass_west_ribbon", "grass_root_left_fern",
	"grass_root_right_ribbon", "grass_root_edge_fern", "grass_log_left_fern", "grass_log_top_ribbon",
	"grass_mid_ribbon", "grass_mid_peak_fern", "grass_mid_edge_fern", "grass_east_peak_ribbon",
	"grass_east_fern", "grass_reed_west_ribbon", "grass_reed_west_fern", "grass_reed_mid_ribbon",
	"grass_reed_bank_fern", "grass_reed_east_ribbon", "grass_reed_east_fern", "grass_far_ribbon",
	"grass_far_bank_ribbon", "grass_far_bank_fern",
]
# Existing connected-wood parent indexes. They are compatibility ordering, not identity.
const FADE_PARENTS: Array[int] = [0,1,2,0,0,0,6,7,8,9,0,0,12,13,6,15,16,16]

static func create() -> Dictionary:
	var features: Array[Dictionary] = []
	var visuals: Array[Dictionary] = []
	for index in SOLIDS.size():
		var solid: Dictionary = SOLIDS[index]
		var identity: String = SOLID_IDS[index]
		features.append(_feature(identity,solid.kind,PackedVector2Array(solid.points),index,SOLID_IDS[FADE_PARENTS[index]]))
		visuals.append({"id":identity,"kind":"solid","legacy":solid.duplicate(true)})
	for index in PLANTS.size():
		var plant: Dictionary = PLANTS[index]
		var bounds := Rect2(plant.x-plant.width*0.5-3,plant.y-plant.height,plant.width+6,plant.height)
		var polygon := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
		var identity: String = PLANT_IDS[index]
		features.append(_feature(identity,"grass",polygon,SOLIDS.size()+index,identity))
		visuals.append({"id":identity,"kind":"plant","legacy":plant.duplicate(true)})
	var result := {
		"meta":{"id":"pond_v2","revision":1,"contract_version":Definition.CONTRACT_VERSION,"content_hash":""},
		"bounds":{"size":SIZE,"water":WATER,"floor_y":FLOOR,"net_area":NET_AREA,"vegetation_drag_zones":GRASS.duplicate()},
		"anchors":{"player_spawn":SPAWN,"home":HOME},
		"bait_sites":BAIT_SITES.duplicate(),
		"interaction_features":features,
		"visual_features":visuals,
		"presentation":{"visual_profile_id":"legacy_pond","wood_groups":WOOD_GROUPS.duplicate(true)},
	}
	result.meta.content_hash = Definition.content_hash(result)
	return result

static func _feature(identity: String, kind: String, points: PackedVector2Array, index: int, fade_id: String) -> Dictionary:
	var solid := kind != "grass"
	return {
		"id":identity,"kind":kind,"compatibility_index":index,
		"shape":{"type":"polygon","points":points},
		"capabilities":{
			"fish_passable":true,"net_blocking":solid,"rope_anchor":true,
			"contact_fade":true,"grass_binding":not solid,"shore_visible":true,
			"npc_spawn_blocking":solid,"fish_occluding":solid,
		},
		"fade_group_id":fade_id,"presentation_ref":identity,
	}
