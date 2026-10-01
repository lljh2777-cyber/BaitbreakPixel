extends RefCounted

const Art = preload("res://scripts/pixel_art.gd")

# Raster-only plant styling. Keep these stalk centerlines identical to
# grass_binding.gd: its coils and anchored strip deformation follow them.
static func _spine(plant: Dictionary, stem: int, growth: float, t: float) -> Vector2:
	var fraction := float(stem)/maxi(1,int(plant.stems)-1)
	var height: float = plant.height*(0.67+0.33*sin(stem*2.37+1.2))
	if stem==int(plant.stems)/2: height=plant.height
	var phase: float = plant.x*0.13+stem*0.7
	return Vector2(plant.x+(fraction-0.5)*plant.width*(1+growth*0.38)
		+sin(t*1.5+phase+growth*2.1)*growth*2,129-height*growth)

static func paint(canvas: Image, plant: Dictionary, t: float) -> void:
	var back: bool = plant.back
	var shade := Color("30665f") if back else Color("3f725f")
	var body := Color("417c70") if back else Color("68936e")
	var light := Color("548b79") if back else Color("94b17e")
	for stem in range(plant.stems):
		var phase: float = plant.x*0.13+stem*0.7
		var tint := shade.lerp(body,0.68) if stem%3==0 else body
		if plant.kind=="ribbon":
			_ribbon(canvas,plant,stem,t,tint,shade,light)
		else:
			var height: float = 129-_spine(plant,stem,1,t).y
			# Alternate the leaves up the stalk rather than repeating mirrored
			# fern triangles. Sparse fine branches read as submerged pondweed.
			var nodes := maxi(4,roundi(height/7.0))
			for node in range(nodes):
				var growth := 0.16+(node+0.16*sin(phase+node*1.7))/float(nodes)*0.78
				var side := -1.0 if (node+stem)%2==0 else 1.0
				var anchor := _spine(plant,stem,growth,t)
				var length := (5.0+minf(height,75)*0.07)*(0.74+0.24*sin(node*2.3+phase))
				length *= 1.0-growth*0.42
				var rise := 1.6+length*0.39+sin(phase+node)*1.4
				var tip := anchor+Vector2(side*length,-rise)
				var leaf_color := tint if (node+stem)%3 else light
				_leaf(canvas,anchor,tip,1.25 if height<35 else 1.85,leaf_color,shade)
				# A second, offset filament on some nodes breaks the comb pattern
				# without filling the gaps between neighboring clumps.
				if (node+stem)%3!=1 and growth<0.79:
					var fork := anchor.lerp(tip,0.44)
					var fine_tip := fork+Vector2(side*length*0.38,-2.5-length*0.20)
					Art.paint_line(canvas,fork,fine_tip,tint)
				if (node+stem)%4==0:
					var offset := _spine(plant,stem,minf(growth+0.045,0.92),t)
					_leaf(canvas,offset,offset+Vector2(-side*length*0.60,-rise*0.72),1.1,tint,shade)
			# Leave a quiet, continuous spine for the existing binding contact.
			for segment in range(12):
				Art.paint_line(canvas,_spine(plant,stem,segment/12.0,t),_spine(plant,stem,(segment+1)/12.0,t),shade if segment<3 else tint)
			if plant.kind=="reed":
				var tip := _spine(plant,stem,1,t)
				Art.paint_line(canvas,tip,tip-Vector2(0,5),Color("657e66") if back else Color("9d9a6e"))
		# Short, dark root collars make the separate stalks feel planted.
		var root := _spine(plant,stem,0,t)
		Art.paint_line(canvas,root+Vector2(-1,0),root+Vector2(1,0),shade)

static func _ribbon(canvas: Image, plant: Dictionary, stem: int, t: float, body: Color, shade: Color, light: Color) -> void:
	var phase: float = plant.x*0.13+stem*0.7
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for step in range(17):
		var growth := step/16.0
		var axis := _spine(plant,stem,growth,t)
		# Broadest below mid-height, with a gently uneven folded edge and a
		# pointed end. The original centerline always remains inside the blade.
		var breadth := (0.75+sin(PI*growth)*1.15)*(1.0 if stem%2 else 1.16)
		var bend := sin(PI*growth)*sin(phase+growth*4.3)*1.9
		if step==16: breadth=0.0; bend=0.0
		left.append((axis+Vector2(minf(-breadth,bend-breadth),0)).round())
		right.append((axis+Vector2(maxf(breadth,bend+breadth),0)).round())
	var silhouette := PackedVector2Array(left)
	for step in range(16,-1,-1): silhouette.append(right[step])
	Art.paint_polygon(canvas,silhouette,body)
	for step in range(1,16):
		# Broken edge light suggests a twisting strap leaf; it is deliberately
		# low contrast in the back layer, not a bright outline around each stalk.
		if step<7 and (step+stem)%5!=0:
			Art.paint_line(canvas,right[step-1],right[step],shade)
		if step>3 and step<13 and (step+stem)%7<4:
			Art.paint_line(canvas,left[step-1],left[step],light)
	Art.paint_line(canvas,_spine(plant,stem,15.0/16,t),_spine(plant,stem,1,t),body)

static func _leaf(canvas: Image, root: Vector2, tip: Vector2, width: float, body: Color, shade: Color) -> void:
	var axis := tip-root
	var normal := axis.normalized().orthogonal()
	var bend := root+axis*0.50+Vector2(0,0.7)
	# A narrow curved lance, with an uneven belly and a tapered tip.
	var points := PackedVector2Array([root.round(),(bend-normal*width).round(),tip.round(),(bend+normal*width*0.7).round()])
	Art.paint_polygon(canvas,points,body)
	Art.paint_line(canvas,root,bend,shade)
	Art.paint_line(canvas,bend,tip,body)
