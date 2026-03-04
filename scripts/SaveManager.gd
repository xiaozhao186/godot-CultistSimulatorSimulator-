extends Node

const SAVE_DIR = "user://saves/"
const AUTO_SAVE_NAME = "autosave"

signal game_saved(slot_name)
signal game_loaded(data)

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func save_game(slot_name: String = AUTO_SAVE_NAME) -> void:
	var save_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"scenario_id": GameManager.current_scenario_id if GameManager.current_scenario_id else "",
		"cards": _serialize_cards(),
		"verbs": _serialize_verbs(),
		# "events": _serialize_events(), # TODO: Implement EventPanel serialization
		"global_variables": {} # Placeholder
	}
	
	var file = FileAccess.open(SAVE_DIR + slot_name + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		print("Game saved to: " + slot_name)
		game_saved.emit(slot_name)
	else:
		printerr("Failed to save game: " + slot_name)

func load_game(slot_name: String = AUTO_SAVE_NAME) -> void:
	var path = SAVE_DIR + slot_name + ".json"
	if not FileAccess.file_exists(path):
		printerr("Save file not found: " + path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.data
			_apply_load_data(data)
			game_loaded.emit(data)
		else:
			printerr("JSON Parse Error: ", json.get_error_message())

func has_save(slot_name: String = AUTO_SAVE_NAME) -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot_name + ".json")

func _serialize_cards() -> Array:
	var cards = []
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		for child in tabletop.get_children():
			if child is Card and not child.is_queued_for_deletion():
				# Skip cards that are currently held in an event slot
				# We check this by seeing if the card has the 'in_event_slot' meta flag
				if child.has_meta("in_event_slot") and child.get_meta("in_event_slot"):
					continue
				if child.has_meta("in_event_storage") and child.get_meta("in_event_storage"):
					continue
					
				cards.append({
					"id": child.data.id,
					"pos_x": child.global_position.x,
					"pos_y": child.global_position.y,
					"lifetime": child.current_lifetime,
					"stack_count": child.stack_count
				})
	return cards

func _serialize_verbs() -> Array:
	var verbs = []
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		for child in tabletop.get_children():
			if child is Verb and not child.is_queued_for_deletion():
				# Use Verb's serialize method
				verbs.append(child.serialize())
	return verbs

func _apply_load_data(data: Dictionary) -> void:
	# This function assumes we are already in the Tabletop scene or handles transition
	# For now, let's assume GameManager handles the scene switch and then calls this,
	# OR this function triggers the scene switch.
	# Let's delegate the actual object reconstruction to GameManager to keep dependencies clean.
	GameManager.restore_game_state(data)
