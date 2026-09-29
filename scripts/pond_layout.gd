extends RefCounted

# Convex clockwise silhouettes are shared by rendering, fish collision and rope routing.
# Wood pieces may overlap where branches join; floor-connected props have no under-floor route.
const SOLIDS: Array = [
	{"kind":"wood", "seed":1, "points":[Vector2(326,174),Vector2(339,168),Vector2(348,176),Vector2(360,315),Vector2(315,315)]},
	{"kind":"stone", "seed":2, "points":[Vector2(165,313),Vector2(167,303),Vector2(179,293),Vector2(196,291),Vector2(213,300),Vector2(219,313)]},
	{"kind":"stone", "seed":3, "points":[Vector2(433,313),Vector2(437,297),Vector2(451,284),Vector2(469,288),Vector2(481,305),Vector2(478,314)]},
	{"kind":"wood", "seed":4, "points":[Vector2(260,313),Vector2(256,255),Vector2(262,247),Vector2(268,251),Vector2(276,313)]},
	{"kind":"wood", "seed":5, "points":[Vector2(578,313),Vector2(548,245),Vector2(549,235),Vector2(558,234),Vector2(593,313)]},
	{"kind":"wood", "seed":6, "points":[Vector2(120,313),Vector2(112,258),Vector2(116,251),Vector2(123,253),Vector2(135,313)]},
	{"kind":"wood", "seed":7, "points":[Vector2(380,311),Vector2(384,301),Vector2(416,286),Vector2(425,291),Vector2(429,306),Vector2(413,314)]},
	{"kind":"stone", "seed":8, "points":[Vector2(5,315),Vector2(6,292),Vector2(18,282),Vector2(30,293),Vector2(34,313)]},
	{"kind":"stone", "seed":9, "points":[Vector2(221,314),Vector2(226,304),Vector2(239,301),Vector2(247,312)]},
	{"kind":"stone", "seed":10, "points":[Vector2(598,314),Vector2(604,301),Vector2(616,293),Vector2(630,298),Vector2(637,313)]},
	{"kind":"wood", "seed":11, "points":[Vector2(302,213),Vector2(305,207),Vector2(334,225),Vector2(330,235)]},
	{"kind":"wood", "seed":12, "points":[Vector2(343,253),Vector2(368,225),Vector2(374,225),Vector2(373,233),Vector2(351,264)]}
]

# The brightest dense weed patches form soft obstacles, separate from solid wood/stone.
const GRASS: Array[Rect2] = [Rect2(140,253,24,60),Rect2(480,249,22,64),Rect2(598,251,26,62)]
const PLANTS: Array = [
	{"x":17,"height":65,"width":17,"kind":"ribbon","stems":5,"back":true},
	{"x":100,"height":82,"width":26,"kind":"reed","stems":6,"back":true},
	{"x":148,"height":95,"width":35,"kind":"fern","stems":7,"back":true},
	{"x":213,"height":47,"width":29,"kind":"ribbon","stems":6,"back":true},
	{"x":287,"height":68,"width":22,"kind":"reed","stems":4,"back":true},
	{"x":374,"height":82,"width":33,"kind":"ribbon","stems":6,"back":true},
	{"x":472,"height":86,"width":37,"kind":"fern","stems":7,"back":true},
	{"x":571,"height":89,"width":26,"kind":"reed","stems":5,"back":true},
	{"x":622,"height":96,"width":31,"kind":"ribbon","stems":7,"back":true},
	{"x":151,"height":62,"width":24,"kind":"fern","stems":7,"back":false},
	{"x":491,"height":66,"width":22,"kind":"ribbon","stems":7,"back":false},
	{"x":611,"height":64,"width":26,"kind":"fern","stems":7,"back":false},
	{"x":92,"height":23,"width":15,"kind":"ribbon","stems":5,"back":false},
	{"x":248,"height":27,"width":17,"kind":"fern","stems":4,"back":false},
	{"x":288,"height":39,"width":12,"kind":"reed","stems":3,"back":false},
	{"x":357,"height":22,"width":20,"kind":"ribbon","stems":5,"back":false},
	{"x":519,"height":24,"width":21,"kind":"ribbon","stems":5,"back":false},
	{"x":567,"height":19,"width":20,"kind":"fern","stems":4,"back":false}
]

static func nearest_boundary(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var nearest := polygon[0]
	var distance := INF
	for index in polygon.size():
		var candidate := Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])
		var separation := candidate.distance_squared_to(point)
		if separation < distance:
			nearest = candidate
			distance = separation
	return nearest

static func touches(point: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(point,polygon) or nearest_boundary(point,polygon).distance_squared_to(point) < radius*radius
