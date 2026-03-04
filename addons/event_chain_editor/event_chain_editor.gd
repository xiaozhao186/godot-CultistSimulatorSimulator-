@tool
extends EditorPlugin

const EventGraphData = preload("res://addons/event_chain_editor/resources/event_graph_data.gd")
const GraphViewScene = preload("res://addons/event_chain_editor/scenes/graph_view.tscn")

var graph_view_instance

func _enter_tree():
	# Register custom resource
	# Assuming icon.svg is in project root, or use one in assets
	add_custom_type("EventGraphData", "Resource", EventGraphData, preload("res://icon.svg"))
	
	# Load the main UI scene
	graph_view_instance = GraphViewScene.instantiate()
	
	# Add the main UI to the editor's bottom panel
	add_control_to_bottom_panel(graph_view_instance, "Event Chain")
	
	# Hide it initially
	_make_visible(false)

func _exit_tree():
	# Clean up custom resource
	remove_custom_type("EventGraphData")
	
	# Remove the main UI
	if graph_view_instance:
		remove_control_from_bottom_panel(graph_view_instance)
		graph_view_instance.queue_free()

func _handles(object):
	return object is EventGraphData

func _edit(object):
	if object is EventGraphData:
		graph_view_instance.load_graph(object)
	
func _make_visible(visible):
	if graph_view_instance:
		graph_view_instance.visible = visible
