class_name CameraController
extends Camera2D

@export var move_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.5
@export var pan_speed: float = 1.0
@export var bounds_path: NodePath = NodePath("../TableBounds")

var _bounds = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var n = get_node_or_null(bounds_path)
	_bounds = n
	_clamp_to_bounds()

func _process(delta: float) -> void:
	# Keyboard movement
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	input_dir = input_dir.normalized()
	
	position += input_dir * move_speed * delta / zoom.x
	_clamp_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_speed, zoom_speed)
		
		# Middle mouse pan
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		zoom.x = clamp(zoom.x, min_zoom, max_zoom)
		zoom.y = clamp(zoom.y, min_zoom, max_zoom)
		_clamp_to_bounds()
		
	elif event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		position -= event.relative * pan_speed / zoom.x
		_clamp_to_bounds()

func _clamp_to_bounds() -> void:
	if _bounds == null or not _bounds.has_method("get_table_rect"):
		return
	var table_rect: Rect2 = _bounds.get_table_rect()
	if table_rect.size == Vector2.ZERO:
		return
	var viewport_size = get_viewport_rect().size
	var half = viewport_size * 0.5 / zoom
	var min_x = table_rect.position.x + half.x
	var max_x = table_rect.position.x + table_rect.size.x - half.x
	var min_y = table_rect.position.y + half.y
	var max_y = table_rect.position.y + table_rect.size.y - half.y
	if min_x > max_x or min_y > max_y:
		position = table_rect.get_center()
		return
	position = Vector2(clamp(position.x, min_x, max_x), clamp(position.y, min_y, max_y))
