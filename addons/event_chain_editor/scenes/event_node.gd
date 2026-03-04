@tool
extends GraphNode

signal request_save(resource: Resource)
signal request_disconnect_incoming(from_node: String, from_port: int)

var event_data: Resource
var _updating_ui = false
var _port_to_outcome: Dictionary = {}
var _next_output_port_index: int = 1
var _last_resource_basename: String = ""
var _save_queued: bool = false

@onready var title_edit = $MainContainer/TitleEdit
@onready var desc_edit = $MainContainer/DescEdit
@onready var duration_spin = $MainContainer/PropsContainer/DurationSpin
@onready var auto_start_check = $MainContainer/PropsContainer/AutoStartCheck
@onready var auto_collect_check = $MainContainer/PropsContainer/AutoCollectCheck
# Use get_node to avoid initialization race conditions, or check in setup
@onready var add_reward_btn = $MainContainer/RewardsHeader/AddRewardBtn
@onready var rewards_container = $MainContainer/RewardsContainer
@onready var add_slot_btn = $MainContainer/SlotsHeader/AddSlotBtn
@onready var slots_container = $MainContainer/SlotsContainer
@onready var incoming_links_container = $MainContainer/IncomingLinksContainer
@onready var incoming_toggle_btn = $MainContainer/IncomingHeader/IncomingToggleBtn

func setup(data: Resource):
	event_data = data
	
	# Wait for ready before accessing onready nodes
	# IMPORTANT: This must be first. If setup is called before _ready(), @onready vars are null.
	if not is_node_ready():
		await ready
	
	_ensure_writable()
	
	# Connect changed signal for live updates
	if not event_data.changed.is_connected(_on_data_changed):
		event_data.changed.connect(_on_data_changed)
	
	# Connect UI signals
	if title_edit: title_edit.text_changed.connect(_on_title_changed)
	if desc_edit: desc_edit.text_changed.connect(_on_desc_changed)
	if duration_spin: duration_spin.value_changed.connect(_on_duration_changed)
	if auto_start_check: auto_start_check.toggled.connect(_on_auto_start_toggled)
	if auto_collect_check: auto_collect_check.toggled.connect(_on_auto_collect_toggled)
	if add_reward_btn: add_reward_btn.pressed.connect(_on_add_reward_pressed)
	if add_slot_btn: add_slot_btn.pressed.connect(_on_add_slot_pressed)
	if incoming_toggle_btn:
		incoming_toggle_btn.toggled.connect(func(pressed):
			if incoming_links_container:
				incoming_links_container.visible = pressed
				_refresh_layout()
		)
	
	_update_ui()

func _ensure_writable():
	if not event_data: return
	
	# Ensure arrays are not read-only/shared
	if event_data.instant_branches.is_read_only():
		event_data.instant_branches = _clone_typed_resource_array(event_data.instant_branches, EventBranchData)
	if event_data.branches.is_read_only():
		event_data.branches = _clone_typed_resource_array(event_data.branches, EventBranchData)
	if event_data.rewards.is_read_only():
		event_data.rewards = _clone_typed_resource_array(event_data.rewards, EventRewardData)
	if event_data.slots.is_read_only():
		event_data.slots = _clone_typed_resource_array(event_data.slots, EventSlotData)

func _clone_typed_resource_array(source: Array, element_class) -> Array:
	var cloned := Array([], TYPE_OBJECT, "Resource", element_class)
	if source:
		cloned.append_array(source)
	return cloned

func _typed_array_append(source: Array, element_class, element) -> Array:
	var cloned := _clone_typed_resource_array(source, element_class)
	cloned.append(element)
	return cloned

func _typed_array_remove_at(source: Array, element_class, remove_index: int) -> Array:
	var cloned := Array([], TYPE_OBJECT, "Resource", element_class)
	if not source:
		return cloned
	for i in range(source.size()):
		if i == remove_index:
			continue
		cloned.append(source[i])
	return cloned

