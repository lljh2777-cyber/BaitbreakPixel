extends RefCounted
## Pure visual descriptors. This module cannot read Layout, World or gameplay targets.
const Seed = preload("res://scripts/watergen/water_visual_seed.gd")
const Map = preload("res://scripts/watergen/public_map_context.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const VERSION := "wg-6.1-terrain-v1"
const STYLES := ["fern_channel", "ribbon_slope", "lily_basin", "root_shelf"]
const DEPTHS := ["far", "middle", "near"]

static func validate(profile: Variant) -> bool:
	return Profile.keys(profile, ["terrain_style", "terrain_relief", "ridge_count", "depression_count", "center_clearance", "bank_bias"]) and profile.terrain_style in STYLES and Profile.number(profile.terrain_relief, 24, 96) and Profile.number(profile.ridge_count, 1, 5, true) and Profile.number(profile.depression_count, 1, 3, true) and Profile.number(profile.center_clearance, 0.5, 1) and Profile.number(profile.bank_bias, -1, 1)

static func stream(seed: int, kind: String, index := 0) -> RandomNumberGenerator:
	return Seed.stream(seed, "terrain", VERSION + "/" + kind, index)

static func generate(map: Variant, profile: Variant, visual_seed: Variant) -> Dictionary:
	if not Seed.valid(visual_seed): return {"ok": false, "code": "SEED"}
	if not validate(profile): return {"ok": false, "code": "TERRAIN_PROFILE"}
	if not Map.validate(map).ok or map.world_size_px != [1280, 480]: return {"ok": false, "code": "PUBLIC_MAP"}
	var macro := stream(visual_seed, "macro")
	var plan := {"format": "baitbreak-visual-terrain-plan", "generator_version": VERSION, "visual_seed": visual_seed, "world_size_px": [1280, 480], "map_public_digest": map.map_public_digest, "profile": profile.duplicate(true), "terrain_regions": [], "ridges": [], "depressions": [], "stone_shelves": [], "sediment_channels": [], "foreground_rises": []}
	var center := 640.0 + macro.randf_range(-55, 55)
	# Broad masses first; details use their own streams and cannot perturb this plan.
	for depth in DEPTHS:
		var near: bool = depth == "near"
		plan.terrain_regions.append({"kind": "slope", "depth_layer": depth, "base_y": 367.0 if depth == "far" else 431.0 if depth == "middle" else 479.0, "bank_bias": profile.bank_bias, "height": profile.terrain_relief * (0.50 if depth == "far" else 0.30 if not near else 0.12), "phase": macro.randf_range(0, TAU)})
	for index in int(profile.ridge_count):
		var rng := stream(visual_seed, "ridge", index)
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := (140.0 if side < 0 else 1100.0) + rng.randf_range(-65, 65)
		if index >= 2: x += -side * rng.randf_range(130, 220)
		var favored: float = 1.0 + profile.bank_bias * side * 0.64
		for depth in ["far", "middle"]:
			plan.ridges.append({"kind": "mud_ridge", "depth_layer": depth, "x": x + (36 if depth == "middle" else 0), "width": rng.randf_range(350, 510), "height": profile.terrain_relief * favored * rng.randf_range(0.55, 0.8) * (1.0 if depth == "far" else 0.66), "curvature": rng.randf_range(1.0, 1.45), "seed": int(rng.seed)})
	for index in int(profile.depression_count):
		var rng := stream(visual_seed, "depression", index)
		plan.depressions.append({"kind": "depression", "x": center + index * 190, "width": rng.randf_range(300, 430) * (1.35 if profile.terrain_style == "lily_basin" else 1.0), "height": rng.randf_range(14, 25), "curvature": rng.randf_range(1.0, 1.3)})
	# A curved low channel widens toward the viewer; it has no vertical wall or outline.
	var channel := stream(visual_seed, "channel")
	plan.sediment_channels.append({"kind": "sediment_channel", "x": center, "y": 369, "width": 90 if profile.terrain_style == "fern_channel" else 155 if profile.terrain_style == "lily_basin" else 65, "bend": channel.randf_range(-95, 95), "phase": channel.randf_range(0, TAU), "shade": 0.17 if profile.terrain_style == "lily_basin" else 0.11})
	for index in (6 if profile.terrain_style == "root_shelf" else 3):
		var rng := stream(visual_seed, "shelf", index)
		var side := 1.0 if profile.bank_bias >= 0 else -1.0
		var x := (1090.0 if side > 0 else 185.0) - side * index * 49 + rng.randf_range(-20, 20)
		plan.stone_shelves.append({"kind": "stone_shelf", "depth_layer": "middle", "x": x, "width": rng.randf_range(85, 130), "height": rng.randf_range(14, 23), "shade": rng.randf_range(0.09, 0.16), "seed": int(rng.seed)})
	for side in [-1, 1]:
		var rng := stream(visual_seed, "foreground", side + 1)
		plan.foreground_rises.append({"kind": "foreground_rise", "x": 180 if side < 0 else 1160, "width": rng.randf_range(310, 420), "height": rng.randf_range(13, 24), "curvature": 1.25, "depth_layer": "near"})
	return {"ok": true, "plan": plan}

static func mound(object: Dictionary, x: float) -> float:
	var t: float = absf(x - object.x) / (object.width * 0.5)
	if t >= 1: return 0.0
	return pow(0.5 + cos(t * PI) * 0.5, object.curvature) * object.height

static func surface_y(plan: Dictionary, depth: String, x: float) -> float:
	var region: Dictionary = plan.terrain_regions[DEPTHS.find(depth)]
	var y: float = region.base_y - region.bank_bias * (x / 1280.0 - 0.5) * region.height
	for ridge in plan.ridges:
		if ridge.depth_layer == depth: y -= mound(ridge, x)
	for depression in plan.depressions: y += mound(depression, x) * (1.0 if depth == "far" else 0.35)
	if depth == "near":
		for rise in plan.foreground_rises: y -= mound(rise, x)
	# Small smooth erosion, never a serrated wall. Quiet center for actors and food.
	y += sin(x * 0.018 + region.phase) * 1.8 + sin(x * 0.006 + region.phase) * 3.0
	var center_weight: float = smoothstep(330, 590, x) * (1.0 - smoothstep(700, 950, x)) * plan.profile.center_clearance
	return lerpf(y, maxf(y, 382.0 if depth == "far" else 424.0 if depth == "middle" else 478.0), center_weight)
