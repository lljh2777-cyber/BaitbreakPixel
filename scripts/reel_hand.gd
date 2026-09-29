extends RefCounted

const Sprite=preload("res://assets/first_person/left_reel_hands_v016.png")
const Hand=preload("res://scripts/angler_hand.gd")
# Match the visible palm size to the reference right hand; keep the grip
# as the scale origin so resizing cannot pull the fingers off the reel.
const SIZE:=104.0
const GRIP:=Vector2(0.805,0.405)
const PINCH:=Vector2(0.80,0.40)
var texture:ViewportTexture

func prepare(view:Node2D) -> void:
	var pixels:=SubViewport.new(); pixels.name="LeftReelHandPixels"
	pixels.size=Vector2i(128,64); pixels.transparent_bg=true; pixels.disable_3d=true
	pixels.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	pixels.render_target_update_mode=SubViewport.UPDATE_ONCE; view.add_child(pixels)
	var art:=TextureRect.new(); art.texture=Sprite; art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.size=Vector2(128,64); art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){vec4 c=texture(TEXTURE,UV); COLOR=vec4(c.rgb,step(0.5,c.a));}"
	var material:=ShaderMaterial.new(); material.shader=shader; art.material=material
	pixels.add_child(art); texture=pixels.get_texture()

static func pose(right:Dictionary,rig:RefCounted) -> Dictionary:
	var hub:=Hand.point(Vector2(1030,926),right.wrist,right.angle)
	var crank:=hub+Vector2(-10+cos(rig.reel_phase)*5,sin(rig.reel_phase)*8+3).rotated(right.angle)
	var adjuster:=Hand.point(Vector2(1014,910),right.wrist,right.angle)
	var paying:bool=rig.reel_hand_mode>0
	var reach:=smoothstep(0,1,rig.reel_hand_amount)
	var target:=adjuster if paying else crank
	var angle:float=right.angle*0.35+(sin(rig.release_phase)*0.10 if paying else sin(rig.reel_phase)*0.065)
	var grip:=target+Vector2(-14,100)*(1-reach)
	return {"hub":hub,"crank":crank,"adjuster":adjuster,"grip":grip,"angle":angle,"cell":1 if paying else 0,"pivot":PINCH if paying else GRIP,"reach":reach}

static func sprite_point(local:Vector2,state:Dictionary) -> Vector2:
	# Keep the hand and cuff rigid. Continue the sleeve along the forearm axis
	# below the picture, so the finite source image can never expose a cut end.
	var sleeve:=Vector2(-0.8,0.8)*maxf(0,(local.y-0.70)/0.30)
	return state.grip+((local-state.pivot+sleeve)*SIZE).rotated(state.angle)

func draw_hand(view:Node2D,state:Dictionary) -> void:
	if texture==null: return
	for band in [Vector2(0,0.70),Vector2(0.70,1)]:
		var vertices:=PackedVector2Array(); var uv:=PackedVector2Array()
		for corner:Vector2 in [Vector2(0,band.x),Vector2(1,band.x),Vector2(1,band.y),Vector2(0,band.y)]:
			vertices.append(sprite_point(corner,state))
			uv.append(Vector2((corner.x+state.cell)*0.5,corner.y))
		view.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,texture)

func draw(view:Node2D,right:Dictionary,world:Node2D) -> void:
	if texture==null: return
	var rig:RefCounted=world.angler
	if world.hooked!=world.HookState.HOOKED and rig.reel_hand_amount<=0: return
	var state:=pose(right,rig)
	var crank_path:=PackedVector2Array([state.hub,state.hub+Vector2(-5,2).rotated(right.angle),state.crank])
	view.draw_polyline(crank_path,Color("231e1c"),3)
	view.draw_polyline(crank_path,Color("8b8879"),1)
	view.draw_rect(Rect2(state.crank.round()-Vector2(3,2),Vector2(6,4)),Color("30251e"))
	view.draw_rect(Rect2(state.adjuster.round()-Vector2(2,2),Vector2(4,4)),Color("776752"))
	# The spool turns as line actually travels; paying out does not wind the handle backwards.
	var phase:float=rig.reel_phase if rig.feedback_reel_speed(world)<=0 else -rig.release_phase*3
	for i in 2:
		var glint:Vector2=state.hub+(Vector2.from_angle(phase+i*PI)*Vector2(4,7)).rotated(right.angle)
		view.draw_rect(Rect2(glint.round(),Vector2(2,2)),Color("c7c1a9"))
	if rig.reel_hand_amount<=0 or world.Net.busy(world): return
	draw_hand(view,state)