func _ensure_branch_writable(branch: EventBranchData) -> void:
	if not branch:
		return
	if branch.conditions == null or branch.conditions.is_read_only():
		branch.conditions = _clone_typed_resource_array(branch.conditions if branch.conditions else [], EventCondition)
	if branch.outcomes == null or branch.outcomes.is_read_only():
		branch.outcomes = _clone_typed_resource_array(branch.outcomes if branch.outcomes else [], EventOutcome)

func _on_data_changed():
	if _updating_ui: return
	_update_ui()
	
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _updating_ui:
		return
	if not event_data:
		return
	if event_data.resource_path.is_empty():
		return
	
	var base = event_data.resource_path.get_file().get_basename()
	if base.is_empty():
		return
	if base == _last_resource_basename:
		return
	
	_last_resource_basename = base
	title = base
	if _is_user_editing_text():
		return
	if event_data.id != base:
		event_data.id = base
		_request_save()

func _update_ui():
	if not event_data: return
	
	_updating_ui = true
	var data = event_data
	var display_id := ""
	if not data.resource_path.is_empty():
		display_id = data.resource_path.get_file().get_basename()
	if display_id.is_empty():
		display_id = data.id
	if display_id.is_empty():
		display_id = "Unnamed Event"
	title = display_id
	
	if not data.resource_path.is_empty() and data.id != display_id and display_id != "Unnamed Event" and not _is_user_editing_text():
		data.id = display_id
		_request_save()
	
	_last_resource_basename = display_id
	
	if title_edit and not title_edit.has_focus():
		title_edit.text = data.title
	if desc_edit and not desc_edit.has_focus():
		desc_edit.text = data.description
	if duration_spin:
		# Don't update value if user is interacting to avoid fighting (though SpinBox handles this better than LineEdit)
		# But since we use value_changed signal to save, updating it here might trigger signal again if not careful.
		# _updating_ui flag handles the signal loop, but not the focus/input interruption.
		# Ideally we check if it has focus, but SpinBox focus is on its LineEdit child.
		# For now, let's just update it. The issue usually comes from full rebuilds.
		duration_spin.value = data.duration
	if auto_start_check: auto_start_check.button_pressed = data.auto_start
	if auto_collect_check: auto_collect_check.button_pressed = data.auto_collect
	
	# Only rebuild dynamic lists if we are NOT currently editing them to avoid focus loss
	# We can check if any child of these containers has focus.
	if not _container_has_focus(rewards_container):
		_rebuild_rewards_list()
	if not _container_has_focus(slots_container):
		_rebuild_slots_ui()
	
	# _rebuild_slots() rebuilds the entire Branch/Condition/Outcome UI.
	# This is the main culprit for Condition input focus loss.
	# We should only rebuild if we are NOT editing something inside it.
	# But GraphNode slots are direct children, mixed with others.
	# We need a way to detect if focus is within our dynamic slots area.
	if not _dynamic_slots_have_focus():
		_rebuild_slots() 
		
	_updating_ui = false

func _container_has_focus(container: Control) -> bool:
	if not container: return false
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not focus_owner: return false
	return container.is_ancestor_of(focus_owner) or container == focus_owner

func _dynamic_slots_have_focus() -> bool:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not focus_owner: return false
	# Check if focus owner is one of our dynamic children (Condition editors, Outcome SpinBoxes, etc)
	# These are added as direct children of GraphNode (self) starting from index 2 (after MainContainer and DefaultNext)
	# But `is_ancestor_of` works for any parent.
	# Since dynamic slots are direct children of `self`, we can check if `self` is ancestor.
	# BUT `MainContainer` is also a child. We need to exclude it.
	if self.is_ancestor_of(focus_owner):
		# It's inside the GraphNode. Is it inside MainContainer?
		var main_container = get_node_or_null("MainContainer")
		if main_container and main_container.is_ancestor_of(focus_owner):
			return false # Focus is in Title/Desc/Props, not dynamic slots
		return true # Focus is in dynamic slots (Branches/Conditions/Outcomes)
	return false

