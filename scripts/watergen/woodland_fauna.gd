extends RefCounted
## Decorative residents of the authored woodland pond. Anchors are visual only.
## No World, Authority, food, hook, NPC or collision inputs; explicit local time.
const SEED := 713284
const CLEAR_ZONE := Rect2(320, 77, 679, 230)
const PALETTES := {
	"shrimp": {"d": "553d34", "b": "a46d50", "h": "be9070", "e": "2e3635"},
	"snail": {"d": "394b42", "b": "7b8165", "h": "a0a183"},
	"distant_fish": {"d": "255968", "b": "54818a", "h": "54818a"}
}
const ROWS := {
	"shrimp": [
		["............hh", ".....bbbb..h..", "...bbhbbbeb...", ".bbdbbbbbb....", "dd..d.d.d.....", "....d..d..d..."],
		["............hh", ".....bbbb..h..", "...bbhbbbeb...", ".bbdbbbbbb....", "dd..d.d.d.....", "...d..d..d...."]],
	"snail": [
		["..ddddd....", ".dbbhbbd...", ".dbhdbbd.h.", ".dbbbbd..dh", "..ddddbbbb.", ".bbbbbbbd.."],
		["..ddddd....", ".dbbhbbd.h.", ".dbhdbbd.dh", ".dbbbbd..d.", "..ddddbbbb.", ".bbbbbbbd.."]],
	"distant_fish": [
		["d...bb..", ".dbbbhbd", "d...dd.."],
		[".d..bb..", "ddbbbhbd", ".d..dd.."]]
}
var texture: Texture2D
var regions: Dictionary = {}
var residents: Array[Dictionary] = []
var schools: Array[Dictionary] = []
var upload_count := 0

func _init() -> void:
	# Atlas is prepared exactly once for this scenery layer, never in draw/sample.
	var atlas := Image.create(96, 8, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var column := 0
	for kind: String in ["shrimp", "snail", "distant_fish"]:
		regions[kind] = []
		for rows: Array in ROWS[kind]:
			var width: int = rows[0].length()
			var height := rows.size()
			for y in height:
				for x in width:
					var token: String = rows[y][x]
					if PALETTES[kind].has(token): atlas.set_pixel(column + x, y, Color(PALETTES[kind][token]))
			regions[kind].append(Rect2(column, 0, width, height))
			column += 16
	texture = ImageTexture.create_from_image(atlas)
	upload_count = 1
	# Sparse fixed art anchors; they never create simulation actors.
	residents = [
		{"id": "shrimp-left", "kind": "shrimp", "anchor": Vector2(170, 339), "travel": 7.0, "slope": 0.30, "period": 21.0, "phase": 2.0},
		{"id": "shrimp-trough", "kind": "shrimp", "anchor": Vector2(465, 414), "travel": 8.0, "slope": 0.17, "period": 25.0, "phase": 8.0},
		{"id": "shrimp-right", "kind": "shrimp", "anchor": Vector2(956, 432), "travel": 6.0, "slope": -0.25, "period": 23.0, "phase": 13.0},
		{"id": "snail-wood", "kind": "snail", "anchor": Vector2(435, 315), "travel": 0.0, "slope": 0.0, "period": 16.0, "phase": 1.0},
		{"id": "snail-stone", "kind": "snail", "anchor": Vector2(1119, 296), "travel": 0.0, "slope": 0.0, "period": 19.0, "phase": 5.0}
	]
	schools = [
		{"id": "school-left", "anchor": Vector2(248, 149), "amplitude": Vector2(13, 3), "period": 31.0, "phase": 0.3, "direction": 1, "offsets": [Vector2(-30, -3), Vector2(-12, -12), Vector2(-7, 6), Vector2(13, -4), Vector2(27, 10)]},
		{"id": "school-right", "anchor": Vector2(1069, 228), "amplitude": Vector2(12, 3), "period": 37.0, "phase": 2.1, "direction": -1, "offsets": [Vector2(-27, -6), Vector2(-12, 9), Vector2(1, -12), Vector2(14, 1), Vector2(31, 12)]}
	]

func sample(visual_time: float, visual_seed := SEED) -> Array[Dictionary]:
	if not is_finite(visual_time) or visual_time < 0: return []
	var result: Array[Dictionary] = []
	# Integer seed only changes phases; visual habitats and density are stable.
	var phase_offset := posmod((visual_seed ^ 0x51fa17) * 1664525 + 1013904223, 2147483647) / 2147483647.0 * TAU
	for animal: Dictionary in residents:
		var cycle := fmod(visual_time + animal.phase + phase_offset, animal.period)
		var displacement := 0.0
		var bounce := 0.0
		var moving := false
		if animal.kind == "shrimp":
			if cycle >= 11 and cycle < 13:
				var t := (cycle - 11) / 2.0
				displacement = animal.travel * (0.5 - 0.5 * cos(t * PI)); bounce = -sin(t * PI) * 1.2; moving = true
			elif cycle >= 13 and cycle < animal.period - 3: displacement = animal.travel
			elif cycle >= animal.period - 3:
				var t: float = (cycle - animal.period + 3) / 3.0
				displacement = animal.travel * (0.5 + 0.5 * cos(t * PI)); moving = true
		var feet: Vector2 = animal.anchor + Vector2(displacement, displacement * animal.slope + bounce)
		var frame := int(cycle * 5) % 2 if moving else int(cycle / 4) % 2
		var region: Rect2 = regions[animal.kind][frame]
		result.append({"id": animal.id, "kind": animal.kind, "position": (feet - Vector2(region.size.x * 0.5, region.size.y)).round(), "region": region, "opacity": 0.92 if animal.kind == "shrimp" else 0.82, "flip": false})
	for school: Dictionary in schools:
		var angle: float = visual_time / school.period * TAU + school.phase + phase_offset
		var center: Vector2 = school.anchor + Vector2(sin(angle) * school.amplitude.x * school.direction, sin(angle * 0.7) * school.amplitude.y)
		for index in school.offsets.size():
			var offset: Vector2 = school.offsets[index]
			var frame := int(visual_time * 1.5 + index) % 2
			result.append({"id": school.id + "/" + str(index), "kind": "distant_fish", "position": (center + offset + Vector2(0, sin(angle + index) * 1.2)).round(), "region": regions.distant_fish[frame], "opacity": 0.46, "flip": cos(angle) * school.direction < 0})
	return result

func draw(view: Node2D, visual_time: float, pass_name: String="background", hosts: Dictionary={}) -> void:
	for animal: Dictionary in sample(visual_time):
		var attached: bool=animal.kind=="snail"
		var layer: String="attached" if attached else "foreground" if animal.kind=="shrimp" else "background"
		if layer!=pass_name: continue
		var opacity: float=animal.opacity
		if attached:
			var host: String="wood_main" if animal.id=="snail-wood" else "stone_east"
			if not hosts.has(host): continue
			opacity*=hosts[host]
		var destination := Rect2(animal.position, animal.region.size)
		if animal.flip: destination.position.x += destination.size.x; destination.size.x = -destination.size.x
		view.draw_texture_rect_region(texture, destination, animal.region, Color(1, 1, 1, opacity))

func debug_draw(view: Node2D, visual_time: float) -> void:
	for animal: Dictionary in sample(visual_time):
		view.draw_rect(Rect2(animal.position, animal.region.size).grow(3), Color(0.6, 0.85, 0.75, 0.7), false, 1)
