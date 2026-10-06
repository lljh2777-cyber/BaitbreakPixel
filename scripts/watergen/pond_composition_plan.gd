extends RefCounted
## Round-one composition only. Input is allowlisted public map data, never World.
const Map=preload("res://scripts/watergen/public_map_context.gd")
const Seed=preload("res://scripts/watergen/water_visual_seed.gd")
const VERSION:="pond-composition-study-1"
const IDS:=["A","B","C"]

static func generate(map: Dictionary, variant: String, visual_seed: int) -> Dictionary:
	if not Map.validate(map).ok or map.world_size_px!=[1280,480]: return {"ok":false,"code":"PUBLIC_MAP"}
	if variant not in IDS or not Seed.valid(visual_seed): return {"ok":false,"code":"SETTINGS"}
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/composition_studies.json"))
	var plan: Dictionary=profiles[variant].duplicate(true)
	plan.merge({"version":VERSION,"variant":variant,"visual_seed":visual_seed,"map_public_digest":map.map_public_digest})
	# Widely spaced, asymmetric art-directed shoulders. Small independent offsets
	# avoid repetition; linear erosion detail never introduces periodic mounds.
	for layer in ["far","middle"]:
		var rng:=Seed.stream(visual_seed,VERSION,variant+"/"+layer)
		for i in range(1,plan[layer].size()-1):
			plan[layer][i][0]+=rng.randi_range(-12,12)
			plan[layer][i][1]+=rng.randi_range(-5,5)
	plan["floor_columns"]=[]
	for x in 1280: plan.floor_columns.append(ceili(Map.floor_at(map,x)))
	# The paint mask uses the exact existing floor columns; it cannot invent land
	# in the swimming region. Quiet activity corridor is shared by all studies.
	plan["quiet_rect"]=[300,110,680,160]
	return {"ok":true,"plan":plan}

static func height(points: Array, x: float) -> float:
	for i in range(points.size()-1):
		if x>points[i+1][0]: continue
		var a:=Vector2(points[i][0],points[i][1]); var b:=Vector2(points[i+1][0],points[i+1][1])
		var t:=clampf((x-a.x)/(b.x-a.x),0,1)
		# Smooth within each unequal shoulder, with no repeated bump primitive.
		return lerpf(a.y,b.y,t*t*(3-2*t))
	return points[-1][1]
