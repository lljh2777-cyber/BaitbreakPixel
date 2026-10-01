extends RefCounted
# One material field per connected tree. Individual sprites retain the exact
# collision masks and opacity targets, but overlapping pixels are identical.
const Layout=preload("res://scripts/pond_layout.gd")
const GROUPS: Array = [[1,4,5,6,11,12],[7,15],[17,18]]
const PALETTE: Array[Color] = [Color("293f3b"),Color("424f40"),Color("666b4f"),Color("8c8b67")]
const SHAPES: Dictionary = {
	1:[[Vector2(337,171),Vector2(335,237),Vector2(343,299),Vector2(353,368),Vector2(355,434)],[8.0,14.0,18.0,26.0,25.0]],
	4:[[Vector2(266,246),Vector2(286,260),Vector2(310,282),Vector2(329,304),Vector2(342,331)],[4.0,7.0,8.0,11.0,15.0]],
	5:[[Vector2(415,222),Vector2(394,238),Vector2(369,266),Vector2(353,290),Vector2(349,314)],[4.0,7.0,9.0,12.0,16.0]],
	6:[[Vector2(247,430),Vector2(262,412),Vector2(283,399),Vector2(310,399),Vector2(336,420),Vector2(353,434)],[3.0,6.0,7.0,7.0,11.0,17.0]],
	7:[[Vector2(487,422),Vector2(530,411),Vector2(590,390),Vector2(647,374),Vector2(663,374)],[9.0,17.0,17.0,17.0,7.0]],
	11:[[Vector2(303,210),Vector2(319,220),Vector2(331,234),Vector2(336,253)],[3.0,4.0,7.0,9.0]],
	12:[[Vector2(372,227),Vector2(360,243),Vector2(346,260),Vector2(342,279)],[4.0,5.0,8.0,11.0]],
	15:[[Vector2(583,312),Vector2(587,338),Vector2(600,363),Vector2(617,381),Vector2(641,376)],[3.0,5.0,7.0,12.0,15.0]],
	17:[[Vector2(1224,363),Vector2(1218,399),Vector2(1202,433)],[6.0,8.0,9.0]],
	18:[[Vector2(1172,363),Vector2(1190,385),Vector2(1207,399),Vector2(1207,420)],[3.0,6.0,8.0,10.0]]
}

static func context(obstacle: Dictionary) -> Dictionary:
	var group: Array=[int(obstacle.seed)]
	for candidate: Array in GROUPS:
		if int(obstacle.seed) in candidate: group=candidate; break
	var polygons: Array[PackedVector2Array]=[]
	var shapes: Array[Dictionary]=[]
	for seed_value: int in group:
		var points:=PackedVector2Array(obstacle.points)
		for solid: Dictionary in Layout.SOLIDS:
			if solid.seed==seed_value: points=PackedVector2Array(solid.points); break
		polygons.append(points)
		var controls: Array=SHAPES.get(seed_value,[[points[0],points[points.size()/2]],[6.0,6.0]])
		shapes.append(_curve(controls,seed_value))
	var trunk: Dictionary=shapes[0]
	for branch: Dictionary in shapes.slice(1):
		var join:=_sample(branch.path[-1],trunk)
		branch.offset=Vector2(join.across,join.along-branch.length)
	return {"seed":group[0],"shapes":shapes,"branches":shapes.slice(1),"polygons":polygons,"top":trunk.path[0].y}

static func _curve(controls: Array, seed_value: int) -> Dictionary:
	var path: Array[Vector2]=[]
	var radii: Array[float]=[]
	var points: Array=controls[0]
	for i in range(points.size()-1):
		var p0: Vector2=points[maxi(0,i-1)]
		var p1: Vector2=points[i]
		var p2: Vector2=points[i+1]
		var p3: Vector2=points[mini(points.size()-1,i+2)]
		for step in range(4):
			var t:=step/4.0
			path.append(p1.cubic_interpolate(p2,p0,p3,t))
			radii.append(lerpf(controls[1][i],controls[1][i+1],t))
	path.append(points[-1]); radii.append(controls[1][-1])
	var length:=0.0
	var segments: Array[Dictionary]=[]
	var bounds:=Rect2(path[0],Vector2.ZERO)
	var max_radius:=0.0
	for i in path.size():
		bounds=bounds.expand(path[i]); max_radius=maxf(max_radius,radii[i])
		if i==0: continue
		var edge:=path[i]-path[i-1]
		var distance:=edge.length()
		segments.append({"a":path[i-1],"edge":edge,"length":distance,"squared":edge.length_squared(),
			"normal":edge.normalized().orthogonal(),"travelled":length,"r0":radii[i-1],"r1":radii[i]})
		length+=distance
	return {"path":path,"radii":radii,"length":length,"seed":seed_value,"offset":Vector2.ZERO,
		"segments":segments,"bounds":bounds.grow(max_radius*1.65)}

static func contains(point: Vector2, tree: Dictionary) -> bool:
	for polygon: PackedVector2Array in tree.polygons:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false

