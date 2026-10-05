extends Node2D

# Developer-only public-geometry viewer. No World, gameplay actors or net session.
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
const Context=preload("res://scripts/maps/map_context.gd")
const Presentation=preload("res://scripts/maps/map_presentation.gd")
const Art=preload("res://scripts/pixel_art.gd")
const Water=preload("res://scripts/pond_water_art.gd")
const Plants=preload("res://scripts/pond_plant_art.gd")
const OFFSET:=Vector2(24,72)
const ZOOM:=0.96
var result:Dictionary={}
var context:RefCounted
var presentation:RefCounted
var props:Array[Dictionary]=[]
var plants:Array[Dictionary]=[]
var water_texture:Texture2D
var font:SystemFont
var overlay:=true
var selected_seed:=42
var error_text:=""
var seed_box:LineEdit
var build_ms:=0.0
var bake_ms:=0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	seed_box=LineEdit.new(); seed_box.position=Vector2(250,16); seed_box.size=Vector2(160,34); seed_box.placeholder_text="0..2147483647"; seed_box.text=str(selected_seed)
	add_child(seed_box); seed_box.text_submitted.connect(func(_text:String): apply_text())
	_button("生成 / 同 Seed 重建",Vector2(425,16),func(): apply_text())
	_button("随机 Seed",Vector2(625,16),func(): seed_box.text=str(randi_range(0,Request.MAX_SEED)); apply_text())
	_button("复制 Seed",Vector2(760,16),func(): DisplayServer.clipboard_set(str(selected_seed)))
	_button("显示 / 隐藏检查层",Vector2(895,16),func(): overlay=not overlay; queue_redraw())

func _button(label:String, at:Vector2, action:Callable) -> void:
	var button:=Button.new(); button.text=label; button.position=at; button.size=Vector2(120,34)
	button.pressed.connect(action); add_child(button)

func apply_text() -> bool:
	var value:String=seed_box.text.strip_edges()
	if value.is_empty() or value.length()>10 or not value.is_valid_int() or str(value.to_int())!=value:
		error_text="请输入 0..2147483647 的整数 Seed"; queue_redraw(); return false
	return configure(value.to_int())

func configure(map_seed:int) -> bool:
	var begin:=Time.get_ticks_usec()
	var generated:=Generator.generate(Request.create(map_seed))
	if not generated.valid: error_text=str(generated.errors); queue_redraw(); return false
	var loaded:=Context.from_definition(generated.definition)
	if not loaded.valid: error_text=str(loaded.errors); queue_redraw(); return false
	result=generated; context=loaded.context; presentation=Presentation.for_context(context)
	build_ms=(Time.get_ticks_usec()-begin)/1000.0
	begin=Time.get_ticks_usec()
	if water_texture==null: water_texture=ImageTexture.create_from_image(Water.water_image(presentation))
	props=Art.scene_props(presentation); plants.clear()
	for plant:Dictionary in presentation.plants:
		var canvas:=Image.create(1280,132,false,Image.FORMAT_RGBA8); canvas.fill(Color.TRANSPARENT)
		Plants.paint(canvas,plant,0.0)
		var region:=Rect2i(int(plant.x-plant.width*0.5-14),int(129-plant.height-8),int(plant.width+29),int(plant.height+12)).intersection(Rect2i(0,0,1280,132))
		plants.append({"texture":ImageTexture.create_from_image(canvas.get_region(region)),"position":Vector2(region.position)+Vector2(0,plant.y-129)})
	bake_ms=(Time.get_ticks_usec()-begin)/1000.0
	selected_seed=map_seed; error_text=""; seed_box.text=str(map_seed); queue_redraw(); return true

func _draw() -> void:
	if font==null: return
	draw_rect(Rect2(0,0,1280,720),Color("102833"))
	draw_string(font,Vector2(24,40),"P5 开发预览 · 地图 Seed",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b8e2d3"))
	if not error_text.is_empty(): draw_string(font,Vector2(24,690),error_text,HORIZONTAL_ALIGNMENT_LEFT,1200,16,Color("ffb38a"))
	if result.is_empty(): return
	draw_set_transform(OFFSET,0,Vector2.ONE*ZOOM)
	draw_texture(water_texture,Vector2.ZERO)
	draw_rect(Rect2(0,0,1280,55),Color("759b92"))
	draw_rect(Rect2(0,55,1280,3),Color("b7d2b5"))
	draw_rect(Rect2(0,433,1280,47),Color("4a5b4f"))
	for prop:Dictionary in props: draw_texture(prop.texture,prop.position)
	for plant:Dictionary in plants: draw_texture(plant.texture,plant.position)
	if overlay:
		for rect:Rect2 in Profile.protected_regions(context.bait_sites):
			var clipped:=rect.intersection(Rect2(Vector2.ZERO,Profile.SIZE))
			draw_rect(clipped,Color(0.55,0.90,0.78,0.06)); draw_rect(clipped,Color(0.55,0.90,0.78,0.32),false,1)
		for feature:Dictionary in context.interaction_features:
			var points:PackedVector2Array=feature.shape.points.duplicate(); points.append(points[0])
			draw_polyline(points,Color("e8c57a") if feature.kind!="grass" else Color("9adc92"),1)
			draw_string(font,context.feature_bounds(feature.id).position-Vector2(0,5),feature.id,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("cfdbb5"))
	for index in context.bait_sites.size():
		var point:Vector2=context.bait_sites[index]
		draw_circle(point,5,Color("ffd786")); draw_arc(point,12,0,TAU,24,Color("ffd786"),1)
		draw_string(font,point+Vector2(16,5),"饵点 %d" % (index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffeac4"))
	draw_circle(context.home,10,Color("72dbbd")); draw_string(font,context.home+Vector2(14,8),"巢穴",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c9f5dd"))
	draw_circle(context.player_spawn,5,Color("f1bb86")); draw_string(font,context.player_spawn+Vector2(14,-3),"出生",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffdfb7"))
	draw_set_transform(Vector2.ZERO)
	var metrics:Dictionary=result.diagnostics.metrics
	draw_string(font,Vector2(24,565),"Seed %d  /  generated_pond v1  /  balanced_pond_v1  /  attempt %d" % [selected_seed,result.diagnostics.attempt_index],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d9eddf"))
	draw_string(font,Vector2(24,596),"木 %d · 石 %d · 草 %d     覆盖 %.1f%%     饵点最小间距 %.0f     网路 开放 %d / 截断 %d / 无效 %d" % [metrics.wood_count,metrics.stone_count,metrics.grass_count,metrics.cover_density*100,metrics.bait_spacing,metrics.net_routes.open,metrics.net_routes.partial,metrics.net_routes.invalid],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a8cec0"))
	draw_string(font,Vector2(24,626),"Map hash: "+context.content_hash,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("87a99f"))
	draw_string(font,Vector2(24,655),"生成/校验/Context %.1f ms · 像素素材 %.1f ms · 淡色框为保护区；黄点仅是候选位置，不表示安全饵。" % [build_ms,bake_ms],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a8cec0"))
	if error_text.is_empty(): draw_string(font,Vector2(24,690),"仅供布局审查：没有比赛、Hook 分配或存档联机；路线指标为保守采样，尚未验证完整比赛可达性。",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d1bb8d"))
