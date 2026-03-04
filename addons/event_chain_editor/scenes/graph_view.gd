@tool
extends Control

const EventGraphData = preload("res://addons/event_chain_editor/resources/event_graph_data.gd")
const EventNodeScene = preload("res://addons/event_chain_editor/scenes/event_node.tscn")
const EditorSaveManager = preload("res://addons/event_chain_editor/save_manager.gd")

var current_graph_data: EventGraphData
var editor_save_manager: EditorSaveManager

@onready var graph_edit: GraphEdit = $VBoxContainer/GraphEdit
@onready var toolbar_container: HBoxContainer = $VBoxContainer/Toolbar

@onready var popup_menu: PopupMenu = PopupMenu.new()
@onready var create_dialog: ConfirmationDialog = ConfirmationDialog.new()
var _create_dialog_line_edit: LineEdit
var _create_pos: Vector2

func _ready():
	editor_save_manager = EditorSaveManager.new()
	add_child(editor_save_manager)
	
	# Add Save Button to Toolbar
	var save_btn = Button.new()
	save_btn.text = "Save Graph"
	save_btn.pressed.connect(save_graph_manual)
	# Insert as first item or append
	toolbar_container.add_child(save_btn)
	# Move to be the first child if label is there
	toolbar_container.move_child(save_btn, 0)
	
	add_child(popup_menu)
	popup_menu.add_item("Create New Event", 0)
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	
	add_child(create_dialog)
	create_dialog.title = "Create New Event"
	var vbox = VBoxContainer.new()
	create_dialog.add_child(vbox)
	_create_dialog_line_edit = LineEdit.new()
	_create_dialog_line_edit.placeholder_text = "Event Name (e.g. MyEvent)"
	var name_label = Label.new()
	name_label.text = "Enter Event Name:"
	vbox.add_child(name_label)
	vbox.add_child(_create_dialog_line_edit)
	create_dialog.confirmed.connect(_on_create_dialog_confirmed)
	
	if graph_edit:
		graph_edit.gui_input.connect(_on_graph_edit_gui_input)
		if not graph_edit.connection_request.is_connected(_on_connection_request):
			graph_edit.connection_request.connect(_on_connection_request)
		if not graph_edit.disconnection_request.is_connected(_on_disconnection_request):
			graph_edit.disconnection_request.connect(_on_disconnection_request)
		if not graph_edit.delete_nodes_request.is_connected(_on_delete_nodes_request):
			graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
		
		# Connect selection signal for Inspector integration
		if not graph_edit.node_selected.is_connected(_on_node_selected):
			graph_edit.node_selected.connect(_on_node_selected)
		# Also handle deselection to clear inspector? Or keep last?
		# Usually good UX to clear or show GraphData properties.
		if not graph_edit.node_deselected.is_connected(_on_node_deselected):
			graph_edit.node_deselected.connect(_on_node_deselected)

func load_graph(data: EventGraphData):
	if not is_node_ready():
		await ready

	current_graph_data = data
	
	if not graph_edit:
		return
		
	graph_edit.clear_connections()
	
	# Clear existing nodes
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	
	if not data:
		return

	# Load nodes from data
	var resource_to_node_name = {}
	
	for res_path in data.nodes:
		if FileAccess.file_exists(res_path):
			var event_res = load(res_path)
			if event_res:
				var node = _add_node(event_res, data.nodes[res_path])
				resource_to_node_name[res_path] = node.name
	
	# Restore connections
	call_deferred("_restore_connections", resource_to_node_name)

