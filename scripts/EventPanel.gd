class_name EventPanel
extends Panel

@export var event_data: EventData
@onready var slots_container: GridContainer = $SlotsCenter/SlotsContainer
@onready var title_label: Label = $TitleLabel
@onready var desc_label: RichTextLabel = $DescLabel
@onready var start_button: Button = $StartButton
@onready var timer_bar: ProgressBar = $TimerBar
@onready var timer: Timer = $Timer
@onready var close_button: Button = $CloseButton
@onready var stack_underlay: TextureRect = $StackUnderlay
@onready var attributes_container: HBoxContainer = $AttributesContainer

# Icon Mapping for Attributes
const IconMappingScript = preload("res://scripts/IconMapping.gd")

enum State { CONFIGURING, WORKING, COLLECTING }
var current_state: State = State.CONFIGURING

var active_slots: Array[EventSlot] = []
var dragging_window: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO

# { slot_index: { "card_node": node, "original_data": data, "action": "return/consume/reward" } }
var recorded_cards: Dictionary = {}

# Internal storage for cross-stage persistence
# Array of Token (Card or Verb) nodes
var internal_storage: Array[Token] = []

# Pending storage for cards placed in slots with action_type == "reward".
# These cards persist across chained events and can be handled later via EventRewardData.transformations.
var pending_storage: Array[Card] = []

# Store the root event data to support reversion from instant branches
var root_event_data: EventData = null
var instant_branch_stack: Array[EventData] = []

# Flag to track if this event is part of a chain (i.e. not the initial one)
var is_chained_event: bool = false

var _pending_drop_nonce: Dictionary = {}
var _pending_drop_start_pos: Dictionary = {}

signal panel_closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10 # Ensure panel is above normal cards but below dragged cards/popups
	visibility_changed.connect(_on_visibility_changed) # Connect visibility signal
	GameManager.token_dropped.connect(_on_token_dropped)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if event_data:
		setup(event_data)
	else:
		# Should not happen typically, but ensure valid state
		current_state = State.CONFIGURING
		
	if AudioManager and visible and _should_play_sound():
		AudioManager.play_sfx("panel_open")

func _should_play_sound() -> bool:
	if source_verb == null: return true # Default to sound if no source
	if source_verb.data and bool(source_verb.data.get("hidden_runtime")):
		return false
	return true

func _process(_delta: float) -> void:
	if event_data == null:
		return
		
	if current_state == State.WORKING and not timer.is_stopped() and event_data.duration > 0:
		# If paused, we need to pause the timer manually if it's set to PROCESS_MODE_ALWAYS (child inherits)
		# But Timer node has its own process_callback.
		# If parent is ALWAYS, child is ALWAYS by default.
		# So we must check AppState.is_paused() and set timer.paused accordingly?
		# Or just set Timer.process_mode = PAUSABLE?
		# Actually, if EventPanel is ALWAYS, Timer inherits ALWAYS.
		# So we should toggle Timer.paused property based on AppState.
		timer.paused = AppState.is_paused()
		
		timer_bar.value = (1.0 - timer.time_left / event_data.duration) * 100.0
		# Ensure visibility if running
		if not timer_bar.visible:
			timer_bar.visible = true
	
	# Update held cards positions to follow slots
	for slot in active_slots:
		if slot.held_card and is_instance_valid(slot.held_card):
			# Keep card centered in slot
			# Slot is a Control in World Space (child of Panel)
			# Card is a Node2D in World Space (child of Tabletop)
			slot.held_card.global_position = slot.get_global_rect().get_center()

	_update_slot_previews()

	# Magnet Logic: Check for force inhale
	if current_state == State.WORKING:
		for slot in active_slots:
			# Safety check for slot data
			if slot.data == null: continue
			if slot.data.force_inhale and slot.held_card == null:
				_attempt_magnet_inhale(slot)

func _attempt_magnet_inhale(slot: EventSlot) -> void:
	# Find Tabletop
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop: return
	
	var candidates: Array[Card] = []
	
	# Collect all candidates first, then randomly pick one
	for node in tabletop.get_children():
		if not (node is Card):
			continue
		var card: Card = node
		if not card.visible:
			continue
		if not card.input_pickable:
			continue
		if GameManager.dragging_token == card:
			continue
			
		var is_target = false
		if slot.data and not slot.data.specific_card_ids.is_empty():
			if slot.data.specific_card_ids.has(card.data.id) and slot._validate_card(card):
				is_target = true
		else:
			# Use validation logic without permanently accepting
			if slot.try_accept_card(card):
				slot.held_card = null
				card.remove_meta("in_event_slot")
				card.remove_meta("slot_locked")
				slot.modulate = Color.WHITE
				is_target = true
		
		if is_target:
			candidates.append(card)
	
	if candidates.is_empty():
		return
	
	var chosen: Card = candidates[randi() % candidates.size()]
	Log.debug("[Debug] Magnet inhaling card: " + str(chosen.data.id) + " (random from " + str(candidates.size()) + ")")
	
	# Snap to slot
	chosen.global_position = slot.get_global_rect().get_center()
	chosen.z_index = 20
	chosen.input_pickable = false
	if not visible:
		chosen.visible = false
	
	# Force accept
	slot.held_card = chosen
	chosen.set_meta("in_event_slot", true)
	chosen.set_meta("slot_locked", true)
	_bind_card_to_slot(chosen, slot)
	
	_check_requirements()
	return

func _on_close_button_pressed() -> void:
	# Only allow full cancellation if it's the INITIAL event configuration.
	# If we are in a chained event (e.g. evb02) but still in CONFIGURING state,
	# we should MINIMIZE instead of CANCEL, to preserve progress.
	if current_state == State.CONFIGURING and not is_chained_event:
		# Cancel behavior: Return all cards and destroy panel
		_return_all_cards()
		panel_closed.emit()
		queue_free()
	else:
		# Minimize behavior: Just hide the panel, let it run in background
		# This applies to:
		# 1. WORKING state
		# 2. COLLECTING state
		# 3. CONFIGURING state of a chained event (is_chained_event = true)
		visible = false
		
		# HIDE force-inhaled cards so they disappear with the panel
		_hide_force_inhaled_cards()

func _return_all_cards() -> void:
	# Return all cards from slots
	for slot in active_slots:
		if slot.held_card and is_instance_valid(slot.held_card):
			# Force release even if locked/force_inhaled
			# because this is a full cancel/return
			var card = slot.held_card
			slot.release_card()
			card.z_index = 0
			card.input_pickable = true # Ensure pickable restored
			card.visible = true # Ensure visible restored
	
	# Also return internal storage cards
	for card in internal_storage:
		if is_instance_valid(card):
			if card.has_meta("in_event_storage"):
				card.remove_meta("in_event_storage")
			card.visible = true
			card.input_pickable = true
			card.z_index = 0
			card.global_position = global_position + Vector2(0, 150)
	internal_storage.clear()

