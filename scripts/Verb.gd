class_name Verb
extends Token

@export var event_data: EventData # Deprecated: use data.default_event
@export var data: VerbData
@onready var label: Label = $Label
@onready var progress_bar: TextureProgressBar = $ProgressBar
@onready var timer_label: Label = $TimerLabel
@onready var sprite: Sprite2D = $Icon

var active_panel: EventPanel = null
var id: String = ""
var _hidden_runtime_collision_saved: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _saved_monitoring: bool = true
var _saved_monitorable: bool = true
var _saved_shape_disabled: Dictionary = {}

func setup(verb_data: VerbData) -> void:
	data = verb_data
	id = data.id
	name = "Verb_" + id
	if label: label.text = data.title
	if sprite and data.icon: sprite.texture = data.icon
	if data.default_event:
		event_data = data.default_event
	if bool(data.get("hidden_runtime")):
		_apply_hidden_runtime_collision(true)
		visible = false
		input_pickable = false
	else:
		_apply_hidden_runtime_collision(false)

func _apply_hidden_runtime_collision(enabled: bool) -> void:
	if enabled:
		if not _hidden_runtime_collision_saved:
			_hidden_runtime_collision_saved = true
			_saved_collision_layer = collision_layer
			_saved_collision_mask = collision_mask
			_saved_monitoring = monitoring
			_saved_monitorable = monitorable
			_saved_shape_disabled.clear()
			for child in get_children():
				if child is CollisionShape2D:
					_saved_shape_disabled[child.get_instance_id()] = child.disabled
		collision_layer = 0
		collision_mask = 0
		monitoring = false
		monitorable = false
		for child in get_children():
			if child is CollisionShape2D:
				child.disabled = true
	else:
		if not _hidden_runtime_collision_saved:
			return
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		monitoring = _saved_monitoring
		monitorable = _saved_monitorable
		for child in get_children():
			if child is CollisionShape2D:
				var k = child.get_instance_id()
				if _saved_shape_disabled.has(k):
					child.disabled = bool(_saved_shape_disabled[k])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	clicked.connect(_on_clicked)
	
	if data:
		setup(data)
	elif event_data:
		# Legacy support
		if label: label.text = event_data.title
		
	GameManager.register_verb(self)
	
	if progress_bar: progress_bar.visible = false
	if timer_label: timer_label.visible = false
	
	# Check for auto-start
	# We defer this to ensure everything is ready and connected
	call_deferred("_check_auto_start")

func _check_auto_start() -> void:
	if event_data and event_data.auto_start:
		Log.debug("[Debug] Verb auto-start triggering for: " + str(name))
		_start_auto_in_background()

func _start_auto_in_background() -> void:
	if is_instance_valid(active_panel):
		return
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var panel = load("res://scenes/EventPanel.tscn").instantiate()
	panel.visible = false # Ensure invisible before adding to tree to prevent _ready sound
	tabletop.add_child(panel)
	
	# Manually set source_verb BEFORE setup, so _should_play_sound works in _ready
	panel.source_verb = self
	
	panel.setup(event_data, false, self)
	panel.position = global_position + Vector2(50, -50)
	panel.z_index = 10
	# panel.visible = false # Already set above
	active_panel = panel
	active_panel.panel_closed.connect(_on_panel_closed)

func _exit_tree() -> void:
	GameManager.unregister_verb(self)

func _process(delta: float) -> void:
	super._process(delta)
	
	if is_instance_valid(active_panel) and active_panel.current_state == EventPanel.State.WORKING:
		# Access timer from active_panel
		var timer = active_panel.timer
		# Check if event_data is valid before accessing
		if active_panel.event_data == null:
			return
			
		var duration = active_panel.event_data.duration
		if timer and duration > 0:
			if progress_bar:
				progress_bar.visible = true
				progress_bar.max_value = duration
				# Invert logic: Empty -> Full means value goes 0 -> duration?
				# User said "Empty to Full" AND "Countdown".
				# Usually countdown implies Full -> Empty.
				# If "Empty to Full", then value = duration - time_left
				progress_bar.value = duration - timer.time_left
				
			if timer_label:
				timer_label.visible = true
				timer_label.text = "%.1f" % timer.time_left
	else:
		if progress_bar: progress_bar.visible = false
		if timer_label: timer_label.visible = false

