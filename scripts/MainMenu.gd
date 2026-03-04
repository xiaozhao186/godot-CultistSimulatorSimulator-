extends Control

@onready var main_menu_container: VBoxContainer = $CenterContainer/VBoxContainer
@onready var scenario_selection_panel: Panel = $ScenarioSelectionPanel
@onready var scenario_list: ItemList = $ScenarioSelectionPanel/VBoxContainer/ScenarioList
@onready var start_scenario_button: Button = $ScenarioSelectionPanel/VBoxContainer/StartButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var version_button: Button = $VersionButton

# Path to scan for scenarios
const SCENARIO_PATH = "res://data/scenarios/"
const VERSION_DIR = "res://versiondata"

var _selected_scenario: ScenarioData = null
var _available_scenarios: Array[ScenarioData] = []

func _ready() -> void:
	_setup_menu()
	_scan_scenarios()
	_sync_version_button()
	
	# Check for autosave
	if SaveManager.has_save("autosave"):
		continue_button.disabled = false
	else:
		continue_button.disabled = true

	# Play Main Menu Music
	# Using "伏尔加船夫" as placeholder for Main Menu
	if AudioManager:
		AudioManager.play_menu_music()

func _setup_menu() -> void:
	$CenterContainer/VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$CenterContainer/VBoxContainer/NewGameButton.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	$CenterContainer/VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)
	# Exit button sound might not play fully if app quits immediately, but we add it anyway
	
	$ScenarioSelectionPanel/VBoxContainer/HBoxContainer/BackButton.pressed.connect(_on_scenario_back_pressed)
	$ScenarioSelectionPanel/VBoxContainer/HBoxContainer/BackButton.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	start_scenario_button.pressed.connect(_on_start_scenario_pressed)
	start_scenario_button.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))
	
	scenario_list.item_selected.connect(_on_scenario_selected)
	
	scenario_selection_panel.visible = false
	
	if version_button:
		version_button.pressed.connect(_on_version_pressed)
		version_button.pressed.connect(func(): if AudioManager: AudioManager.play_sfx("ui_click"))

func _sync_version_button() -> void:
	if not version_button:
		return
	version_button.text = _get_latest_version_label()

func _on_version_pressed() -> void:
	var panel = load("res://scenes/ChangelogPanel.tscn").instantiate()
	add_child(panel)
	panel.visible = true

func _get_latest_version_label() -> String:
	var dir = DirAccess.open(VERSION_DIR)
	if dir == null:
		return "v0.0.0"
	var best_name := ""
	var best_semver = null
	var re = RegEx.new()
	if re.compile("^v(\\d+)\\.(\\d+)\\.(\\d+)") != OK:
		return "v0.0.0"
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower = file_name.to_lower()
			if lower.ends_with(".md") or lower.ends_with(".txt"):
				var m = re.search(file_name)
				var semver = null
				if m:
					semver = [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))]
				if semver is Array:
					if best_semver == null or _cmp_semver(semver, best_semver) > 0:
						best_semver = semver
						best_name = file_name
				else:
					if best_semver == null and file_name > best_name:
						best_name = file_name
		file_name = dir.get_next()
	if best_name == "":
		return "v0.0.0"
	var m2 = re.search(best_name)
	if m2:
		return "v" + m2.get_string(1) + "." + m2.get_string(2) + "." + m2.get_string(3)
	return best_name

func _cmp_semver(a: Array, b: Array) -> int:
	for i in range(3):
		var da = int(a[i])
		var db = int(b[i])
		if da < db:
			return -1
		if da > db:
			return 1
	return 0

func _scan_scenarios() -> void:
	_available_scenarios.clear()
	var dir = DirAccess.open(SCENARIO_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				var original_name = file_name.trim_suffix(".remap").trim_suffix(".import")
				if original_name.ends_with(".tres") or original_name.ends_with(".res"):
					var res = load(SCENARIO_PATH + original_name)
					if res is ScenarioData:
						_available_scenarios.append(res)
			file_name = dir.get_next()
	
	# Update List
	scenario_list.clear()
	for i in range(_available_scenarios.size()):
		var s = _available_scenarios[i]
		scenario_list.add_item(s.title + " (" + s.id + ")")

func _on_new_game_pressed() -> void:
	main_menu_container.visible = false
	scenario_selection_panel.visible = true
	start_scenario_button.disabled = true
	scenario_list.deselect_all()

func _on_continue_pressed() -> void:
	GameManager.load_game("autosave")

func _on_settings_pressed() -> void:
	# Instantiate SettingsPanel
	var settings = load("res://scenes/SettingsPanel.tscn").instantiate()
	add_child(settings)
	# SettingsPanel usually handles its own visibility and pausing
	settings.visible = true

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_scenario_back_pressed() -> void:
	scenario_selection_panel.visible = false
	main_menu_container.visible = true

func _on_scenario_selected(index: int) -> void:
	if index >= 0 and index < _available_scenarios.size():
		_selected_scenario = _available_scenarios[index]
		start_scenario_button.disabled = false

func _on_start_scenario_pressed() -> void:
	if _selected_scenario:
		GameManager.start_scenario(_selected_scenario)
