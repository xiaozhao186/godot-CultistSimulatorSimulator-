class_name EventSlot
extends PanelContainer

@export var data: EventSlotData

# We use Token instead of Card to support generic items (Cards, Verbs)
var held_card: Token = null
var _preview_active: bool = false

@onready var label: Label = $Label

func _ready() -> void:
	# Allow mouse events to pass to parent (EventPanel)
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(slot_data: EventSlotData) -> void:
	data = slot_data
	tooltip_text = data.description
	if label: label.text = data.name

func try_accept_card(card: Card) -> bool:
	if held_card != null: return false
	
	if not _validate_card(card):
		return false
		
	held_card = card
	card.overlap_enabled = false
	card.set_meta("slot_locked", true)
	card.set_meta("in_event_slot", true) # Add meta for save exclusion
	_refresh_visual()
	return true

func release_card() -> void:
	var prev = held_card
	held_card = null
	if prev and is_instance_valid(prev):
		if prev is Token:
			prev.overlap_enabled = true
			prev.set_meta("slot_locked", false)
			prev.remove_meta("in_event_slot") # Remove meta
	_refresh_visual()

func set_preview(active: bool) -> void:
	_preview_active = active
	_refresh_visual()

func _refresh_visual() -> void:
	if held_card != null:
		modulate = Color(0.5, 1, 0.5)
	elif _preview_active:
		modulate = Color(1, 1, 0.7)
	else:
		modulate = Color.WHITE

func _validate_card(card: Card) -> bool:
	if not data: return true

	if not data.specific_card_ids.is_empty():
		var cid = String(card.data.id).strip_edges()
		var ok = false
		for s in data.specific_card_ids:
			if String(s).strip_edges() == cid:
				ok = true
				break
		if not ok:
			return false
	
	# Check Required
	for req_key in data.required_attributes:
		var req_val = int(data.required_attributes[req_key])
		var found_val = 0
		
		# Check in numeric attributes
		if card.data.has_attribute(req_key):
			found_val = card.data.get_attribute(req_key)
			
		if found_val < req_val:
			return false
			
	# Check Forbidden Attributes
	for forb_key in data.forbidden_attributes:
		if not card.data.has_attribute(forb_key):
			continue
		var card_val = card.data.get_attribute(forb_key)
		var forb_val = data.forbidden_attributes[forb_key]
		if int(card_val) == int(forb_val):
			return false
			
	# Check Required Tags (NEW)
	for req_tag in data.required_tags:
		if not card.data.tags.has(req_tag):
			return false
			
	# Check Forbidden Tags (NEW)
	for forb_tag in data.forbidden_tags:
		if card.data.tags.has(forb_tag):
			return false
			
	return true
