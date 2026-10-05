extends RefCounted
## Rasterised once per context. The visible rim is the collision polyline.
static func bake(context: RefCounted) -> ImageTexture:
	var image := Image.create(int(context.size.x),int(context.size.y),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in image.get_width():
		var top := ceili(context.floor_at(x))
		for y in range(top,image.get_height()):
			var depth := y-top
			var color := Color("456558").lerp(Color("263f3e"),clampf(depth/90.0,0,1))
			if depth<2: color=Color("8d9e72")
			elif depth<5: color=Color("687f5b")
			elif posmod(y+int(sin(x*0.022)*3),17)==0: color=color.darkened(0.12)
			var grain := posmod(x*71+y*37+x*y*3,101)
			if grain<7: color=color.lightened(0.08)
			elif grain>95: color=color.darkened(0.11)
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)