func _hide_force_inhaled_cards() -> void:
	# Iterate active slots to find force_inhaled cards
	for slot in active_slots:
		if slot.data.force_inhale and slot.held_card:
			var card = slot.held_card
			card.visible = false
			card.input_pickable = false

func serialize() -> Dictionary:
	var data = {
		"current_event_id": event_data.id if event_data else "",
		"event_resource_path": event_data.resource_path if event_data else "",
		"root_event_id": root_event_data.id if root_event_data else "",
		"root_event_path": root_event_data.resource_path if root_event_data else "",
		"current_state": current_state,
		"visible": visible,
		"time_left": timer.time_left if timer else 0.0,
		"duration": event_data.duration if event_data else 0.0,
		"is_chained_event": is_chained_event,
		"slots_content": [],
		"internal_storage": []
	}
	
	# Serialize Slots
	for i in range(active_slots.size()):
		var slot = active_slots[i]
		if slot.held_card:
			data["slots_content"].append({
				"slot_index": i,
				"card_id": slot.held_card.data.id,
				# We might need to save specific instance data if cards are mutable (lifetime, etc)
				# For now, let's assume basic ID is enough OR SaveManager handles card state if they are in tree?
				# Cards in slots are usually children of Tabletop but positioned in slot.
				# SaveManager saves ALL Tabletop children.
				# So we just need to know WHICH card is in WHICH slot.
				# We can use the card's object instance ID? No, that changes.
				# We can use node name if unique? Card_ID is not unique.
				# We should probably save the card's properties here to be safe, 
				# OR ensure we can find the exact card instance on load.
				# Given SaveManager saves all cards, we can try to "claim" them on load.
				# But SaveManager destroys and recreates cards on load.
				# So we need to recreate them inside the panel or claim them from the new set.
				# Let's Serialize the full card data here to be self-contained.
				"card_data": {
					"id": slot.held_card.data.id,
					"lifetime": slot.held_card.current_lifetime,
					"stack_count": slot.held_card.stack_count
				}
			})
			
	# Serialize Internal Storage
	for token in internal_storage:
		if token is Card:
			data["internal_storage"].append({
				"type": "Card",
				"id": token.data.id,
				"lifetime": token.current_lifetime,
				"stack_count": token.stack_count
			})
		elif token is Verb:
			data["internal_storage"].append({
				"type": "Verb",
				"id": token.data.id
			})
			
	return data

func deserialize(data: Dictionary) -> void:
	# Restore Event Data
	var loaded_event = false
	
	# Try Path first (more reliable for nested folders)
	var event_path = data.get("event_resource_path", "")
	if event_path != "" and ResourceLoader.exists(event_path):
		var res = load(event_path)
		if res is EventData:
			setup(res, false, null, true)
			loaded_event = true
			
	# Fallback to ID-based lookup if path failed
	if not loaded_event:
		var event_id = data.get("current_event_id", "")
		if event_id != "":
			# Try GameManager cache first (handles scattered files)
			var cached_data = GameManager.get_event_data(event_id)
			if cached_data:
				setup(cached_data, false, null, true)
				loaded_event = true
			else:
				# Old fallback
				var path = "res://data/Events/" + event_id + ".tres"
				if ResourceLoader.exists(path):
					var res = load(path)
					if res is EventData:
						setup(res, false, null, true)
						loaded_event = true
				else:
					# Try recursive scan? Or just warn.
					print("[Warning] Event data not found for ID: ", event_id)
				
	# If setup failed (event_data is null), we should probably not proceed with state restoration that assumes valid event_data
	if event_data == null:
		print("[Error] Failed to restore event data. Aborting deserialization.")
		# If this panel is useless without data, maybe queue_free?
		# But we are in the middle of restoration.
		# Let's just return to avoid crashes.
		return
				
	# Restore Root Event
	var root_path = data.get("root_event_path", "")
	if root_path != "" and ResourceLoader.exists(root_path):
		root_event_data = load(root_path)
	elif data.get("root_event_id", "") != "":
		var root_id = data.get("root_event_id", "")
		# Try Cache
		var cached_root = GameManager.get_event_data(root_id)
		if cached_root:
			root_event_data = cached_root
		else:
			var path = "res://data/Events/" + root_id + ".tres"
			if ResourceLoader.exists(path):
				root_event_data = load(path)
			
	# Restore State
	current_state = data.get("current_state", State.CONFIGURING)
	is_chained_event = data.get("is_chained_event", false)
	
	# Restore Slots
	var slots_content = data.get("slots_content", [])
	for item in slots_content:
		var idx = item.slot_index
		if idx < active_slots.size():
			var slot = active_slots[idx]
			# Re-create card
			var card_info = item.card_data
			var card_data_res = CardDatabase.get_card_data(card_info.id)
			if card_data_res:
				var card = load("res://scenes/Card.tscn").instantiate()
				get_tree().root.get_node("Tabletop").add_child(card) # Add to scene first
				card.setup(card_data_res)
				card.current_lifetime = card_info.lifetime
				card.stack_count = card_info.stack_count
				card._update_stack_badge()
				
				# Put in slot
				slot.held_card = card
				card.overlap_enabled = false
				card.set_meta("slot_locked", true)
				card.set_meta("in_event_slot", true)
				card.global_position = slot.get_global_rect().get_center()
				card.z_index = 20
				if current_state == State.WORKING:
					card.visible = false
					card.input_pickable = false
				elif current_state == State.COLLECTING:
					card.visible = true
					card.input_pickable = true
				else:
					card.visible = true
					card.input_pickable = true
					
				# Re-bind signals
				_bind_card_to_slot(card, slot)
				
	# Restore Internal Storage
	var storage_content = data.get("internal_storage", [])
	for item in storage_content:
		if item.type == "Card":
			var card_data_res = CardDatabase.get_card_data(item.id)
			if card_data_res:
				var card = load("res://scenes/Card.tscn").instantiate()
				get_tree().root.get_node("Tabletop").add_child(card)
				card.setup(card_data_res)
				card.current_lifetime = item.lifetime
				card.stack_count = item.stack_count
				card._update_stack_badge()
				
				card.set_meta("in_event_storage", true)
				card.visible = false
				card.input_pickable = false
				card.is_timer_active = false
				internal_storage.append(card)
				
		elif item.type == "Verb":
			var verb = GameManager.spawn_verb(item.id) # Use spawn to ensure registration
			if verb:
				verb.visible = false
				verb.input_pickable = false
				internal_storage.append(verb)

	# Restore Timer
	if current_state == State.WORKING:
		var time_left = data.get("time_left", 0.0)
		if time_left > 0:
			timer.start(time_left)
			timer_bar.visible = true
			start_button.disabled = true
			start_button.text = "Working..."
			# Lock slots if needed
			for slot in active_slots:
				if not slot.data.interactive_during_work:
					if slot.held_card:
						slot.held_card.input_pickable = false
						
	elif current_state == State.COLLECTING:
		timer_bar.visible = false
		start_button.text = "Collect"
		start_button.disabled = false # Assuming manual collect allowed
		if stack_underlay:
			stack_underlay.visible = internal_storage.size() > 1
			
	_update_attributes_display()
	_update_slot_previews()

