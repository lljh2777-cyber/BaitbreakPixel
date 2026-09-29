extends RefCounted

const Sprite = preload("res://assets/first_person/angler_hand_forearm.png")
const PaletteShader = preload("res://scripts/hand_palette.gdshader")
const PIXEL_SIZE := 112
const PALETTE := ["10263b","ffd49a","f2b777","d58f53","a85e38","edb951","bd8739","865c2b","8b9256","536650","314b43","24383c","dce7de","9cabb4","5c6c80","344758"]
const SIZE := 142.0
const WRIST := Vector2(0.49,0.42)
const SOCKET := Vector2(0.077,0.065)
const ROD_AXIS := Vector2(-0.70710678,-0.70710678)
const FOREARM_ROOT := Vector2(1.0,1.0)
const UPPER_ORIGIN := Vector2(0.60,0.55)
const SHOULDER := Vector2(480,420)
const UPPER_LENGTH := 170.0
const FOREARM_LENGTH := 110.0
const REST_TIP_HEIGHT := 112.0
const HAND_UVS := [Vector2(0,0),Vector2(1,0),Vector2(1,0.10),Vector2(0.10,1),Vector2(0,1)]
const SLEEVE_UVS := [Vector2(0.02,1),Vector2(1,0.02),Vector2(1,1)]
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

static func pose(horizontal: float, time: float, reel_speed: float, shaft_length: float=210.0) -> Dictionary:
	# The hand, forearm and upper arm have separate rigid transforms. Solve the
	# elbow on a fixed-length upper-arm circle, rather than sliding the whole art.
	var travel := clampf(horizontal,0,1)
	var angle := deg_to_rad(lerpf(-22,-7,travel))
	angle+=sin(time*7)*0.002*minf(absf(reel_speed)/36,1)
	var source_arm := FOREARM_ROOT-WRIST
	var forearm_angle := source_arm.angle()+angle+deg_to_rad(lerpf(-4,4,travel))
	var forearm := Vector2.from_angle(forearm_angle)*FOREARM_LENGTH
	var tip_offset := ((SOCKET-WRIST)*SIZE+ROD_AXIS*shaft_length).rotated(angle)
	var wrist_y := REST_TIP_HEIGHT-tip_offset.y
	var elbow_y := wrist_y+forearm.y
	var shoulder_dy := elbow_y-SHOULDER.y
	var elbow := Vector2(SHOULDER.x+sqrt(maxf(0,UPPER_LENGTH*UPPER_LENGTH-shoulder_dy*shoulder_dy)),elbow_y)
	var wrist := elbow-forearm
	return {"wrist":wrist,"angle":angle,"socket":point(SOCKET,wrist,angle),"axis":ROD_AXIS.rotated(angle),
		"elbow":elbow,"shoulder":SHOULDER,"forearm_angle":forearm_angle-source_arm.angle(),
		"upper_angle":(SHOULDER-elbow).angle()-(FOREARM_ROOT-UPPER_ORIGIN).angle(),
		"forearm_scale":FOREARM_LENGTH/source_arm.length(),"upper_scale":UPPER_LENGTH/source_arm.length()}

static func point(uv: Vector2, wrist: Vector2, angle: float) -> Vector2:
	return wrist+((uv-WRIST)*SIZE).rotated(angle)

func draw(view: Node2D, pose: Dictionary, time: float, reel_speed: float) -> void:
	if pixel_texture==null: return
	# Cuff overlap and a textured elbow cover the joints; no vertices are warped
	# between bones and no part of the hand is stretched or folded.
	_piece(view,pose.elbow,pose.upper_angle,pose.upper_scale,SLEEVE_UVS,UPPER_ORIGIN)
	_piece(view,pose.wrist,pose.forearm_angle,pose.forearm_scale,SLEEVE_UVS)
	_elbow(view,pose.elbow,pose.forearm_angle)
	_piece(view,pose.wrist,pose.angle,SIZE,HAND_UVS)
	var wrist: Vector2=pose.wrist
	var angle: float=pose.angle
	if absf(reel_speed)<0.5: return
	# Light travels around the metal spool in the actual winding direction.
	for glint in 2:
		var arc := PackedVector2Array()
		var phase := time*7*signf(reel_speed)+glint*PI
		for step in 5:
			var local := Vector2.from_angle(phase+step*0.09)*Vector2(0.052,0.028)
			arc.append(point(Vector2(0.144,0.390)+local.rotated(-0.8),wrist,angle).round())
		view.draw_polyline(arc,Color("dce7de"),1)

func _piece(view: Node2D, origin: Vector2, angle: float, size: float, region: Array, uv_origin: Vector2=WRIST) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for uv: Vector2 in region:
		vertices.append(origin+((uv-uv_origin)*size).rotated(angle))
		uvs.append(uv)
	view.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,pixel_texture)

func _elbow(view: Node2D, center: Vector2, angle: float) -> void:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for step in 16:
		var radial := Vector2.from_angle(step*TAU/16.0)
		vertices.append(center+(radial*17).rotated(angle))
		uvs.append(Vector2(0.80,0.76)+radial*0.11)
	view.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,pixel_texture)
