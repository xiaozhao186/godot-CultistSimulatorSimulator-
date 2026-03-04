class_name Token
extends Area2D

signal dropped(token: Token)
signal clicked(token: Token)
signal double_clicked(token: Token)
signal drag_started(token: Token)

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_z_index: int = 0
var overlap_enabled: bool = true
var last_click_time: float = 0.0
var press_time: float = 0.0
var press_pos: Vector2 = Vector2.ZERO
const DOUBLE_CLICK_TIME: float = 0.3
const CLICK_MAX_DURATION: float = 0.2
const CLICK_MAX_DISTANCE: float = 10.0

const DRAG_SCALE: float = 1.12

var _base_scale: Vector2 = Vector2.ONE
var _scale_tween: Tween = null

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_base_scale = scale
	add_to_group("selectables")

func _on_mouse_entered() -> void:
	GameManager.add_hovered_token(self)

func _on_mouse_exited() -> void:
	GameManager.remove_hovered_token(self)
	
func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if GameManager.get_top_token_at_mouse() != self:
					return
					
				var current_time = Time.get_ticks_msec() / 1000.0
				if current_time - last_click_time < DOUBLE_CLICK_TIME:
					double_clicked.emit(self)
				last_click_time = current_time
				
				press_time = current_time
				press_pos = event.global_position
				begin_drag(event.global_position)
				
				if AudioManager:
					AudioManager.play_sfx("card_click")
					
				# clicked.emit(self) # Removed immediate emit
			else:
				# This part handles release IF the mouse is still over the shape.
				# We keep it for click detection, but drag end is handled in _input now.
				_handle_click_release(event)

func begin_drag(_global_mouse_pos: Vector2) -> void:
	dragging = true
	GameManager.dragging_token = self
	drag_offset = global_position - get_global_mouse_position()
	original_z_index = z_index
	z_index = 100
	_overlap_drag_scale(true)
	drag_started.emit(self)

func _end_drag() -> void:
	if dragging:
		dragging = false
		if GameManager.dragging_token == self:
			GameManager.dragging_token = null
		z_index = original_z_index
		_overlap_drag_scale(false)
		_clamp_to_table_bounds()
		dropped.emit(self)
		GameManager.token_dropped.emit(self)
		if GameManager.has_method("schedule_post_drop_resolution"):
			GameManager.schedule_post_drop_resolution(self)

func _overlap_drag_scale(is_dragging: bool) -> void:
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_SINE)
	_scale_tween.set_ease(Tween.EASE_OUT)
	var target = _base_scale * (DRAG_SCALE if is_dragging else 1.0)
	_scale_tween.tween_property(self, "scale", target, 0.22)

func _clamp_to_table_bounds() -> void:
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var bounds = tabletop.get_node_or_null("TableBounds")
	if bounds == null or not bounds.has_method("clamp_point_to_card_bounds"):
		return
	global_position = bounds.clamp_point_to_card_bounds(global_position, _get_half_size())

func _get_half_size() -> Vector2:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var rect: RectangleShape2D = child.shape
			var s = rect.size * Vector2(abs(scale.x), abs(scale.y))
			return s * 0.5
	return Vector2(60, 80) * Vector2(abs(scale.x), abs(scale.y))

func _handle_click_release(event: InputEventMouseButton) -> void:
	var release_time = Time.get_ticks_msec() / 1000.0
	var dist = press_pos.distance_to(event.global_position)
	
	# Check for valid click (short duration, short distance)
	if release_time - press_time < CLICK_MAX_DURATION and dist < CLICK_MAX_DISTANCE:
		clicked.emit(self)
		GameManager.token_clicked.emit(self)


func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
		_clamp_to_table_bounds()