func _show_force_inhaled_cards() -> void:
	# Restore visibility of force_inhaled cards when panel reopens
	for slot in active_slots:
		if slot.data.force_inhale and slot.held_card:
			var card = slot.held_card
			card.visible = true
			# Keep input_pickable = false because it's still locked inside
			card.input_pickable = false 

func _on_visibility_changed() -> void:
	if visible:
		_show_force_inhaled_cards()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Check for card interaction first
		for slot in active_slots:
			if slot.held_card and slot.get_global_rect().has_point(get_global_mouse_position()):
				# Only forward input if allowed in current state
				if current_state == State.CONFIGURING or \
				   (current_state == State.WORKING and slot.data.interactive_during_work) or \
				   current_state == State.COLLECTING:
					
					# Forward input to card
					slot.held_card._input_event(null, event, 0)
					accept_event() # Stop propagation so panel doesn't drag
					return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_window = true
				drag_start_pos = get_local_mouse_position()
				move_to_front()
			else:
				dragging_window = false
	elif event is InputEventMouseMotion and dragging_window:
		var mouse_pos := get_local_mouse_position()
		position += mouse_pos - drag_start_pos

var source_verb: Verb = null

func setup(data: EventData, preserve_cards: bool = false, source: Verb = null, suppress_auto_start: bool = false) -> void:
	if source:
		source_verb = source
		
	# Store currently held cards if we need to preserve them
	# Structure: { slot_index: Card }
	var cards_by_index = {}
	var cards_to_redistribute = [] # Keep list for fallback
	
	if preserve_cards:
		for i in range(active_slots.size()):
			var slot = active_slots[i]
			if slot.held_card:
				var card = slot.held_card
				cards_by_index[i] = card
				cards_to_redistribute.append(card)
				
				# Disconnect signal to avoid calling with freed slot later
				# Use a safer disconnection loop
				_unbind_card_from_slot(card)
				
				# Detach from slot logic but don't release physically yet
				slot.held_card = null 
	
	event_data = data
	title_label.text = data.title
	desc_label.text = data.description
	
	# Clear slots - BUT DON'T QUEUE_FREE IMMEDIATELY IF CARD IS STILL ATTACHED?
	# We already detached held_card above.
	for child in slots_container.get_children():
		child.queue_free()
	active_slots.clear()
	
	# Configure Grid layout based on slot count
	if data.slots.size() <= 3:
		slots_container.columns = 1 # Or just rely on container sizing? 
		# GridContainer with columns=1 puts them in a column.
		# User wants: "1 slot: center right", "2-3 slots: centered on line".
		# Actually, GridContainer flow is Row-Major.
		# If columns=3, and we have 1 item, it's top-left of grid.
		# To center them, we might need to adjust container alignment or position.
		# For simplicity, let's keep columns=3.
		slots_container.columns = 3
		# Adjust vertical position to center in right panel?
		# Currently hardcoded in scene.
	else:
		slots_container.columns = 3
	
	for slot_data in data.slots:
		var slot_scene = load("res://scenes/EventSlot.tscn")
		var slot = slot_scene.instantiate()
		slots_container.add_child(slot)
		slot.setup(slot_data)
		active_slots.append(slot)
	
	timer_bar.value = 0
	timer_bar.visible = false
	
	# Update Attributes Display
	_update_attributes_display()
	
	# Redistribute preserved cards
	# 1.2 Instant Branch Refactor: Track original index
	
	if preserve_cards:
		# 1. Try to restore to exact index
		var remaining_cards = []
		
		for index in cards_by_index:
			var card = cards_by_index[index]
			var restored = false
			
			if index < active_slots.size():
				var target_slot = active_slots[index]
				# Check if slot is empty and accepts card
				if target_slot.held_card == null and target_slot.try_accept_card(card):
					Log.debug("[Debug] Instant Branch: Restored card to index " + str(index))
					# Manually trigger visual snap
					card.global_position = target_slot.get_global_rect().get_center()
					card.z_index = 20
					
					_bind_card_to_slot(card, target_slot)
					restored = true
				else:
					print("[Warning] Instant Branch: Slot ", index, " unavailable or incompatible. Downgrading...")
			else:
				print("[Warning] Instant Branch: Index ", index, " out of bounds (", active_slots.size(), "). Downgrading...")
				
			if not restored:
				remaining_cards.append(card)
		
		# 2. Try to autofill remaining cards to ANY slot
		if not remaining_cards.is_empty():
			_distribute_cards_to_slots(remaining_cards)
			
		# 3. Return unassigned cards
		for card in cards_to_redistribute: # Use full list to check everyone
			if is_instance_valid(card) and not _is_card_in_any_slot(card):
				card.visible = true
				card.input_pickable = true
				card.z_index = 0
				# Reset connection state to be safe
				_unbind_card_from_slot(card)
						
				card.global_position = global_position + Vector2(0, 150)
	
	# Try to autofill from internal storage as well
	if not internal_storage.is_empty():
		Log.debug("[Debug] Setup: Internal storage has " + str(internal_storage.size()) + " cards. Attempting autofill...")
		var remaining_storage: Array[Token] = []
		for token in internal_storage:
			if token is Card and _try_autofill_card(token):
				Log.debug("[Debug] Autofilled card into slot: " + str(token.data.id))
			else:
				Log.debug("[Debug] Token kept in storage: " + str(token.name))
				remaining_storage.append(token)
		internal_storage = remaining_storage
	
	current_state = State.CONFIGURING
	start_button.text = "Start"
	start_button.visible = true
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not start_button.pressed.is_connected(_play_click_sound):
		start_button.pressed.connect(_play_click_sound)
	
	# Auto-start check
	if not suppress_auto_start and event_data.auto_start:
		Log.debug("[Debug] Auto-starting event: " + str(event_data.title))
		_start_event()
	else:
		_check_requirements()
		if current_state == State.CONFIGURING:
			_check_instant_branches()

func _distribute_cards_to_slots(cards: Array) -> void:
	for card in cards:
		_try_autofill_card(card)

func _try_autofill_card(card: Card) -> bool:
	# Check if card is relevant to the event branches first
	if not _is_card_relevant(card):
		return false
		
	for slot in active_slots:
		if slot.held_card == null and slot.try_accept_card(card):
			# Manually trigger the visual snap logic since we bypassed the drag-drop event
			card.global_position = slot.get_global_rect().get_center()
			card.z_index = 20
			
			if not card.drag_started.is_connected(_on_card_drag_started):
				card.drag_started.connect(_on_card_drag_started.bind(slot, card))
			return true
	return false

func _is_card_in_any_slot(card: Card) -> bool:
	for slot in active_slots:
		if slot.held_card == card:
			return true
	return false

