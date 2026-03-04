extends Control

@onready var close_button: Button = $Panel/Root/Header/Close
@onready var version_list: ItemList = $Panel/Root/Body/VersionList
@onready var content_text: RichTextLabel = $Panel/Root/Body/Content/Scroll/Content

const VERSION_DIR := "res://versiondata"

var _entries: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(queue_free)
	version_list.item_selected.connect(_on_version_selected)
	_scan_versions()
	if _entries.is_empty():
		content_text.text = "No version data."
		return
	version_list.select(0)
	_load_entry(0)

func _on_version_selected(index: int) -> void:
	_load_entry(index)

func _scan_versions() -> void:
	_entries.clear()
	version_list.clear()
	var dir = DirAccess.open(VERSION_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower = file_name.to_lower()
			if lower.ends_with(".md") or lower.ends_with(".txt"):
				var full_path = VERSION_DIR + "/" + file_name
				_entries.append({
					"file_name": file_name,
					"path": full_path,
					"version": _parse_semver_from_name(file_name)
				})
		file_name = dir.get_next()
	_entries.sort_custom(_sort_entry_desc)
	for e in _entries:
		version_list.add_item(String(e.file_name))

func _sort_entry_desc(a: Dictionary, b: Dictionary) -> bool:
	var va = a.get("version")
	var vb = b.get("version")
	if va is Array and vb is Array:
		return _cmp_semver(va, vb) > 0
	if va is Array and not (vb is Array):
		return true
	if vb is Array and not (va is Array):
		return false
	return String(a.get("file_name", "")) > String(b.get("file_name", ""))

func _parse_semver_from_name(name: String):
	var re = RegEx.new()
	var err = re.compile("^v(\\d+)\\.(\\d+)\\.(\\d+)")
	if err != OK:
		return null
	var m = re.search(name)
	if m == null:
		return null
	return [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))]

func _cmp_semver(a: Array, b: Array) -> int:
	for i in range(3):
		var da = int(a[i])
		var db = int(b[i])
		if da < db:
			return -1
		if da > db:
			return 1
	return 0

func _load_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var path = String(_entries[index].path)
	if not FileAccess.file_exists(path):
		content_text.text = "Missing file: " + path
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		content_text.text = "Failed to open: " + path
		return
	content_text.text = f.get_as_text()