func update_incoming_links(links: Array):
	if not incoming_links_container: return
	
	for child in incoming_links_container.get_children():
		child.queue_free()
		
	if links.is_empty():
		var label = Label.new()
		label.text = "None"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		incoming_links_container.add_child(label)
		return
		
	for link in links:
		var row = HBoxContainer.new()
		var label = Label.new()
		
		# link is {from_node: String, from_port: int, from_title: String, branch_info: String, ...}
		# We expect graph_view to pass more info now.
		# If from_title is available, use it. Otherwise use from_node.
		# branch_info should be like "Branch X, Outcome Y"
		
		var node_display = link.get("from_title", link.from_node)
		var info_display = link.get("branch_info", "Port %d" % link.from_port)
		
		label.text = "%s (%s) ->" % [node_display, info_display]
		row.add_child(label)
		
		var unlink_btn = Button.new()
		unlink_btn.text = "Unlink"
		unlink_btn.pressed.connect(func():
			request_disconnect_incoming.emit(link.from_node, link.from_port)
		)
		row.add_child(unlink_btn)
		
		incoming_links_container.add_child(row)

func _is_user_editing_text() -> bool:
	return (title_edit and title_edit.has_focus()) or (desc_edit and desc_edit.has_focus())

func _request_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_flush_save")

func _flush_save() -> void:
	_save_queued = false
	_save_resource()

func _rebuild_rewards_list():
	for child in rewards_container.get_children():
		child.queue_free()
		
	for i in range(event_data.rewards.size()):
		var reward = event_data.rewards[i]
		var row = HBoxContainer.new()
		
		var label = Label.new()
		label.text = "Rwd %d" % i
		row.add_child(label)
		
		var edit_btn = Button.new()
		edit_btn.text = "Edit"
		edit_btn.pressed.connect(func(): EditorInterface.edit_resource(reward))
		row.add_child(edit_btn)
		
		var del_btn = Button.new()
		del_btn.text = "x"
		del_btn.pressed.connect(_on_delete_reward_pressed.bind(i))
		row.add_child(del_btn)
		
		rewards_container.add_child(row)

func _rebuild_slots_ui():
	for child in slots_container.get_children():
		child.queue_free()
		
	for i in range(event_data.slots.size()):
		var slot = event_data.slots[i]
		var row = HBoxContainer.new()
		
		var label = Label.new()
		label.text = "Slot %d" % i
		row.add_child(label)
		
		# Edit ID (Required Card ID) - Assuming 'specific_card_ids' usage or 'id' property
		# Based on EventSlotData: id, name, description, specific_card_ids
		# Let's expose ID and Name for now
		
		var name_edit = LineEdit.new()
		name_edit.placeholder_text = "Name"
		name_edit.text = slot.name
		name_edit.custom_minimum_size.x = 80
		name_edit.text_changed.connect(func(txt): 
			slot.name = txt
			_save_resource()
		)
		row.add_child(name_edit)
		
		var edit_btn = Button.new()
		edit_btn.text = "Edit"
		edit_btn.pressed.connect(func(): EditorInterface.edit_resource(slot))
		row.add_child(edit_btn)
		
		var del_btn = Button.new()
		del_btn.text = "x"
		del_btn.pressed.connect(_on_delete_slot_pressed.bind(i))
		row.add_child(del_btn)
		
		slots_container.add_child(row)

