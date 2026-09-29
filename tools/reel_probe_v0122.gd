extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Brain=preload("res://scripts/fish_brain.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for scenario in ["idle","ai","resist"]:
		var game=World.new()
		var brain=Brain.new()
		game.reset_world({"ruleset":"duel","challenge":true,"water_strength":0,"seed":2719})
		brain.reset(2719)
		game.fish=Vector2(240,205); game.aim=Vector2.RIGHT
		game.baits[0].active=true; game._enter_hook(0); game._attach_hook()
		for frame in 240:
			var fish_command: Dictionary=brain.command(game,1.0/60) if scenario=="ai" else {}
			if scenario=="resist": fish_command={"move":Vector2.DOWN,"dash":true}
			var command: Dictionary={"reel":true} if frame<120 else {"release":true}
			game.simulate(1.0/60,fish_command,command)
			if frame%30==0:
				print("REEL_PROBE | ",scenario," | frame=",frame," | fish=",game.fish," | tension=",game.tension," | line=",game.rope_length," | stretch=",game.line_anchor(0).distance_to(game.mouth())-game.rope_length," | speed=",game.reel_speed," | state=",game.hooked," | ai=",brain.state)
		game.free()
	quit()
