class_name SettingsStore
extends RefCounted

signal load_failed(message: String)
signal save_failed(message: String)

func load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_failed.emit("无法打开设置文件读取: " + path)
		return {}
	var text = f.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_failed.emit("设置文件格式错误: " + path)
		return {}
	return parsed

func save(path: String, data: Dictionary) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		save_failed.emit("无法打开设置文件写入: " + path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true