func _rebuild_slots():
	_port_to_outcome.clear()
	_next_output_port_index = 1
	# Clear dynamic children (keep MainContainer at index 0)
	# MainContainer is the first child. We need to keep it.
	for i in range(get_child_count() - 1, 0, -1):
		var child = get_child(i)
		remove_child(child)
		child.queue_free()
		
	# Row 0: MainContainer (Input Port)
	set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Row 1: Default Next Event (Output Port 0 - Type 0)
	var default_container = HBoxContainer.new()
	default_container.alignment = BoxContainer.ALIGNMENT_END
	var default_label = Label.new()
	default_label.text = "Default Next"
	default_container.add_child(default_label)
	add_child(default_container)
	set_slot(1, false, 0, Color.WHITE, true, 0, Color.WHITE)
	
	var slot_index = 2
	
	# === Instant Branches Section ===
	slot_index = _build_branch_section("Instant Branches", event_data.instant_branches, slot_index, true)
	
	# === Result Branches Section ===
	slot_index = _build_branch_section("Result Branches", event_data.branches, slot_index, false)
	_refresh_layout()

func _build_branch_section(title_text: String, branches_array: Array, start_index: int, is_instant: bool) -> int:
	var current_index = start_index
	
	# Section Header
	var header = HBoxContainer.new()
	var label = Label.new()
	label.text = title_text
	header.add_child(label)
	var add_btn = Button.new()
	add_btn.text = "+"
	add_btn.pressed.connect(_on_add_branch_pressed.bind(is_instant))
	header.add_child(add_btn)
	add_child(header)
	set_slot(current_index, false, 0, Color.WHITE, false, 0, Color.WHITE)
	current_index += 1
	
	# Iterate Branches
	for b_idx in range(branches_array.size()):
		var branch = branches_array[b_idx]
		
		# Branch Header Row (Delete Branch)
		var branch_header = HBoxContainer.new()
		branch_header.add_theme_constant_override("separation", 10)
		var b_label = Label.new()
		b_label.text = "Branch %d" % b_idx
		b_label.add_theme_color_override("font_color", Color.YELLOW)
		branch_header.add_child(b_label)
		
		var del_branch_btn = Button.new()
		del_branch_btn.text = "Delete Branch"
		del_branch_btn.pressed.connect(_on_delete_branch_pressed.bind(b_idx, is_instant))
		branch_header.add_child(del_branch_btn)
		
		add_child(branch_header)
		set_slot(current_index, false, 0, Color.WHITE, false, 0, Color.WHITE)
		current_index += 1
		
		# Conditions Container
		var cond_container = VBoxContainer.new()
		var cond_header = HBoxContainer.new()
		var cond_label = Label.new()
		cond_label.text = "Conditions"
		cond_header.add_child(cond_label)
		var add_cond_btn = Button.new()
		add_cond_btn.text = "+"
		add_cond_btn.pressed.connect(_on_add_condition_pressed.bind(branch))
		cond_header.add_child(add_cond_btn)
		cond_container.add_child(cond_header)
		
		# List Conditions
		for c_idx in range(branch.conditions.size()):
			var cond = branch.conditions[c_idx]
			var cond_row = _create_condition_editor(cond, branch, c_idx)
			cond_container.add_child(cond_row)
			
		add_child(cond_container)
		set_slot(current_index, false, 0, Color.WHITE, false, 0, Color.WHITE)
		current_index += 1
		
		# Outcomes Header
		var out_header = HBoxContainer.new()
		out_header.alignment = BoxContainer.ALIGNMENT_END
		var out_label = Label.new()
		out_label.text = "Outcomes"
		out_header.add_child(out_label)
		var add_out_btn = Button.new()
		add_out_btn.text = "+"
		add_out_btn.pressed.connect(_on_add_outcome_pressed.bind(branch))
		out_header.add_child(add_out_btn)
		add_child(out_header)
		set_slot(current_index, false, 0, Color.WHITE, false, 0, Color.WHITE)
		current_index += 1
		
		# List Outcomes (These are the ports!)
		for o_idx in range(branch.outcomes.size()):
			var outcome = branch.outcomes[o_idx]
			var out_row = HBoxContainer.new()
			out_row.alignment = BoxContainer.ALIGNMENT_END
			
			var prob_spin = SpinBox.new()
			prob_spin.step = 0.1
			prob_spin.min_value = 0.0
			prob_spin.max_value = 1.0
			prob_spin.value = outcome.probability
			prob_spin.custom_minimum_size.x = 60
			prob_spin.value_changed.connect(func(val): 
				outcome.probability = val
				_request_save()
			)
			var prob_label = Label.new()
			prob_label.text = "Prob:"
			out_row.add_child(prob_label)
			out_row.add_child(prob_spin)
			
			var del_out_btn = Button.new()
			del_out_btn.text = "x"
			del_out_btn.pressed.connect(_on_delete_outcome_pressed.bind(branch, o_idx))
			out_row.add_child(del_out_btn)
			
			var arrow_label = Label.new()
			arrow_label.text = "->"
			out_row.add_child(arrow_label)
			
			add_child(out_row)
			# PORT COLOR: Cyan for Instant, Orange for Result
			var color = Color.CYAN if is_instant else Color.ORANGE
			# Enable RIGHT port
			set_slot(current_index, false, 0, Color.WHITE, true, 0, color)
			_port_to_outcome[_next_output_port_index] = { 
				"branch": branch, 
				"outcome": outcome,
				"branch_index": b_idx, # Store indices for easy lookup
				"outcome_index": o_idx,
				"is_instant": is_instant
			}
			_next_output_port_index += 1
			current_index += 1
			
	return current_index

