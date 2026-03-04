class_name UIButton
extends TextureButton

@export var hover_tint: Color = Color(1, 1, 1, 0.15)

var _base_modulate: Color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_modulate = modulate
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_click")

func _on_mouse_entered() -> void:
	modulate = _base_modulate + hover_tint

func _on_mouse_exited() -> void:
	modulate = _base_modulate
