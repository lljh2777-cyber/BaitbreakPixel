extends "terrain_relief.gd"
const Legacy=preload("res://scripts/maps/generation/generated_pond_v1.gd")
const Presentation=preload("res://scripts/maps/map_presentation.gd")
const PlantArt=preload("res://scripts/pond_plant_art.gd")
const Binding=preload("res://scripts/grass_binding.gd")
const Dynamic=preload("res://scripts/watergen/water_dynamic_generator.gd")
const Frame=preload("res://scripts/watergen/water_visual_frame.gd")

func _initialize() -> void:
	generator_version=3
	super._initialize()

func run() -> void:
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/forest_pond_atmosphere.json"))
	for seed in 100:
		var result:=Generator.generate(Request.create(seed,3))
		check(result.valid,"grounded seed %d" % seed)
		if not result.valid: continue
		var original:=Legacy.generate(Request.create(seed,1),result.diagnostics.attempt_index)
		var loaded:=Resolver.resolve(Resolver.generated(seed,3))
		check(loaded.valid,"v3 resolved from recipe with contract v2")
		var context: RefCounted=loaded.context
		var presentation:=Presentation.for_context(context)
		for i in original.interaction_features.size():
			var old: Dictionary=original.interaction_features[i]
			var feature: Dictionary=result.definition.interaction_features[i]
			if old.kind=="grass": continue
			var foot: Array[float]=[]
			for p: Vector2 in old.shape.points:
				if p.y==433: foot.append(p.x)
			if foot.is_empty(): continue # a branch is supported by its trunk
			foot.sort()
			var bottom: float=-INF
			for p: Vector2 in feature.shape.points: bottom=maxf(bottom,p.y)
			for x in range(ceili(foot[0]),floori(foot[-1])+1):
				check(bottom+0.001>=context.floor_at(x),"whole solid contact edge embeds in slope")
			check(feature.fade_group_id==old.fade_group_id,"wood grouping retained")
		for plant: Dictionary in presentation.plants:
			for stem in int(plant.stems):
				var p:=PlantArt._spine(plant,stem,0,2)+Vector2(0,plant.y-129)
				check(absf(p.y-context.floor_at(p.x))<0.001,"every interactive stem reaches its terrain")
				var info: Dictionary={"base":plant.y,"roots":plant.root_y,"width":plant.width,"x":plant.x,"y":plant.y-30,"height":plant.height,"amount":1.0,"bend":4.0}
				check(Binding.deform(p,info).is_equal_approx(p),"binding leaves sloped roots fixed")
		if seed not in [0,42,64]: continue
		var public_map:=Adapter.build(context)
		for visual_seed in [42,713284]:
			var generated:=Dynamic.generate(public_map,profile,visual_seed)
			check(generated.ok,"grounded decorative plan")
			for layer in generated.plan.layers:
				for object in layer.objects:
					var stems: Array=object.get("stems",[])
					if object.kind=="animated_stem": stems=[object.stem]
					for stem in stems:
						check(absf(stem.y-context.floor_at(stem.x)-2)<0.001,"decor roots follow final atmosphere position")
						for camera in [Vector2.ZERO,Vector2(290,120),Vector2(640,120)]:
							check(Frame.layer_offset(camera,generated.plan.parallax_compensation[layer.name])==-camera,"pan cannot detach decorative roots")
	var old:=Resolver.resolve(Resolver.generated(42,2))
	check(old.valid and old.context.map_ref.id=="generated_pond_v2_42","v2 recipe remains available")
	var invalid:=Request.create(42,3); invalid.map_contract_version=3
	check(not Request.validate(invalid).valid,"generator v3 is not schema v3")
	await super.run()
