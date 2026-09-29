extends SceneTree
const Suite=preload("res://tests/line_motion_v0181.gd")
const Motion=preload("res://scripts/line_motion.gd")
const Shore=preload("res://scripts/shore_view.gd")
func _initialize() -> void:
	var suite=Suite.new()
	var bytes:=PackedByteArray()
	for target in [0,1,12]:
		var w=suite.fixture(target)
		w.untangle_phase="unwind"
		for i in 43:
			w.wraps[0].progress=1-i/42.0; w.untangle_age=i/42.0*w.UNWIND_SECONDS; w.elapsed=4+i/60.0
			var frame:=Motion.new().sample(w)
			bytes.append_array(var_to_bytes([frame.path,frame.front,frame.tail,frame.effects,frame.action,Shore.tackle_pose(w,w.elapsed),Shore.float_position(w,w.elapsed)]))
		w.free()
	var hashing:=HashingContext.new(); hashing.start(HashingContext.HASH_SHA256); hashing.update(bytes)
	print("UNWIND_BASELINE | ",hashing.finish().hex_encode())
	suite.free(); quit()
