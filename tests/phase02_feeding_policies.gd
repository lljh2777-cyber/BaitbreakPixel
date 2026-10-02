extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("FEEDING_POLICY_FAIL | "+label)
func fixture(kind: String="cluster") -> Dictionary:
	return {"tick":0,"self":{"fish_id":1,"position":Vector2(200,200),"mouth":Vector2(211,200),
		"aim":Vector2.RIGHT,"velocity":Vector2.ZERO,"stamina":100.0,"stamina_ratio":1.0,
		"caution_state":"CALM","satiety":100.0,"satiety_band":"NORMAL","instinct_drive":0.0,
		"score":0.0,"power":0.35,"feeding":false},
		"perceived_baits":[{"bait_id":1,"band":"near","distance":42.0,"has_attached_food":true,
			"food_position":Vector2(242,200),"hints":{"shape_hint":{"cluster":"grain_cluster","worm":"slender_curved","chunk":"solid_chunk"}[kind],
			"motion":{"water_drift":Vector2.ZERO}}}]}
func _initialize() -> void:
	var mixed:=Policy.new(); mixed.reset("Mixed")
	for kind in ["cluster","worm","chunk"]:
		var observation:=fixture(kind)
		var original:=observation.duplicate(true)
		var mode:=mixed.choose_mode(observation.perceived_baits[0],observation.self)
		check(mode==("suck" if kind=="cluster" else "bite"),"Mixed responds to observed "+kind+" shape")
		mixed.command(observation,World.TICK_SECONDS)
		check(observation==original,"policy leaves detached observation immutable")
	var risk:=fixture("chunk")
	risk.self.caution_state="ALARMED"
	check(mixed.choose_mode(risk.perceived_baits[0],risk.self)=="suck","fed alarmed fish uses standoff suction")
	risk.self.satiety=15.0; risk.self.satiety_band="CRITICAL"
	check(mixed.choose_mode(risk.perceived_baits[0],risk.self)=="bite","critical hunger changes Mixed choice on same observed food")
	risk.perceived_baits[0].hints.erase("shape_hint")
	check(Policy.observed_kind(risk.perceived_baits[0])=="unknown","far/absent shape never filled from private type")
	for name in Policy.POLICIES:
		var first:=Policy.new(); first.reset(name)
		var second:=Policy.new(); second.reset(name)
		var input:=fixture()
		var command: Dictionary=first.command(input,World.TICK_SECONDS)
		check(command==second.command(input,World.TICK_SECONDS),name+" deterministic from same observation")
		check(not command.qte,name+" cannot use unavailable hook/QTE truth")
		if name=="BiteOnly": check(not command.suck and Vector2(command.move).x>0,name+" closes to automatic Bite without suction")
		if name=="SuckOnly": check(command.suck and Vector2(command.move).length()<0.0001,name+" holds 31px mouth standoff inside 44px cone")
	var home:=Policy.new(); home.reset("Mixed")
	var state:=fixture(); state.self.score=60.0; state.self.position=Vector2(60,401)
	check(home.command(state,World.TICK_SECONDS).home,"home interaction issued from public score/map")
	check(not home.command(state,World.TICK_SECONDS).home,"home interaction is not toggled every tick")
	var world:=World.new(); world.reset_world({"seed":234,"rules":{"water_strength":0.0}})
	var observation:=Observation.build(world,false)
	for bait in world.baits: bait.hook=not bait.hook
	var altered:=Observation.build(world,false)
	check(observation==altered,"hidden hook labels do not change feeding observations")
	for name in Policy.POLICIES:
		var before:=Policy.new(); before.reset(name)
		var after:=Policy.new(); after.reset(name)
		check(before.command(observation,World.TICK_SECONDS)==after.command(altered,World.TICK_SECONDS),name+" command invariant to hidden hook truth")
	world.free()
	# Real neutral 60 Hz tick under each named policy retains automatic mouth Bite.
	for name in Policy.POLICIES:
		world=World.new(); world.reset_world({"seed":61,"rules":{"water_strength":0.0,"instinct_max_strength":0.0}})
		world.fish=Vector2(250,200); world.aim=Vector2.RIGHT
		for bait in world.baits:
			bait.active=false; bait.hook=false
			for grain in bait.grains: grain.eaten=true
		var grain: Dictionary=world.baits[0].grains[0]
		grain.eaten=false; grain.free=true; grain.pos=world.mouth()+Vector2(3,0)
		var controller:=Policy.new(); controller.reset(name)
		world.advance_tick(controller.command(Observation.build(world,false),World.TICK_SECONDS),{})
		check(world.simulation_tick==1 and is_equal_approx(world.elapsed,1.0/60.0),name+" runs actual fixed step")
		check(world.score>0 and world.bite_cooldown>0,name+" honestly retains automatic Bite including SuckOnly")
		world.free()
	print("FEEDING_POLICY | passed=%d | failed=%d" % [passed,failed]); quit(0 if failed==0 else 1)
