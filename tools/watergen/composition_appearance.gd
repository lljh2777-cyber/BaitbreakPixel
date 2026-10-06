extends "res://scripts/watergen/generated_water_appearance.gd"
## Preview-owned cache. Production Appearance and Main do not depend on this.
const Plan=preload("res://scripts/watergen/pond_composition_plan.gd")
const Baker=preload("res://scripts/watergen/pond_composition_baker.gd")
var variant:="A"
var studies: Dictionary={}
var study: Dictionary={}
var study_context: RefCounted
var bake_count:=0
var show_baseline:=false
var original_bed: Texture2D

func prepare(context: RefCounted, seed_value: int) -> bool:
	if not super.prepare(context,seed_value): return false
	if context.map_source.kind!="generated": study={}; return true
	if study_context!=context:
		studies.clear(); study_context=context
		original_bed=preload("res://scripts/pond_bed_art.gd").bake(context) if context.has_relief else null
	var key: String=variant+":"+str(seed_value)
	if not studies.has(key):
		var generated:=Plan.generate(Adapter.build(context),variant,seed_value)
		if not generated.ok: return false
		var start:=Time.get_ticks_usec()
		var baked:=Baker.bake(generated.plan)
		if not baked.ok: return false
		var result: Dictionary={"plan":generated.plan,"prepare_us":Time.get_ticks_usec()-start}
		for layer in ["far","anchors","bed","foreground"]: result[layer]=ImageTexture.create_from_image(baked[layer])
		if studies.size()>=3: studies.erase(studies.keys()[0])
		studies[key]=result; bake_count+=1
	study=studies[key]
	return true

func draw_blockout(view: Node2D, camera: Vector2, time: float) -> void:
	# Reuse the quiet water/lighting pass only. All old terrain, repeated logs,
	# plants and NPCs are intentionally absent from this frozen composition board.
	draw_slot(view,"water",camera,time)
	view.draw_set_transform(-camera)
	for layer in ["far","bed","anchors","foreground"]:
		view.draw_texture(study[layer],Vector2.ZERO)
