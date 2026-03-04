extends CanvasLayer

@onready var event_group_option: OptionButton = $Panel/VBoxContainer/EventGroupOption
@onready var event_option: OptionButton = $Panel/VBoxContainer/EventOption
@onready var verb_option: OptionButton = $Panel/VBoxContainer/VerbOption
@onready var bind_button: Button = $Panel/VBoxContainer/BindButton
@onready var spawn_verb_button: Button = $Panel/VBoxContainer/SpawnVerbButton
@onready var spawn_card_button: Button = $Panel/VBoxContainer/SpawnCardButton
@onready var card_option: OptionButton = $Panel/VBoxContainer/CardOption

var available_events: Array[EventData] = []
var available_cards: Array[CardData] = []
var available_verbs: Array[VerbData] = []
var active_verbs: Array[Verb] = []
var _event_groups: Dictionary = {}
var _group_names: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bind_button.pressed.connect(_on_bind_pressed)
	spawn_verb_button.pressed.connect(_on_spawn_verb_pressed)
	spawn_card_button.pressed.connect(_on_spawn_card_pressed)
	event_group_option.item_selected.connect(func(_idx): _rebuild_event_list())
	
	visible = AppState.is_debug_console_enabled()
	AppState.debug_console_enabled_changed.connect(_on_debug_console_enabled_changed)
	
	# Scan for events and cards
	_scan_data("res://data")
	_finalize_scan()

func _on_debug_console_enabled_changed(enabled: bool) -> void:
	visible = enabled

func _scan_data(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_data(path + "/" + file_name)
			else:
				var original_name = file_name.trim_suffix(".remap").trim_suffix(".import")
				if original_name.ends_with(".tres") or original_name.ends_with(".res"):
					var res_path = path + "/" + original_name
					var res = load(res_path)
					if res is EventData:
						available_events.append(res)
						var group = _get_event_group(res_path)
						if not _event_groups.has(group):
							_event_groups[group] = []
						_event_groups[group].append(res)
					elif res is CardData:
						available_cards.append(res)
						card_option.add_item(res.name + " (" + res.id + ")")
					elif res is VerbData:
						available_verbs.append(res)
			file_name = dir.get_next()
	else:
		print("Failed to open data directory: " + path)

func _finalize_scan() -> void:
	_group_names.clear()
	for k in _event_groups.keys():
		_group_names.append(String(k))
	_group_names.sort()
	event_group_option.clear()
	event_group_option.add_item("All")
	for group_name in _group_names:
		event_group_option.add_item(group_name)
	_rebuild_event_list()
	_rebuild_verb_list()

func _rebuild_event_list() -> void:
	event_option.clear()
	available_events.clear()
	var selected_group = event_group_option.get_item_text(event_group_option.selected) if event_group_option.item_count > 0 else "All"
	if selected_group == "All":
		for group in _group_names:
			for ev in _event_groups.get(group, []):
				available_events.append(ev)
	else:
		for ev in _event_groups.get(selected_group, []):
			available_events.append(ev)
	for ev in available_events:
		event_option.add_item(ev.title + " (" + ev.id + ")")

func _rebuild_verb_list() -> void:
	verb_option.clear()
	for v in available_verbs:
		verb_option.add_item(v.title + " (" + v.id + ")")

func _get_event_group(res_path: String) -> String:
	var idx = res_path.find("/Events/")
	if idx == -1:
		return "Other"
	var rest = res_path.substr(idx + "/Events/".length())
	var parts = rest.split("/")
	if parts.is_empty():
		return "Other"
	return parts[0]

func _on_bind_pressed() -> void:
	if available_events.is_empty(): return
	
	var event_idx = event_option.selected
	if event_idx == -1: return
	var selected_event = available_events[event_idx]
	
	# Spawn a new Verb instead of binding to an existing one
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop: return
	
	var verb = load("res://scenes/Verb.tscn").instantiate()
	
	# Create a temporary VerbData for this event
	var verb_data = VerbData.new()
	verb_data.id = "debug_" + selected_event.id + "_" + str(randi())
	verb_data.title = selected_event.title
	verb_data.default_event = selected_event
	# Optional: Set a generic icon if needed
	
	tabletop.add_child(verb)
	verb.setup(verb_data)
	
	# Position near the camera center, slightly offset
	var cam_pos = get_viewport().get_camera_2d().global_position
	verb.position = cam_pos + Vector2(randf_range(-100, 100), randf_range(-50, 50))
	
	print("Spawned new verb for event: " + selected_event.title)

func _on_spawn_verb_pressed() -> void:
	if available_verbs.is_empty():
		return
	var idx = verb_option.selected
	if idx == -1:
		return
	var data = available_verbs[idx]
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop:
		return
	var verb = load("res://scenes/Verb.tscn").instantiate()
	tabletop.add_child(verb)
	verb.setup(data)
	var cam_pos = get_viewport().get_camera_2d().global_position
	verb.position = cam_pos + Vector2(randf_range(-100, 100), randf_range(-50, 50))

func _on_spawn_card_pressed():
	if available_cards.is_empty(): 
		_spawn_generic_card()
		return
		
	var idx = card_option.selected
	if idx == -1: return
	var data = available_cards[idx]
	_spawn_card_instance(data)

func _spawn_generic_card():
	var card_data = CardData.new()
	card_data.id = "test_card"
	card_data.name = "Test Card"
	card_data.attributes = {StringName("reason"): 1}
	card_data.icon = preload("res://icon.svg")
	_spawn_card_instance(card_data)

func _spawn_card_instance(data: CardData):
	var card = load("res://scenes/Card.tscn").instantiate()
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		tabletop.add_child(card)
		card.setup(data)
		card.position = get_viewport().get_camera_2d().global_position + Vector2(0, 100)
