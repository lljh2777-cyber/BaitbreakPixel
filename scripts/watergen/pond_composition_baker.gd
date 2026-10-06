extends RefCounted
## Static pixel layers, prepared on selection only. No sprite is an interaction target.
const Plan=preload("res://scripts/watergen/pond_composition_plan.gd")
const Seed=preload("res://scripts/watergen/water_visual_seed.gd")
const Raster=preload("res://scripts/watergen/water_raster.gd")
const Field=preload("res://scripts/watergen/water_visual_baker.gd")

static func canvas() -> Image:
	var result:=Image.create(1280,480,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	return result

static func bake(plan: Dictionary) -> Dictionary:
	if plan.get("version")!=Plan.VERSION: return {"ok":false,"code":"PLAN"}
	var far:=canvas(); var anchors:=canvas(); var bed:=canvas(); var foreground:=canvas()
	_surface(far,plan)
	_soil(bed,plan)
	# Only broad grouped rock masses and ONE wood anchor, no ecological dressing.
	for i in plan.rocks.size(): _rock(anchors,plan,plan.rocks[i],i)
	for i in plan.logs.size(): _log(anchors,plan,plan.logs[i],i)
	_foreground(foreground,plan)
	return {"ok":true,"far":far,"anchors":anchors,"bed":bed,"foreground":foreground}

static func grain(x: int, y: int, salt: int=0) -> float:
	var n: int=(x*374761393+y*668265263+salt*362437) & 0x7fffffff
	n=((n ^ (n >> 13))*1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0x7fffffff)/2147483647.0

static func rim(plan: Dictionary, x: int) -> int:
	# At most two pixels of erosion; authored banks determine every broad slope.
	return roundi(Plan.height(plan.bed,x)+(Field._noise(Vector2(x/29.0,1),4.1)-.5)*4)

static func _surface(image: Image, plan: Dictionary) -> void:
	var dark:=Color("244d54"); var light:=Color("436367")
	for x in 1280:
		var top:=roundi(Plan.height(plan.far,x))
		for y in range(top,480):
			var value:=.35+Field._noise(Vector2(x/97.0,y/43.0),7.4)*.16
			var color:=dark.lerp(light,floorf(value*16)/16)
			color.a=.62*minf(1,float(y-top+1)/7)
			image.set_pixel(x,y,color)

static func _rock(image: Image, plan: Dictionary, spec: Array, index: int) -> void:
	var rng:=Seed.stream(plan.visual_seed,Plan.VERSION,plan.variant+"/rock",index)
	var p:=Vector2(spec[0],0); var w: float=spec[1]; var h: float=spec[2]
	p.y=Plan.height(plan.bed,p.x)+8
	var outline:=PackedVector2Array([p+Vector2(-w*.55,6),p+Vector2(-w*.51,-h*.29),p+Vector2(-w*.31,-h*.83),p+Vector2(-w*.10,-h),p+Vector2(w*.20,-h*.95),p+Vector2(w*.46,-h*.48),p+Vector2(w*.54,5)])
	var pale:=Color("9baba0"); var dark:=Color("304b50")
	for x in range(maxi(0,int(p.x-w)),mini(1280,int(p.x+w))):
		for y in range(maxi(0,int(p.y-h)-1),mini(480,int(p.y)+7)):
			var point:=Vector2(x+.5,y+.5)
			if not Geometry2D.is_point_in_polygon(point,outline): continue
			var u: float=(x-p.x)/w; var v: float=(p.y-y)/h
			var face:=0.22 if u>.05+v*.08 else 0.43 if v<.70-u*.5 else .66
			face+=Field._noise(Vector2(x/21.0,y/15.0),2.6)*.06-.03
			var c:=dark.lerp(pale,face)
			c.a=clampf((p.y+6-y)/9.0,0,1)
			image.set_pixel(x,y,c)
	# Broad facets only. Fine stone texture belongs to a later detail pass.
	var seam:=p+Vector2(rng.randf_range(-.15,.12)*w,-h*.67)
	Raster.line(image,seam,seam+Vector2(w*.16,h*.36),Color("3c595b"))

static func _log(image: Image, plan: Dictionary, spec: Dictionary, index: int) -> void:
	var points:=PackedVector2Array()
	for p: Array in spec.path: points.append(Vector2(p[0],p[1]))
	var bounds:=Rect2(points[0],Vector2.ZERO)
	for p: Vector2 in points: bounds=bounds.expand(p)
	bounds=bounds.grow(spec.width+4)
	var light:=Color("a9a87b"); var dark:=Color("354b41")
	for x in range(maxi(0,int(bounds.position.x)),mini(1280,ceili(bounds.end.x))):
		for y in range(maxi(0,int(bounds.position.y)),mini(480,ceili(bounds.end.y))):
			var point:=Vector2(x+.5,y+.5)
			# Broken, oblique ends replace capsule caps; chips vary with radius.
			var first_axis: Vector2=(points[1]-points[0]).normalized()
			var last_axis: Vector2=(points[-1]-points[-2]).normalized()
			if (point-points[0]).dot(first_axis)<-2+grain(x/3,y/3,index)*5: continue
			if (point-points[-1]).dot(last_axis)>2-grain(x/3,y/3,index+2)*5: continue
			var distance:=INF; var along:=0.0; var side:=0.0; var travel:=0.0
			for i in range(points.size()-1):
				var edge:=points[i+1]-points[i]
				var t:=clampf((point-points[i]).dot(edge)/edge.length_squared(),0,1)
				var delta:=point-points[i].lerp(points[i+1],t)
				if delta.length()<distance:
					distance=delta.length(); along=travel+t*edge.length(); side=delta.dot(edge.normalized().orthogonal())
				travel+=edge.length()
			var radius: float=spec.width*(.43+.57*(1-clampf(along/maxf(1,travel),0,1)))
			radius+=(Field._noise(Vector2(along/33.0,1),index+3.2)-.5)*4
			if distance>radius: continue
			# Three broad irregular bark planes; no evenly ruled parallel stripes.
			var cross:=side/radius+(Field._noise(Vector2(along/67.0,side/13.0),index+1.1)-.5)*.24
			var value:=.68 if cross<-.55 else .49 if cross<.10 else .30
			if absf(cross+.26)<.065 and Field._noise(Vector2(along/46.0,1),1.8)>.30: value-=.13
			value+=(Field._noise(Vector2(along/39.0,side/6.0),3.1)-.5)*.08
			var color:=dark.lerp(light,value)
			color.a=1
			image.set_pixel(x,y,color)
	# A single connected broken branch establishes the trunk's direction.
	var at:=points[1]
	Raster.polygon(image,PackedVector2Array([at+Vector2(-8,3),at+Vector2(-24,-31),at+Vector2(-22,-37),at+Vector2(-7,-18),at+Vector2(7,2)]),Color("647155"))

static func _soil(image: Image, plan: Dictionary) -> void:
	var light:=Color(plan.sediment_light); var dark:=Color(plan.sediment_dark)
	for x in 1280:
		var top:=rim(plan,x)
		for y in range(top,480):
			var depth:=y-top
			var patch:=Field._noise(Vector2(x/49.0,y/22.0),3.3)
			var fine:=grain(x,y,17)
			var value:=.41+patch*.10-smoothstep(8,110,depth)*.28
			# Variable-width alluvial cap and patchy exposed soil, no ruled bands.
			var cap:=3+int(Field._noise(Vector2(x/27.0,2),6.7)*7)
			if depth<cap: value+=.12*(1-float(depth)/cap)
			if fine<.016: value-=.09
			elif fine>.986: value+=.08
			var c:=dark.lerp(light,clampf(floorf(value*14)/14.0,0,1))
			image.set_pixel(x,y,c)

static func _foreground(image: Image, plan: Dictionary) -> void:
	# Local corner wedges only: no connected ridge or high wall across the screen.
	for contour: Array in plan.foreground:
		var points:=PackedVector2Array()
		for p: Array in contour: points.append(Vector2(p[0],p[1]))
		points.append(Vector2(contour[-1][0],480)); points.append(Vector2(contour[0][0],480))
		Raster.polygon(image,points,Color("16353b"))
		for x in range(int(contour[0][0]),mini(1280,int(contour[-1][0]))):
			var top:=roundi(Plan.height(contour,x))
			for y in range(top,480):
				var c:=Color("15343a").lerp(Color("36514c"),.23+(1-smoothstep(0,13,y-top))*.32)
				image.set_pixel(x,y,c)
