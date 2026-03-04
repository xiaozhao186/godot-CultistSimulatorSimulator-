@tool
extends Node

## Manages saving of resources and graph data with throttling and batching.
## This prevents excessive disk writes and ensures consistent save order.

# Signals could be added here if needed, e.g. saved, error

var _pending_resources := {}
var _pending_graph : Resource # EventGraphData
var _timer := Timer.new()

const DEBOUNCE_TIME = 0.3 # seconds

func _ready():
	_timer.one_shot = true
	_timer.wait_time = DEBOUNCE_TIME
	_timer.timeout.connect(_flush)
	add_child(_timer)

func _exit_tree():
	_flush()

func request_save_resource(res: Resource):
	if not res or res.resource_path.is_empty():
		return
	
	# Update the pending resource reference
	_pending_resources[res.resource_path] = res
	_schedule()

func request_save_graph(graph: Resource):
	# Type check can be done via casting or duck typing if cyclic dependency is an issue
	# graph is EventGraphData
	if not graph or graph.resource_path.is_empty():
		return
		
	_pending_graph = graph
	_schedule()

func force_save():
	_timer.stop()
	_flush()

func _schedule():
	if _timer.is_stopped():
		_timer.start()

func _flush():
	# 1. Save all pending resources first
	# Using keys() to iterate over a snapshot of keys
	var paths = _pending_resources.keys()
	for path in paths:
		var res = _pending_resources.get(path)
		if res:
			var err = ResourceSaver.save(res, path)
			if err != OK:
				push_error("SaveManager: Failed to save resource %s: %d" % [path, err])
			else:
				print("[EventEditor] Saved resource: ", path.get_file())
	
	_pending_resources.clear()

	# 2. Save graph data after resources
	# This ensures that if the graph references new resources, they are saved first.
	if _pending_graph and not _pending_graph.resource_path.is_empty():
		var err = ResourceSaver.save(_pending_graph, _pending_graph.resource_path)
		if err != OK:
			push_error("SaveManager: Failed to save graph %s: %d" % [_pending_graph.resource_path, err])
		else:
			print("[EventEditor] Saved graph: ", _pending_graph.resource_path.get_file())
		_pending_graph = null
