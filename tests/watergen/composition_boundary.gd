extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
const Adapter=preload("res://scripts/watergen/watergen_public_adapter.gd")
const Plan=preload("res://scripts/watergen/pond_composition_plan.gd")
const Baker=preload("res://scripts/watergen/pond_composition_baker.gd")
var passed:=0
var failed:=0
func check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("COMPOSITION_BOUNDARY_FAIL | "+message)
func _initialize() -> void:
	for seed: int in [42,1346]:
		var a:=World.new(); var b:=World.new()
		var config: Dictionary={"map_source":Resolver.generated(seed,3),"seed":64317,"challenge":false}
		check(a.reset_world(config) and b.reset_world(config),"identical setup")
		var snapshot:=var_to_bytes(a.capture_snapshot())
		var public:=Adapter.build(a.map_context)
		var public_bytes:=var_to_bytes(public)
		for choice in Plan.IDS:
			var generated:=Plan.generate(public,choice,713284)
			check(generated.ok and generated==Plan.generate(public,choice,713284),"deterministic study")
			check(generated.plan.preview_only and generated.plan.logs.size()==1,"explicit non-playable board with one primary wood anchor")
			var turns:=0; var previous_slope:=1.0
			for x in range(8,1280,8):
				var slope:=signf(Plan.height(generated.plan.bed,x)-Plan.height(generated.plan.bed,x-8))
				if slope!=0 and slope!=previous_slope: turns+=1
				if slope!=0: previous_slope=slope
			check(turns==1,"one broad basin, no repeated mounds or extra extrema")
			var baked:=Baker.bake(generated.plan)
			check(baked.ok,"raster valid")
			var endpoints_grounded:=true
			for endpoint: Array in [generated.plan.logs[0].path[0],generated.plan.logs[0].path[-1]]:
				var contact:=false
				for x in range(int(endpoint[0])-10,int(endpoint[0])+10):
					for y in range(int(endpoint[1])-24,mini(480,int(endpoint[1])+24)):
						if baked.anchors.get_pixel(x,y).a>0 and baked.bed.get_pixel(x,y).a>0: contact=true
				if not contact: print("UNSUPPORTED_LOG_END | ",choice," | ",endpoint," | bed_y=",Baker.rim(generated.plan,int(endpoint[0])))
				endpoints_grounded=endpoints_grounded and contact
			check(endpoints_grounded,"both main log ends meet the authored banks or bed")
			var bed_area:=0; var foreground_area:=0; var quiet:=true; var corners_only:=true
			for x in 1280:
				for y in 480:
					if baked.bed.get_pixel(x,y).a>0: bed_area+=1
					if baked.foreground.get_pixel(x,y).a>0:
						foreground_area+=1
						if x in range(200,1080) or y<420: corners_only=false
					if x>=360 and x<920 and y>=70 and y<330:
						for layer in ["bed","anchors","foreground"]:
							if baked[layer].get_pixel(x,y).a>0: quiet=false
			check(bed_area<1280*480*.24,"main terrain occupies less than 24 percent of frame")
			check(foreground_area<1280*480*.025 and corners_only,"foreground below 2.5 percent, local bottom corners only")
			check(quiet,"560 by 260 central water corridor remains completely open")
			check(generated.plan.bed==Plan.generate(public,choice,22).plan.bed,"noise and map seeds cannot alter primary slope design")
			if seed==42: print("COMPOSITION_AREA | %s | bed=%.2f%% | foreground=%.2f%%" % [choice,100.0*bed_area/(1280*480),100.0*foreground_area/(1280*480)])
			check(public_bytes==var_to_bytes(public) and snapshot==var_to_bytes(a.capture_snapshot()),"raster leaves geometry, authority, bait and RNG unchanged")
		# Independent control world never receives a study; compare all evolving state.
		var equal:=true
		for tick in 600:
			if tick%100==0: Plan.generate(public,Plan.IDS[(tick/100)%3],tick+13)
			var input: Dictionary={"move":Vector2.RIGHT if tick<360 else Vector2.DOWN,"aim":Vector2.RIGHT,"feeding":tick%120<30}
			a.advance_tick(input,{}); b.advance_tick(input,{})
			if a.capture_snapshot()!=b.capture_snapshot(): equal=false
		check(equal,"600 ticks preserve physics, food, NPC, hook truth and RNG")
		a.free(); b.free()
	print("COMPOSITION_BOUNDARY | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)
