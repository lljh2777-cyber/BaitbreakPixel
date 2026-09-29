extends RefCounted

const Sprite = preload("res://assets/first_person/angler_hand_pixel.png")
const PaletteShader = preload("res://scripts/hand_palette.gdshader")
const PIXEL_SIZE := 80
const PALETTE := ["10263b","ffd49a","f2b777","d58f53","a85e38","edb951","bd8739","865c2b","8b9256","536650","314b43","24383c","dce7de","9cabb4","5c6c80","344758"]
const SIZE := 136.0
const WRIST := Vector2(0.70,0.56)
const SOCKET := Vector2(0.093,0.075)
const GRID := 18
var mesh := ArrayMesh.new()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var pixel_texture: ViewportTexture

func prepare(view: Node2D) -> void:
	# Render this foreground layer once at its native pixel resolution and palette.
	# The source artwork is redrawn pixel art; this also prevents fine texture from leaking in.
	var pixel_view := SubViewport.new()
	pixel_view.name="HandPixels"
	pixel_view.size=Vector2i(PIXEL_SIZE,PIXEL_SIZE)
	pixel_view.transparent_bg=true
	pixel_view.disable_3d=true
	pixel_view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	pixel_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	view.add_child(pixel_view)
	var art := TextureRect.new()
	art.texture=Sprite
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.size=Vector2(PIXEL_SIZE,PIXEL_SIZE)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader=PaletteShader
	var colors := PackedColorArray()
	for hex in PALETTE: colors.append(Color(hex))
	material.set_shader_parameter("palette",colors)
	art.material=material
	pixel_view.add_child(art)
	pixel_texture=pixel_view.get_texture()

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
	if pixel_texture==null: return
	view.draw_mesh(mesh,pixel_texture)
	if absf(reel_speed)<0.5: return
	# Light travels around the metal spool in the actual winding direction.
	for glint in 2:
		var arc := PackedVector2Array()
		var phase := time*7*signf(reel_speed)+glint*PI
		for step in 5:
			var local := Vector2.from_angle(phase+step*0.09)*Vector2(0.078,0.040)
			arc.append(point(Vector2(0.158,0.486)+local.rotated(-0.8),wrist,angle).round())
		view.draw_polyline(arc,Color("dce7de"),1)
