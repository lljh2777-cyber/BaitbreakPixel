extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Profile=preload("res://scripts/food_profile.gd")
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1; push_error("BAIT_TYPE_FAIL | "+label)
func identities(w: Node2D) -> Array:
	var values: Array=[]
	for bait in w.baits: values.append([bait.bait_id,bait.bait_type,bait.hook])
	return values
func _initialize() -> void:
	var a:=World.new(); var b:=World.new()
	for mode in ["survival","duel"]:
		for seed_value in 64:
			a.reset_world({"seed":seed_value,"ruleset":mode}); b.reset_world({"seed":seed_value,"ruleset":mode})
			check(a.capture_snapshot()==b.capture_snapshot(),"identical seeds include deterministic type positions and event RNG")
			var active: Array=[]
			for bait in a.baits:
				if bait.active: active.append(bait.bait_type)
			check(active.size()==(2 if mode=="duel" else 3),"existing ambient food budget unchanged")
			var unique: Dictionary={}
			for kind in active: unique[kind]=true
			check(unique.size()==active.size(),"survival one each, duel two sampled without replacement")
			var prior:=identities(a)
			a.fish=Vector2(600,300)
			for tick in 5: a.advance_tick({}, {})
			check(identities(a)==prior,"living bait type remains fixed")
	a.reset_world({"seed":213,"ruleset":"duel"})
	var old: Dictionary=a.baits[0]
	old.grains[0].free=true
	var loose: Dictionary=old.grains[0].duplicate(true)
	a.refill_hook_bait(0)
	check(a.baits[0].bait_id!=old.bait_id and a.baits[0].grains[-1]==loose,"rehang rolls new lifecycle while preserving loose food identity/type")
	var type_before: String=a.baits[0].bait_type
	var offsets: Array=[]
	for grain in a.baits[0].grains: offsets.append(grain.offset)
	a.redeploy_bait(0)
	var after: Array=[]
	for grain in a.baits[0].grains: after.append(grain.offset)
	check(a.baits[0].bait_type==type_before and offsets==after,"recasting existing food never morphs its type or shape")
	a.reset_world({"seed":624,"rules":{"water_strength":0.0}})
	var snapshot: Dictionary=a.capture_snapshot()
	check(b.restore_snapshot(snapshot),"typed snapshot restores")
	for tick in 120:
		var command: Dictionary={"move":Vector2(0.2,-0.1),"aim":Vector2.RIGHT,"suck":tick%3==0}
		a.advance_tick(command,{}); b.advance_tick(command,{})
	check(a.capture_snapshot()==b.capture_snapshot(),"typed snapshot replay keeps exact authority and RNG result")
	diagnose(a)
	a.free(); b.free()
	print("BAIT_TYPES | passed=%d | failed=%d" % [passed,failed]); quit(1 if failed else 0)
func diagnose(w: Node2D) -> void:
	# Exercise constrained initial populations and post-rehang assignments separately.
	for mode in ["survival","duel"]:
		for scenario in ["default","zero","max"]:
			var rules: Dictionary={}
			if scenario=="zero": rules={"bait_hook_probability":0.0,"bait_danger_min":0.0,"bait_danger_max":0.0}
			if scenario=="max": rules={"bait_hook_probability":1.0,"bait_danger_min":1.0,"bait_danger_max":2.0,"bait_safe_min":1.0}
			var initial: Dictionary={}; var refill: Dictionary={}
			for kind in Profile.TYPES: initial[kind]=[0,0]; refill[kind]=[0,0]
			for seed_value in 1000:
				w.reset_world({"seed":10000+seed_value,"ruleset":mode,"rules":rules})
				var danger:=0; var population:=0
				for bait in w.baits:
					if not bait.active: continue
					initial[bait.bait_type][0]+=1; initial[bait.bait_type][1]+=int(bait.hook)
					population+=1; danger+=int(bait.hook)
				check(danger<=int(w.rule("bait_danger_max")) and danger>=int(w.rule("bait_danger_min")) and population-danger>=int(w.rule("bait_safe_min")),"types preserve initial hook constraints")
				for replacement in 3:
					w.refill_hook_bait(0)
					var bait: Dictionary=w.baits[0]
					refill[bait.bait_type][0]+=1; refill[bait.bait_type][1]+=int(bait.hook)
			for cohort in [{"name":"initial","counts":initial},{"name":"rehang","counts":refill}]:
				var low:=1.0; var high:=0.0
				for kind in Profile.TYPES:
					var counts: Array=cohort.counts[kind]
					var rate:=float(counts[1])/maxi(1,counts[0]); low=minf(low,rate); high=maxf(high,rate)
					check(counts[0]>=300,"diagnostic has useful sample size for each type")
					print("TYPE_HOOK_DIAGNOSTIC | mode=%s scenario=%s cohort=%s type=%s total=%d hooks=%d rate=%.6f" % [mode,scenario,cohort.name,kind,counts[0],counts[1],rate])
				check(high-low<0.10,"type conditional hook rates within 10pp across constrained "+mode+" "+scenario+" "+cohort.name)
