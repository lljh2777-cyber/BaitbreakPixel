extends RefCounted

# Source coordinates identify the supplied reference's actual wrist, ferrule and tip.
const Sprite = preload("res://assets/first_person/reference_tackle_v0158.png")
const CANVAS := Vector2(1448,1086)
const WRIST := Vector2(1190,983)
const SOCKET := Vector2(1066,794)
const TIP := Vector2(872,462)
const ROD_AXIS := Vector2(-0.5045176672416012,-0.8634013686815031)
const SIZE := 0.285
const PIXEL_SIZE := Vector2i(362,272)
const ARM_PIVOT := Vector2(470,800)
const WRIST_REACH := Vector2(0,-500)
var pixel_texture: ViewportTexture

func prepare(view: Node2D) -> void:
	var pixels := SubViewport.new()
	pixels.name="ReferenceTacklePixels"
	pixels.size=PIXEL_SIZE
	pixels.transparent_bg=true
	pixels.disable_3d=true
	pixels.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	pixels.render_target_update_mode=SubViewport.UPDATE_ONCE
	view.add_child(pixels)
	var art := TextureRect.new()
	art.texture=Sprite
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.size=Vector2(PIXEL_SIZE)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# Retain reference colors, only removing translucent cutout edge pixels.
	var shader := Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){vec4 c=texture(TEXTURE,UV); COLOR=vec4(c.rgb,step(0.5,c.a));}"
	var material := ShaderMaterial.new(); material.shader=shader; art.material=material
	pixels.add_child(art)
	pixel_texture=pixels.get_texture()

static func pose(horizontal: float, time: float, reel_speed: float) -> Dictionary:
	var travel := clampf(horizontal,0,1)
	var arm_angle := deg_to_rad(lerpf(-12,12,travel))
	var angle := deg_to_rad(lerpf(-3,15,travel))
	angle+=sin(time*7)*0.0015*minf(absf(reel_speed)/36,1)
	# A fixed off-screen arm pivot drives a real wrist arc. The wrist adds a
	# smaller rotation, keeping the grip upright as the arm sweeps across the lake.
	# Neither the float nor the camera is allowed to cancel this movement.
	var wrist := ARM_PIVOT+WRIST_REACH.rotated(arm_angle)
	return {"wrist":wrist,"angle":angle,"arm_angle":arm_angle,"socket":point(SOCKET,wrist,angle),"axis":ROD_AXIS.rotated(angle)}

static func point(source: Vector2, wrist: Vector2, angle: float) -> Vector2:
	return wrist+((source-WRIST)*SIZE).rotated(angle)

func draw(view: Node2D, pose: Dictionary, _time: float, _reel_speed: float) -> void:
	if pixel_texture==null: return
	var corners := [Vector2(970,786),Vector2(1448,786),CANVAS,Vector2(970,1086)]
	var vertices := PackedVector2Array(); var uv := PackedVector2Array()
	for source: Vector2 in corners:
		vertices.append(point(source,pose.wrist,pose.angle))
		uv.append(source/CANVAS)
	view.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,pixel_texture)

func draw_rod(view: Node2D, points: PackedVector2Array) -> void:
	if pixel_texture==null: return
	var side := Vector2(-ROD_AXIS.y,ROD_AXIS.x)
	# Sample the same reference shaft in material-length strips; load curves it.
	for part in range(1,points.size()):
		var a := (part-1)/float(points.size()-1); var b := part/float(points.size()-1)
		var normal := Vector2(-(points[part]-points[part-1]).normalized().y,(points[part]-points[part-1]).normalized().x)
		var vertices := PackedVector2Array([points[part-1]+normal*6,points[part]+normal*6,points[part]-normal*6,points[part-1]-normal*6])
		var uv := PackedVector2Array([(SOCKET.lerp(TIP,a)+side*(6/SIZE))/CANVAS,(SOCKET.lerp(TIP,b)+side*(6/SIZE))/CANVAS,(SOCKET.lerp(TIP,b)-side*(6/SIZE))/CANVAS,(SOCKET.lerp(TIP,a)-side*(6/SIZE))/CANVAS])
		view.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,pixel_texture)
