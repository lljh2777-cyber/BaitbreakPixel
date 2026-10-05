extends SceneTree
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
func _initialize() -> void:
	var failed: Array=[]
	var maximum:=0
	for seed in 1000:
		var result:=Generator.generate(Request.create(seed,2))
		if not result.valid: failed.append({"seed":seed,"attempts":result.diagnostics.attempts})
		else: maximum=maxi(maximum,result.diagnostics.attempt_index+1)
	print("TERRAIN_SWEEP | passed=%d | failed=%d | max_attempts=%d" % [1000-failed.size(),failed.size(),maximum])
	if not failed.is_empty(): print(failed)
	quit(0 if failed.is_empty() else 1)
