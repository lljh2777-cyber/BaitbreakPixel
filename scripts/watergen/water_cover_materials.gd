extends RefCounted
## RGB-only material finish for existing public sprites. Never changes masks,
## crop origins, target membership, plant frames, or authority-dependent alpha.
var props: Array[Dictionary] = []
var plant_frames: Array = []
var preparation_us := 0
var texture_count := 0
var rgba_bytes := 0

static func finish(source: Image, kind: String, origin: Vector2, variation: int) -> Image:
	var result := source.duplicate() as Image
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			if color.a == 0: continue
			var wx: float = origin.x + x
			var wy: float = origin.y + y
			var patch := sin(wx * 0.065 + variation) + sin(wy * 0.11 - wx * 0.025 + variation * 0.7)
			var fleck := posmod(int(wx) * 17 + int(wy) * 31 + variation * 23, 47)
			var painted := color
			match kind:
				"wood":
					# Broad worn bark and submerged algae follow one spatial field
					# across the entire already-joined tree, including its junctions.
					if patch > 0.55:
						painted = color.lerp(Color("799075"), 0.22 if fleck < 33 else 0.12)
					elif patch < -0.80:
						painted = color.lerp(Color("544934"), 0.26)
					if fleck < 4: painted = painted.darkened(0.09)
					elif fleck > 43 and patch < 0.5: painted = painted.lerp(Color("a5a080"), 0.12)
				"stone":
					var strata := sin(wx * 0.038 + wy * 0.23 + sin(wx * 0.065 + variation) * 1.8)
					if strata > 0.85: painted = color.lerp(Color("899185"), 0.21)
					elif strata < -0.78: painted = color.darkened(0.12)
					if patch > 0.95: painted = painted.lerp(Color("526b54"), 0.24)
					if fleck < 5: painted = painted.darkened(0.12)
					elif fleck > 43: painted = painted.lerp(Color("9b9c83"), 0.14)
				"plant":
					# Original eight poses remain intact; modest tonal variation
					# adds leaf texture without food-like bright dots or new stems.
					var growth := 1.0 - y / float(maxi(1, source.get_height() - 1))
					painted = color.lerp(Color("34594e"), (1.0 - growth) * 0.20)
					if patch > 0.30: painted = painted.lerp(Color("85a084"), 0.10 * growth)
					if fleck < 7: painted = painted.darkened(0.07)
			painted.a = color.a
			result.set_pixel(x, y, painted)
	return result

func prepare(source_props: Array[Dictionary], source_plants: Array, kinds: Array[String]) -> bool:
	if not props.is_empty(): return true
	if source_props.size() != kinds.size() or source_props.is_empty() or source_plants.is_empty(): return false
	var started := Time.get_ticks_usec()
	var next_props: Array[Dictionary] = []
	var next_plants: Array = []
	var count := 0
	var bytes := 0
	for index in source_props.size():
		var sprite: Dictionary = source_props[index]
		var pixels := finish(sprite.texture.get_image(), kinds[index], sprite.position, sprite.targets[0])
		var copy: Dictionary = sprite.duplicate(true)
		copy.texture = ImageTexture.create_from_image(pixels)
		next_props.append(copy)
		count += 1; bytes += pixels.get_data_size()
	for index in source_plants.size():
		var frames: Array[Dictionary] = []
		for sprite in source_plants[index]:
			var pixels := finish(sprite.texture.get_image(), "plant", sprite.position, index)
			frames.append({"texture":ImageTexture.create_from_image(pixels), "position":sprite.position})
			count += 1; bytes += pixels.get_data_size()
		next_plants.append(frames)
	props = next_props
	plant_frames = next_plants
	texture_count = count
	rgba_bytes = bytes
	preparation_us = Time.get_ticks_usec() - started
	return true
