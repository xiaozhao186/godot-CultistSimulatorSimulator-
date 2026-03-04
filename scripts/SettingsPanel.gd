extends Control

@onready var close_button: Button = $Panel/Root/Header/Close
@onready var resolution_option: OptionButton = $Panel/Root/Items/ResolutionRow/ResolutionOption
@onready var debug_toggle: CheckButton = $Panel/Root/Items/DebugRow/DebugToggle
@onready var debug_logs_toggle: CheckButton = $Panel/Root/Items/DebugLogsRow/DebugLogsToggle
@onready var save_exit_button: Button = $Panel/Root/Items/SaveExitButton

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(800, 600),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_on_close_pressed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	if debug_toggle:
		debug_toggle.toggled.connect(_on_debug_toggled)
		debug_toggle.button_pressed = AppState.is_debug_console_enabled()
	if debug_logs_toggle:
		debug_logs_toggle.toggled.connect(_on_debug_logs_toggled)
		debug_logs_toggle.button_pressed = AppState.is_debug_logs_enabled()
		
	AppState.settings_open_changed.connect(_on_settings_open_changed)
	SettingsService.resolution_changed.connect(_sync_resolution)
	_build_resolution_items()
	_build_volume_controls()
	_sync_resolution(SettingsService.get_resolution())
	visible = AppState.is_settings_open()
	
	if save_exit_button:
		save_exit_button.pressed.connect(_on_save_exit_pressed)
		# Only show if we are in the Tabletop scene (in-game)
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.name == "Tabletop":
			save_exit_button.visible = true
		else:
			save_exit_button.visible = false

func _on_save_exit_pressed() -> void:
	if SaveManager:
		SaveManager.save_game("autosave")
	AppState.close_settings()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_debug_toggled(toggled: bool) -> void:
	AppState.set_debug_console_enabled(toggled)

func _on_debug_logs_toggled(toggled: bool) -> void:
	AppState.set_debug_logs_enabled(toggled)

func _build_resolution_items() -> void:
	resolution_option.clear()
	for r in RESOLUTIONS:
		resolution_option.add_item(str(r.x) + "×" + str(r.y))

func _on_settings_open_changed(open: bool) -> void:
	visible = open
	if open:
		_sync_resolution(SettingsService.get_resolution())
		if AudioManager:
			AudioManager.play_sfx("panel_open")
	else:
		if AudioManager:
			AudioManager.play_sfx("panel_close")

func _on_close_pressed() -> void:
	visible = false
	AppState.close_settings()

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	SettingsService.set_resolution(RESOLUTIONS[index])

func _sync_resolution(res_size: Vector2i) -> void:
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == res_size:
			resolution_option.select(i)
			return

func _build_volume_controls() -> void:
	var items_container = $Panel/Root/Items
	if not items_container: return

	# Separator
	items_container.add_child(HSeparator.new())
	
	# Title
	var label = Label.new()
	label.text = "Audio Settings"
	# label.add_theme_font_size_override("font_size", 18) # Optional styling
	items_container.add_child(label)
	
	# Sliders
	_add_volume_slider(items_container, "Master Volume", "Master", SettingsService.master_volume)
	_add_volume_slider(items_container, "Music Volume", "Music", SettingsService.music_volume)
	_add_volume_slider(items_container, "SFX Volume", "SFX", SettingsService.sfx_volume)

func _add_volume_slider(parent: Node, label_text: String, bus_name: String, current_value: float) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = current_value
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(val): SettingsService.set_volume(bus_name, val))
	row.add_child(slider)
