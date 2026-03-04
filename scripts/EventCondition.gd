@tool
extends Resource
class_name EventCondition

enum Type { HAS_TAG, SUM, COUNT, TABLE_HAS_TAG, TABLE_SUM, TABLE_COUNT, TABLE_HAS_CARD_ID, TABLE_COUNT_CARD_ID }
enum Op { GTE, GT, LTE, LT, EQ, NEQ }

@export var type: Type = Type.HAS_TAG:
	set(v):
		type = v
		notify_property_list_changed()

@export var tag: String = ""
@export var attribute: String = ""
@export var card_id: String = ""
@export var value: int = 0
@export var op: Op = Op.GTE

func _validate_property(property: Dictionary) -> void:
	if property.name == "tag":
		if type == Type.SUM or type == Type.TABLE_SUM or type == Type.TABLE_HAS_CARD_ID or type == Type.TABLE_COUNT_CARD_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			
	if property.name == "attribute":
		if type != Type.SUM and type != Type.TABLE_SUM:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			
	if property.name == "card_id":
		if type != Type.TABLE_HAS_CARD_ID and type != Type.TABLE_COUNT_CARD_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			
	if property.name == "value" or property.name == "op":
		if type == Type.HAS_TAG or type == Type.TABLE_HAS_TAG or type == Type.TABLE_HAS_CARD_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
