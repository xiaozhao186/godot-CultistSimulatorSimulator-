extends Control

@onready var title_label: Label = $Panel/Root/Title
@onready var body_label: RichTextLabel = $Panel/Root/Body
@onready var image_rect: TextureRect = $Panel/Root/Image
@onready var back_button: Button = $Panel/Root/BackButton

var ending: EndingData = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.pressed.connect(_on_back_pressed)
	_apply()

func setup(data: EndingData) -> void:
	ending = data
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	if ending == null:
		title_label.text = ""
		body_label.text = ""
		image_rect.texture = null
		return
	title_label.text = ending.title
	body_label.text = ending.body
	image_rect.texture = ending.image

func _on_back_pressed() -> void:
	AppState.set_paused(false)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
