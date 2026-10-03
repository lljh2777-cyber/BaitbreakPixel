extends "res://scripts/watergen/water_visual_cache.gd"
const DynamicGenerator = preload("res://scripts/watergen/water_dynamic_generator.gd")
const DynamicBaker = preload("res://scripts/watergen/water_dynamic_baker.gd")

func generate(map: Dictionary, profile: Dictionary, visual_seed: int) -> Dictionary:
	return DynamicGenerator.generate(map, profile, visual_seed)

func bake(plan: Dictionary) -> Dictionary:
	return DynamicBaker.bake(plan)
