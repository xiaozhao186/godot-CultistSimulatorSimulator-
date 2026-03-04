class_name TableBounds
extends Node

@export var background_path: NodePath = NodePath("../Background")
@export_range(0.0, 0.2, 0.01) var card_margin_ratio: float = 0.08
@export_range(1.0, 1.5, 0.01) var cover_view_margin: float = 1.05
@export var camera_path: NodePath = NodePath("../MainCamera")

func _ready() -> void:
	_fit_background_to_camera_view()

func _fit_background_to_camera_view() -> void:
	var bg = get_background()
	if bg == null or bg.texture == null:
		return
	var camera = get_node_or_null(camera_path)
	if camera == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var min_zoom := 0.5
	var v = camera.get("min_zoom")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		min_zoom = float(v)
	var required_world = viewport_size / float(min_zoom) * cover_view_margin
	var tex_size = bg.texture.get_size()
	if tex_size == Vector2.ZERO:
		return
	var scale_factor = max(required_world.x / tex_size.x, required_world.y / tex_size.y)
	bg.scale = Vector2(scale_factor, scale_factor)

func get_background() -> Sprite2D:
	var n = get_node_or_null(background_path)
	return n if n is Sprite2D else null

func get_table_rect() -> Rect2:
	var bg = get_background()
	if bg == null or bg.texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var size: Vector2 = bg.texture.get_size() * bg.scale
	return Rect2(bg.global_position - size * 0.5, size)

func get_card_bounds_rect() -> Rect2:
	var table_rect = get_table_rect()
	if table_rect.size == Vector2.ZERO:
		return table_rect
	var margin_scalar = min(table_rect.size.x, table_rect.size.y) * card_margin_ratio
	var margin = Vector2(margin_scalar, margin_scalar)
	return Rect2(table_rect.position + margin, table_rect.size - margin * 2.0)

func clamp_point_to_card_bounds(point: Vector2, half_size: Vector2) -> Vector2:
	var r = get_card_bounds_rect()
	if r.size == Vector2.ZERO:
		return point
	var min_x = r.position.x + half_size.x
	var max_x = r.position.x + r.size.x - half_size.x
	var min_y = r.position.y + half_size.y
	var max_y = r.position.y + r.size.y - half_size.y
	return Vector2(clamp(point.x, min_x, max_x), clamp(point.y, min_y, max_y))
