extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const World=preload("res://scripts/world_simulation.gd")
const GOLDEN_HASHES={0:"5f7e7eef138a567a5730458a8206318f6414d012cd894c6302de6e2e244397d9",42:"1b3ec14f90f3082bf3fca0f1ecb92f237964a6056fffed43c9969629546ceded"}
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATOR_DETERMINISM_FAIL | "+label)
func _initialize() -> void:
	var world=World.new(); world.reset_world({"seed":5321})
	var before:=var_to_bytes(world.capture_snapshot())
	var seen:Dictionary={}
	for map_seed in range(100):
		var request:=Request.create(map_seed)
		var a:=Generator.generate(request)
		check(a.valid,"seed accepts "+str(map_seed))
		if not a.valid: continue
		seed(map_seed+71893); randf() # unrelated global RNG cannot steer layout
		var b:=Generator.generate(request)
		check(b.valid and var_to_bytes(a)==var_to_bytes(b),"same recipe and retry yield exact complete output")
		check(Definition.canonical(a.definition)==Definition.canonical(b.definition),"same canonical authority")
		check(a.source==Request.source(request) and request==Request.create(map_seed),"source and caller immutability")
		seen[a.definition.meta.content_hash]=true
		if GOLDEN_HASHES.has(map_seed): check(a.definition.meta.content_hash==GOLDEN_HASHES[map_seed],"generator-v1 authority golden")
		var visual:Dictionary=a.definition.duplicate(true)
		visual.visual_features[0].legacy.visual_seed=987654321
		visual.presentation.visual_profile_id="different_preview_only"
		check(Definition.content_hash(visual)==a.definition.meta.content_hash,"visual seed/profile never enter authority hash")
	check(seen.size()==100,"100 seeds have distinct authority layouts")
	check(before==var_to_bytes(world.capture_snapshot()),"generation consumes no simulation state or RNG")
	world.free()
	check(Generator.generate(Request.create(2147483647)).definition.meta.content_hash=="d29f449872d0294dcc95f3370da0ad98144e939e7d697d428c47aeedfbaae150","maximum supported seed golden")
	check(not Generator.generate({}).valid,"bad recipe fails without definition")
	print("PHASE05_GENERATOR_DETERMINISM | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
