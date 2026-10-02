extends SceneTree

const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const FoodProfile=preload("res://scripts/food_profile.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("BAIT_OBSERVATION_PASS | ",label)
	else: failed+=1; push_error("BAIT_OBSERVATION_FAIL | "+label)

func no_private(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if key in ["bait_type","profile","hook","hook_id","tackle","rng_seed","rng_state","future_secret","suction_efficiency","bite_efficiency","satiety_scale","fragmentation"]: return false
			if not no_private(value[key]): return false
	elif value is Array:
		for item in value:
			if not no_private(item): return false
	return true

func place(world: Node2D, kind: String, position: Vector2) -> void:
	world.baits[0]=world._assign_bait_identity(world._make_bait(0,0,kind),0)
	var bait: Dictionary=world.baits[0]
	bait.active=true; bait.pos=position; bait.angle=0.0; bait.suction_offset=Vector2.ZERO
	for grain: Dictionary in bait.grains: grain.pos=position+Vector2(grain.offset)

func _initialize() -> void:
	var world:=World.new(); world.reset_world({"seed":2202})
	world.fish=Vector2(250,200)
	for bait: Dictionary in world.baits: bait.active=false
	for kind: String in FoodProfile.TYPES:
		var profile:=FoodProfile.get_profile(kind)
		for distance: float in [30.0,100.0,200.0]:
			place(world,kind,world.fish+Vector2(distance,0))
			var before: PackedByteArray=var_to_bytes(world.capture_snapshot())
			var observed:=Observation.build(world)
			var entry: Dictionary=observed.perceived_baits[0]
			check(var_to_bytes(world.capture_snapshot())==before,kind+" projection does not consume RNG or mutate authority at "+entry.band)
			check(entry.visual.visual_kind==kind and entry.visual.shape_hint==profile.shape_hint and entry.visual.smell_hint==profile.smell_hint,kind+" visual cues derive from visible profile at "+entry.band)
			var grains_match:=true
			for grain: Dictionary in entry.visual.grains:
				grains_match=grains_match and grain.visual_kind==kind and grain.keys()==Observation.VISUAL_GRAIN_FIELDS
			check(grains_match and no_private(observed),kind+" only allowlisted public cues cross the boundary at "+entry.band)
			if entry.band=="far":
				check(entry.hints.keys()==["approx_position","approx_size"],kind+" far decisions retain only coarse position and size")
			else:
				check(entry.hints.shape_hint==profile.shape_hint and entry.hints.smell_hint==profile.smell_hint and entry.hints.smell=="food",kind+" medium/near decisions expose only legal type cues")
			var hints:=Observation.build(world,false)
			var without_visuals:=observed.duplicate(true)
			for item: Dictionary in without_visuals.perceived_baits: item.erase("visual")
			check(hints==without_visuals and Protocol.safe_values(hints),kind+" hint-only observation retains distance semantics at "+entry.band)
			world.baits[0].hook=true; world.baits[0].hook_id=987
			world.baits[0].bait_type="chunk" if kind!="chunk" else "worm"
			world.baits[0].future_secret={"profile":{"suction_efficiency":0.1}}
			for grain: Dictionary in world.baits[0].grains: grain.future_secret=true
			check(Observation.build(world)==observed,kind+" hook truth, authority type and unknown fields cannot change visible food cues")
	place(world,"chunk",Vector2(280,200))
	var bait: Dictionary=world.baits[0]
	var loose: Dictionary=bait.grains[0].duplicate(true)
	loose.id="old-worm"; loose.visual_kind="worm"; loose.free=true; loose.pos=Vector2(270,200)
	bait.grains.append(loose); bait.active=false
	var mixed:=Observation.build(world)
	var old_food: Dictionary=mixed.perceived_baits[0]
	check(old_food.visual.visual_kind=="worm" and old_food.visual.grains.size()==1 and old_food.hints.shape_hint=="slender_curved","hidden replacement chunk cannot relabel old visible worm fragments")
	bait.bait_type="cluster"
	check(Observation.build(world)==mixed,"changing an invisible reserve type leaves old food observation byte-equivalent")
	bait.active=true
	var deployed: Dictionary=Observation.build(world).perceived_baits[0]
	check(deployed.visual.visual_kind=="chunk" and deployed.visual.grains[-1].visual_kind=="worm","new attached food and older loose fragments keep distinct visible kinds")
	deployed.visual.grains[0].visual_kind="worm"; deployed.visual.shape_hint="changed"
	check(bait.grains[0].visual_kind=="chunk","mutating type cues in a detached observation cannot alter authority")
	bait.active=false; loose.eaten=true
	check(Observation.build(world).perceived_baits.is_empty(),"a wholly invisible reserve has no type or hint record")
	world.free()
	print("PHASE02_OBSERVATION_TESTS | passed=%d | failed=%d" % [passed,failed])
	quit(0 if failed==0 else 1)
