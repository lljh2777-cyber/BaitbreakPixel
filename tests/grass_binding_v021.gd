extends SceneTree
const World=preload("res://scripts/world_simulation.gd")
const Grass=preload("res://scripts/grass_binding.gd")
const Motion=preload("res://scripts/line_motion.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("GRASS_BIND_PASS | ",label)
	else: failed+=1; push_error("GRASS_BIND_FAIL | "+label)
func run() -> void:
	var w=World.new(); w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0})
	w.fish=Vector2(150,260); w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	for target in range(w.Layout.SOLIDS.size(),w.targets.size()):
		var bounds:Rect2=w.targets[target].bounds
		var good_width:=true; var anchored:=true; var connected:=true; var immutable:=true; var reversible:=true
		for y in [bounds.position.y+4,bounds.get_center().y,bounds.end.y-8]:
			var coil:Dictionary=w.Layout.coil_at(w.targets[target],Vector2(bounds.get_center().x,y)); coil.target=target
			w.wraps.assign([coil]); w.elapsed=4; w.fish=Vector2(bounds.get_center().x+16,minf(y+8,w.Layout.FLOOR-14))
			for reverse in [false,true]:
				w.untangle_phase="unwind" if reverse else ""
				for i in 31:
					var progress:=i/30.0
					w.wraps[0].progress=progress
					var snapshot:PackedByteArray=var_to_bytes(w.capture_snapshot())
					var profile:=Grass.profile(w,w.wraps[0],progress)
					var ring:=Motion.coil(profile.wrap,progress,reverse)
					var route:=Motion.new().sample(w)
					var b:=Rect2(ring.points[0],Vector2.ZERO)
					for point in ring.points: b=b.expand(point)
					good_width=good_width and b.size.x<=15 and b.size.y<=10
					anchored=anchored and Grass.deform(Vector2(profile.x,profile.base),profile)==Vector2(profile.x,profile.base)
					connected=connected and route.path[0]==w.line_anchor(0) and route.path[-1].is_equal_approx(route.fish.mouth) and route.tail==route.path.slice(route.path.size()-route.tail.size())
					immutable=immutable and snapshot==var_to_bytes(w.capture_snapshot())
					if i==30: reversible=reversible and absf(ring.points[-1].y-ring.points[0].y-5)<0.001
		check(good_width and anchored,"compact stem binding at tip/middle/root with stationary roots: target %d" % target)
		check(connected and immutable,"both directions keep a single connected route and unchanged physics: target %d" % target)
		check(reversible,"one open helical turn has separate entry/exit instead of a floating closed ring: target %d" % target)
	# The wider leaves must not determine the near-tip binding radius.
	var c:Dictionary=w.Layout.coil_at(w.targets[w.Layout.SOLIDS.size()+1],Vector2(150,366)); c.target=w.Layout.SOLIDS.size()+1
	var tip:=Grass.profile(w,c,1.0)
	c.center.y=419
	var base:=Grass.profile(w,c,1.0)
	check(tip.wrap.radii.x<base.wrap.radii.x and tip.wrap.radii.x<=2.2,"sparse fern tip binds one stem while the lower bundle widens naturally")
	var root_left:=Vector2(base.x-10,base.base); var root_right:=Vector2(base.x+10,base.base)
	check(Grass.deform(root_left,base)==root_left and Grass.deform(root_right,base)==root_right,"the entire root row stays fixed, including short clumps")
	var a:=Grass.deform(Vector2(base.x+8,base.y),base)
	w.tension=1; var loaded:=Grass.profile(w,c,1)
	check(a.distance_to(Grass.deform(Vector2(base.x+8,base.y),loaded))<4,"load deformation stays subtle rather than dragging the clump through the scene")
	w.wraps.assign([c]); w.untangle_phase="unwind"; w.wraps[0].progress=0.0001
	var before:PackedVector2Array=Motion.build(w).path
	var offset:float=w.fish_line_length-Vector2(w.wraps[0].entry).distance_to(w.mouth())
	w.wraps.clear(); w.untangle_phase=""; w.rope_length=w.line_anchor(0).distance_to(w.mouth())+offset+0.32*32
	var after:PackedVector2Array=Motion.build(w).path
	var gap:=0.0
	for p in before:
		var nearest:=INF
		for i in range(1,after.size()): nearest=minf(nearest,p.distance_to(Geometry2D.get_closest_point_to_segment(p,after[i-1],after[i])))
		gap=maxf(gap,nearest)
	check(gap<0.20,"last grass contact releases smoothly into the free strand")
	w.free()
	print("GRASS_BINDING_V0183 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