func _refresh_node_incoming_links(node_name: String):
	if not graph_edit: return
	var node = graph_edit.get_node(str(node_name))
	if not node or not node.has_method("update_incoming_links"): return
	
	var links = []
	var connection_list = graph_edit.get_connection_list()
	for conn in connection_list:
		# Godot 4 connection list uses 'to_node' and 'from_node' keys
		if conn["to_node"] == node_name:
			var from_node_name = conn["from_node"]
			var from_port = conn["from_port"]
			var from_node = graph_edit.get_node(str(from_node_name))
			
			var from_title = from_node_name
			var branch_info = "Port %d" % from_port
			
			if from_node and from_node.event_data:
				# Use Event ID/Title
				if not from_node.event_data.id.is_empty():
					from_title = from_node.event_data.id
				elif not from_node.event_data.title.is_empty():
					from_title = from_node.event_data.title
				
				# Get Branch/Outcome info
				# Output port 0 is Default Next
				if from_port == 0:
					branch_info = "Default Next"
				elif from_node.has_method("get_outcome_mapping_by_port"):
					var mapping = from_node.get_outcome_mapping_by_port(from_port)
					if mapping:
						if mapping.has("branch_index"):
							var b_idx = mapping.branch_index
							var o_idx = mapping.outcome_index
							var is_inst = mapping.get("is_instant", false)
							var type_str = "Inst Br" if is_inst else "Res Br"
							branch_info = "%s %d, Out %d" % [type_str, b_idx, o_idx]
					else:
						# Fallback to slot mapping if method missing or failed
						if from_node.has_method("get_outcome_mapping"):
							var map2 = from_node.get_outcome_mapping(from_port)
							if map2 and map2.has("branch_index"):
								var b_idx = map2.branch_index
								var o_idx = map2.outcome_index
								var is_inst = map2.get("is_instant", false)
								var type_str = "Inst Br" if is_inst else "Res Br"
								branch_info = "%s %d, Out %d" % [type_str, b_idx, o_idx]
			
			links.append({
				"from_node": from_node_name,
				"from_port": from_port,
				"from_title": from_title,
				"branch_info": branch_info
			})
	
	node.update_incoming_links(links)

