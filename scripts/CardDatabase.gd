extends Node

var card_db: Dictionary = {}

func _ready() -> void:
	_scan_cards("res://data")
	print("Card Database Loaded: " + str(card_db.size()) + " entries.")

func _scan_cards(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_cards(path + "/" + file_name)
			else:
				var original_name = file_name.trim_suffix(".remap").trim_suffix(".import")
				if original_name.ends_with(".tres") or original_name.ends_with(".res"):
					var res = load(path + "/" + original_name)
					if res is CardData:
						if card_db.has(res.id):
							push_warning("Duplicate card ID found: " + res.id)
						card_db[res.id] = res
			file_name = dir.get_next()

func get_card_data(id: String) -> CardData:
	return card_db.get(id, null)
