extends Node

signal resolution_changed(size: Vector2i)
signal settings_saved(path: String)
signal settings_load_failed(message: String)
signal settings_save_failed(message: String)

const SETTINGS_PATH := "user://settings.json"

var _resolution: Vector2i = Vector2i.ZERO
var _store := preload("res://scripts/SettingsStore.gd").new()

# Volume Settings (0.0 - 1.0)
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Wait for AudioManager to be ready if it's an autoload
	call_deferred("_load_and_apply")
	AppState.speed_changed.connect(_on_speed_changed)

func get_resolution() -> Vector2i:
	if _resolution != Vector2i.ZERO:
		return _resolution
	return DisplayServer.window_get_size()

func set_resolution(size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	_resolution = size
	if not OS.has_feature("editor"):
		DisplayServer.window_set_size(size)
	resolution_changed.emit(size)
	_save()
	return true

func _load_and_apply() -> void:
	var loaded = _load()
	if loaded.has("resolution") and loaded.resolution is Array and loaded.resolution.size() == 2:
		var w = int(loaded.resolution[0])
		var h = int(loaded.resolution[1])
		if w > 0 and h > 0:
			_resolution = Vector2i(w, h)
			if not OS.has_feature("editor"):
				DisplayServer.window_set_size(_resolution)
			resolution_changed.emit(_resolution)
	if loaded.has("speed"):
		var speed = float(loaded.speed)
		AppState.set_speed_multiplier(speed)
		
	# Apply Volume
	if loaded.has("master_volume"):
		master_volume = float(loaded.master_volume)
	if loaded.has("music_volume"):
		music_volume = float(loaded.music_volume)
	if loaded.has("sfx_volume"):
		sfx_volume = float(loaded.sfx_volume)
		
	# Sync with AudioManager
	if AudioManager:
		AudioManager.set_master_volume(master_volume)
		AudioManager.set_music_volume(music_volume)
		AudioManager.set_sfx_volume(sfx_volume)

func set_volume(bus_name: String, value: float) -> void:
	match bus_name:
		"Master":
			master_volume = value
			if AudioManager: AudioManager.set_master_volume(value)
		"Music":
			music_volume = value
			if AudioManager: AudioManager.set_music_volume(value)
		"SFX":
			sfx_volume = value
			if AudioManager: AudioManager.set_sfx_volume(value)
	_save()

func _load() -> Dictionary:
	_store.load_failed.connect(func(msg: String) -> void: settings_load_failed.emit(msg), CONNECT_ONE_SHOT)
	return _store.load(SETTINGS_PATH)

func _save() -> void:
	var data: Dictionary = {
		"resolution": [get_resolution().x, get_resolution().y],
		"speed": AppState.get_speed_multiplier(),
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}
	_store.save_failed.connect(func(msg: String) -> void: settings_save_failed.emit(msg), CONNECT_ONE_SHOT)
	if _store.save(SETTINGS_PATH, data):
		settings_saved.emit(SETTINGS_PATH)

func _on_speed_changed(_multiplier: float) -> void:
	_save()