func _on_node_request_disconnect_incoming(from_node: String, from_port: int, to_node: String):
	# ...
	var connection_list = graph_edit.get_connection_list()
	for conn in connection_list:
		if conn["from_node"] == from_node and conn["from_port"] == from_port and conn["to_node"] == to_node:
			_on_disconnection_request(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
			return

func _restore_connections(resource_to_node_name: Dictionary) -> void:
	await get_tree().process_frame
	
	for res_path in resource_to_node_name:
		var node_name = resource_to_node_name[res_path]
		var node = graph_edit.get_node(str(node_name))
		if not node or not node.event_data:
			continue
		
		var event_data = node.event_data
		var next_event = event_data.default_next_event
		if next_event and next_event.resource_path in resource_to_node_name:
			var next_node_name = resource_to_node_name[next_event.resource_path]
			graph_edit.connect_node(node_name, 0, next_node_name, 0)
		
		if not node.has_method("get_outcome_slot_map"):
			continue
		
		var slot_map: Dictionary = node.get_outcome_slot_map()
		for slot in slot_map.keys():
			var entry = slot_map[slot]
			if not entry or not entry.has("outcome"):
				continue
			var outcome = entry.outcome
			if outcome and outcome.target_event and outcome.target_event.resource_path in resource_to_node_name:
				var target_node_name = resource_to_node_name[outcome.target_event.resource_path]
				graph_edit.connect_node(node_name, int(slot), target_node_name, 0)
	
	# Update all incoming links
	for child in graph_edit.get_children():
		if child is GraphNode:
			_refresh_node_incoming_links(child.name)

func _on_node_selected(node):
	# Disable auto-inspector selection to prevent focus stealing/hiding the graph
	# if node is GraphNode and node.event_data:
	# 	EditorInterface.edit_resource(node.event_data)
	pass

func _on_node_deselected(node):
	# Optional: Show graph properties or nothing
	# EditorInterface.edit_resource(current_graph_data)
	pass

func _add_node(event_res, pos: Vector2) -> GraphNode:
	var node = EventNodeScene.instantiate()
	node.position_offset = pos
	graph_edit.add_child(node)
	node.setup(event_res)
	
	if node.has_signal("request_save"):
		node.request_save.connect(editor_save_manager.request_save_resource)
	
	if node.has_signal("request_disconnect_incoming"):
		node.request_disconnect_incoming.connect(func(from_n, from_p): _on_node_request_disconnect_incoming(from_n, from_p, node.name))
		
	return node

func save_graph_manual():
	save_graph()
	if editor_save_manager:
		editor_save_manager.force_save()

func save_graph():
	if not current_graph_data: return
	
	# Ensure graph data has a valid path before saving
	if current_graph_data.resource_path.is_empty():
		print_debug("Cannot save graph: EventGraphData has no resource_path.")
		return

	# Force update node positions before clearing
	# Note: This loop only updates positions. Connection data is saved separately in the graph resources.
	current_graph_data.nodes.clear()
	for child in graph_edit.get_children():
		if child is GraphNode and child.event_data:
			# Only save nodes that have a valid resource path
			if not child.event_data.resource_path.is_empty():
				current_graph_data.nodes[child.event_data.resource_path] = child.position_offset
			else:
				print("Warning: EventNode has empty resource path, skipping save for this node.")
	
	editor_save_manager.request_save_graph(current_graph_data)

func _on_connection_request(from_node, from_port, to_node, to_port):
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	
	var from_n = graph_edit.get_node(str(from_node))
	var to_n = graph_edit.get_node(str(to_node))
	
	if from_n and to_n and from_n.event_data and to_n.event_data:
		var event_data = from_n.event_data
		var target_event = to_n.event_data
		
		# GraphEdit's from_port is OUTPUT PORT INDEX (0..N-1), not slot row index.
		# Output port 0 is Default Next in our node layout.
		if from_port == 0:
			event_data.default_next_event = target_event
			editor_save_manager.request_save_resource(event_data)
			save_graph()
			_refresh_node_incoming_links(str(to_node))
			return
			
		# For other ports, use the mapping logic
		if from_n.has_method("get_outcome_mapping_by_port"):
			var mapping = from_n.get_outcome_mapping_by_port(from_port)
			if mapping and mapping.has("outcome"):
				var outcome = mapping.outcome
				outcome.target_event = target_event
				editor_save_manager.request_save_resource(event_data)
				save_graph()
				_refresh_node_incoming_links(str(to_node))
				return
		
		# Fallback to old slot method if new method not found (shouldn't happen)
		if from_n.has_method("get_outcome_mapping"):
			var mapping = from_n.get_outcome_mapping(from_port)
			if mapping and mapping.has("outcome"):
				var outcome = mapping.outcome
				outcome.target_event = target_event
				editor_save_manager.request_save_resource(event_data)
				save_graph()
				_refresh_node_incoming_links(str(to_node))
				return

func _on_disconnection_request(from_node, from_port, to_node, to_port):
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	
	_refresh_node_incoming_links(str(to_node))
	
	var from_n = graph_edit.get_node(str(from_node))
	if from_n and from_n.event_data:
		var event_data = from_n.event_data
		
		if from_port == 0:
			event_data.default_next_event = null
		else:
			if from_n.has_method("get_outcome_mapping_by_port"):
				var mapping = from_n.get_outcome_mapping_by_port(from_port)
				if mapping and mapping.has("outcome"):
					mapping.outcome.target_event = null
			elif from_n.has_method("get_outcome_mapping"):
				var mapping = from_n.get_outcome_mapping(from_port)
				if mapping and mapping.has("outcome"):
					mapping.outcome.target_event = null
		
		editor_save_manager.request_save_resource(event_data)
		save_graph()

func _on_delete_nodes_request(nodes):
	for node_name in nodes:
		var node = graph_edit.get_node(str(node_name))
		if node:
			graph_edit.remove_child(node)
			node.queue_free()
	
	save_graph()

func _on_graph_edit_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_create_pos = get_local_mouse_position() # Rough pos, needs adjustment for graph coordinates
			popup_menu.position = get_screen_position() + get_local_mouse_position()
			popup_menu.popup()

func _on_popup_menu_id_pressed(id):
	if id == 0: # Create New Event
		_create_dialog_line_edit.text = ""
		create_dialog.popup_centered(Vector2(300, 100))

func _on_create_dialog_confirmed():
	var event_name = _create_dialog_line_edit.text.strip_edges()
	if event_name.is_empty():
		event_name = "NewEvent"
	
	# Determine folder path based on Graph name
	var folder_path = "res://data/Events/" # Default fallback
	
	if current_graph_data and not current_graph_data.resource_path.is_empty():
		var graph_path = current_graph_data.resource_path
		var graph_dir = graph_path.get_base_dir()
		var graph_name = graph_path.get_file().get_basename()
		
		# Check if we are in a structure like .../Evtree/
		if graph_dir.ends_with("/Evtree"):
			# Go up one level to Scenario Root
			var scenario_root = graph_dir.get_base_dir()
			# Create/Use Events folder at Scenario Root
			folder_path = scenario_root + "/Events/" + graph_name + "/"
		else:
			# Fallback: Create Events folder next to the graph or inside it?
			# Let's try to find a sibling "Events" folder
			# If graph is in res://data/test/Events/test_graph.tres, parent is .../Events.
			if graph_dir.ends_with("/Events"):
				folder_path = graph_dir + "/" + graph_name + "/"
			else:
				# Generic relative path
				folder_path = graph_dir + "/Events/" + graph_name + "/"
	
	# Create folder if needed
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(folder_path):
		dir.make_dir_recursive(folder_path)
	
	# Create Resource
	var new_event = EventData.new()
	new_event.id = event_name
	
	var file_path = folder_path + event_name + ".tres"
	var err = ResourceSaver.save(new_event, file_path)
	if err != OK:
		print("Error saving new event: ", err)
		return
	
	# Force FileSystem scan to ensure the new file is picked up
	EditorInterface.get_resource_filesystem().scan()
	
	# IMPORTANT: Reload the resource from disk to ensure we have the version with the correct resource_path
	# ResourceSaver.save does NOT automatically update the resource_path of the object in memory if it was empty.
	new_event = load(file_path)
	
	# Add to graph
	# Calculate correct graph position
	# _create_pos is local to GraphView (Control). GraphEdit is a child.
	# We need position relative to GraphEdit's scroll/zoom.
	# Simplification: Use center of screen or try to reverse map.
	# Let's use the graph_edit.get_local_mouse_position() at the time of click if we saved it?
	# We saved _create_pos from GraphView local.
	
	# Actually, best to use GraphEdit's local mouse pos at popup time.
	# But popup logic above used get_local_mouse_position() on GraphView.
	# graph_edit is at (0,0) in GraphView usually?
	var graph_local_pos = _create_pos - graph_edit.position
	var graph_pos = (graph_local_pos + graph_edit.scroll_offset) / graph_edit.zoom
	
	if current_graph_data:
		if not current_graph_data.nodes.has(file_path):
			_add_node(new_event, graph_pos)
			current_graph_data.nodes[file_path] = graph_pos
			save_graph()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "files":
		var files = data["files"]
		for file in files:
			if file.ends_with(".tres") or file.ends_with(".res"):
				return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "files":
		var files = data["files"]
		
		# Convert screen position to graph coordinates
		# Use 'zoom' instead of 'zoom_scale' as GraphEdit property name changed in Godot 4
		var drop_pos = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
		
		for file in files:
			var res = load(file)
			if res is EventData:
				if current_graph_data:
					if not current_graph_data.nodes.has(file):
						_add_node(res, drop_pos)
						current_graph_data.nodes[file] = drop_pos
						save_graph()
						# Offset next node slightly if dropping multiple
						drop_pos += Vector2(20, 20)
					else:
						print("Event already in graph: ", file)
