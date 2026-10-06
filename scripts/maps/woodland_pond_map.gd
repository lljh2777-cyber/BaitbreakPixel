extends RefCounted
## Authored fixed map aligned to the Watergen A art plate, not a generation recipe.
const Definition=preload("res://scripts/maps/map_definition.gd")
const Legacy=preload("res://scripts/maps/pond_v2_map.gd")
const ID:="woodland_pond"
const PROFILE:="woodland_pond_art"
const BED:=[[0,264],[60,279],[120,308],[200,342],[300,361],[390,386],[470,399],[550,419],[650,435],[750,449],[850,446],[950,432],[1030,410],[1110,390],[1185,363],[1280,325]]
const SOLIDS:=[
	{"id":"wood_main","kind":"wood","name":"沟谷倒木","group":"wood_main","points":[[246,262],[385,297],[474,310],[473,350],[369,335],[274,311],[247,310]]},
	{"id":"wood_middle","kind":"wood","group":"wood_main","points":[[471,309],[593,334],[676,345],[674,382],[569,369],[471,350]]},
	{"id":"wood_east","kind":"wood","group":"wood_main","points":[[674,345],[789,365],[894,383],[894,410],[784,399],[674,382]]},
	{"id":"wood_tip","kind":"wood","group":"wood_main","points":[[891,383],[984,398],[990,405],[966,421],[891,410]]},
	{"id":"wood_stump","kind":"wood","group":"wood_main","points":[[181,325],[196,301],[198,263],[205,236],[218,235],[230,218],[241,228],[248,262],[250,310],[269,342],[247,351],[222,339],[204,352],[188,348]]},
	{"id":"wood_upper_branch","kind":"wood","group":"wood_main","points":[[688,349],[706,339],[727,323],[736,322],[737,329],[716,360],[706,365]]},
	{"id":"wood_lower_branch","kind":"wood","group":"wood_main","points":[[781,393],[792,395],[802,432],[795,437],[787,417]]},
	{"id":"stone_center","kind":"stone","points":[[348,373],[360,353],[392,337],[421,334],[443,351],[458,384],[425,389],[374,382]]},
	{"id":"stone_east","kind":"stone","points":[[1017,377],[1034,334],[1069,309],[1115,285],[1145,288],[1171,315],[1175,358],[1147,381],[1094,400],[1046,396]]},
	{"id":"stone_west_edge","kind":"stone","points":[[0,195],[21,194],[38,204],[51,232],[57,265],[30,270],[0,259]]}
]
# These masks are visual silhouettes including attached moss. They are deliberately
# separate from the authoritative contact polygons above; they cannot create targets.
const WOOD_SKIN:=[[160,352],[176,304],[188,250],[200,214],[221,207],[244,205],[258,250],[285,242],[350,252],[385,245],[420,248],[445,268],[460,270],[490,268],[520,285],[565,285],[612,310],[665,307],[700,315],[725,306],[744,306],[755,328],[751,336],[800,346],[855,352],[910,366],[952,375],[991,382],[1004,411],[975,435],[811,421],[811,447],[784,447],[777,417],[672,402],[558,389],[470,371],[386,359],[312,348],[273,337],[278,364],[232,372],[212,358],[195,368],[173,363]]
const STONE_SKINS:={
	"stone_center":[[342,376],[351,350],[389,331],[425,331],[447,347],[465,387],[427,396],[370,387]],
	"stone_east":[[993,388],[1017,345],[1059,311],[1083,292],[1118,279],[1149,282],[1179,310],[1183,363],[1151,388],[1095,410],[1038,405]],
	"stone_west_edge":[[0,190],[25,190],[45,200],[58,230],[65,268],[35,277],[0,269]]
}
const GRASSES:=[
	{"id":"grass_west","x":105,"y":279,"width":56,"height":144,"stems":7,"kind":"ribbon","back":false,"points":[[61,181],[78,153],[104,136],[132,160],[147,206],[142,251],[125,280],[85,280]],"skin":[[0,113],[24,102],[52,102],[77,108],[94,91],[115,98],[150,136],[173,152],[170,191],[147,222],[160,224],[151,270],[134,292],[74,290],[51,261],[39,210]]},
	{"id":"grass_east","x":1238,"y":334,"width":52,"height":145,"stems":7,"kind":"ribbon","back":false,"points":[[1206,239],[1218,197],[1244,178],[1271,203],[1279,254],[1279,326],[1258,341],[1223,340]],"skin":[[1188,226],[1206,210],[1207,181],[1230,153],[1251,148],[1262,165],[1280,155],[1280,354],[1245,361],[1203,343],[1192,300]]}
]

static func polygon(values: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p: Array in values: result.append(Vector2(p[0],p[1]))
	return result

static func create() -> Dictionary:
	var features: Array[Dictionary]=[]; var visuals: Array[Dictionary]=[]
	var wood_seeds: Array=[]
	for spec: Dictionary in SOLIDS:
		var index:=features.size(); var shape:=Geometry2D.convex_hull(polygon(spec.points))
		if shape[0]==shape[-1]: shape.resize(shape.size()-1)
		features.append(Legacy._feature(spec.id,spec.kind,shape,index,spec.get("group",spec.id)))
		var skin: Array=WOOD_SKIN if spec.id=="wood_main" else STONE_SKINS.get(spec.id,[])
		visuals.append({"id":spec.id,"kind":"solid","legacy":{"kind":spec.kind,"name":spec.get("name","木枝" if spec.kind=="wood" else "石头"),"seed":index+1,"skin_polygon":polygon(skin)}})
		if spec.kind=="wood": wood_seeds.append(index+1)
	for spec: Dictionary in GRASSES:
		features.append(Legacy._feature(spec.id,"grass",polygon(spec.points),features.size(),spec.id))
		var visual: Dictionary=spec.duplicate(true); visual.erase("id"); visual.erase("points"); visual.erase("skin")
		visual["skin_polygon"]=polygon(spec.skin)
		visuals.append({"id":spec.id,"kind":"plant","legacy":visual})
	var result: Dictionary={
		"meta":{"id":ID,"revision":1,"contract_version":2,"content_hash":""},
		"bounds":{"size":Vector2(1280,480),"water":Rect2(8,34,1264,427),"floor_y":464.0,"floor_profile":polygon(BED),"net_area":Rect2(30,48,1220,394),"vegetation_drag_zones":[Rect2(77,238,55,45),Rect2(1212,293,59,45)]},
		"anchors":{"player_spawn":Vector2(560,260),"home":Vector2(545,395)},
		"bait_sites":[Vector2(310,175),Vector2(500,235),Vector2(700,155),Vector2(890,245),Vector2(1040,200),Vector2(800,310)],
		"interaction_features":features,"visual_features":visuals,
		"presentation":{"visual_profile_id":PROFILE,"wood_groups":[wood_seeds]}}
	result.meta.content_hash=Definition.content_hash(result)
	return result
