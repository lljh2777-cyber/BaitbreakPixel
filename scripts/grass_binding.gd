extends RefCounted

const Presentation=preload("res://scripts/maps/map_presentation.gd")

static func smooth(value: float) -> float:
	var p:=clampf(value,0,1)
	return p*p*(3-2*p)

static func profile(world: Node2D, wrap: Dictionary, progress: float) -> Dictionary:
	var target: int=int(wrap.target)
	if target<0 or target>=world.targets.size() or not world.targets[target].capabilities.grass_binding: return {}
	var map := Presentation.for_context(world.map_context)
	var index: int=map.plant_index_for_target(target)
	if index<0: return {}
	var plant: Dictionary=map.plant_for_target(target)
	if plant.is_empty(): return {}
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
	var amount:=smooth(progress/0.5)
	var info: Dictionary={"target":wrap.target,"plant":index,"x":float(plant.x),"height":float(plant.height),"base":float(plant.y),"y":y,"amount":amount,"bend":pull.x*(1+world.tension*3)*amount}
	var visual: Dictionary=wrap.duplicate()
	visual.center=deform(center,info)
	visual.radii=Vector2(clampf((right-left)*0.40+1.4,2.1,6.0),1.6)
	visual.pitch=5.0
	visual.entry=Vector2(visual.center)+Vector2(visual.radii.x,-visual.pitch*0.5)
	visual.grass=true
	visual.slant=pull.x*1.4
	info.wrap=visual
	return info

static func deform(point: Vector2, info: Dictionary) -> Vector2:
	var growth:=clampf((float(info.base)-point.y)/float(info.height),0,1)
	var distance: float=(point.y-float(info.y))/maxf(11,float(info.height)*0.22)
	var gather: float=1-0.20*float(info.amount)*exp(-distance*distance)*smooth(growth/0.16)
	return Vector2(float(info.x)+(point.x-float(info.x))*gather+float(info.bend)*growth*growth,point.y)
