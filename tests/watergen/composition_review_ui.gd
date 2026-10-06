extends SceneTree
const Scene=preload("res://scenes/watergen/composition_review.tscn")
var output:="res://artifacts/watergen/composition-review-final"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var review:=Scene.instantiate(); root.add_child(review)
	for frame in 4: await process_frame
	var before:=var_to_bytes(review.game.capture_snapshot())
	review.choose("B")
	for frame in 4: await process_frame
	review.choose("C")
	review.full_world=false; review.refresh()
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var valid: bool=before==var_to_bytes(review.game.capture_snapshot()) and review.game.view.generated_water.study.plan.variant=="C"
	valid=valid and root.get_texture().get_image().save_png(output.path_join("review-controls.png"))==OK
	review.free()
	print("COMPOSITION_REVIEW_UI | passed=%d | failed=%d" % [2 if valid else 0,0 if valid else 1])
	quit(0 if valid else 1)