func _update_slot_previews() -> void:
	if not visible:
		_clear_slot_previews()
		return
	if current_state == State.COLLECTING:
		_clear_slot_previews()
		return
	var dragging = GameManager.dragging_token
	if dragging == null or not is_instance_valid(dragging) or not (dragging is Card):
		_clear_slot_previews()
		return
	var card: Card = dragging
	if not card.dragging:
		_clear_slot_previews()
		return
	if not _is_card_relevant(card):
		_clear_slot_previews()
		return
	var best = _get_best_slot_for_card(card)
	var slot: EventSlot = best.slot
	var ratio: float = best.ratio
	for s in active_slots:
		s.set_preview(s == slot and ratio >= 0.35)

func _clear_slot_previews() -> void:
	for s in active_slots:
		s.set_preview(false)

func _get_best_slot_for_card(card: Card) -> Dictionary:
	var best_slot: EventSlot = null
	var best_ratio: float = 0.0
	var card_rect = _get_card_rect(card)
	if card_rect.size == Vector2.ZERO:
		return { "slot": null, "ratio": 0.0 }
	for slot in active_slots:
		if slot.held_card != null:
			continue
		if current_state == State.WORKING and not slot.data.interactive_during_work:
			continue
		var r = _get_overlap_ratio(card_rect, slot.get_global_rect())
		if r > best_ratio:
			best_ratio = r
			best_slot = slot
	return { "slot": best_slot, "ratio": best_ratio }

func _get_card_rect(card: Card) -> Rect2:
	var half = card._get_half_size()
	return Rect2(card.global_position - half, half * 2.0)

func _get_overlap_ratio(card_rect: Rect2, slot_rect: Rect2) -> float:
	if not card_rect.intersects(slot_rect):
		return 0.0
	var inter = card_rect.intersection(slot_rect)
	var card_area = card_rect.size.x * card_rect.size.y
	if card_area <= 0.0:
		return 0.0
	var inter_area = max(0.0, inter.size.x) * max(0.0, inter.size.y)
	return inter_area / card_area

func _start_drop_confirmation(card: Card, slot: EventSlot) -> void:
	for s in active_slots:
		s.set_preview(s == slot)
	var nonce = int(_pending_drop_nonce.get(card, 0)) + 1
	_pending_drop_nonce[card] = nonce
	_pending_drop_start_pos[card] = card.global_position
	_confirm_drop(card, slot, card.global_position, nonce)

func _confirm_drop(card: Card, slot: EventSlot, start_pos: Vector2, nonce: int) -> void:
	if float(_get_best_slot_for_card(card).ratio) >= 0.7:
		_finish_drop_if_valid(card, slot, start_pos, nonce)
		return
	await get_tree().create_timer(0.1).timeout
	_finish_drop_if_valid(card, slot, start_pos, nonce)

func _finish_drop_if_valid(card: Card, slot: EventSlot, start_pos: Vector2, nonce: int) -> void:
	if not is_instance_valid(card) or not is_instance_valid(slot):
		return
	if int(_pending_drop_nonce.get(card, 0)) != nonce:
		return
	if current_state == State.COLLECTING:
		_clear_slot_previews()
		return
	if card.dragging:
		_clear_slot_previews()
		return
	if card.global_position.distance_to(start_pos) > 4.0:
		_clear_slot_previews()
		return
	var best = _get_best_slot_for_card(card)
	if best.slot != slot or float(best.ratio) < 0.5:
		_clear_slot_previews()
		return
	if slot.try_accept_card(card):
		card.global_position = slot.get_global_rect().get_center()
		card.z_index = 20
		card.original_z_index = 20
		_bind_card_to_slot(card, slot)
		
		if AudioManager and _should_play_sound():
			AudioManager.play_sfx("drop_card")
			
		_check_requirements()
		if current_state == State.CONFIGURING:
			_check_instant_branches()
		_update_attributes_display()
	_clear_slot_previews()


func _on_token_dropped(token: Token) -> void:
	# Always reset mouse filter on drop (in case it was set to IGNORE during drag)
	if mouse_filter != Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	if not visible: return
	if not token is Card: return
	var card = token as Card
	
	if current_state == State.COLLECTING:
		return

	if not _is_card_relevant(card):
		return

	var best = _get_best_slot_for_card(card)
	var best_slot: EventSlot = best.slot
	var best_ratio: float = best.ratio
	if best_slot == null:
		_clear_slot_previews()
		return

	if current_state == State.WORKING and not best_slot.data.interactive_during_work:
		_clear_slot_previews()
		return

	if best_ratio < 0.5:
		_clear_slot_previews()
		return

	_start_drop_confirmation(card, best_slot)

