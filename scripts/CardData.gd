class_name CardData
extends Resource

@export var id: String
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var tags: Array[String] = [] # Pure attributes (e.g., "Fire", "Human")
@export var attributes: Dictionary[StringName, int] = {} # Numeric stats (e.g., {"Attack": 5})
@export var lifetime: float = -1.0 # -1 means infinite
@export var stackable: bool = false
@export var transform_on_expire: bool = false
@export var transform_card_id: String = ""

func has_attribute(key) -> bool:
	var k = StringName(String(key).strip_edges())
	if attributes.has(k):
		return true
	var ks = String(k)
	return attributes.has(ks)

func get_attribute(key, default_value: int = 0) -> int:
	var k = StringName(String(key).strip_edges())
	if attributes.has(k):
		return int(attributes[k])
	var ks = String(k)
	if attributes.has(ks):
		return int(attributes[ks])
	return int(default_value)
