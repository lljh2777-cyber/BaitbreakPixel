extends RefCounted

# Persistence boundary. Simulation never reads user files or touches preferences.
const Rules = preload("res://scripts/game_rules.gd")

static func load_profile(file: ConfigFile) -> Dictionary:
	if int(file.get_value("rules","version",0)) in [1,Rules.VERSION]:
		var values: Variant=file.get_value("rules","values",{})
		return Rules.normalize(values) if values is Dictionary else Rules.defaults()
	var old := {}
	for key in ["line_sensitivity","line_force","effort_frequency","effort_window","effort_boost","effort_weak"]:
		if file.has_section_key("practice",key): old[key]=file.get_value("practice",key)
	for key in ["slack_hold","mouth_window","break_hold"]:
		if file.has_section_key("timing",key): old[key]=file.get_value("timing",key)
	if old.has("mouth_window") and int(file.get_value("timing","qte_revision",0))<1:
		if old.mouth_window is float or old.mouth_window is int: old.mouth_window*=0.6
	return Rules.legacy(old)

static func save_profile(file: ConfigFile, values: Dictionary) -> void:
	file.set_value("rules","version",Rules.VERSION)
	file.set_value("rules","values",Rules.normalize(values))

static func preset_names(directory: String) -> PackedStringArray:
	var names := PackedStringArray()
	# A first-use preset folder does not exist until the first save. Confirm
	# that only the leaf is absent; keep real parent/access/file errors visible.
	if not DirAccess.dir_exists_absolute(directory):
		var parent := DirAccess.open(directory.get_base_dir())
		if parent!=null and not parent.dir_exists(directory.get_file()) and not parent.file_exists(directory.get_file()):
			return names
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".json"): names.append(filename.trim_suffix(".json"))
	names.sort()
	return names

static func save_preset(directory: String, title: String, values: Dictionary) -> Error:
	var name := title.strip_edges()
	if name.is_empty() or name.length()>40 or name!=name.validate_filename() or name in [".",".."]: return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK: return error
	var file := FileAccess.open(directory.path_join(name+".json"),FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(Rules.document(values),"  "))
	file.flush()
	return file.get_error()

static func load_preset(directory: String, title: String) -> Dictionary:
	if title!=title.validate_filename() or title in [".",".."]: return {"error":"方案名无效"}
	var path := directory.path_join(title+".json")
	if not FileAccess.file_exists(path): return {"error":"找不到方案文件"}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>65536: return {"error":"方案文件无法读取或过大"}
	return Rules.parse_text(file.get_as_text())
