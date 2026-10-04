extends SceneTree

const World = preload("res://scripts/world_simulation.gd")
const Shore = preload("res://scripts/shore_view.gd")
const Motion = preload("res://scripts/line_motion.gd")
const Grass = preload("res://scripts/grass_binding.gd")
const Fish = preload("res://scripts/fish_winding.gd")
const NetMotion = preload("res://scripts/net_motion.gd")
const Presentation = preload("res://scripts/maps/map_presentation.gd")
const Fixture = preload("res://tests/fixtures/phase04/authority_fixture.gd")
const Legacy = preload("res://scripts/pond_layout.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error("SHORE_PROJECTION_FAIL | " + label)

func _init() -> void:
	pond_equivalence()
	fixture_projection()
	print("PHASE04_SHORE_PROJECTION | passed=%d | failed=%d" % [passed,failed])
	quit(1 if failed else 0)

func prepare_hook(game: Node2D) -> void:
	game.baits[0].active=true
	game._enter_hook(0)
	game._attach_hook()
	game.elapsed=3.25
	game.tension=0.72
	game.fish_line_length=44

func fingerprint(game: Node2D) -> PackedByteArray:
	# Includes RNG, all serialized Authority/observation data, and map identity.
	return var_to_bytes(game.capture_snapshot())

func pond_equivalence() -> void:
	var game := World.new()
	check(game.reset_world({"seed":918,"water_strength":0.0,"npc_count":3}),"default round initialized")
	var before := fingerprint(game)
	for x: float in [-10.0,0.0,8.0,66.0,320.25,640.0,1238.0,1280.0]:
		for y: float in [0.0,48.0,55.0,68.0,85.0,200.25,385.0,431.0,432.0,433.0,480.0]:
			var point := Vector2(x,y)
			var expected := legacy_to_screen(point)
			check(Shore.to_screen(point,game)==expected,"exact legacy forward projection " + str(point))
			check(Shore.to_world(expected,game)==legacy_to_world(expected),"exact legacy inverse projection " + str(point))
			check(Shore.to_world(expected,game).distance_to(point)<0.001,"pond projection roundtrip " + str(point))
			check(Shore.to_screen(point)==expected and Shore.to_world(expected)==legacy_to_world(expected),"explicit no-world compatibility " + str(point))
			check(Shore.projection_at(y,game)==legacy_projection_at(y),"exact perspective coefficients " + str(point))
	check(fingerprint(game)==before,"projection/default adapter consumes no RNG or Authority state")
	for center: Vector2 in [Vector2(30,85),Vector2(640,200),Vector2(1250,400)]:
		game.net_pos=center
		before=fingerprint(game)
		for phase: Vector3 in [Vector3(0,0,0),Vector3(0.4,0,0),Vector3(1,0,0),Vector3(1,0.5,0.3),Vector3(1,1,1)]:
			var frame := {"center":center,"enter":phase.x,"out":phase.y,"settle":phase.z,"caught":phase.z>0,"drag":Vector2(3,-2),"bag":center+Vector2(4,6)}
			check(NetMotion.shore_pose(game,frame)==legacy_net_pose(game,frame),"exact legacy shore net geometry")
		check(fingerprint(game)==before,"net pose leaves Authority/RNG unchanged")
	prepare_hook(game)
	for start: Vector2 in [Vector2(206,48),Vector2(100,425),Vector2(500,320)]:
		for end: Vector2 in [Vector2(300,200),Vector2(200,432),Vector2(550,340)]:
			for slack: float in [0.0,20.0,120.0]:
				var length := start.distance_to(end)+slack
				check(Motion.strand(game,start,end,length)==legacy_strand(game,start,end,length),"exact legacy strand including floor-limited sag")
	for target in game.targets.size():
		var bounds: Rect2=game.targets[target].bounds
		for y: float in [bounds.position.y+4,bounds.get_center().y,bounds.end.y-8]:
			var wrap: Dictionary=game.MapGeometry.coil_at(game.targets[target],Vector2(bounds.get_center().x,y))
			wrap.target=target
			game.fish=Vector2(bounds.get_center().x+16,minf(y+8,game.map_context.floor_y-14))
			game.wraps.assign([wrap])
			for progress: float in [0.0,0.08,0.25,0.5,0.8,0.95,1.0]:
				game.wraps[0].progress=progress
				before=fingerprint(game)
				check(Grass.profile(game,game.wraps[0],progress)==legacy_grass(game,game.wraps[0],progress),"exact legacy grass lookup/deformation target %d" % target)
				check(Fish.pose(game)==legacy_pose(game),"exact legacy fish orbit target %d" % target)
				check(fingerprint(game)==before,"grass/orbit leaves Authority and RNG unchanged")
	game.free()

func fixture_projection() -> void:
	var definition := Fixture.create()
	# Interleaved target kinds and reversed visual records prevent count-offset
	# lookups from accidentally passing. This stays test-only, never registered.
	definition.visual_features[0].kind="solid"
	definition.visual_features[1].kind="plant"
	definition.visual_features[1].legacy={"x":445,"y":255,"width":24,"height":45,"stems":5,"kind":"fern","back":false}
	definition.interaction_features[1].capabilities.grass_binding=true
	definition.visual_features.reverse()
	Fixture.seal(definition)
	var game := World.new()
	check(game.reset_world({"seed":918,"water_strength":0.0,"npc_count":0},definition),"interleaved distinct-map round initialized")
	var context: RefCounted=game.map_context
	var before := fingerprint(game)
	check(Shore.surface_y(game)==79,"surface follows shifted fixture water")
	check(Shore.to_screen(Vector2(0,79),game)==Shore.ORIGIN+Vector2(219,0),"fixture surface maps to distant lane")
	check(Shore.to_screen(Vector2(context.size.x,context.floor_y-1),game)==Vector2(Shore.ORIGIN.x+640.0*Shore.SCALE.x,Shore.ORIGIN.y+257.0*Shore.SCALE.y),"fixture floor and width fill same view projection")
	for point: Vector2 in [Fixture.SPAWN,Fixture.HOME,Fixture.WATER.position,Fixture.WATER.end,Vector2(0,0),Vector2(800,353)]:
		var projected := Shore.to_screen(point,game)
		check(Shore.to_world(projected,game).distance_to(point)<0.001,"fixture shore roundtrip " + str(point))
		check(projected!=Shore.to_screen(point),"fixture projection never silently defaults to pond " + str(point))
	var route := PackedVector2Array([Vector2(145,120),Vector2(500,120),Vector2(500,300),Vector2(145,300)])
	var projected := Shore.projected(route,game)
	for index in route.size(): check(projected[index]==Shore.to_screen(route[index],game),"route propagates display world")
	var frame := {"center":Vector2(400,220),"enter":1.0,"out":0.0,"settle":0.0,"caught":false,"drag":Vector2(3,5),"bag":Vector2(405,230)}
	var net := NetMotion.shore_pose(game,frame)
	check(net.center==Shore.to_screen(frame.center,game),"net center propagates fixture world")
	check(net.center!=NetMotion.shore_pose(default_world(),frame).center,"fixture net does not use default projection")
	check(fingerprint(game)==before,"fixture projection and net leave Authority and RNG unchanged")
	prepare_hook(game)
	var wrap: Dictionary=game.MapGeometry.coil_at(game.targets[1],Vector2(445,233))
	wrap.target=1; wrap.progress=0.5
	game.wraps.assign([wrap])
	game.tension=0.0
	before=fingerprint(game)
	var cover := Grass.profile(game,wrap,0.5)
	check(not cover.is_empty() and cover.target==1 and cover.plant==0 and cover.x==445.0,"interleaved target resolves correct plant by presentation identity")
	var map := Presentation.for_context(context)
	check(map.plant_for_target(1).feature_id=="grass_net" and map.plant_index_for_target(0)==-1,"plant lookup independent of solid count and visual array ordering")
	wrap=wrap.duplicate()
	wrap.target=3
	check(Grass.profile(game,wrap,0.5).is_empty(),"nonbinding capability cannot invent vegetation binding")
	wrap.target=-1
	check(Grass.profile(game,wrap,0.5).is_empty(),"unknown binding target fails closed")
	var strand := Motion.strand(game,Vector2(300,350),Vector2(420,350),200)
	check(strand[Motion.STEPS/2].y==353.0,"fixture floor limits sag instead of pond floor")
	check(fingerprint(game)==before,"fixture grass/strand leaves Authority and RNG unchanged")
	game.free()
	_default_world.free()

var _default_world: Node2D
func default_world() -> Node2D:
	_default_world=World.new()
	_default_world.reset_world({"seed":918,"npc_count":0})
	return _default_world

# Frozen P4.3 formulas retained as a readable arithmetic oracle. Do not update
# these to call the new map path: they prove pond_v2 keeps every projected bit.
static func legacy_projection_at(y: float) -> Vector2:
	var near := clampf((y-55.0)/(Legacy.FLOOR-1-55.0),0,1)
	return Vector2(lerpf(243,Shore.ORIGIN.x,near),lerpf(0.44,Shore.SCALE.x,near))

static func legacy_to_screen(point: Vector2) -> Vector2:
	var projection := legacy_projection_at(point.y)
	return Vector2(projection.x+point.x*(640.0/Legacy.SIZE.x)*projection.y,Shore.ORIGIN.y+(point.y-55.0)*(257.0/(Legacy.FLOOR-1-55.0))*Shore.SCALE.y)

static func legacy_to_world(point: Vector2) -> Vector2:
	var y := (point.y-Shore.ORIGIN.y)/(Shore.SCALE.y*257.0/(Legacy.FLOOR-1-55.0))+55.0
	var projection := legacy_projection_at(y)
	return Vector2((point.x-projection.x)/projection.y*(Legacy.SIZE.x/640.0),y)

static func legacy_strand(world: Node2D, start: Vector2, end: Vector2, available: float, start_tangent: Vector2=Vector2.ZERO, end_tangent: Vector2=Vector2.ZERO) -> PackedVector2Array:
	var chord := start.distance_to(end)
	var direction := (end-start).normalized()
	var a := start+direction*chord/3
	var b := end-direction*chord/3
	if not start_tangent.is_zero_approx(): a=start+start_tangent.normalized()*minf(9,chord*0.25)
	if not end_tangent.is_zero_approx(): b=end-end_tangent.normalized()*minf(9,chord*0.25)
	var excess := maxf(0,available-chord)
	var bow := minf(30,sqrt(excess*(2*chord+excess))*0.30)
	bow=minf(bow,maxf(0.0,Legacy.FLOOR-1-maxf(start.y,end.y)))
	var normal := direction.orthogonal()
	# A slack strand hangs down rather than flipping to the other side when a
	# moving fish crosses the contact. Anchors stay exact, including at zero length.
	var sag := Vector2(0,bow)
	var points := PackedVector2Array()
	for i in Motion.STEPS+1:
		var p := i/float(Motion.STEPS)
		var wave: float=sin(world.elapsed*16-p*9)*world.tension*0.32*sin(PI*p)
		points.append(start.bezier_interpolate(a,b,end,p)+sag*sin(PI*p)+normal*wave)
	points[0]=start; points[-1]=end
	return points


static func legacy_grass(world: Node2D, wrap: Dictionary, progress: float) -> Dictionary:
	var index: int=int(wrap.target)-Legacy.SOLIDS.size()
	if index<0 or index>=Legacy.PLANTS.size(): return {}
	var plant: Dictionary=Legacy.PLANTS[index]
	var y:=clampf(wrap.center.y,float(plant.y)-float(plant.height)+8,float(plant.y)-7)
	var growth:=clampf((float(plant.y)-y)/float(plant.height),0,1)
	var stem:=int(plant.stems)/2
	var fraction:=float(stem)/maxi(1,int(plant.stems)-1)
	# Match the central stem in the cached pixel plant frame exactly.
	var t:=posmod(int(world.elapsed*12.0/TAU),8)*TAU/12.0
	var x: float=plant.x+(fraction-0.5)*plant.width*(1+growth*0.38)
	x+=sin(t*1.5+plant.x*0.13+stem*0.7+growth*2.1)*growth*2
	var left:=x; var right:=x
	# Near the tips only one stem reaches this height; lower down, bind the
	# neighboring stems that actually exist here, not the spread of the leaves.
	for neighbor in range(maxi(0,stem-1),mini(int(plant.stems),stem+2)):
		var height: float=plant.height if neighbor==stem else plant.height*(0.67+0.33*sin(neighbor*2.37+1.2))
		if float(plant.y)-height>y-3: continue
		var rise:=clampf((float(plant.y)-y)/height,0,1)
		var part:=float(neighbor)/maxi(1,int(plant.stems)-1)
		var px: float=plant.x+(part-0.5)*plant.width*(1+rise*0.38)+sin(t*1.5+plant.x*0.13+neighbor*0.7+rise*2.1)*rise*2
		left=minf(left,px); right=maxf(right,px)
	x=(left+right)*0.5
	var center:=Vector2(x,y)
	var pull: Vector2=(world.line_anchor(world.bound_bait)-center).normalized()*0.65+(world.mouth()-center).normalized()*0.35
	var amount:=Grass.smooth(progress/0.5)
	var info: Dictionary={"target":wrap.target,"plant":index,"x":float(plant.x),"height":float(plant.height),"base":float(plant.y),"y":y,"amount":amount,"bend":pull.x*(1+world.tension*3)*amount}
	var visual: Dictionary=wrap.duplicate()
	visual.center=Grass.deform(center,info)
	visual.radii=Vector2(clampf((right-left)*0.40+1.4,2.1,6.0),1.6)
	visual.pitch=5.0
	visual.entry=Vector2(visual.center)+Vector2(visual.radii.x,-visual.pitch*0.5)
	visual.grass=true
	visual.slant=pull.x*1.4
	info.wrap=visual
	return info


static func legacy_pose(world: Node2D) -> Dictionary:
	var result: Dictionary={"active":false,"position":world.fish,"mouth":world.mouth(),"front":true}
	if world.hooked!=world.HookState.HOOKED or not world.winding() or world.landing or world.net_state=="caught": return result
	var wrap: Dictionary=world.wraps[-1]
	var p: float=clampf(wrap.progress,0,1)
	var cover:=legacy_grass(world,wrap,p)
	if not cover.is_empty(): wrap=cover.wrap
	# Approach, one complete lap, then rejoin the still-moving player. The lap
	# slows at its ends so neither the mouth nor the body teleports into a turn.
	var lap:=clampf((p-0.14)/0.72,0,1)
	var turn:=lap*lap/(2*0.12*0.88) if lap<0.12 else 1-pow(1-lap,2)/(2*0.12*0.88) if lap>0.88 else (lap-0.06)/0.88
	var angle: float=-PI/2+TAU*turn
	var blend:=Fish.smooth(p/0.14)*(1-Fish.smooth((p-0.86)/0.14))
	var center: Vector2=wrap.center
	center.y=clampf(center.y,85,Legacy.FLOOR-21)
	var radius:=Vector2(float(wrap.radii.x)+14,13)
	radius.x=minf(radius.x,maxf(7,minf(center.x-9,Legacy.SIZE.x-9-center.x)))
	var orbit:=center+Vector2(cos(angle),sin(angle))*radius
	var position: Vector2=Vector2(world.fish).lerp(orbit,blend)
	# Projected yaw: narrow gently while rounding either end of the obstacle,
	# instead of abruptly mirroring or turning the belly upside down.
	var near: float=sin(angle)
	var scale: float=0.95+near*0.05
	var orbit_x:=Vector2(-sin(angle),cos(angle)*0.30)*scale
	var facing: Vector2=world.aim
	var upright: Vector2=facing.orthogonal()*(1 if facing.x>=0 else -1)
	var axis_x:=Vector2.from_angle(lerp_angle(facing.angle(),orbit_x.angle(),blend))*lerpf(1,orbit_x.length(),blend)
	var axis_y:=upright.lerp(Vector2(0,scale),blend)
	result.merge({"active":true,"position":position,"mouth":position.round()+axis_x*10,"front":blend<0.95 or near>=0,"axis_x":axis_x,"axis_y":axis_y,"blend":blend,"lap":turn,"center":center,"radii":radius,"shade":lerpf(1,0.87,blend*maxf(0,-near)),"end_on":blend*(1-Fish.smooth(absf(sin(angle))/0.38)),"toward_camera":cos(angle)>0},true)
	return result


static func legacy_net_pose(world: Node2D, frame: Dictionary) -> Dictionary:
	var center:=legacy_to_screen(frame.center)
	var enter: float=frame.enter
	var out: float=frame.out
	# Lift the rigid hoop over the water, dip at A, then pull it towards the camera on exit.
	center=Vector2(-64,385).lerp(center,enter)-Vector2(0,sin(enter*PI)*24)
	center=center.lerp(Vector2(-68,412),out)
	var scale: float=world.rule("net_scale")*lerpf(0.88,1.06,clampf((world.net_pos.y-55)/257.0,0,1))
	var angle: float=-0.38+sin(world.net_angle)*0.16-(1-enter)*0.28-out*0.28
	var u:=Vector2.from_angle(angle)*24*scale
	var v:=Vector2.from_angle(angle).orthogonal()*12*scale
	var grip:=Vector2(147+clampf((center.x-180)*0.20,-15,50),312+clampf((center.y-255)*0.1,-5,6))
	grip.x=minf(grip.x,center.x-78) # Follow a near-left net without folding the shaft back across the wrist.
	grip=Vector2(96,420).lerp(grip,enter).lerp(Vector2(34,427),out)
	var socket:=NetMotion.edge_toward(center,u,v,grip)
	var projected_drag:=legacy_to_screen(frame.center+frame.drag)-legacy_to_screen(frame.center)
	var bag_offset:=Vector2(-7,18)+projected_drag*0.8
	bag_offset=bag_offset.lerp(Vector2(0,22),frame.settle)
	var bag:=center+bag_offset*scale
	return {"center":center,"u":u,"v":v,"bag":bag,
		"bu":Vector2(15,1)*scale,"bv":Vector2(-2,12)*scale,
		"socket":socket,"grip":grip,"caught":frame.caught,"shore":true,
		"hand_angle":clampf((socket-grip).angle()+0.72,-0.48,0.45)}
