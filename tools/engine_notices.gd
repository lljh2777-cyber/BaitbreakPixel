extends SceneTree

func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string("This game uses Godot Engine " + Engine.get_version_info().string + "\nhttps://godotengine.org\n\n")
	file.store_string(Engine.get_license_text())
	file.store_string("\n\nThird-party components and copyright notices:\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(), "  "))
	file.store_string("\n\nComponent license texts:\n")
	var licenses := Engine.get_license_info()
	for license in licenses:
		file.store_string("\n\n" + license + "\n" + licenses[license])
	file.close()
	quit()
