extends RefCounted

const Sprite = preload("res://assets/first_person/angler_hand.png")
const SIZE := 136.0
const WRIST := Vector2(0.70,0.56)
const SOCKET := Vector2(0.102,0.094)
const GRID := 18
var mesh := ArrayMesh.new()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()

func _init() -> void:
	for row in GRID+1:
		for column in GRID+1: uvs.append(Vector2(column,row)/float(GRID))
	for row in GRID:
		for column in GRID:
			var i := row*(GRID+1)+column
			indices.append_array(PackedInt32Array([i,i+1,i+GRID+2,i,i+GRID+2,i+GRID+1]))

static func wrist_position(x: float) -> Vector2:
	return Vector2(554+clampf((x-300)/300,-1,1)*12,294)

static func grip_angle(wrist: Vector2, tip: Vector2, time: float, reel_speed: float) -> float:
	var winding := sin(time*9)*0.009*minf(absf(reel_speed)/36,1)
	return (tip-wrist).angle()-(SOCKET-WRIST).angle()+winding

static func point(uv: Vector2, wrist: Vector2, angle: float) -> Vector2:
	# Rotate the grip as one piece; blend into the cuff so the sleeve stays on the forearm.
	var wrist_weight := 1.0-smoothstep(1.28,1.72,uv.x+uv.y)
	return wrist+((uv-WRIST)*SIZE).rotated(angle*wrist_weight)

func draw(view: Node2D, wrist: Vector2, angle: float, time: float, reel_speed: float) -> void:
	var vertices := PackedVector3Array()
	for uv in uvs:
		var p := point(uv,wrist,angle).round()
		vertices.append(Vector3(p.x,p.y,0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	view.draw_mesh(mesh,Sprite)
	if absf(reel_speed)<0.5: return
	# Light travels around the metal spool in the actual winding direction.
	for glint in 2:
		var arc := PackedVector2Array()
		var phase := time*7*signf(reel_speed)+glint*PI
		for step in 5:
			var local := Vector2.from_angle(phase+step*0.09)*Vector2(0.078,0.040)
			arc.append(point(Vector2(0.158,0.486)+local.rotated(-0.8),wrist,angle).round())
		view.draw_polyline(arc,Color(1.0,0.91,0.70,0.52),1)
