extends RefCounted

static func sprite(rows: Array[String], palette: Dictionary) -> Texture2D:
	var width := 0
	for row in rows: width = maxi(width, row.length())
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var token := rows[y][x]
			if palette.has(token): image.set_pixel(x, y, Color(palette[token]))
	return ImageTexture.create_from_image(image)

static func fish() -> Texture2D:
	return sprite([
		".............dd.........",
		"............dffd........",
		"..dd.....ddddfffdddd....",
		"..dfd..ddfffffffffffdd..",
		"...dfddffffffffhhfffffd.",
		"...dfffffffffhhhhhwwfffd",
		"....dffffffffhhhhhwbwffd",
		"...dffffffffffffhhwwwffd",
		"...dfddffffllffffffffdd",
		"..dfd..ddlllpllllllddd..",
		"..dd.....ddllpllldd.....",
		"...........dddddd......."],
		{"d":"985436", "f":"e6a448", "h":"ffd879", "l":"f3c780", "p":"fff0b5", "w":"fff6d3", "b":"132a38"})

static func reed() -> Texture2D:
	return sprite([
		"....tt..........", "....tt.......t..", "....tt......tt..", "....ss......tt..",
		".....s......ss..", "..l..s.....s....", "..ll.s.....s....", "...lls..l..s....",
		"....ss..ll.s....", ".....s...lls....", ".....s....ss....", ".....s....s.....",
		".....s....s.....", ".....s....s.....", ".....s....s.....", "....sss..sss...."],
		{"t":"c59d63", "s":"437d6d", "l":"67ac85"})