func _on_card_drag_started(_token: Token, slot: EventSlot, card: Token) -> void:
	Log.debug("[Debug] Token drag started from slot. Setting mouse filter to IGNORE.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Special handling for Reward Collection (Stack Logic)
	if current_state == State.COLLECTING and internal_storage.size() > 0:
		# If this drag is from the single reward slot
		if slot == active_slots[0]:
			# The card is already being dragged out by Token logic
			# We need to remove it from internal_storage
			if internal_storage.has(card):
				internal_storage.erase(card)
			
			# Release from slot logic
			slot.held_card = null
			# Reward card dragged out should return to table layer after drop
			# (Token._end_drag sets z_index = original_z_index)
			card.original_z_index = 0
			if card is Card:
				card.is_timer_active = true
			
			# FORCE DRAG START for the card
			# The signal Token.drag_started was emitted, which called this function.
			# But if we don't set proper Z-Index and dragging state, it might glitch.
			# Token.gd handles dragging = true and start pos.
			# We just need to ensure Z-Index is correct for dragging (Token.gd sets original_z_index).
			# Here we downgrade it to normal layer if needed?
			# User said: "被拖动时，OnDragStart 把 z-index 降为卡牌层默认值（例如 5）"
			# Actually Token.gd sets z_index = 100 on drag start.
			# So we don't need to manually set it here, unless we want to override.
			# But we need to record that it was from reward slot.
			
			# Check if more items exist
			if not internal_storage.is_empty():
				# Pop next item immediately into slot
				var next_token = internal_storage[0]
				next_token.visible = true
				next_token.input_pickable = true
				next_token.z_index = 20 # Ensure high Z-Index
				next_token.global_position = slot.get_global_rect().get_center()
				
				slot.held_card = next_token
				
				# Re-bind drag signal for the new token
				if next_token is Card:
					_bind_card_to_slot(next_token, slot)
				elif not next_token.drag_started.is_connected(_on_card_drag_started):
					next_token.drag_started.connect(_on_card_drag_started.bind(slot, next_token))
				
				Log.debug("[Debug] Collection: Next item popped from stack.")
			
			# Update Stack Underlay visibility
			if stack_underlay:
				stack_underlay.visible = internal_storage.size() > 1
				
			# If empty now (after popping), check completion
			if internal_storage.is_empty() and slot.held_card == null:
				_check_collection_complete()
			
			_update_attributes_display()
			return

	if slot.held_card == card:
		slot.release_card()
		card.original_z_index = 0 # Ensure it returns to table layer after drop
		if card is Card:
			card.is_timer_active = true
			_unbind_card_from_slot(card)
		else:
			var connected_callable = _on_card_drag_started.bind(slot, card)
			if card.drag_started.is_connected(connected_callable):
				card.drag_started.disconnect(connected_callable)
			else:
				for conn in card.drag_started.get_connections():
					if conn.callable.get_object() == self and conn.callable.get_method() == "_on_card_drag_started":
						card.drag_started.disconnect(conn.callable)
		
		# Update attributes on removal
		_update_attributes_display()
			
		_check_requirements()
		
		# Check for instant branch reversion or switching
		if current_state == State.CONFIGURING:
			_check_instant_branches()
			
		# Check for collection auto-close
		if current_state == State.COLLECTING:
			_check_collection_complete()

func _check_instant_branches() -> void:
	# Only valid in configuring state
	if current_state != State.CONFIGURING: return
	
	var stats = _calculate_current_stats()
	var target = _select_instant_target(event_data, stats)
	if target != null and event_data != target:
		Log.debug("[Debug] Instant Branch matched! Switching to: " + str(target.title))
		if instant_branch_stack.is_empty():
			root_event_data = event_data
		instant_branch_stack.append(event_data)
		setup(target, true) # true = preserve cards
	else:
		if not instant_branch_stack.is_empty():
			# If the previous layer would still select the current event, do NOT revert.
			var prev_event: EventData = instant_branch_stack.back()
			var prev_target: EventData = _select_instant_target(prev_event, stats)
			if prev_target != null and prev_target == event_data:
				return
			
			Log.debug("[Debug] No instant branch matched. Reverting to previous event: " + str(prev_event.title))
			instant_branch_stack.pop_back()
			if instant_branch_stack.is_empty():
				root_event_data = null
			setup(prev_event, true)

func _select_instant_target(from_event: EventData, stats: Dictionary) -> EventData:
	if from_event == null:
		return null
	var cards: Array[CardData] = []
	for slot in active_slots:
		if slot.held_card is Card and slot.held_card.data != null:
			cards.append(slot.held_card.data)
	for branch in from_event.instant_branches:
		if not branch.evaluate(stats.total_stats, stats.tag_counts, stats.present_tags, stats.table_total_stats, stats.table_tag_counts, stats.table_present_tags, stats.table_card_id_counts):
			continue
		var t = branch.get_random_target()
		if t == null:
			continue
		if _can_preserve_cards_in_event(t, cards):
			return t
	return null

func _can_preserve_cards_in_event(target_event: EventData, cards: Array[CardData]) -> bool:
	if target_event == null:
		return false
	if cards.is_empty():
		return true
	var slot_datas: Array[EventSlotData] = []
	for s in target_event.slots:
		if s != null:
			slot_datas.append(s)
	if slot_datas.is_empty():
		return false
	return _can_assign_cards_to_slots(cards, slot_datas)

func _can_assign_cards_to_slots(cards: Array[CardData], slot_datas: Array[EventSlotData]) -> bool:
	var used: Array[bool] = []
	used.resize(slot_datas.size())
	return _assign_card_dfs(0, cards, slot_datas, used)

func _assign_card_dfs(i: int, cards: Array[CardData], slot_datas: Array[EventSlotData], used: Array[bool]) -> bool:
	if i >= cards.size():
		return true
	var card_data = cards[i]
	for s_i in range(slot_datas.size()):
		if used[s_i]:
			continue
		var slot_data = slot_datas[s_i]
		if slot_data != null and slot_data.accepts_card_data(card_data):
			used[s_i] = true
			if _assign_card_dfs(i + 1, cards, slot_datas, used):
				return true
			used[s_i] = false
	return false

func _check_requirements() -> bool:
	# 1. Check if all required slots are filled
	for slot in active_slots:
		if slot.held_card == null:
			start_button.disabled = true
			return false
			
	# 2. Check if at least one branch condition is met (or default exists)
	# To do this, we need to simulate the stats
	var stats = _calculate_current_stats()
	var valid_branch = false
	
	if event_data.branches.is_empty():
		valid_branch = true # No branches = always valid (go to default)
	else:
		for branch in event_data.branches:
			if branch.evaluate(stats.total_stats, stats.tag_counts, stats.present_tags, stats.table_total_stats, stats.table_tag_counts, stats.table_present_tags, stats.table_card_id_counts):
				valid_branch = true
				break
				
	if not valid_branch and event_data.default_next_event == null:
		# If no branch matches and no default, disable start
		start_button.disabled = true
		return false

	start_button.disabled = false
	return true

func _is_card_relevant(card: Card) -> bool:
	# Safety check
	if event_data == null:
		return false
		
	# Check against BOTH branches and instant_branches.
	# If BOTH are empty, then any card is relevant (unless slot restricts it, which is checked elsewhere).
	if event_data.branches.is_empty() and event_data.instant_branches.is_empty():
		return true
	
	# Check normal branches
	for branch in event_data.branches:
		if _is_card_relevant_to_branch(card, branch):
			return true
			
	# Check instant branches
	for branch in event_data.instant_branches:
		if _is_card_relevant_to_branch(card, branch):
			return true
			
	return false

func _is_card_relevant_to_branch(card: Card, branch: EventBranchData) -> bool:
	# If a branch has no conditions, it accepts anything (Always True)
	if branch.conditions.is_empty():
		return true
		
	for cond in branch.conditions:
		match cond.type:
			EventCondition.Type.HAS_TAG, EventCondition.Type.COUNT:
				if card.data.tags.has(cond.tag):
					return true
			EventCondition.Type.SUM:
				# For SUM, we check if the card has the attribute.
				if card.data.has_attribute(cond.attribute):
					return true
			EventCondition.Type.TABLE_HAS_TAG, EventCondition.Type.TABLE_COUNT:
				if card.data.tags.has(cond.tag):
					return true
			EventCondition.Type.TABLE_SUM:
				if card.data.has_attribute(cond.attribute):
					return true
			EventCondition.Type.TABLE_HAS_CARD_ID, EventCondition.Type.TABLE_COUNT_CARD_ID:
				if card.data.id == cond.card_id:
					return true
	return false

func _calculate_current_stats() -> Dictionary:
	var total_stats = {}
	var tag_counts = {}
	var present_tags = {}
	var table_total_stats = {}
	var table_tag_counts = {}
	var table_present_tags = {}
	var table_card_id_counts = {}
	
	for slot in active_slots:
		if slot.held_card:
			var data = slot.held_card.data
			for stat_key in data.attributes:
				var stat = String(stat_key)
				total_stats[stat] = int(total_stats.get(stat, 0) + int(data.attributes[stat_key]))
			for tag in data.tags:
				tag_counts[tag] = tag_counts.get(tag, 0) + 1
				present_tags[tag] = true
				
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		for node in tabletop.get_children():
			if not (node is Card):
				continue
			var card: Card = node
			if not is_instance_valid(card) or card.data == null:
				continue
			var card_id = card.data.id
			table_card_id_counts[card_id] = table_card_id_counts.get(card_id, 0) + 1
			for tag in card.data.tags:
				table_tag_counts[tag] = table_tag_counts.get(tag, 0) + 1
				table_present_tags[tag] = true
			for stat_key in card.data.attributes:
				var stat = String(stat_key)
				table_total_stats[stat] = int(table_total_stats.get(stat, 0) + int(card.data.attributes[stat_key]))
				
	return {
		"total_stats": total_stats,
		"tag_counts": tag_counts,
		"present_tags": present_tags,
		"table_total_stats": table_total_stats,
		"table_tag_counts": table_tag_counts,
		"table_present_tags": table_present_tags,
		"table_card_id_counts": table_card_id_counts
	}

func _check_branches() -> EventData:
	# 1. Aggregate Data from CURRENT active slots (to handle mid-event changes)
	var stats = _calculate_current_stats()
	
	Log.debug("[Debug] Checking Branches for Event: " + str(event_data.title))
	Log.debug("  Total Stats: " + str(stats.total_stats))
	Log.debug("  Tag Counts: " + str(stats.tag_counts))
	Log.debug("  Present Tags: " + str(stats.present_tags))
	
	# 2. Evaluate Branches
	for i in range(event_data.branches.size()):
		var branch = event_data.branches[i]
		if branch.evaluate(stats.total_stats, stats.tag_counts, stats.present_tags, stats.table_total_stats, stats.table_tag_counts, stats.table_present_tags, stats.table_card_id_counts):
			Log.debug("  -> Branch matched at index: " + str(i))
			# Get target using probability logic
			return branch.get_random_target()
		else:
			Log.debug("  -> Branch failed at index: " + str(i))
			
	Log.debug("  -> No branch matched, using default if available.")
	return null

func _start_event() -> void:
	current_state = State.WORKING
	start_button.visible = false
	start_button.disabled = true
	
	# Commit to this event path, clearing any temporary branch history
	root_event_data = null
	instant_branch_stack.clear()
	
	recorded_cards.clear()
	
	# 1. Record Cards
	for i in range(active_slots.size()):
		var slot = active_slots[i]
		if slot.held_card:
			var card = slot.held_card
			var action = slot.data.action_type # return, consume, reward
			
			recorded_cards[i] = {
				"card_node": card,
				"data": card.data,
				"action": action
			}
			
			# If slot is interactive during work, we don't hide the card
			# But we might need to lock non-interactive ones
			if not slot.data.interactive_during_work:
				card.visible = false
				card.input_pickable = false
			
			# If action is consume, we should probably hide it regardless?
			# Or wait until end to consume?
			# Cultist Simulator keeps cards visible but locked usually.
			# Let's keep logic: if interactive, it stays. If not, it's consumed/locked.
			# For now, stick to old behavior: hide/disable
			if action == "consume":
				card.visible = false
				card.input_pickable = false
			else:
				card.visible = false
				card.input_pickable = false
	
	timer_bar.visible = true # Ensure visible
	
	Log.debug("[Debug] Starting event: " + str(event_data.title) + " | Duration: " + str(event_data.duration))
	
	# Prevent Timer error if duration is too small or zero
	if event_data.duration <= 0.0:
		push_warning("Event duration is <= 0. Forcing minimum duration 0.1s.")
		timer.wait_time = 0.1
	else:
		timer.wait_time = event_data.duration
		
	timer.start()

func _on_timer_timeout() -> void:
	print("Event Completed: " + event_data.title)
	
	if AudioManager and _should_play_sound():
		AudioManager.play_sfx("work_complete")
	
	# 1. Check Branches for Next Step BEFORE moving/releasing cards from slots.
	# Branch evaluation depends on active_slots / held_card stats.
	var next_event = _check_branches()
	
	# 2. Process Cards (Move to internal storage / pending / consume) and apply rewards/transformations.
	_process_finished_cards()
	
	if next_event:
		# Transition to next stage
		Log.debug("[Debug] Transitioning to next event: " + str(next_event.title))
		
		# Mark as chained since we are transitioning automatically
		is_chained_event = true
		
		setup(next_event, false) # false = don't preserve visual cards (they are in storage now)
	else:
		# No next event -> Collection Mode
		Log.debug("[Debug] No next event, entering collection mode.")
		_enter_collection_mode()

func _process_finished_cards() -> void:
	# Iterate over ACTIVE SLOTS to capture current state (including interactive additions)
	for slot in active_slots:
		if slot.held_card:
			var card_node = slot.held_card
			var action = slot.data.action_type
			
			if not is_instance_valid(card_node): continue
			
			if action == "return":
				if card_node is Card:
					var card: Card = card_node
					slot.release_card()
					if not internal_storage.has(card):
						_move_card_to_storage(card)
					
			elif action == "consume":
				slot.release_card()
				card_node.queue_free()
			elif action == "reward":
				if card_node is Card:
					var card: Card = card_node
					slot.release_card()
					pending_storage.append(card)
					card.set_meta("in_event_storage", true)
					card.visible = false
					card.input_pickable = false
					for conn in card.drag_started.get_connections():
						if conn.callable.get_object() == self and conn.callable.get_method() == "_on_card_drag_started":
							card.drag_started.disconnect(conn.callable)

	# Also handle any rewards defined in THIS event
	Log.debug("[Debug] Processing Event Rewards. Count: " + str(event_data.rewards.size()))
	
	# Delayed deletion list
	var verbs_to_delete_late: Array[String] = []
	var should_delete_source = false
	
	# Process Rewards & Transformations
	var ending_fired = false
	for reward in event_data.rewards:
		if not ending_fired:
			var ending_value = reward.get("ending_index")
			if ending_value is int and ending_value >= 0:
				ending_fired = true
				GameManager.trigger_ending(ending_value)
		# 1. Handle Transformations
		if not reward.transformations.is_empty():
			for trans in reward.transformations:
				if trans.target_index < pending_storage.size():
					var target_card = pending_storage[trans.target_index]
					if is_instance_valid(target_card):
						# Check Conditions
						var required_id = String(trans.required_card_id).strip_edges()
						var card_id = ""
						if target_card.data:
							card_id = String(target_card.data.id).strip_edges()
						var match_id = required_id.is_empty() or card_id == required_id
						
						if match_id:
							# Apply Action
							var action = String(trans.action).strip_edges()
							if action.is_empty():
								action = "transform"
							match action:
								"transform":
									var result_id = String(trans.resulting_card_id).strip_edges()
									if not result_id.is_empty():
										Log.debug("[Debug] Transforming card " + str(card_id) + " -> " + str(result_id))
										_add_reward_to_storage(result_id)
										target_card.queue_free() # Destroy original
										pending_storage[trans.target_index] = null # Mark handled
								"return":
									Log.debug("[Debug] Returning pending card: " + str(card_id))
									_move_card_to_storage(target_card)
									pending_storage[trans.target_index] = null # Mark handled
								"consume":
									Log.debug("[Debug] Consuming pending card: " + str(card_id))
									target_card.queue_free()
									pending_storage[trans.target_index] = null # Mark handled
		
		# 2. Handle Fixed Rewards
		if reward.type == EventRewardData.RewardType.FIXED:
			for card_id in reward.card_ids:
				_add_reward_to_storage(card_id)
				
	# 3. Handle Verb Manipulation
		if not reward.verb_ids_to_spawn.is_empty():
			for verb_id in reward.verb_ids_to_spawn:
				Log.debug("[Debug] Spawning verb: " + str(verb_id))
				var verb = GameManager.spawn_verb(verb_id)
				# Auto-start if configured (VerbData should have auto_start?)
				# Or if it's spawned from event, maybe we want it to pop up.
				
		if not reward.verb_ids_to_delete.is_empty():
			verbs_to_delete_late.append_array(reward.verb_ids_to_delete)
			
		if reward.delete_source_verb:
			should_delete_source = true
			
	# Register cleanup tasks
	if not verbs_to_delete_late.is_empty():
		_pending_verb_deletions.append_array(verbs_to_delete_late)
	if should_delete_source:
		_pending_source_deletion = true

var _pending_verb_deletions: Array[String] = []
var _pending_source_deletion: bool = false

func _move_card_to_storage(card_node: Card) -> void:
	# Ensure it's hidden while in storage
	card_node.set_meta("in_event_storage", true)
	card_node.visible = false
	card_node.input_pickable = false
	card_node.is_timer_active = false
	
	internal_storage.append(card_node)
	
	# Disconnect any existing drag signals from previous slots
	_unbind_card_from_slot(card_node)

func _add_reward_to_storage(card_id: String) -> void:
	Log.debug("[Debug] Attempting to add reward: " + str(card_id))
	var data = CardDatabase.get_card_data(card_id)
	if data:
		var card = load("res://scenes/Card.tscn").instantiate()
		
		# Try to find a valid parent for the card
		# Ideally "Tabletop", but fallback to current scene or even the panel itself (though panel clips content?)
		# Panel usually clips content, so better to be outside.
		var parent = get_tree().root.get_node_or_null("Tabletop")
		if not parent:
			parent = get_tree().current_scene
			Log.debug("[Debug] 'Tabletop' node not found. Adding reward to current scene: " + str(parent.name))
			
		if parent:
			parent.add_child(card)
			card.setup(data)
			# Ensure proper Z-Index logic:
			# If hidden, Z-Index doesn't matter much, but when shown, it should be above panel?
			# Panel is Z=10. Card in slot is Z=20.
			# But if Panel is in CanvasLayer or high Z, and Card is in Tabletop...
			# If Tabletop is Z=0, Panel Z=10 covers Card Z=0.
			# But Card Z=20 should cover Panel Z=10.
			# However, if Panel is a Control in a CanvasLayer, it might always be on top of Node2D.
			# Check if Tabletop is Node2D or Control. Usually Node2D.
			# If Panel is child of Tabletop (as per search result: "/root/Tabletop/EventPanel"), then Z-index works relative to siblings.
			# EventPanel is Z=10.
			# Reward Card added to Tabletop (Z=0 default).
			# If we set Card Z=20, it should be above Panel.
			
			card.set_meta("in_event_storage", true)
			card.visible = false
			card.input_pickable = false
			if card is Card:
				card.is_timer_active = false
			internal_storage.append(card)
			Log.debug("[Debug] Reward added to storage: " + str(card_id))
		else:
			print("[Error] No suitable parent found for reward card!")
	else:
		print("[Error] Card data not found for ID: ", card_id)

func _enter_collection_mode() -> void:
	# Default behavior: any remaining pending cards are returned to the player.
	for card in pending_storage:
		if is_instance_valid(card):
			_move_card_to_storage(card)
	pending_storage.clear()
	visible = true
	move_to_front()

	current_state = State.COLLECTING
	timer_bar.visible = false
	start_button.text = "Collect All"
	start_button.disabled = false
	start_button.visible = true
	start_button.pressed.disconnect(_on_start_button_pressed)
	start_button.pressed.connect(_on_collect_all_pressed)
	
	# Disable close button in collection mode
	if close_button:
		close_button.visible = false
		
	title_label.text = "Complete: " + event_data.title
	# desc_label.text = "Event finished. Collect your items." # Don't overwrite description

	timer_bar.visible = false
	
	# Auto-collect check
	if event_data.auto_collect:
		Log.debug("[Debug] Auto-collecting items...")
		# We need to make sure the output slots are populated first!
		# Otherwise _on_collect_all_pressed sees empty active_slots (because we just cleared them above)
		# and then tries to dump internal_storage (which is correct), but visual feedback might be skipped?
		# Wait, the logic below creates output slots from internal_storage.
		# If we call _on_collect_all_pressed HERE, the slots haven't been created yet.
		
		# Let's populate slots first, THEN auto-collect.
		pass 
	else:
		# Only clear slots if NOT auto-collecting immediately? 
		# No, we always need to clear input slots and show output slots.
		pass
	
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()
	active_slots.clear()
	
	# Create ONE Output Slot for Stacked Collection (only if items exist)
	if not internal_storage.is_empty():
		var output_slot_scene = load("res://scenes/EventSlot.tscn")
		var slot = output_slot_scene.instantiate()
		slots_container.add_child(slot)
		
		# Adjust Grid to single center
		slots_container.columns = 1 
		
		var slot_data = EventSlotData.new()
		slot_data.name = "Output"
		slot.setup(slot_data)
		active_slots.append(slot)
		
		# Initial Population of the Stack
		var token = internal_storage[0]
		token.visible = true
		token.input_pickable = true
		token.z_index = 20 # Ensure this is higher than Panel Z=10
		token.global_position = slot.get_global_rect().get_center()
		
		if token is Card:
			slot.held_card = token
			_bind_card_to_slot(token, slot)
		elif token is Verb:
			slot.held_card = token
			if not token.drag_started.is_connected(_on_card_drag_started):
				token.drag_started.connect(_on_card_drag_started.bind(slot, token))
	else:
		Log.debug("[Debug] No rewards to collect, skipping output slot creation.")

	# Defer button positioning to ensure UI layout is updated
	call_deferred("_update_collect_button_position")
	
	# Update Stack Underlay visibility
	if stack_underlay:
		stack_underlay.visible = internal_storage.size() > 1
		
	# Now trigger auto-collect if enabled
	if event_data.auto_collect:
		_on_collect_all_pressed()

func _update_collect_button_position() -> void:
	if not is_instance_valid(start_button): return
	
	if active_slots.size() > 0:
		var slot = active_slots[0]
		var slot_rect = slot.get_global_rect()
		start_button.global_position = slot_rect.get_center() + Vector2(-start_button.size.x * 0.5, slot_rect.size.y * 0.5 + 18.0)
	else:
		# If no slots, center button in panel or below title?
		# Let's put it below the description label
		if desc_label:
			start_button.global_position = Vector2(global_position.x + size.x * 0.5 - start_button.size.x * 0.5, desc_label.global_position.y + desc_label.size.y + 20)
		else:
			start_button.global_position = global_position + Vector2(size.x * 0.5 - start_button.size.x * 0.5, 100)

func _update_attributes_display() -> void:
	if not attributes_container: return
	
	# Clear existing
	for child in attributes_container.get_children():
		child.queue_free()
		
	var aggregated_tags = []
	var aggregated_stats = {}
	
	for slot in active_slots:
		if slot.held_card and slot.held_card is Card:
			var data = slot.held_card.data
			for tag in data.tags:
				if not aggregated_tags.has(tag):
					aggregated_tags.append(tag)
			for stat_key in data.attributes:
				var stat = String(stat_key)
				aggregated_stats[stat] = aggregated_stats.get(stat, 0) + int(data.attributes[stat_key])
	
	# Render Tags
	for tag in aggregated_tags:
		_create_attribute_icon(tag, "")
		
	# Render Stats
	for stat in aggregated_stats:
		_create_attribute_icon(stat, str(aggregated_stats[stat]))

func _create_attribute_icon(key: String, value_text: String) -> void:
	var container = HBoxContainer.new()
	container.tooltip_text = key.capitalize() + (": " + value_text if value_text else "")
	
	var icon_rect = TextureRect.new()
	# Use IconMappingScript
	var lower_key = key.to_lower()
	var path = IconMappingScript.DEFAULT_ICON_PATH
	if IconMappingScript.ICON_MAP.has(lower_key):
		path = IconMappingScript.ICON_MAP[lower_key]
	
	if ResourceLoader.exists(path):
		icon_rect.texture = load(path)
	else:
		icon_rect.texture = load(IconMappingScript.DEFAULT_ICON_PATH)
		
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(icon_rect)
	
	if value_text != "":
		var label = Label.new()
		label.text = value_text
		label.add_theme_color_override("font_color", Color.BLACK)
		container.add_child(label)
		
	attributes_container.add_child(container)

func _on_collect_all_pressed() -> void:
	# Dump everything to table
	# Iterate active slots first (currently held item)
	for slot in active_slots:
		if slot.held_card:
			var card = slot.held_card
			slot.release_card()
			if card.has_meta("in_event_storage"):
				card.remove_meta("in_event_storage")
			card.z_index = 0
			if card is Card:
				card.is_timer_active = true
			card.global_position += Vector2(randf_range(-20, 20), randf_range(50, 100))
	
	# Also dump remaining internal storage (the stack)
	for token in internal_storage:
		token.visible = true
		token.input_pickable = true
		token.z_index = 0
		if token.has_meta("in_event_storage"):
			token.remove_meta("in_event_storage")
		if token is Card:
			token.is_timer_active = true
		# Position them near the slot output
		if active_slots.size() > 0:
			token.global_position = active_slots[0].get_global_rect().get_center() + Vector2(randf_range(-20, 20), randf_range(50, 100))
		else:
			token.global_position = global_position + Vector2(randf_range(300, 400), randf_range(100, 200))
			
	internal_storage.clear()
	
	# Update UI
	if stack_underlay:
		stack_underlay.visible = false

	# Execute Pending Verb Deletions (Post-Collection)
	for verb_id in _pending_verb_deletions:
		GameManager.delete_verb(verb_id)
	_pending_verb_deletions.clear()
	
	if _pending_source_deletion:
		if is_instance_valid(source_verb):
			Log.debug("[Debug] Deleting source verb (Post-Collection): " + str(source_verb.name))
			GameManager.delete_specific_verb(source_verb)
		else:
			print("[Warning] Cannot delete source verb: Not valid or not set.")
		
	# Check if empty to close
	_check_collection_complete()
	_pending_source_deletion = false

func _check_collection_complete() -> void:
	# Check if any slots still hold cards
	# In Stack mode, check if internal_storage is empty AND slot is empty
	# 2026-02-14 Update: Only check for Cards. Verbs are already on the table.
	
	var has_cards = false
	if not internal_storage.is_empty():
		# Internal storage might contain cards (rewards) or other tokens?
		# Currently only Cards are added to storage as rewards.
		has_cards = true
	else:
		for slot in active_slots:
			if slot.held_card:
				has_cards = true
				break
	
	if not has_cards:
		Log.debug("[Debug] Collection complete. Closing panel.")
		if is_instance_valid(source_verb) and not _pending_source_deletion and not source_verb.is_queued_for_deletion():
			source_verb.set_meta("auto_restart", true)
		panel_closed.emit()
		
		# Reset internal state properly for reuse (if pooled) or just cleanup
		current_state = State.CONFIGURING
		active_slots.clear()
		# internal_storage is already cleared
		
		queue_free()

func _bind_card_to_slot(card: Card, slot: EventSlot) -> void:
	if not card.drag_started.is_connected(_on_card_drag_started):
		card.drag_started.connect(_on_card_drag_started.bind(slot, card))
	if not card.timer_expired_in_slot.is_connected(_on_card_expired_in_slot):
		card.timer_expired_in_slot.connect(_on_card_expired_in_slot)

func _unbind_card_from_slot(card: Card) -> void:
	# Disconnect drag_started
	for conn in card.drag_started.get_connections():
		if conn.callable.get_object() == self and conn.callable.get_method() == "_on_card_drag_started":
			card.drag_started.disconnect(conn.callable)
	# Disconnect timer_expired_in_slot
	if card.timer_expired_in_slot.is_connected(_on_card_expired_in_slot):
		card.timer_expired_in_slot.disconnect(_on_card_expired_in_slot)

func _on_card_expired_in_slot(card: Card) -> void:
	Log.debug("[Debug] Card expired in slot: " + str(card.name))
	# Find the slot
	var slot: EventSlot = null
	for s in active_slots:
		if s.held_card == card:
			slot = s
			break
			
	if slot:
		_unbind_card_from_slot(card)
		slot.release_card()
		# Card logic: reset z-index, pickable, visible
		card.original_z_index = 0
		card.z_index = 0
		card.visible = true
		card.input_pickable = true
		if card.has_meta("in_event_slot"):
			card.remove_meta("in_event_slot")
		if card.has_meta("slot_locked"):
			card.remove_meta("slot_locked")
		
		# Trigger actual expiration
		card.force_expire()
		
		# Update Panel State
		_update_attributes_display()
		_check_requirements()
		if current_state == State.CONFIGURING:
			_check_instant_branches()

# Override _on_start_button_pressed to only work in configuring
func _play_click_sound() -> void:
	if AudioManager and _should_play_sound():
		AudioManager.play_sfx("ui_click")

func _on_start_button_pressed() -> void:
	if current_state == State.CONFIGURING:
		if _check_requirements():
			# start_button.disabled = true # Moved to _start_event
			_start_event()