func get_outcome_mapping_by_port(output_port_index: int) -> Dictionary:
	# Godot 4 GraphEdit uses OUTPUT PORT INDEX (0, 1, 2...) for connections.
	# We need to map this to our internal structure.
	# Default Next is port 0.
	# Outcomes start from port 1.
	
	if output_port_index == 0:
		# This is Default Next, but usually this function is called for Outcomes.
		# If needed, return empty or specific dict.
		return {}
		
	# Check our cached map
	# Note: _port_to_outcome keys are "output port indices" (starting from 1 because 0 is skipped/DefaultNext?)
	# Let's check where _port_to_outcome is filled.
	# It is filled in _rebuild_slots with _next_output_port_index.
	# _next_output_port_index starts at 1.
	# So yes, output_port_index should match keys in _port_to_outcome directly.
	
	var mapping = _port_to_outcome.get(output_port_index, {})
	if mapping.is_empty():
		return {}
		
	# Enrich mapping with indices if not present (stored mapping has "branch", "outcome")
	# We need to find the indices.
	# Since _port_to_outcome only stores references, we might need to search or store indices there too.
	# Let's modify _rebuild_slots to store indices in _port_to_outcome.
	
	# But wait, if I modify _rebuild_slots now, I might break other things?
	# No, just adding keys to the dict is safe.
	return mapping

func get_outcome_mapping(slot_index: int):
	# Map slot/port index to Branch/Outcome info
	var current_index = 2
	
	# === Instant Branches ===
	current_index += 1 # Header
	
	for b_idx in range(event_data.instant_branches.size()):
		var branch = event_data.instant_branches[b_idx]
		current_index += 3 # Header + Cond + OutHeader
		
		for o_idx in range(branch.outcomes.size()):
			if current_index == slot_index:
				return { 
					"branch": branch, 
					"outcome": branch.outcomes[o_idx],
					"branch_index": b_idx,
					"outcome_index": o_idx,
					"is_instant": true
				}
			current_index += 1
			
	# === Result Branches ===
	current_index += 1 # Header
	
	for b_idx in range(event_data.branches.size()):
		var branch = event_data.branches[b_idx]
		current_index += 3 # Header + Cond + OutHeader
		
		for o_idx in range(branch.outcomes.size()):
			if current_index == slot_index:
				return { 
					"branch": branch, 
					"outcome": branch.outcomes[o_idx],
					"branch_index": b_idx,
					"outcome_index": o_idx,
					"is_instant": false
				}
			current_index += 1
			
	return null

