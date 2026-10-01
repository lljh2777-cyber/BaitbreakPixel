extends SceneTree
const Hand=preload("res://scripts/angler_hand.gd")
const Shore=preload("res://scripts/shore_view.gd")

class RigLayer extends Node2D:
	var hand: RefCounted
	var pose: Dictionary
	func _draw() -> void:
		if not pose.is_empty():
			hand.draw_rod(self,Shore.rod_points(pose,pose.brace,1,Vector2(410,213)))
			hand.draw(self,pose,0,0)

func _initialize() -> void: call_deferred("run")

func connected_to_edge(picture: Image, seed_at: Vector2, checkpoints: Array) -> bool:
	picture.convert(Image.FORMAT_RGBA8)
	var bytes := picture.get_data()
	var width := picture.get_width(); var height := picture.get_height()
	var start := Vector2i(seed_at.round())
	if bytes[(start.y*width+start.x)*4+3]<128: return false
	var visited := PackedByteArray(); visited.resize(width*height)
	var pending := PackedInt32Array([start.y*width+start.x])
	visited[pending[0]]=1
	var cursor := 0; var edge := false
	while cursor<pending.size():
		var index := pending[cursor]; cursor+=1
		var x := index%width; var y := index/width
		if x==width-1 or y==height-1: edge=true
		for dy in range(-1,2):
			for dx in range(-1,2):
				var nx := x+dx; var ny := y+dy
				if nx<0 or ny<0 or nx>=width or ny>=height: continue
				var neighbor := ny*width+nx
				if visited[neighbor] or bytes[neighbor*4+3]<128: continue
				visited[neighbor]=1; pending.append(neighbor)
	if not edge: return false
	for checkpoint: Vector2 in checkpoints:
		var point := Vector2i(checkpoint.round())
		if point.x<0 or point.y<0 or point.x>=width or point.y>=height: continue
		if not visited[point.y*width+point.x]: return false
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var viewport := SubViewport.new(); viewport.size=Vector2i(640,327)
	viewport.transparent_bg=true; viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := RigLayer.new(); viewport.add_child(layer)
	layer.hand=Hand.new(); layer.hand.prepare(layer)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var failed := 0; var passed := 0
	for sample in 42:
		var travel:=sample%21
		var brace:=1.0 if sample>=21 else 0.0
		for phase in [0.0,PI/14]:
			layer.pose=Hand.pose(travel/20.0,phase,-36,brace)
			layer.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			var pose: Dictionary=layer.pose
			var picture := viewport.get_texture().get_image()
			var seed := Hand.point(Vector2(1160,942),pose.wrist,pose.angle)
			var checks := [pose.wrist,Hand.point(Vector2(1090,845),pose.wrist,pose.angle),Hand.point(Vector2(1030,923),pose.wrist,pose.angle)]
			if connected_to_edge(picture,seed,checks): passed+=1
			else:
				failed+=1; push_error("JOINT_ALPHA_GAP | travel="+str(travel)+" phase="+str(phase))
				if failed==1: picture.save_png("res://artifacts/arm-gap-v0159.png")
	print("ARM_ALPHA_V0159 | continuous_alpha_poses=",passed," | failed=",failed)
	viewport.queue_free(); await process_frame; quit(1 if failed else 0)
