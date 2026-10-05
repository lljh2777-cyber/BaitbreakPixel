extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Candidate=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Gate=preload("res://scripts/maps/generation/map_playability_validator.gd")
const Definition=preload("res://scripts/maps/map_definition.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("PLAYABILITY_FAIL | "+label)
func reseal(value: Dictionary) -> Dictionary:
	value.meta.content_hash=Definition.content_hash(value)
	return value
func _initialize() -> void:
	var request:=Request.create(42)
	var result:=Generator.generate(request)
	check(result.valid,"known generated layout accepted")
	if not result.valid: print(result.errors); quit(1); return
	var base:Dictionary=result.definition
	for scenario in ["bait-overlap","home-covered","spawn-covered","no-anchor","net-sealed","too-dense","bad-polygon","duplicate-id","no-baits","tiny-net"]:
		var bad:=base.duplicate(true)
		match scenario:
			"bait-overlap": bad.bait_sites[1]=bad.bait_sites[0]+Vector2(1,0)
			"home-covered","spawn-covered":
				var center:Vector2=bad.anchors.home if scenario=="home-covered" else bad.anchors.player_spawn
				bad.interaction_features[0].shape.points=PackedVector2Array([center-Vector2(10,10),center+Vector2(10,-10),center+Vector2(10,10),center+Vector2(-10,10)])
			"no-anchor":
				for feature:Dictionary in bad.interaction_features: feature.capabilities.rope_anchor=false
			"net-sealed": bad.interaction_features[0].shape.points=PackedVector2Array([Vector2(8,68),Vector2(1272,68),Vector2(1272,431),Vector2(8,431)])
			"too-dense":
				for feature:Dictionary in bad.interaction_features: feature.shape.points=PackedVector2Array([Vector2(150,250),Vector2(1250,250),Vector2(1250,431),Vector2(150,431)])
			"bad-polygon": bad.interaction_features[0].shape.points=PackedVector2Array([Vector2(150,300),Vector2(200,400),Vector2(150,400),Vector2(200,300)])
			"duplicate-id": bad.interaction_features[1].id=bad.interaction_features[0].id
			"no-baits": bad.bait_sites=[]
			"tiny-net": bad.bounds.net_area=Rect2(30,85,1,1)
		check(not Gate.validate(reseal(bad)).valid,"reject "+scenario)
	var before:=var_to_bytes(base)
	check(Gate.validate(base).valid and var_to_bytes(base)==before,"validator is read-only")
	var count:Array[int]=[0]
	var exhausted:=Generator._attempts(request,func(_request:Dictionary,_attempt:int)->Dictionary: count[0]+=1; return {})
	check(not exhausted.valid and exhausted.definition.is_empty() and count[0]==32 and exhausted.diagnostics.attempts.size()==32,"exactly 32 retries then explicit failure without fallback")
	var retried:=Generator._attempts(request,func(_request:Dictionary,attempt:int)->Dictionary: return {} if attempt<2 else base.duplicate(true))
	check(retried.valid and retried.diagnostics.attempt_index==2,"retry accepts only first validated candidate")
	check(Candidate.attempt_seed(request,0)!=Candidate.attempt_seed(request,1),"attempt seed independently derived")
	var boxes:Array[Rect2]=[]
	var open:=Gate.net_routes(boxes)
	check(open.open==24 and open.partial==0 and open.invalid==0,"unblocked diagnostic routes")
	boxes.append(Rect2(0,0,1280,480))
	check(Gate.net_routes(boxes).invalid==24,"all starts obstructed detected")
	print("PHASE05_PLAYABILITY | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
