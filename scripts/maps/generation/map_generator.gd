extends RefCounted
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Candidate=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
const Validator=preload("res://scripts/maps/map_validator.gd")

# A result envelope, not another map model. Only definition is Authority geometry.
# Retry count is fixed/versioned and exhaustion is explicit; no implicit pond fallback.
static func generate(request: Variant) -> Dictionary:
	var validation:=Request.validate(request)
	if not validation.valid: return {"valid":false,"errors":validation.errors,"definition":{},"source":{},"diagnostics":{}}
	var attempts:Array[Dictionary]=[]
	for attempt in Profile.MAX_ATTEMPTS:
		var definition:=Candidate.generate(request,attempt)
		var structural:=Validator.validate(definition)
		attempts.append({"attempt_index":attempt,"valid":structural.valid,"errors":structural.errors})
		if not structural.valid: continue
		return {"valid":true,"errors":[],"definition":definition,"source":Request.source(request),
			"diagnostics":{"map_seed":request.map_seed,"attempt_index":attempt,"attempt_seed":Candidate.attempt_seed(request,attempt),
				"content_hash":definition.meta.content_hash,"feature_count":definition.interaction_features.size(),"attempts":attempts}}
	return {"valid":false,"errors":["deterministic generation exhausted 32 attempts"],"definition":{},"source":Request.source(request),"diagnostics":{"map_seed":request.map_seed,"attempts":attempts}}
