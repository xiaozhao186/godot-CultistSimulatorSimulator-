extends Control

@onready var pause_button: TextureButton = $Content/Buttons/PauseButton
@onready var speed_button: TextureButton = $Content/Buttons/SpeedButton
@onready var settings_button: TextureButton = $Content/Buttons/SettingsButton
@onready var speed_badge: Label = $Content/Buttons/SpeedButton/SpeedBadge

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	AppState.paused_changed.connect(_sync_pause_state)
	AppState.speed_changed.connect(_sync_speed_state)
	AppState.settings_open_changed.connect(_sync_settings_open)

	_sync_pause_state(AppState.is_paused())
	_sync_speed_state(AppState.get_speed_multiplier())
	_sync_settings_open(AppState.is_settings_open())

func _on_pause_pressed() -> void:
	if AppState.is_settings_open():
		return
	AppState.toggle_pause()

func _on_speed_pressed() -> void:
	if AppState.is_settings_open():
		return
	AppState.toggle_speed()

func _on_settings_pressed() -> void:
	if AppState.is_settings_open():
		AppState.close_settings()
	else:
		AppState.open_settings()

func _sync_pause_state(is_paused: bool) -> void:
	pause_button.button_pressed = is_paused
	pause_button.modulate = Color(1, 1, 1, 1) if not is_paused else Color(1, 0.85, 0.5, 1)

func _sync_speed_state(multiplier: float) -> void:
	speed_badge.visible = multiplier >= 2.0

func _sync_settings_open(open: bool) -> void:
	settings_button.disabled = false
	pause_button.disabled = open
	speed_button.disabled = open
