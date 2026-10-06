extends RefCounted
## Round-one composition only. Input is allowlisted public map data, never World.
const Map=preload("res://scripts/watergen/public_map_context.gd")
const Seed=preload("res://scripts/watergen/water_visual_seed.gd")
const VERSION:="pond-composition-blockout-2"
const IDS:=["A","B","C"]

static func generate(map: Dictionary, variant: String, visual_seed: int) -> Dictionary:
	if not Map.validate(map).ok or map.world_size_px!=[1280,480]: return {"ok":false,"code":"PUBLIC_MAP"}
	if variant not in IDS or not Seed.valid(visual_seed): return {"ok":false,"code":"SETTINGS"}
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/watergen/composition_studies.json"))
	var plan: Dictionary=profiles[variant].duplicate(true)
	plan.merge({"version":VERSION,"variant":variant,"visual_seed":visual_seed,"map_public_digest":map.map_public_digest})
	# This is a frozen art board, NOT a replacement for the runtime floor.
	# Authored control points set the entire silhouette. Seeds affect texture only.
	plan["preview_only"]=true
	plan["quiet_rect"]=[360,70,560,260]
	return {"ok":true,"plan":plan}

static func tangent(points: Array, i: int) -> float:
	if i==0: return float(points[1][1]-points[0][1])/(points[1][0]-points[0][0])
	if i==points.size()-1: return float(points[i][1]-points[i-1][1])/(points[i][0]-points[i-1][0])
	var left: float=points[i][0]-points[i-1][0]
	var right: float=points[i+1][0]-points[i][0]
	var a: float=(points[i][1]-points[i-1][1])/left
	var b: float=(points[i+1][1]-points[i][1])/right
	if a*b<=0: return 0.0
	var w1:=2*right+left; var w2:=right+2*left
	return (w1+w2)/(w1/a+w2/b)

static func height(points: Array, x: float) -> float:
	for i in range(points.size()-1):
		if x>points[i+1][0]: continue
		var a:=Vector2(points[i][0],points[i][1]); var b:=Vector2(points[i+1][0],points[i+1][1])
		var t:=clampf((x-a.x)/(b.x-a.x),0,1)
		# Shape-preserving Hermite slope: no periodic basis and no extra extrema.
		var span:=b.x-a.x
		return (2*t*t*t-3*t*t+1)*a.y+(t*t*t-2*t*t+t)*span*tangent(points,i)+(-2*t*t*t+3*t*t)*b.y+(t*t*t-t*t)*span*tangent(points,i+1)
	return points[-1][1]
