extends Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	text = "Pause"
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	get_tree().paused = not get_tree().paused
	text = "Resume" if get_tree().paused else "Pause"
