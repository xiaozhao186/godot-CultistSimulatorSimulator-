extends Node

signal paused_changed(is_paused: bool)
signal speed_changed(multiplier: float)
signal settings_open_changed(open: bool)
signal debug_console_enabled_changed(enabled: bool)
signal debug_logs_enabled_changed(enabled: bool)

var _settings_open: bool = false
var _paused_before_settings: bool = false
var _speed_multiplier: float = 1.0
var _debug_console_enabled: bool = false # Default to hidden
var _debug_logs_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_open = false

func is_debug_console_enabled() -> bool:
	return _debug_console_enabled

func set_debug_console_enabled(enabled: bool) -> void:
	if _debug_console_enabled != enabled:
		_debug_console_enabled = enabled
		debug_console_enabled_changed.emit(enabled)

func is_debug_logs_enabled() -> bool:
	return _debug_logs_enabled

func set_debug_logs_enabled(enabled: bool) -> void:
	if _debug_logs_enabled != enabled:
		_debug_logs_enabled = enabled
		debug_logs_enabled_changed.emit(enabled)

func is_settings_open() -> bool:
	return _settings_open

func get_speed_multiplier() -> float:
	return _speed_multiplier

func set_speed_multiplier(multiplier: float) -> void:
	var m = 2.0 if multiplier >= 2.0 else 1.0
	if is_equal_approx(_speed_multiplier, m):
		return
	_speed_multiplier = m
	Engine.time_scale = _speed_multiplier
	speed_changed.emit(_speed_multiplier)

func toggle_speed() -> void:
	set_speed_multiplier(2.0 if _speed_multiplier < 2.0 else 1.0)

func is_paused() -> bool:
	return get_tree().paused

func set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	paused_changed.emit(paused)

func toggle_pause() -> void:
	set_paused(not get_tree().paused)

func open_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	_paused_before_settings = get_tree().paused
	set_paused(true)
	settings_open_changed.emit(true)

func close_settings() -> void:
	if not _settings_open:
		return
	_settings_open = false
	set_paused(_paused_before_settings)
	settings_open_changed.emit(false)
