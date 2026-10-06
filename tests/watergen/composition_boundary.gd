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
			check(generated.plan.logs.size() in [1,2],"bounded primary wood anchors")
			var baked:=Baker.bake(generated.plan)
			check(baked.ok,"raster valid")
			var exact:=true
			for x in 1280:
				for y in 480:
					if (baked.bed.get_pixel(x,y).a>0)!=(y>=ceili(a.map_context.floor_at(x))): exact=false
			check(exact,"soil alpha uses exact existing boundary at every pixel")
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
