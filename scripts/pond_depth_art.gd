extends RefCounted

# Cached decorative depth planes. These never enter collision or coil geometry.
const Layout=preload("res://scripts/pond_layout.gd")
const Art=preload("res://scripts/pixel_art.gd")

static func _canvas() -> Image:
	var image:=Image.create(int(Layout.SIZE.x),int(Layout.SIZE.y),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

static func _grain(x: int, y: int, seed_value: int=0) -> float:
	return float(posmod(x*127+y*311+seed_value*73,997))/997.0

static func distant_image() -> Image:
	var image:=_canvas()
	# Submerged shelves grow larger toward the banks, opening a central valley.
	for rock: Array in [[-4,350,145,172],[90,372,106,121],[181,384,85,79],[306,398,65,43],[473,394,66,42],[715,395,91,46],[916,380,86,67],[1028,371,105,100],[1189,358,145,151],[1280,356,106,194]]:
		_rock(image,Vector2(rock[0],rock[1]),Vector2(rock[2],rock[3]),int(rock[0])+31,0.24,Color("205057"),Color("427472"))
	for clump: Array in [[40,343,157,8],[146,367,120,8],[248,383,100,7],[430,379,98,7],[554,389,69,5],[746,383,94,7],[901,374,130,8],[1040,356,179,8],[1189,340,207,10]]:
		_weed(image,Vector2(clump[0],clump[1]),float(clump[2]),int(clump[3]),Color(0.09,0.25,0.29,0.38),1.0)
	_timber(image,Vector2(170,386),Vector2(288,320),9,Color(0.09,0.24,0.27,0.35),Color(0.20,0.37,0.35,0.32))
	_timber(image,Vector2(992,393),Vector2(1145,317),13,Color(0.08,0.22,0.27,0.40),Color(0.20,0.36,0.35,0.32))
	return image

static func middle_image() -> Image:
	var image:=_canvas()
	# Staggered ledges and overlapping rocks, rather than a repeated stone row.
	for rock: Array in [[-10,415,79,94],[73,411,69,59],[117,412,41,32],[268,405,40,29],[408,411,62,42],[453,412,31,24],[792,416,57,51],[920,413,45,29],[1078,411,49,44],[1162,414,81,73],[1272,414,91,128]]:
		_rock(image,Vector2(rock[0],rock[1]),Vector2(rock[2],rock[3]),int(rock[0])+61,0.64,Color("274f52"),Color("69867b"))
	for clump: Array in [[12,403,174,7],[65,395,116,5],[121,403,62,4],[216,408,56,4],[409,399,126,6],[473,411,43,3],[766,409,117,6],[838,409,81,5],[1051,403,159,7],[1190,407,193,8]]:
		_weed(image,Vector2(clump[0],clump[1]),float(clump[2]),int(clump[3]),Color(0.20,0.38,0.32,0.64),1.2)
	return image

static func surface_image() -> Image:
	var image:=_canvas()
	# Floating leaves have broad undersides and long, irregular stalks.
	for pad: Array in [[85,36,314],[186,26,257],[484,34,340],[565,24,295],[884,41,369],[976,28,298],[1162,38,345]]:
		var x: float=pad[0]; var width: float=pad[1]; var depth: float=pad[2]
		var previous:=Vector2(x,57)
		for step in 23:
			var f: float=(step+1)/23.0
			var point:=Vector2(x+sin(f*3.1+x)*8+f*f*9,57+depth*f).round()
			Art.paint_line(image,previous,point,Color(0.28,0.40,0.25,0.55))
			Art.paint_line(image,previous+Vector2(1,0),point+Vector2(1,0),Color(0.19,0.32,0.25,0.50))
			if step in [9,15,20]:
				Art.paint_line(image,point,point+Vector2(-4,-6),Color(0.25,0.40,0.30,0.40))
			previous=point
		var outline:=PackedVector2Array([Vector2(x-width,53),Vector2(x-width*0.82,48),Vector2(x-width*0.25,46),Vector2(x+width*0.52,47),Vector2(x+width,52),Vector2(x+width*0.82,57),Vector2(x+width*0.18,59),Vector2(x-2,54),Vector2(x-9,59),Vector2(x-width*0.70,57)])
		Art.paint_polygon(image,outline,Color("526849"))
		Art.paint_line(image,outline[1],outline[3],Color("86966a"))
		Art.paint_line(image,Vector2(x-width*0.66,56),Vector2(x+width*0.72,57),Color("2b4c40"))
		Art.paint_line(image,Vector2(x,53),Vector2(x-width*0.63,50),Color("69865c"))
	# A reed bank's dangling roots frame the left edge without filling open water.
	for root_index in 13:
		var x:=8.0+root_index*4.0
		var length:=77.0+float(posmod(root_index*31,107))
		var previous:=Vector2(x,56)
		for step in 14:
			var f: float=(step+1)/14.0
			var point:=Vector2(x+sin(f*4+root_index)*f*16,56+f*length).round()
			Art.paint_line(image,previous,point,Color(0.45,0.44,0.29,0.66))
			if step%3==1: Art.paint_line(image,point,point+Vector2(6+step/2,8),Color(0.35,0.39,0.26,0.56))
			previous=point
	return image

static func floor_image() -> Image:
	var image:=_canvas()
	# Distance contracts the gravel and fades the far bed into the water.
	for x in image.get_width():
		var horizon:=357.0+sin(x*0.008+1)*9+sin(x*0.029)*4
		for y in range(int(horizon),image.get_height()):
			var depth:=clampf((y-horizon)/(Layout.FLOOR-horizon),0,1)
			var channel:=exp(-pow((x-664.0)/(102+depth*156),2))
			var wave:=sin(x*0.074+y*0.19)+sin(x*0.037-y*0.093)
			var dark:=Color("355a55"); var sand:=Color("7d8970")
			var light:=0.18+channel*0.37+wave*0.047+(_grain(x,y)-0.5)*0.09
			var color:=dark.lerp(sand,clampf(light,0,1))
			color.a=smoothstep(0,0.58,depth)
			image.set_pixel(x,y,color)
	# Gravel comes in loose patches, with elliptical contact shadows.
	for index in 205:
		var y:=366+posmod(index*47+index*index*3,109)
		var depth: float=(y-355.0)/125.0
		var x:=posmod(index*109+index*index*17,1280)
		var size:=Vector2(2+floorf(depth*5)+index%3,1+floorf(depth*3))
		_rock(image,Vector2(x,y),size,index+137,0.45+depth*0.35,Color("2c4947"),Color("8a9479"))
	return image

static func foreground_image() -> Image:
	var image:=_canvas()
	# Broad dark blades overlap the bed at the near edge. The fish and food
	# render above this plane, so depth accents cannot hide interaction cues.
	for clump: Array in [[26,475,96,7],[153,477,66,5],[349,479,73,6],[598,479,55,5],[895,477,81,6],[1038,476,105,7],[1248,478,134,8]]:
		_weed(image,Vector2(clump[0],clump[1]),float(clump[2]),int(clump[3]),Color("153b3c"),2.8)
	for rock: Array in [[-4,475,73,69],[287,478,35,24],[837,477,43,26],[1267,481,81,94]]:
		_rock(image,Vector2(rock[0],rock[1]),Vector2(rock[2],rock[3]),int(rock[0])+47,1.0,Color("173d3d"),Color("41615a"))
	return image

static func _rock(image: Image, base: Vector2, size: Vector2, seed_value: int, alpha: float, shade: Color, light: Color) -> void:
	# A dome with chipped shoulders and curved, shaded volume in a pixel mask.
	_shadow(image,base+Vector2(0,2),Vector2(size.x*0.56+1,maxf(1,size.y*0.06)),alpha*0.35)
	var points:=PackedVector2Array()
	for step in 15:
		var angle:=PI+step/14.0*PI
		var chip:=1.0+sin(step*2.1+seed_value)*0.047
		points.append((base+Vector2(cos(angle)*size.x*0.5,sin(angle)*size.y)*chip).round())
	points.append(base+Vector2(size.x*0.5,3)); points.append(base+Vector2(-size.x*0.5,3))
	for y in range(maxi(0,int(base.y-size.y)-4),mini(image.get_height(),int(base.y)+4)):
		for x in range(maxi(0,int(base.x-size.x*0.6)),mini(image.get_width(),int(base.x+size.x*0.6)+1)):
			var point:=Vector2(x+0.5,y+0.5)
			if not Geometry2D.is_point_in_polygon(point,points): continue
			var u: float=(x-base.x)/(size.x*0.5)
			var v: float=(y-(base.y-size.y))/size.y
			var dome:=sqrt(maxf(0,1-u*u))
			var amount:=0.30+dome*0.28-u*0.12-v*0.28
			amount+=sin(x*0.17+y*0.21+seed_value)*sin(y*0.13)*0.048
			if v<0.35 and u<0.45: amount+=0.11
			if _grain(x,y,seed_value)>0.88: amount+=0.09
			if absf(u-(0.27+sin(y*0.06+seed_value)*0.10))<0.038 and v>0.36: amount-=0.17
			var color:=shade.lerp(light,clampf(roundf(amount*7)/7.0,0,1)); color.a=alpha
			if v<0.31 and _grain(x/3,y/2,seed_value)>0.77: color=color.lerp(Color("658060"),0.24); color.a=alpha
			var under:=image.get_pixel(x,y)
			if under.a>alpha:
				color=under.lerp(color,alpha); color.a=under.a
			image.set_pixel(x,y,color)

static func _shadow(image: Image, center: Vector2, radius: Vector2, strength: float) -> void:
	for y in range(maxi(0,floori(center.y-radius.y)),mini(image.get_height(),ceili(center.y+radius.y))):
		for x in range(maxi(0,floori(center.x-radius.x)),mini(image.get_width(),ceili(center.x+radius.x))):
			var distance:=((Vector2(x,y)-center)/radius).length_squared()
			if distance>=1: continue
			var under:=image.get_pixel(x,y)
			var shadow:=Color(0.04,0.13,0.13,strength*(1-distance))
			if under.a>0:
				var color:=under.lerp(shadow,shadow.a); color.a=maxf(under.a,shadow.a)
				image.set_pixel(x,y,color)
			else: image.set_pixel(x,y,shadow)

static func _weed(image: Image, base: Vector2, height: float, stems: int, color: Color, breadth: float) -> void:
	for stem in stems:
		var root:=base+Vector2((stem-float(stems-1)*0.5)*6,0)
		var rise:=height*(0.57+sin(stem*2.37+base.x)*0.18+float(stem%3)*0.10)
		var bend:=sin(stem*1.9+base.x)*height*0.13
		var left:=PackedVector2Array(); var right:=PackedVector2Array()
		var previous:=root
		for step in 13:
			var f:=step/12.0
			var point:=root+Vector2(bend*f*f+sin(f*4+stem)*f*3,-rise*f)
			var width:=breadth*(1-f)*sin(f*PI)*1.3
			left.append((point-Vector2(width,0)).round()); right.append((point+Vector2(width,0)).round())
			if breadth<2.0:
				Art.paint_line(image,previous,point,color)
				if step in [3,5,7,9]:
					var side:=1.0 if (stem+step)%3 else -1.0
					var tip:=point+Vector2(side*(4+height*0.045)*(1-f*0.5),-3-height*0.024)
					Art.paint_polygon(image,PackedVector2Array([point,point.lerp(tip,0.5)+Vector2(0,1.5),tip,point.lerp(tip,0.5)-Vector2(0,1)]),color)
			previous=point
		if breadth>=2.0:
			for step in range(12,-1,-1): left.append(right[step])
			Art.paint_polygon(image,left,color)
			var edge:=color.lightened(0.07)
			for step in range(3,9): Art.paint_line(image,right[step],right[step+1],edge)

static func _timber(image: Image, base: Vector2, tip: Vector2, width: float, shade: Color, light: Color) -> void:
	var normal: Vector2=(tip-base).normalized().orthogonal()
	Art.paint_polygon(image,PackedVector2Array([base-normal*width,tip-normal*width*0.4,tip+normal*width*0.3,base+normal*width*0.7]),shade)
	Art.paint_line(image,base-normal*width*0.6,tip-normal*width*0.3,light)
	var join:=base.lerp(tip,0.58)
	Art.paint_polygon(image,PackedVector2Array([join-normal*3,join+Vector2(-7,-43),join+Vector2(-3,-45),join+normal*5]),shade)