static func _sample(point: Vector2, shape: Dictionary) -> Dictionary:
	var nearest:=INF
	var across:=0.0
	var along:=0.0
	var radius:=1.0
	var normal:=Vector2.RIGHT
	for segment: Dictionary in shape.segments:
		var edge: Vector2=segment.edge
		var a: Vector2=segment.a
		var ratio:=clampf((point-a).dot(edge)/float(segment.squared),0,1)
		var delta:=point-a.lerp(a+edge,ratio)
		var distance:=delta.length_squared()
		if distance>=nearest: continue
		nearest=distance
		normal=segment.normal
		across=delta.dot(normal)
		along=segment.travelled+segment.length*ratio
		radius=lerpf(segment.r0,segment.r1,ratio)
	return {"across":across,"along":along,"radius":radius,"normal":normal,"distance":sqrt(nearest)}

static func color_at(point: Vector2, tree: Dictionary) -> Color:
	var trunk: Dictionary=tree.shapes[0]
	var base:=_sample(point,trunk)
	var along: float=base.along
	var across: float=base.across
	var radius: float=base.radius
	var normal: Vector2=base.normal
	var branch_weight:=0.0
	var tip: Dictionary=trunk
	var tip_along: float=base.along
	# Branch fibres bend down into the trunk. The collar is a shared spatial
	# blend, not a new patch over the branch's straight polygon end.
	var away:=smoothstep(float(base.radius)*0.22,float(base.radius)*1.18,absf(base.across))
	# Bounds and the trunk core only skip samples with guaranteed zero weight.
	for branch: Dictionary in tree.branches:
		if away<=0 or not Rect2(branch.bounds).has_point(point): continue
		var sample:=_sample(point,branch)
		var reach:=1.0-smoothstep(0.8,1.65,float(sample.distance)/float(sample.radius))
		var weight:=reach*away
		if weight<=branch_weight: continue
		branch_weight=weight
		along=lerpf(base.along,float(sample.along)+branch.offset.y,weight)
		across=lerpf(base.across,float(sample.across)+branch.offset.x,weight)
		radius=lerpf(base.radius,sample.radius,weight)
		normal=Vector2(base.normal).lerp(sample.normal,weight).normalized()
		if weight>0.5: tip=branch; tip_along=sample.along
	var side:=clampf(across/radius,-1,1)
	var light:=0.33+sqrt(maxf(0,1-side*side))*0.34+side*normal.dot(Vector2(-0.8,-0.6))*0.21
	var tone:=0 if light<0.34 else (1 if light<0.49 else (2 if light<0.64 else 3))
	var color: Color=PALETTE[tone]
	var seed_value: int=tree.seed
	var wave:=across+sin(along*0.047+seed_value)*1.35+sin(along*0.117+seed_value*2.3)*0.55
	var groove:=sin(wave*0.87+seed_value)
	var broken:=sin(along*0.093+wave*0.31)+sin(along*0.037-seed_value)
	if groove>0.83 and broken> -0.25: color=PALETTE[maxi(0,tone-1)]
	elif groove< -0.93 and broken>0.55 and tone>0: color=PALETTE[mini(3,tone+1)]
	var scar:=sin(along*0.031+seed_value)+sin(across*0.35+along*0.019)
	if scar>1.55 and absf(side)<0.65: color=PALETTE[mini(3,tone+1)]
	var bark:=sin(along*0.026+seed_value*2.1)+sin(wave*0.28+seed_value*0.7)
	if bark>1.17 and absf(side)>0.24:
		color=PALETTE[maxi(0,tone-1)]
		if groove>0.83: color=PALETTE[0]
	# Exposed tips only. Branch bases have neither cut end grain nor outlines.
	if tip_along<3.4+sin(across*1.1+tip.seed)*1.4:
		color=Color("a5a080") if posmod(floori(across*1.5)+int(tip.seed),5)<3 else Color("757858")
	if seed_value in [1,7] and branch_weight<0.15:
		var knot:=Vector2((base.across-base.radius*0.13)/4.0,(base.along-trunk.length*(0.39 if seed_value==1 else 0.65))/7.0)
		var ring:=knot.length()+sin(knot.angle()*3+seed_value)*0.09
		if ring<0.45: color=Color("3b5149")
		elif ring<0.70 or (ring>0.96 and ring<1.15): color=PALETTE[tone if knot.y<0 else mini(3,tone+1)]
		elif ring<0.94: color=PALETTE[0]
	if seed_value==7:
		var end:=Vector2((point.x-657)/8.0,(point.y-375)/13.0)
		var ring:=end.length()+sin(end.angle()*5)*0.09
		if ring<1:
			color=Color("8c9070") if end.x<0 else Color("67765d")
			if ring>0.65 and ring<0.80: color=Color("586950")
			if ring<0.34: color=Color("304e47")
			if end.y>0.1 and absf(end.x+end.y*0.2)<0.10: color=Color("425b49")
	if point.y>422+sin(point.x*0.14+seed_value)*3: color=color.lerp(Color("4d685b"),0.45)
	var top_edge:=not contains(point-Vector2(0,2),tree)
	var lower_edge:=not contains(point+Vector2(1,1),tree)
	var algae:=sin(point.x*0.19+seed_value*1.7)+sin(point.x*0.071-point.y*0.08)
	if top_edge and algae>0.9 and point.y>float(tree.top)+5:
		color=Color("748769") if algae>1.55 else Color("526d58")
	elif lower_edge: color=Color("344b43")
	return color
