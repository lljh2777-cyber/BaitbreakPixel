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
	var far:=canvas(); var middle:=canvas(); var bed:=canvas()
	_surface(far,plan,"far")
	_surface(middle,plan,"middle")
	# Ground each background mass on its own distant bank, never on collision data.
	for i in plan.rocks.size(): _rock(middle,plan,plan.rocks[i],i)
	for i in plan.logs.size(): _log(middle,plan,plan.logs[i],i)
	_soil(bed,plan)
	return {"ok":true,"far":far,"middle":middle,"bed":bed}

static func grain(x: int, y: int, salt: int=0) -> float:
	var n: int=(x*374761393+y*668265263+salt*362437) & 0x7fffffff
	n=((n ^ (n >> 13))*1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0x7fffffff)/2147483647.0

static func _surface(image: Image, plan: Dictionary, layer: String) -> void:
	var far:=layer=="far"
	var dark:=Color("244c4c") if far else Color("2b4e50")
	var light:=Color("557069") if far else Color("647b6a")
	for x in 1280:
		var rim:=Plan.height(plan[layer],x)
		# Broken silt lips with long quiet stretches, not a continuous bright wave.
		rim+=roundf((Field._noise(Vector2(x/39.0,1),4.1)-0.5)*4)
		for y in range(maxi(0,floori(rim)),480):
			var d:=y-rim
			var coarse:=Field._noise(Vector2(x/43.0,y/17.0),7.4)
			var speck:=grain(x,y,2)
			var value:=0.24+coarse*0.30+(1-smoothstep(1,19,d))*0.13
			if speck>.97: value+=.12
			elif speck<.035: value-=.10
			var color:=dark.lerp(light,floorf(value*12)/12.0)
			color.a=minf(1,(d+2)/5.0)*(0.86 if far else 0.82)
			if d<0: continue
			image.set_pixel(x,y,color)

static func _rock(image: Image, plan: Dictionary, spec: Array, index: int) -> void:
	var rng:=Seed.stream(plan.visual_seed,Plan.VERSION,plan.variant+"/rock",index)
	var p:=Vector2(spec[0],spec[1]); var w: float=spec[2]; var h: float=spec[3]
	p.y=maxf(Plan.height(plan.far,p.x-w*.55),Plan.height(plan.far,p.x+w*.55))+13
	var outline:=PackedVector2Array([p+Vector2(-w*.55,6),p+Vector2(-w*.51,-h*.29),p+Vector2(-w*.31,-h*.83),p+Vector2(-w*.10,-h),p+Vector2(w*.20,-h*.95),p+Vector2(w*.46,-h*.48),p+Vector2(w*.54,5)])
	var pale:=Color("6a7d73"); var dark:=Color("304e52")
	for x in range(maxi(0,int(p.x-w)),mini(1280,int(p.x+w))):
		for y in range(maxi(0,int(p.y-h)-1),mini(480,int(p.y)+7)):
			var point:=Vector2(x+.5,y+.5)
			if not Geometry2D.is_point_in_polygon(point,outline): continue
			var u: float=(x-p.x)/w; var v: float=(p.y-y)/h
			var face:=0.22 if u>.05+v*.08 else 0.43 if v<.70-u*.5 else .66
			face+=Field._noise(Vector2(x/12.0,y/8.0),2.6)*.12-.06
			var noise:=grain(x,y,index)
			if noise>.97: face+=.15
			elif noise<.06: face-=.09
			var c:=dark.lerp(pale,face)
			c.a=0.78*clampf((p.y+6-y)/10.0,0,1)
			image.set_pixel(x,y,c)
	# One small flaked seam, kept within the same low-contrast distant material.
	var seam:=p+Vector2(rng.randf_range(-.15,.12)*w,-h*.67)
	Raster.line(image,seam,seam+Vector2(w*.16,h*.36),Color("3c595b"))

static func _log(image: Image, plan: Dictionary, spec: Dictionary, index: int) -> void:
	var points:=PackedVector2Array()
	for p: Array in spec.path: points.append(Vector2(p[0],p[1]))
	var span:=points[-1]-points[0]
	var first_shift:=Plan.height(plan.far,points[0].x)-points[0].y
	var last_shift:=Plan.height(plan.far,points[-1].x)-points[-1].y
	for i in points.size():
		points[i].y+=lerpf(first_shift,last_shift,float(i)/(points.size()-1)) if absf(span.x)>absf(span.y)*2 else first_shift
	var bounds:=Rect2(points[0],Vector2.ZERO)
	for p: Vector2 in points: bounds=bounds.expand(p)
	bounds=bounds.grow(spec.width+4)
	var light:=Color("67796a"); var dark:=Color("294a4e")
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
			var radius: float=spec.width*(.72+.28*(1-clampf(along/maxf(1,travel),0,1)))
			radius+=(Field._noise(Vector2(along/19.0,1),index+3.2)-.5)*3
			if distance>radius: continue
			var value:=.30+(1-side/radius)*.19
			var fibre:=side+Field._noise(Vector2(along/45.0,side/9.0),index+1.1)*5
			var fissure:=posmod(floori(fibre),6)
			if fissure<=1 and Field._noise(Vector2(along/22.0,side),1.8)>.27: value-=.13
			elif fissure==4: value+=.06
			if grain(x,y,index)>.97: value+=.09
			var color:=dark.lerp(light,value)
			color.a=.88
			image.set_pixel(x,y,color)
	# A single broken branch adds direction without multiplying major anchors.
	var at:=points[1]
	Raster.polygon(image,PackedVector2Array([at+Vector2(-8,3),at+Vector2(-15,-36),at+Vector2(-9,-43),at+Vector2(-2,-13),at+Vector2(7,2)]),Color("3c5956"))

static func _soil(image: Image, plan: Dictionary) -> void:
	var light:=Color(plan.sediment_light); var dark:=Color(plan.sediment_dark)
	for x in 1280:
		var top: int=plan.floor_columns[x]
		for y in range(top,480):
			var depth:=y-top
			var patch:=Field._noise(Vector2(x/49.0,y/22.0),3.3)
			var fine:=grain(x,y,17)
			var value:=.30+patch*.33-smoothstep(5,100,depth)*.29
			# Variable-width alluvial cap and patchy exposed soil, no ruled bands.
			var cap:=3+int(Field._noise(Vector2(x/27.0,2),6.7)*7)
			if depth<cap: value+=.15*(1-float(depth)/cap)
			if depth==0: value=.55+patch*.16
			if fine<.04: value-=.14
			elif fine>.97: value+=.13
			var channel_x: float=plan.channel[-1][0]
			for i in range(plan.channel.size()-1):
				var a: Array=plan.channel[i]; var b: Array=plan.channel[i+1]
				if y<=b[1]:
					channel_x=lerpf(a[0],b[0],clampf((y-a[1])/(b[1]-a[1]),0,1)); break
			var channel:=1-smoothstep(18,110,absf(x-channel_x))
			value+=channel*.07
			var c:=dark.lerp(light,clampf(floorf(value*14)/14.0,0,1))
			image.set_pixel(x,y,c)
