extends RefCounted

const Sprite = preload("res://assets/first_person/angler_hand_pixel.png")
const PaletteShader = preload("res://scripts/hand_palette.gdshader")
const PIXEL_SIZE := 80
const PALETTE := ["10263b","ffd49a","f2b777","d58f53","a85e38","edb951","bd8739","865c2b","8b9256","536650","314b43","24383c","dce7de","9cabb4","5c6c80","344758"]
const SIZE := 136.0
const WRIST := Vector2(0.70,0.56)
const SOCKET := Vector2(0.093,0.075)
const FOREARM_ROOT := Vector2(1.0,1.0)
const ELBOW := Vector2(612,356)
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

static func pose(tip: Vector2, time: float, reel_speed: float) -> Dictionary:
	# A single rigid forearm pivots below the play area. Solve its angle so the
	# rod's axis continues from the ferrule towards the target without a wrist twist.
	var axis := (SOCKET-WRIST).normalized()
	var socket_offset := (SOCKET-FOREARM_ROOT)*SIZE
	var target := tip-ELBOW
	var cross_offset := socket_offset.dot(axis.orthogonal())
	var length_on_axis := sqrt(maxf(0,target.length_squared()-cross_offset*cross_offset))
	var shaft_length := maxf(1,length_on_axis-socket_offset.dot(axis))
	var angle := target.angle()-(socket_offset+axis*shaft_length).angle()
	# Wind through the elbow, not by bending the wrist; keep this secondary motion small.
	angle+=sin(time*7)*0.002*minf(absf(reel_speed)/36,1)
	var wrist := ELBOW+((WRIST-FOREARM_ROOT)*SIZE).rotated(angle)
	return {"wrist":wrist,"angle":angle,"socket":point(SOCKET,wrist,angle),"axis":axis.rotated(angle)}

static func point(uv: Vector2, wrist: Vector2, angle: float) -> Vector2:
	return wrist+((uv-WRIST)*SIZE).rotated(angle)

func draw(view: Node2D, wrist: Vector2, angle: float, time: float, reel_speed: float) -> void:
	if pixel_texture==null: return
	view.draw_set_transform(wrist,angle)
	view.draw_texture_rect(pixel_texture,Rect2(-WRIST*SIZE,Vector2(SIZE,SIZE)),false)
	view.draw_set_transform(Vector2.ZERO)
	if absf(reel_speed)<0.5: return
	# Light travels around the metal spool in the actual winding direction.
	for glint in 2:
		var arc := PackedVector2Array()
		var phase := time*7*signf(reel_speed)+glint*PI
		for step in 5:
			var local := Vector2.from_angle(phase+step*0.09)*Vector2(0.078,0.040)
			arc.append(point(Vector2(0.158,0.486)+local.rotated(-0.8),wrist,angle).round())
		view.draw_polyline(arc,Color("dce7de"),1)
