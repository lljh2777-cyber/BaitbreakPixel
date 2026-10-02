extends SceneTree
const Left=preload("res://scripts/reel_hand.gd")
const Right=preload("res://scripts/angler_hand.gd")
const Rig=preload("res://scripts/angler_rig.gd")
class Layer extends Node2D:
	var hand=Left.new()
	var pose:Dictionary={}
	func _draw() -> void:
		if not pose.is_empty(): hand.draw_hand(self,pose)
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This check needs a renderer; rerun without --headless.")
		quit(2)
		return
	call_deferred("run")
func reaches_bottom(picture:Image,start_at:Vector2) -> bool:
	picture.convert(Image.FORMAT_RGBA8)
	var bytes:=picture.get_data(); var width:=picture.get_width(); var height:=picture.get_height()
	var start:=Vector2i(start_at.round())
	if bytes[(start.y*width+start.x)*4+3]<128: return false
	var visited:=PackedByteArray(); visited.resize(width*height)
	var pending:=PackedInt32Array([start.y*width+start.x]); visited[pending[0]]=1
	var cursor:=0
	while cursor<pending.size():
		var index:=pending[cursor]; cursor+=1
		var x:=index%width; var y:=index/width
		if y==height-1: return true
		for dy in range(-1,2):
			for dx in range(-1,2):
				var nx:=x+dx; var ny:=y+dy
				if nx<0 or ny<0 or nx>=width or ny>=height: continue
				var neighbor:=ny*width+nx
				if visited[neighbor] or bytes[neighbor*4+3]<128: continue
				visited[neighbor]=1; pending.append(neighbor)
	return false
func run() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(640,327); viewport.transparent_bg=true
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var layer:=Layer.new(); viewport.add_child(layer); layer.hand.prepare(layer)
	var rig=Rig.new(); rig.reel_hand_amount=1.0
	var passed:=0; var failed:=0
	for sample in 6:
		var horizontal:float=(sample%3)*0.5
		var brace:=1.0 if sample>=3 else 0.0
		for mode in [-1,1]:
			for phase in 8:
				rig.reel_hand_mode=mode; rig.reel_phase=phase*TAU/8; rig.release_phase=phase*TAU/8
				layer.pose=Left.pose(Right.pose(horizontal,0,0,brace),rig); layer.queue_redraw()
				await process_frame; await RenderingServer.frame_post_draw
				var picture:=viewport.get_texture().get_image()
				var palm:=Left.sprite_point(Vector2(0.64,0.49),layer.pose)
				if reaches_bottom(picture,palm): passed+=1
				else: failed+=1; push_error("LEFT_HAND_DISCONNECTED | %s %s %s" % [horizontal,mode,phase])
	var pixels:Image=layer.hand.texture.get_image(); var hard_alpha:=true
	for y in pixels.get_height():
		for x in pixels.get_width():
			var alpha:=pixels.get_pixel(x,y).a
			hard_alpha=hard_alpha and (alpha==0 or alpha==1)
	if pixels.get_size()==Vector2i(128,64) and hard_alpha: passed+=1
	else: failed+=1; push_error("LEFT_HAND_PIXEL_GRID")
	print("REEL_HAND_NATIVE_V016 | passed=",passed," | failed=",failed)
	viewport.queue_free(); await process_frame; quit(1 if failed else 0)
