extends RefCounted

# Versioned Authority constraints; changing these requires a generator version.
const SIZE := Vector2(1280,480)
const WATER := Rect2(8,68,1264,363)
const FLOOR := 433
const NET_AREA := Rect2(30,85,1220,315)
const HOME := Vector2(60,401)
const SPAWN := Vector2(66,385)
const BAIT_COUNT := 6
const BAIT_SPACING := 120
const BAIT_CLEARANCE := 42
const HOME_CLEARANCE := 70
const SPAWN_CLEARANCE := 56
const WOOD_GROUP_RANGE := Vector2i(2,3)
const STONE_RANGE := Vector2i(3,5)
const GRASS_RANGE := Vector2i(5,8)
const MAX_FEATURES := 19
const MAX_ATTEMPTS := 32
const CENTER_OPEN := Rect2(140,145,1040,100)
const NET_SAFE := Rect2(125,95,180,160)
# Fixed spatial slots, sampled within each zone rather than uniform scatter.
const ZONES := [Rect2i(180,275,180,158),Rect2i(380,275,180,158),Rect2i(580,275,180,158),
	Rect2i(780,275,180,158),Rect2i(980,275,180,158)]

static func protected_regions(bait_sites: Array) -> Array[Rect2]:
	var result: Array[Rect2]=[CENTER_OPEN,NET_SAFE,
		Rect2(HOME-Vector2.ONE*HOME_CLEARANCE,Vector2.ONE*HOME_CLEARANCE*2),
		Rect2(SPAWN-Vector2.ONE*SPAWN_CLEARANCE,Vector2.ONE*SPAWN_CLEARANCE*2)]
	for point: Vector2 in bait_sites: result.append(Rect2(point-Vector2.ONE*BAIT_CLEARANCE,Vector2.ONE*BAIT_CLEARANCE*2))
	return result
