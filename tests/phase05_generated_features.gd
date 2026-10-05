extends SceneTree
const Request=preload("res://scripts/maps/generation/map_generation_request.gd")
const Generator=preload("res://scripts/maps/generation/map_generator.gd")
const Validator=preload("res://scripts/maps/map_validator.gd")
const Context=preload("res://scripts/maps/map_context.gd")
const Registry=preload("res://scripts/maps/map_registry.gd")
const Profile=preload("res://scripts/maps/generation/generated_pond_profile.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("GENERATED_FEATURES_FAIL | "+label)
func _initialize() -> void:
	for map_seed in [0,7,42,999,123456789,2147483647]:
		var result:=Generator.generate(Request.create(map_seed))
		check(result.valid,"candidate generated")
		if not result.valid: continue
		var definition:Dictionary=result.definition
		check(Validator.validate(definition).valid,"existing MapValidator accepts generated contract-v1")
		check(definition.bounds.size==Profile.SIZE and definition.anchors.home==Profile.HOME and definition.anchors.player_spawn==Profile.SPAWN,"fixed envelope and safe anchors")
		check(definition.bait_sites.size()==6,"six candidate food positions")
		check(not Registry.load_ref(definition.meta).valid,"generated map is not registered/playable/networked")
		var loaded:=Context.from_definition(definition)
		check(loaded.valid,"development fixture can build ordinary MapContext")
		var ids:Dictionary={}
		var kinds:Dictionary={"wood":0,"stone":0,"grass":0}
		for feature:Dictionary in definition.interaction_features:
			check(not ids.has(feature.id) and feature.id=="%s_%03d" % [feature.kind,kinds[feature.kind]],"stable typed generation slots")
			ids[feature.id]=true; kinds[feature.kind]+=1
			for point:Vector2 in feature.shape.points: check(point==point.round(),"integer template coordinates")
			check(feature.capabilities.grass_binding==(feature.kind=="grass") and feature.capabilities.rope_anchor and feature.capabilities.net_blocking==(feature.kind!="grass"),"original capability semantics")
			check(feature.presentation_ref==feature.id,"public art maps to authority feature")
			if feature.kind=="wood":
				check(feature.fade_group_id=="wood_%03d" % ((kinds.wood-1)/2*2),"connected wood shares fade representative")
		check(kinds.wood>=4 and kinds.wood<=6 and kinds.stone>=3 and kinds.grass>=5,"all required interaction types")
		check(loaded.context.net_blockers.size()==kinds.wood+kinds.stone,"context exports actual generated blockers")
	print("PHASE05_GENERATED_FEATURES | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
