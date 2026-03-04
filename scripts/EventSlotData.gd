class_name EventSlotData
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var required_attributes: Dictionary[StringName, int] = {}
@export var forbidden_attributes: Dictionary[StringName, int] = {}

## Tags Configuration
@export var required_tags: Array[String] = [] # Cards MUST have these tags
@export var forbidden_tags: Array[String] = [] # Cards MUST NOT have these tags

## If true, this slot remains interactive during the WORKING (timer running) state.
@export var interactive_during_work: bool = false

## Magnet / Force Inhale Configuration
@export var force_inhale: bool = false # Auto-grab cards from table. If true, card is locked once inhaled.
@export var specific_card_ids: Array[String] = [] # Specific cards to target (empty = match standard filters)

# action_type: "return", "consume", "reward"
@export_enum("return", "consume", "reward") var action_type: String = "return"

func accepts_card_data(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if not specific_card_ids.is_empty() and not specific_card_ids.has(card_data.id):
		return false
	for req_tag in required_tags:
		if not card_data.tags.has(req_tag):
			return false
	for forb_tag in forbidden_tags:
		if card_data.tags.has(forb_tag):
			return false
	for req_key in required_attributes:
		var req_val = int(required_attributes[req_key])
		if card_data.get_attribute(req_key) < req_val:
			return false
	for forb_key in forbidden_attributes:
		var forb_val = int(forbidden_attributes[forb_key])
		if card_data.has_attribute(forb_key) and card_data.get_attribute(forb_key) == forb_val:
			return false
	return true
