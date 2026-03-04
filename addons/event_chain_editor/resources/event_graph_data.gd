@tool
extends Resource
class_name EventGraphData

# Stores the visual layout of the graph.
# Dictionary format: { "res://path/to/event_data.tres": Vector2(x, y) }
@export var nodes: Dictionary = {}

# Graph view state
@export var scroll_offset: Vector2 = Vector2.ZERO
@export var zoom: float = 1.0
