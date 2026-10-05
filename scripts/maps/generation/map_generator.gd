extends RefCounted
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Candidate=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Relief=preload("res://scripts/maps/generation/generated_pond_v2.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
const Validator=preload("res://scripts/maps/map_validator.gd")
const Playability=preload("res://scripts/maps/generation/map_playability_validator.gd")

# A result envelope, not another map model. Only definition is Authority geometry.
# Retry count is fixed/versioned and exhaustion is explicit; no implicit pond fallback.
static func generate(request: Variant) -> Dictionary:
	var validation:=Request.validate(request)
	if not validation.valid: return {"valid":false,"errors":validation.errors,"definition":{},"source":{},"diagnostics":{}}
	return _attempts(request,Candidate.generate if request.generator_version==1 else Relief.generate)

# Private test seam for exercising bounded exhaustion without altering a recipe.
static func _attempts(request: Dictionary, candidate_factory: Callable) -> Dictionary:
	var attempts:Array[Dictionary]=[]
	for attempt in Profile.MAX_ATTEMPTS:
		var definition:Dictionary=candidate_factory.call(request,attempt)
		var checked:=Playability.validate(definition)
		attempts.append({"attempt_index":attempt,"valid":checked.valid,"errors":checked.errors})
		if not checked.valid: continue
		return {"valid":true,"errors":[],"definition":definition,"source":Request.source(request),
			"diagnostics":{"map_seed":request.map_seed,"attempt_index":attempt,"attempt_seed":Candidate.attempt_seed(request,attempt),
				"content_hash":definition.meta.content_hash,"feature_count":definition.interaction_features.size(),"metrics":checked.metrics,"attempts":attempts}}
	return {"valid":false,"errors":["deterministic generation exhausted 32 attempts"],"definition":{},"source":Request.source(request),"diagnostics":{"map_seed":request.map_seed,"attempts":attempts}}
