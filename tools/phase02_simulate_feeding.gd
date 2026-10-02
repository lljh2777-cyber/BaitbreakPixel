extends SceneTree

# Real 60 Hz paired policy experiment. Authority reads below are instrumentation
# only; feeding_policy.command receives a detached observation and nothing else.
const World=preload("res://scripts/world_simulation.gd")
const Observation=preload("res://scripts/fish_observation.gd")
const Policy=preload("res://tools/phase02_feeding_policy.gd")
const Opponent=preload("res://scripts/angler_brain.gd")
const Profile=preload("res://scripts/food_profile.gd")
var tick_events: Dictionary={"bite":0,"eat":0}

func _initialize() -> void:
	var count:=4
	var first_seed:=21001
	var max_ticks:=22200
	var phase:="pilot"
	var output:="res://artifacts/phase02-feeding-pilot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="): count=int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): first_seed=int(arg.get_slice("=",1))
		if arg.begins_with("--max-ticks="): max_ticks=int(arg.get_slice("=",1))
		if arg.begins_with("--phase="): phase=arg.get_slice("=",1)
		if arg.begins_with("--output="): output=arg.substr(9)
	if count<1 or count>1000 or max_ticks<1 or max_ticks>108600 or not phase in ["pilot","heldout","test"]:
		push_error("invalid feeding experiment arguments"); quit(2); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("cannot create experiment output"); quit(2); return
	var started:=Time.get_ticks_msec()
	var rows: Array=[]
	for index in count:
		for name in Policy.POLICIES:
			var row:=run_round(first_seed+index,name,max_ticks)
			row.phase=phase; rows.append(row)
			print("FEEDING_PROGRESS | ",phase," seed=",first_seed+index," policy=",name," food=",row.food_consumed," hooks=",row.hook_contacts," duration=",row.duration)
		# Preserve completed rows even if a later round fails or times out.
		if not save_json(output.path_join("rounds.json"),rows): quit(2); return
	var summary: Dictionary={"phase":phase,"paired_seeds":count,"first_seed":first_seed,"last_seed":first_seed+count-1,
		"policies":Policy.POLICIES,"tick_seconds":World.TICK_SECONDS,"max_ticks":max_ticks,
		"policy_version":Policy.VERSION,"profile_version":Profile.VERSION,"profiles":Profile.PROFILES,
		"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"definitions":{"SuckOnly":"Standoff suction command policy; unavoidable automatic mouth-range Bite remains enabled.",
			"BiteOnly":"Approach mouth range without suction commands; automatic Bite supplies intake.",
			"Mixed":"Uses observed shape hints, self caution and satiety to choose standoff suction or approach Bite.",
			"feeding_attempts":"World round_stats feeding_attempts: actual suction-state transitions, NOT Bite attempts.",
			"automatic_bite_events":"Observed bite feedback events; automatic events can occur under every policy.",
			"per_type":"Post-tick authority measurement, never supplied to policy; gross satiety is uncapped, effective gain apportioned by gross gain.",
			"feeding_seconds":"Seconds in effective world.feeding state; a Bite event owns its tick and disables that state.",
			"qte":"All fish policies output false: the allowed FishObservation lacks hook/QTE/net state. No hidden-state escape adapter.",
			"win":"Actual world.winner_role, including engine timeout wins; home wins recorded separately."},
		"note":"Small paired bot experiment, not human playability evidence or a forced-winner test. Incomplete rounds remain marked; no seed filtering."}
	if not save_json(output.path_join("summary.json"),summary): quit(2); return
	print("FEEDING_SUMMARY | ",JSON.stringify(summary)); quit()

