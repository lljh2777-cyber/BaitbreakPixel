extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
const World=preload("res://scripts/world_simulation.gd")
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
	check(seen.size()==100,"100 seeds have distinct authority layouts")
	check(before==var_to_bytes(world.capture_snapshot()),"generation consumes no simulation state or RNG")
	world.free()
	check(not Generator.generate({}).valid,"bad recipe fails without definition")
	print("PHASE05_GENERATOR_DETERMINISM | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
