extends RefCounted
## Pure, preview-local frame math. No clock, world, input or textures.
const Contract = preload("res://scripts/watergen/public_map_context.gd")
const Profile = preload("res://scripts/watergen/water_visual_profile.gd")
const MAX_CAMERA := Vector2(640, 120)
var visual_time := 0.0
var paused := false

func advance(delta: float) -> void:
	if not paused and Profile.number(delta, 0, 60): visual_time = fmod(visual_time + delta, 86400.0)

func seek(value: float) -> bool:
	if not Profile.number(value, 0, 86400): return false
	visual_time = value
	return true

static func validate(frame: Variant) -> bool:
	if not Contract._keys(frame, ["role", "camera_offset_px", "viewport_size_px", "visual_time_seconds"]) or frame.role != "preview": return false
	if not frame.viewport_size_px is Array or frame.viewport_size_px.size() != 2: return false
	var size: Array = frame.viewport_size_px
	var native := Profile.number(size[0], 640, 640) and Profile.number(size[1], 360, 360)
	var world := Profile.number(size[0], 1280, 1280) and Profile.number(size[1], 480, 480)
	return (native or world) and frame.camera_offset_px is Array and frame.camera_offset_px.size() == 2 and Profile.number(frame.camera_offset_px[0], 0, 1280 - size[0]) and Profile.number(frame.camera_offset_px[1], 0, 480 - size[1]) and Profile.number(frame.visual_time_seconds, 0, 86400)

static func padding(k: Array) -> Vector2i:
	return Vector2i(ceili(absf(k[0]) * MAX_CAMERA.x) + 4 if k[0] != 0 else 0, ceili(absf(k[1]) * MAX_CAMERA.y) + 4 if k[1] != 0 else 0)

static func layer_offset(camera: Vector2, k: Array) -> Vector2:
	return -camera + (camera * Vector2(k[0], k[1])).round()

static func sway(animation: Dictionary, world_y: float, visual_time: float) -> float:
	var weight := clampf((world_y - animation.root_y) * animation.get("growth", -1) / animation.height, 0, 1)
	# Subtract the initial phase: time zero retains the chosen WG-1 stem pose.
	return roundf(animation.get("amplitude", 2.0) * 0.5 * (sin(visual_time * animation.get("omega", 0.65) + animation.phase) - sin(animation.phase)) * weight * weight)

static func bands(animation: Dictionary, texture_height: int, visual_time: float) -> Array:
	# Sway is monotonic along a patch. Find the integer rounding thresholds instead
	# of reevaluating sine for hundreds of rows. Neighbors guard half-pixel ties.
	var result: Array = []
	var amount: float = animation.get("amplitude", 2.0) * 0.5 * (sin(visual_time * animation.get("omega", 0.65) + animation.phase) - sin(animation.phase))
	var magnitude := absf(amount)
	var cuts: Array[int] = [0, texture_height]
	for level in ceili(magnitude):
		if level + 0.5 > magnitude: continue
		var boundary: float = animation.root_y + animation.get("growth", -1) * animation.height * sqrt((level + 0.5) / magnitude) - animation.origin_px[1]
		for neighbor in range(-1, 3):
			var cut := clampi(floori(boundary) + neighbor, 0, texture_height)
			if not cuts.has(cut): cuts.append(cut)
	cuts.sort()
	for index in range(cuts.size() - 1):
		var row := cuts[index]
		var height := cuts[index + 1] - row
		var weight := clampf((animation.origin_px[1] + row - animation.root_y) * animation.get("growth", -1) / animation.height, 0, 1)
		var shift := roundf(amount * weight * weight)
		if not result.is_empty() and result[-1].shift == shift: result[-1].height += height
		else: result.append({"row": row, "height": height, "shift": shift})
	return result
