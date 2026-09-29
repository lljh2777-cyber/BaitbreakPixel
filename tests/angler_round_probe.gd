extends SceneTree
const Main=preload("res://scenes/main.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=Main.instantiate()
	root.add_child(game)
	game.capture_mode="test"
	game.set_process(false)
	game.set_physics_process(false)
	for trial in range(4):
		game.reset(true,"angler")
		game.fish_brain.reset(2719+trial)
		var paying_out := false
		var last_hook := 0
		for frame in range(21610):
			var command: Dictionary={"target":game.fish+Vector2(28,0)}
			if game.hooked==game.HookState.FREE:
				command.cast=frame==1 or (game.escape_count>0 and frame%240==0)
				command.target=Vector2(180,110) if frame<240 else game.fish+Vector2(28,0)
			else:
				if game.tension>0.84: paying_out=true
				if game.tension<0.70: paying_out=false
				command.reel=not paying_out
				command.release=paying_out
				command.walk=signf(game.fish.x-game.angler.anchor().x) if absf(game.fish.x-game.angler.anchor().x)>12 else 0
				command.net=trial%2==1 and game.stamina<85 and game.hooked==game.HookState.HOOKED and game.angler.net_cooldown<=0
			game.controlled_step(1.0/60,command)
			if trial==1 and game.hooked!=last_hook:
				print("TRANSITION | t=",game.clock," hook=",game.hooked," result=",game.qte_result," high=",game.high_age," notice=",game.notice," stamina=",game.stamina," fish=",game.fish)
			last_hook=game.hooked
			if frame%600==0: print("PROBE | trial=",trial," time=",snappedf(game.clock,0.1)," hook=",game.hooked," food=",snappedf(game.score,0.1)," state=",game.fish_brain.state," t=",snappedf(game.tension,0.01)," fish=",game.fish," stamina=",snappedf(game.stamina,0.1))
			if game.won or game.lost: break
		print("PROBE_RESULT | trial=",trial," won=",game.won," reason=",game.reason," time=",game.clock," hooks=",game.hook_count," escapes=",game.escape_count)
	game.queue_free()
	await process_frame
	quit()
