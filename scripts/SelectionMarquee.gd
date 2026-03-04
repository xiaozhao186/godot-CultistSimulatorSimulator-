extends Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not GameManager.selecting:
		return
	var r: Rect2 = GameManager.get_selection_rect_world()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(r, Color(1, 1, 1, 0.12), true)
	draw_rect(r, Color(1, 1, 1, 0.75), false, 2.0)
