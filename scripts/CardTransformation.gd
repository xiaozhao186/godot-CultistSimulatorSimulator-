class_name CardTransformation
extends Resource

@export var target_index: int = 0
@export var required_card_id: String = ""
@export_enum("transform", "consume", "return") var action: String = "transform"
@export var resulting_card_id: String = "" # For transform
