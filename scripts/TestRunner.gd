extends Node

var _failures := 0

func _ready() -> void:
	_test_settings_store_roundtrip()
	_test_settings_store_missing_file()
	_test_settings_store_invalid_json()
	if _failures == 0:
		print("[TEST] All tests passed.")
	else:
		push_error("[TEST] Failures: " + str(_failures))
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(_failures)

func _assert(cond: bool, message: String) -> void:
	if cond:
		return
	_failures += 1
	push_error("[TEST] " + message)

func _test_settings_store_roundtrip() -> void:
	var store := preload("res://scripts/SettingsStore.gd").new()
	var path = "user://_test_settings.json"
	var data: Dictionary = { "resolution": [1920, 1080], "speed": 2 }
	_assert(store.save(path, data), "SettingsStore.save should return true")
	var loaded = store.load(path)
	_assert(loaded.has("resolution"), "Loaded settings should have resolution")
	_assert(loaded.has("speed"), "Loaded settings should have speed")

func _test_settings_store_missing_file() -> void:
	var store := preload("res://scripts/SettingsStore.gd").new()
	var path = "user://_missing_settings.json"
	var loaded = store.load(path)
	_assert(typeof(loaded) == TYPE_DICTIONARY and loaded.is_empty(), "Missing file should load as empty dictionary")

func _test_settings_store_invalid_json() -> void:
	var path = "user://_invalid_settings.json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("not json")
	var store := preload("res://scripts/SettingsStore.gd").new()
	var loaded = store.load(path)
	_assert(typeof(loaded) == TYPE_DICTIONARY and loaded.is_empty(), "Invalid json should load as empty dictionary")