func run_round(seed_value: int, name: String, max_ticks: int) -> Dictionary:
	var world:=World.new()
	world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival"})
	var controller:=Policy.new(); controller.reset(name)
	var opponent:=Opponent.new()
	world.feedback_requested.connect(_on_feedback)
	var seen: Dictionary={}
	var per_type: Dictionary={}
	for kind in Profile.TYPES: per_type[kind]=fresh_type()
	var automatic_bites:=0
	var bite_during_suction:=0
	var suck_ticks:=0
	var feeding_ticks:=0
	var suction_command_attempts:=0
	var prior_suck:=false
	var trace: Array=[]
	var last_mode:=""
	var last_target:=-1
	for frame in max_ticks:
		var observation:=Observation.build(world,false)
		var command: Dictionary=controller.command(observation,World.TICK_SECONDS)
		if controller.mode!=last_mode or controller.target_id!=last_target:
			trace.append({"tick":int(observation.tick),"target":controller.target_id,"kind":controller.target_kind,
				"mode":controller.mode,"caution":observation.self.caution_state,"satiety":observation.self.satiety})
			last_mode=controller.mode; last_target=controller.target_id
		var commanded_suck: bool=command.suck
		if commanded_suck:
			suck_ticks+=1
			if not prior_suck: suction_command_attempts+=1
		prior_suck=commanded_suck
		var before_score: float=world.score
		var before_satiety: float=world.satiety
		tick_events={"bite":0,"eat":0}
		world.advance_tick(command,opponent.command(world,World.TICK_SECONDS))
		automatic_bites+=int(tick_events.bite)
		if commanded_suck: bite_during_suction+=int(tick_events.bite)
		if world.feeding: feeding_ticks+=1
		if world.score>before_score+0.0000001:
			var consumed: Array[Dictionary]=[]
			var gross:=0.0
			for bait: Dictionary in world.baits:
				for grain: Dictionary in bait.grains:
					if not grain.eaten or seen.has(grain.id) or not world.counted.has(grain.id): continue
					seen[grain.id]=true
					var kind: String=grain.visual_kind
					var points: float=grain.points
					var satiety_gain: float=points*world.rule("satiety_food_value")*float(Profile.get_profile(kind).satiety_scale)
					gross+=satiety_gain
					consumed.append({"kind":kind,"points":points,"gross":satiety_gain})
			var no_food_satiety:=maxf(0.0,before_satiety-world.rule("satiety_decay")*World.TICK_SECONDS)
			var effective:=maxf(0.0,world.satiety-no_food_satiety)
			var bite_types: Dictionary={}
			for grain in consumed:
				var metric: Dictionary=per_type[grain.kind]
				metric.grains+=1; metric.food+=grain.points; metric.satiety_gross+=grain.gross
				metric.satiety_effective+=effective*grain.gross/maxf(0.000001,gross)
				if tick_events.bite>0:
					metric.automatic_bite_grains+=1; metric.automatic_bite_food+=grain.points; bite_types[grain.kind]=true
				else:
					metric.suction_grains+=1; metric.suction_food+=grain.points
			for kind in bite_types: per_type[kind].automatic_bite_events+=1
		if world.match_over: break
	var row: Dictionary={"seed":seed_value,"policy":name,"ticks":world.simulation_tick,"duration":world.elapsed,
		"completed":world.match_over,"winner":world.winner_role,"reason":world.reason,"home_win":world.winner_role=="fish" and world.reason=="home",
		"food_consumed":world.score,"satiety_final":world.satiety,"satiety_mean":world.round_stats.satiety_mean,"satiety_min":world.round_stats.satiety_min,
		"hook_contacts":world.hook_count,"hook_events":world.round_stats.hook_events,"escapes":world.escape_count,
		"feeding_attempts":world.round_stats.feeding_attempts,"feeding_seconds":feeding_ticks*World.TICK_SECONDS,
		"suction_command_attempts":suction_command_attempts,"suction_command_seconds":suck_ticks*World.TICK_SECONDS,
		"automatic_bite_events":automatic_bites,"automatic_bite_while_suction_command":bite_during_suction,
		"per_type":per_type,"mode_seconds":controller.mode_seconds,"mode_choices":controller.choice_counts,"mode_switches":controller.switches,
		"decision_trace":trace,"stats":world.round_stats.duplicate(true)}
	world.free()
	return row

func fresh_type() -> Dictionary:
	return {"grains":0,"food":0.0,"satiety_gross":0.0,"satiety_effective":0.0,"automatic_bite_events":0,
		"automatic_bite_grains":0,"automatic_bite_food":0.0,"suction_grains":0,"suction_food":0.0}

func _on_feedback(cue: String) -> void:
	if tick_events.has(cue): tick_events[cue]+=1

func save_json(path: String, value: Variant) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("cannot write "+path); return false
	file.store_string(JSON.stringify(value,"\t")); file.close(); return true
