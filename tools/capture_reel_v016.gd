extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Shore=preload("res://scripts/shore_view.gd")
var game:Node2D
var frame:=0
var done:=false
var capture_tag:="v016"
var free_spool_preview:=false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-tag="): capture_tag=argument.get_slice("=",1)
		if argument=="--free-spool-preview": free_spool_preview=true
	game=Main.instantiate(); root.add_child(game)
	game.capture_mode="reel-motion"; game.save_path="user://reel-motion-v016.cfg"
	game.set_process(false); game.set_physics_process(false)
	game.reset(false,"angler"); game.menu.close(); game.water_strength=0.6
	game.angler.x=440; game.fish=Vector2(100,275)
	game.baits[0].active=true; game.baits[0].pos=game.angler.anchor()+Vector2(0,132)
	game.angler.previous_anchor=game.angler.anchor(); game.angler.step_tackle_feedback(game,1.0/60)
	game.break_hold_seconds=10; game.slack_hold_seconds=3
func _process(_delta:float) -> bool:
	if not is_instance_valid(game) or done: return false
	var command:={"walk":0.0}
	if frame>=30 and frame<210: command.walk=-1.0
	elif frame>=270 and frame<450: command.walk=1.0
	if free_spool_preview:
		if frame>=30 and frame<150: command.reel=true
		elif frame>=180 and frame<330: command.release=true
	if frame==510:
		game.angler.x=280; game.fish=Vector2(310,235); game._enter_hook(0); game._attach_hook()
		game.practice_effort_frequency=0.5
	if frame>=540 and frame<660: command.reel=true
	elif frame>=690 and frame<810: command.release=true
	elif frame>=840 and frame<930: command.reel=true
	var fish_input:={}
	if frame>=510: fish_input={"move":Vector2.DOWN,"dash":false}
	game.advance_tick(fish_input,command)
	game.view.queue_redraw()
	if frame in [29,65,120,200,245,330,449,545,575,590,605,620,650,700,725,750,780,850,910,989]: capture(frame)
	frame+=1
	if frame>=1020: done=true; finish()
	return false
func capture(index:int) -> void:
	await RenderingServer.frame_post_draw
	var path:="res://artifacts/reel-%04d-%s.png" % [index,capture_tag]
	root.get_texture().get_image().save_png(path)
	var tip:Vector2=Shore.rod_tip(game,game.elapsed)
	var bobber:Vector2=Shore.float_position(game,game.elapsed)
	print("REEL_CAPTURE | ",index," | side=",bobber.x-tip.x," | hand=",game.angler.reel_hand_mode," / ",game.angler.reel_hand_amount," | speed=",game.reel_speed)
func finish() -> void:
	await RenderingServer.frame_post_draw
	print("REEL_MOVIE | frames=",frame)
	game.queue_free(); await process_frame; quit()
