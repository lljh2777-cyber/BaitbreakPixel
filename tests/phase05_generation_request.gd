extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Seeds=preload("res://scripts/maps/generation/seed_derivation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATION_REQUEST_FAIL | "+label)
func _initialize() -> void:
	for seed_value in [0,1,123456789,2147483647]:
		var request:=Request.create(seed_value)
		check(Request.validate(request).valid,"valid seed "+str(seed_value))
		check(Request.source(request).map_seed==seed_value,"detached source recipe")
		for bad in [-1,2147483648,1.0,"1",true,null,[],{}]:
			var invalid:=request.duplicate(); invalid.map_seed=bad
			check(not Request.validate(invalid).valid and Request.source(invalid).is_empty(),"strict seed scalar")
		for key in Request.KEYS:
			var missing:=request.duplicate(); missing.erase(key)
			check(not Request.validate(missing).valid,"missing field "+key)
		for key in ["visual_seed","world_rng","weather","unknown"]:
			var extra:=request.duplicate(); extra[key]=1
			check(not Request.validate(extra).valid,"reject non-authority field "+key)
		var a=Seeds.stream(seed_value,"generated_pond:1:attempt:0")
		var b=Seeds.stream(seed_value,"generated_pond:1:attempt:0")
		var different=Seeds.stream(seed_value,"visual")
		check(a.next_int()!=different.next_int(),"namespace isolation")
		b.next_int()
		for index in 128:
			var value:int=a.between(-100,100)
			check(value==b.between(-100,100) and value>=-100 and value<=100,"portable repeated integer stream")
	for value in [null,[],"seed",17]: check(not Request.validate(value).valid,"non-request rejected")
	for entry: Dictionary in [{"generator_id":"unknown"},{"generator_version":2},{"generator_version":1.0},{"gameplay_profile":"dense"},{"map_contract_version":2}]:
		var invalid:=Request.create(1); invalid.merge(entry,true)
		check(not Request.validate(invalid).valid,"unsupported recipe rejected")
	var named:=Request.create(1); named.erase("map_seed"); named[&"map_seed"]=1
	check(not Request.validate(named).valid,"StringName keys rejected")
	# Fixed vectors pin the arithmetic, independently of random draw count.
	check(Seeds.derive(0,"")==1 and Seeds.derive(1,"")==2,"empty namespace vectors")
	print("PHASE05_GENERATION_REQUEST | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
