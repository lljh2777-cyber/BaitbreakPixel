extends RefCounted

# Presentation only. Input uses this same transform, including the remote display world.
const VIEW_SIZE := Vector2(640,360)

static func offset(world: Node2D, role: String) -> Vector2:
	var focus: Vector2 = world.fish if role=="fish" else Vector2(world.angler.anchor().x,210)
	var desired := focus-Vector2(320,193)
	# Observation follows the fishing position, never the hidden opponent.
	if role=="angler": desired.y=clampf(world.angler.free_line_length-180,0,maxf(0,world.map_context.size.y-VIEW_SIZE.y))
	return desired.clamp(Vector2.ZERO,(world.map_context.size-VIEW_SIZE).max(Vector2.ZERO)).round()

static func to_world(point: Vector2, world: Node2D, role: String) -> Vector2:
	return point+offset(world,role)

static func to_screen(point: Vector2, world: Node2D, role: String) -> Vector2:
	return point-offset(world,role)