func get_outcome_slot_map() -> Dictionary:
	return _port_to_outcome

func _refresh_layout() -> void:
	call_deferred("update_minimum_size")
	call_deferred("reset_size")

func _create_condition_editor(cond: EventCondition, branch: EventBranchData, index: int) -> Control:
	var row = HBoxContainer.new()
	
	# Type Option
	var type_opt = OptionButton.new()
	type_opt.add_item("HAS_TAG", 0)
	type_opt.add_item("SUM", 1)
	type_opt.add_item("COUNT", 2)
	type_opt.add_item("T_HAS_TAG", 3)
	type_opt.add_item("T_SUM", 4)
	type_opt.add_item("T_COUNT", 5)
	type_opt.add_item("T_HAS_ID", 6)
	type_opt.add_item("T_COUNT_ID", 7)
	type_opt.selected = cond.type
	type_opt.item_selected.connect(func(idx): 
		cond.type = idx
		_save_resource()
		_rebuild_slots() # Rebuild to show/hide relevant fields
	)
	row.add_child(type_opt)
	
	# Fields based on type
	if cond.type == 0 or cond.type == 3: # HAS_TAG or T_HAS_TAG
		var tag_edit = LineEdit.new()
		tag_edit.placeholder_text = "Tag"
		tag_edit.text = cond.tag
		tag_edit.custom_minimum_size.x = 80
		tag_edit.text_changed.connect(func(txt): 
			cond.tag = txt
			_request_save()
		)
		row.add_child(tag_edit)
	elif cond.type == 6 or cond.type == 7: # T_HAS_ID or T_COUNT_ID
		var id_edit = LineEdit.new()
		id_edit.placeholder_text = "Card ID"
		id_edit.text = cond.card_id
		id_edit.custom_minimum_size.x = 80
		id_edit.text_changed.connect(func(txt): 
			cond.card_id = txt
			_request_save()
		)
		row.add_child(id_edit)
	else:
		# SUM/COUNT variants
		if cond.type == 1 or cond.type == 4: # SUM or T_SUM needs attribute
			var attr_edit = LineEdit.new()
			attr_edit.placeholder_text = "Attr"
			attr_edit.text = cond.attribute
			attr_edit.custom_minimum_size.x = 80
			attr_edit.text_changed.connect(func(txt): 
				cond.attribute = txt
				_request_save()
			)
			row.add_child(attr_edit)
		elif cond.type == 2 or cond.type == 5: # COUNT or T_COUNT needs tag
			var tag_edit = LineEdit.new()
			tag_edit.placeholder_text = "Tag"
			tag_edit.text = cond.tag
			tag_edit.custom_minimum_size.x = 80
			tag_edit.text_changed.connect(func(txt): 
				cond.tag = txt
				_request_save()
			)
			row.add_child(tag_edit)
			
		# Op
		var op_opt = OptionButton.new()
		var ops = [">=", ">", "<=", "<", "==", "!="]
		for op in ops: op_opt.add_item(op)
		op_opt.selected = cond.op
		op_opt.item_selected.connect(func(idx): 
			cond.op = idx
			_request_save()
		)
		row.add_child(op_opt)
		
		# Value
		var val_spin = SpinBox.new()
		val_spin.value = cond.value
		val_spin.value_changed.connect(func(val): 
			cond.value = int(val)
			_request_save()
		)
		row.add_child(val_spin)
		
	var del_btn = Button.new()
	del_btn.text = "x"
	del_btn.pressed.connect(func():
		_ensure_branch_writable(branch)
		branch.conditions = _typed_array_remove_at(branch.conditions, EventCondition, index)
		_save_resource()
		_rebuild_slots()
	)
	row.add_child(del_btn)
	
	return row

