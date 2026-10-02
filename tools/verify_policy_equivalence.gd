extends SceneTree
# Compare commands on the same world, with independent identically seeded brains.
const World=preload("res://scripts/world_simulation.gd")
const CurrentBrain=preload("res://scripts/fish_brain.gd")
const Angler=preload("res://scripts/angler_brain.gd")
func _initialize() -> void:
	var reference:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference="): reference=arg.substr(12)
	if reference.is_empty(): push_error("explicit frozen reference brain path required"); quit(2); return
	var old_script: Script=load(reference)
	if old_script==null: quit(2); return
	var frames:=0
	for seed_value in range(3001,3011):
		var world:=World.new(); world.reset_world({"seed":seed_value,"challenge":true,"ruleset":"survival"})
		var old: RefCounted=old_script.new(); old.reset(seed_value+100000); old.use_caution=true
		var current:=CurrentBrain.new(); current.reset(seed_value+100000); current.use_caution=true; current.commit_meal=true
		var opponent:=Angler.new()
		for frame in 22200:
			var a: Dictionary=old.command(world,World.TICK_SECONDS)
			var b: Dictionary=current.command(world,World.TICK_SECONDS)
			if var_to_bytes(a)!=var_to_bytes(b):
				push_error("EQUIVALENCE_FAIL | seed=%d tick=%d" % [seed_value,frame]); world.free(); quit(1); return
			frames+=1
			world.advance_tick(a,opponent.command(world,World.TICK_SECONDS))
			if world.match_over: break
		world.free()
	print("EQUIVALENCE_PASS | seeds=10 | identical_command_ticks=",frames)
	quit()