func _on_clicked(_token):
	if dragging: return
	
	# Silence hidden verbs
	if not visible:
		return
	if data and bool(data.get("hidden_runtime")):
		return

	# If we have an active panel (running or minimized), restore it
	if is_instance_valid(active_panel):
		active_panel.position = global_position + Vector2(50, -50)
		active_panel.visible = true
		active_panel.move_to_front()
		if AudioManager: AudioManager.play_sfx("panel_open")
		return
	
	# Find Tabletop root to add EventPanel in World Space
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		# If stack > 1, maybe we should only open panel for ONE verb?
		# But Verb logic is usually "Work Station". If you have 5 Work Stations stacked,
		# do you open 5 panels? Or just one?
		# User said "Behaviour as Card". Cards unstack when dragged.
		# But Verbs are usually clicked to open panel.
		# If I click a stack of 5 Verbs, I probably want to use ONE of them.
		# So, logically, we should probably unstack one if we are going to "use" it.
		# But the current logic is "Click to Open Panel".
		# Let's keep it simple: Clicking a stack opens the panel for THIS verb instance.
		# The stack count is just visual or storage.
		# However, if we move the Verb, we might want to unstack?
		# Currently Verb doesn't implement "drag to unstack" in _input_event like Card does.
		# Let's add that.
		
		var panel = load("res://scenes/EventPanel.tscn").instantiate()
		tabletop.add_child(panel)
		
		# Pass self as source verb
		panel.setup(event_data, false, self)
		
		# Position near the verb/mouse but in world coordinates
		panel.position = global_position + Vector2(50, -50)
		# Set Z-index to be above normal cards (0) but below dragged cards (100)
		panel.z_index = 10
		
		active_panel = panel
		active_panel.panel_closed.connect(_on_panel_closed)
		
		# Removed manual sound trigger: EventPanel handles its own sound in _ready
		# if AudioManager: AudioManager.play_sfx("panel_open")

func _on_panel_closed() -> void:
	active_panel = null
	
	var silent = false
	if not visible: silent = true
	if data and bool(data.get("hidden_runtime")): silent = true
	
	if not silent and AudioManager:
		AudioManager.play_sfx("panel_close")
		
	if has_meta("auto_restart") and bool(get_meta("auto_restart")):
		remove_meta("auto_restart")
		call_deferred("_restart_auto")

func _restart_auto() -> void:
	if is_instance_valid(active_panel):
		return
	if is_queued_for_deletion() or not is_inside_tree():
		return
	if event_data == null or not event_data.auto_start:
		return
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var panel = load("res://scenes/EventPanel.tscn").instantiate()
	panel.visible = false # Ensure invisible before adding to tree
	tabletop.add_child(panel)
	
	# Manually set source_verb BEFORE setup, so _should_play_sound works in _ready if visible was true
	# (Though we set visible=false above, so _ready sound shouldn't play anyway)
	panel.source_verb = self
	
	panel.setup(event_data, false, self)
	panel.position = global_position + Vector2(50, -50)
	panel.z_index = 10
	active_panel = panel
	active_panel.panel_closed.connect(_on_panel_closed)

func serialize() -> Dictionary:
	var state = {
		"id": self.data.id if self.data else id,
		"verb_path": self.data.resource_path if self.data else "",
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"is_debug": id.begins_with("debug_"),
		"debug_event_id": "",
		"debug_event_path": "",
		"panel_state": null
	}
	
	if state.is_debug and self.data and self.data.default_event:
		state.debug_event_id = self.data.default_event.id
		state.debug_event_path = self.data.default_event.resource_path
		
	if is_instance_valid(active_panel):
		state.panel_state = active_panel.serialize()
		
	return state

func deserialize(state: Dictionary) -> void:
	if state.get("panel_state"):
		# If panel was active, re-open and restore it
		# Use _on_clicked logic to spawn panel but don't show it if it wasn't visible?
		# Actually serialize assumes active_panel != null means it exists.
		# If it was minimized (visible=false), serialize still returns data.
		
		# Spawn panel
		var tabletop = get_tree().root.get_node_or_null("Tabletop")
		if tabletop:
			var panel = load("res://scenes/EventPanel.tscn").instantiate()
			
			# Pre-set visibility from saved state to prevent sound if hidden
			if state.panel_state.has("visible"):
				panel.visible = state.panel_state["visible"]
			else:
				panel.visible = true
				
			tabletop.add_child(panel)
			
			# Setup basic link
			# Note: deserialize calls setup inside itself based on saved event ID
			# But we need to link source verb first
			panel.source_verb = self
			
			panel.position = global_position + Vector2(50, -50)
			panel.z_index = 10
			
			active_panel = panel
			active_panel.panel_closed.connect(_on_panel_closed)
			
			# Restore panel internal state
			panel.deserialize(state.panel_state)
			
			# Restore visibility/minimized state (Redundant but safe)
			if state.panel_state.has("visible"):
				panel.visible = state.panel_state["visible"]
			else:
				panel.visible = true
