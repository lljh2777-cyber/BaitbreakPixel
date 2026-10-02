extends SceneTree
const Profile=preload("res://scripts/food_profile.gd")
const World=preload("res://scripts/world_simulation.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("FOOD_PROFILE_FAIL | "+label)
func _initialize() -> void:
	var w:=World.new(); w.reset_world({"seed":321,"rules":{"satiety_decay":0.0}})
	var shapes: Dictionary={}
	for kind in Profile.TYPES:
		var profile:=Profile.get_profile(kind)
		check(profile.id==kind and profile.visual_kind==kind,"known profile identity")
		for field in ["suction_efficiency","bite_efficiency","satiety_scale","fragmentation"]:
			check(profile[field]==1.0,"P2.2 keeps "+field+" baseline; P2.3 remains gated")
		profile.satiety_scale=999.0
		check(Profile.get_profile(kind).satiety_scale==1.0,"profile callers cannot mutate global defaults")
		var bait: Dictionary=w._make_bait(0,0,kind)
		var points:=0.0; var offsets: Array=[]
		for grain in bait.grains:
			points+=grain.points; offsets.append(grain.offset)
			check(grain.visual_kind==kind and Vector2(grain.offset).length()<9,"grain identity and compact physical envelope")
		check(bait.grains.size()==44 and is_equal_approx(points,w.rule("bait_points")),"type preserves total food count and score economy")
		shapes[str(offsets)]=true
		w.score=0; w.satiety=20; w.counted.clear()
		w._consume_grain(bait.grains[0],false)
		check(is_equal_approx(w.score,w.rule("bait_points")*0.6/24) and is_equal_approx(w.satiety,20+w.score*w.rule("satiety_food_value")),"actual consumption keeps baseline score and satiety for "+kind)
	check(shapes.size()==3,"three real physical silhouettes, no display-only phantom food")
	check(not Profile.valid_type("unknown") and not Profile.valid_type(1) and Profile.get_profile("unknown").is_empty(),"unknown profile rejected without silent cluster fallback")
	w.free()
	print("FOOD_PROFILE | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