func _on_add_condition_pressed(branch: EventBranchData):
	_ensure_branch_writable(branch)
	var cond = EventCondition.new()
	branch.conditions = _typed_array_append(branch.conditions, EventCondition, cond)
	_save_resource()
	_rebuild_slots()

func _on_add_outcome_pressed(branch: EventBranchData):
	_ensure_branch_writable(branch)
	var outcome = EventOutcome.new()
	outcome.probability = 1.0
	branch.outcomes = _typed_array_append(branch.outcomes, EventOutcome, outcome)
	_save_resource()
	_rebuild_slots()

func _on_delete_outcome_pressed(branch: EventBranchData, index: int):
	_ensure_branch_writable(branch)
	branch.outcomes = _typed_array_remove_at(branch.outcomes, EventOutcome, index)
	_save_resource()
	_rebuild_slots()
	_refresh_layout()

func _save_resource():
	if event_data and not event_data.resource_path.is_empty():
		request_save.emit(event_data)
		# Force reloading to ensure Editor knows about changes? 
		# Usually ResourceSaver.save is enough for .tres files.
		# But maybe we need to notify property list changed?
		event_data.emit_changed()

# UI Callbacks
func _on_title_changed(new_text):
	if _updating_ui:
		return
	event_data.title = new_text
	_request_save()

func _on_desc_changed():
	if _updating_ui:
		return
	event_data.description = desc_edit.text
	_request_save()

func _on_duration_changed(value):
	if _updating_ui:
		return
	event_data.duration = value
	_request_save()

func _on_auto_start_toggled(pressed):
	if _updating_ui:
		return
	event_data.auto_start = pressed
	_request_save()

func _on_auto_collect_toggled(pressed):
	if _updating_ui:
		return
	event_data.auto_collect = pressed
	_request_save()

func _on_add_reward_pressed():
	var reward = EventRewardData.new()
	_ensure_writable()
	event_data.rewards = _typed_array_append(event_data.rewards, EventRewardData, reward)
	_save_resource()
	_rebuild_rewards_list()

func _on_delete_reward_pressed(index: int):
	_ensure_writable()
	event_data.rewards = _typed_array_remove_at(event_data.rewards, EventRewardData, index)
	_save_resource()
	_rebuild_rewards_list()

func _on_add_slot_pressed():
	_ensure_writable() # Fix: Ensure array is writable before appending
	var slot = EventSlotData.new()
	event_data.slots = _typed_array_append(event_data.slots, EventSlotData, slot)
	_save_resource()
	_rebuild_slots_ui()

func _on_delete_slot_pressed(index: int):
	_ensure_writable() # Fix: Ensure array is writable before removal
	event_data.slots = _typed_array_remove_at(event_data.slots, EventSlotData, index)
	_save_resource()
	_rebuild_slots_ui()

func _on_add_branch_pressed(is_instant: bool):
	_ensure_writable()
	var branch = EventBranchData.new()
	# Initialize arrays explicitly to avoid Nil or shared reference issues
	# Use typed arrays to match the script definition
	branch.conditions = Array([], TYPE_OBJECT, "Resource", EventCondition)
	branch.outcomes = Array([], TYPE_OBJECT, "Resource", EventOutcome)
	
	if is_instant:
		event_data.instant_branches = _typed_array_append(event_data.instant_branches, EventBranchData, branch)
	else:
		event_data.branches = _typed_array_append(event_data.branches, EventBranchData, branch)
	_save_resource()
	_rebuild_slots()

func _on_delete_branch_pressed(index: int, is_instant: bool):
	_ensure_writable()
	if is_instant:
		event_data.instant_branches = _typed_array_remove_at(event_data.instant_branches, EventBranchData, index)
	else:
		event_data.branches = _typed_array_remove_at(event_data.branches, EventBranchData, index)
	_save_resource()
	_rebuild_slots()
	_refresh_layout()
