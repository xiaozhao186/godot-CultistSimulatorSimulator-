extends Node
const ScenarioDataScript = preload("res://scripts/ScenarioData.gd")

signal token_dropped(token)
signal token_clicked(token)

var dragging_token = null

var selecting: bool = false
var selection_start_world: Vector2 = Vector2.ZERO
var selection_end_world: Vector2 = Vector2.ZERO
var selected_tokens: Array[Token] = []
var _selected_modulate: Dictionary = {}

var _group_drag_leader: Token = null
var _group_drag_leader_start: Vector2 = Vector2.ZERO
var _group_drag_start_positions: Dictionary = {}
var _last_dragging_token: Token = null

var current_scenario_id: String = ""
var current_scenario: ScenarioData = null

# Resource Caches
var verb_db: Dictionary = {}
var event_db: Dictionary = {}
var scenario_db: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan_resources("res://data")

func _scan_resources(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_resources(path + "/" + file_name)
			else:
				var original_name = file_name.trim_suffix(".remap").trim_suffix(".import")
				if original_name.ends_with(".tres") or original_name.ends_with(".res"):
					var res_path = path + "/" + original_name
					# Load resource lightly? No, we need type.
					# But load() loads dependencies. This might be slow if many.
					# But we need to know if it's VerbData or EventData.
					# Maybe use ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_REUSE)
					var res = load(res_path)
					if res:
						if res is VerbData:
							if verb_db.has(res.id):
								var existing = verb_db[res.id]
								Log.warn("Duplicate VerbData.id: " + str(res.id) + "\n  a=" + str(existing.resource_path) + "\n  b=" + str(res.resource_path))
							verb_db[res.id] = res
						elif res is EventData:
							event_db[res.id] = res
						elif res is ScenarioData:
							scenario_db[res.id] = res
			file_name = dir.get_next()

func get_event_data(id: String) -> EventData:
	return event_db.get(id, null)

func start_scenario(scenario_data: ScenarioData) -> void:
	current_scenario_id = scenario_data.id
	current_scenario = scenario_data
	
	# Load Tabletop scene
	get_tree().change_scene_to_file("res://scenes/Tabletop.tscn")
	
	# Wait for scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop:
		printerr("Tabletop scene not found after transition!")
		return
		
	# Clear existing tokens (if any, though fresh scene should be empty of dynamic ones)
	# ... (scene reload handles this mostly, but good to be sure)
	
	# Spawn Initial Cards
	for entry in scenario_data.initial_card_entries:
		if entry == null or entry.card == null:
			continue
		var n = max(1, int(entry.count))
		for _i in range(n):
			_spawn_card(entry.card, tabletop)
		
	# Spawn Initial Verbs
	for verb_data in scenario_data.initial_verbs:
		_spawn_verb_from_data(verb_data, tabletop)
		
	# Start Initial Events
	# ... (Implementation depends on event system)
	
	# Play Scenario Music
	if AudioManager:
		if not scenario_data.bgm_playlist.is_empty():
			AudioManager.play_playlist(scenario_data.bgm_playlist)
		else:
			# Fallback to default game music
			AudioManager.play_default_game_music()

	# Auto-pause when scenario starts
	get_tree().paused = true

func load_game(slot_name: String) -> void:
	SaveManager.load_game(slot_name)

func restore_game_state(data: Dictionary) -> void:
	# 1. Switch Scene
	get_tree().change_scene_to_file("res://scenes/Tabletop.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop: return
	
	current_scenario_id = data.get("scenario_id", "")
	current_scenario = scenario_db.get(current_scenario_id, null)
	
	# 2. Clear existing (just in case)
	for child in tabletop.get_children():
		if child is Token:
			child.queue_free()
			
	# 3. Restore Cards
	for card_info in data.get("cards", []):
		var card_data = CardDatabase.get_card_data(card_info.id)
		if card_data:
			var card = _spawn_card(card_data, tabletop)
			card.global_position = Vector2(card_info.pos_x, card_info.pos_y)
			if card_info.has("lifetime"):
				card.current_lifetime = card_info.lifetime
			if card_info.has("stack_count"):
				card.stack_count = card_info.stack_count
				card._update_stack_badge()
				
	# 4. Restore Verbs
	for verb_info in data.get("verbs", []):
		var verb = null
		
		# Handle Debug Verbs (Dynamically Created)
		if verb_info.get("is_debug", false):
			verb = load("res://scenes/Verb.tscn").instantiate()
			var tabletop_node = get_tree().root.get_node_or_null("Tabletop")
			if tabletop_node:
				tabletop_node.add_child(verb)
				
				# Reconstruct temporary VerbData
				var v_data = VerbData.new()
				v_data.id = verb_info.id
				
				# Try to load the event it was bound to
				var event_loaded = false
				
				# Try Path First
				var event_path = verb_info.get("debug_event_path", "")
				if event_path != "" and ResourceLoader.exists(event_path):
					var evt = load(event_path)
					v_data.default_event = evt
					v_data.title = evt.title
					event_loaded = true
				
				# Fallback to ID
				if not event_loaded:
					var event_id = verb_info.get("debug_event_id", "")
					if event_id != "":
						var path = "res://data/Events/" + event_id + ".tres"
						if ResourceLoader.exists(path):
							var evt = load(path)
							v_data.default_event = evt
							v_data.title = evt.title
				
				verb.setup(v_data)
				print("[GameManager] Restored debug verb: ", verb_info.id)
		else:
			# Standard Verbs
			var verb_path = verb_info.get("verb_path", "")
			if verb_path != "" and ResourceLoader.exists(verb_path):
				var v = load(verb_path)
				if v is VerbData:
					verb = load("res://scenes/Verb.tscn").instantiate()
					var tabletop_node = get_tree().root.get_node_or_null("Tabletop")
					if tabletop_node:
						tabletop_node.add_child(verb)
						verb.setup(v)
			if verb == null:
				verb = spawn_verb(verb_info.id) 
			
		if verb:
			verb.global_position = Vector2(verb_info.pos_x, verb_info.pos_y)
			# Restore internal state (Panel, Timer, etc.)
			verb.deserialize(verb_info)
	
	# 5. Restore Music
	if AudioManager and current_scenario:
		if not current_scenario.bgm_playlist.is_empty():
			AudioManager.play_playlist(current_scenario.bgm_playlist)
		else:
			AudioManager.play_default_game_music()

	# Auto-pause after loading game
	get_tree().paused = true

func trigger_ending(index: int) -> void:
	if current_scenario == null:
		return
	if index < 0 or index >= current_scenario.endings.size():
		return
	var ending_data: EndingData = current_scenario.endings[index]
	if ending_data == null:
		return
	AppState.set_paused(true)
	var panel_scene = load("res://scenes/EndingPanel.tscn")
	if panel_scene == null:
		return
	var panel = panel_scene.instantiate()
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	var ui_parent: Node = null
	if tabletop:
		ui_parent = tabletop.get_node_or_null("CanvasLayer")
	if ui_parent == null:
		ui_parent = get_tree().current_scene
	if ui_parent == null:
		return
	ui_parent.add_child(panel)
	panel.setup(ending_data)
	panel.visible = true
	if panel is CanvasItem:
		panel.z_index = 200
		
	# Play Ending Music
	if AudioManager:
		if ending_data.bgm:
			AudioManager.play_music(ending_data.bgm)
		else:
			# Default ending music or fallback
			AudioManager.play_sfx("ending_default") # Keep SFX if no music provided, or play default ending BGM

func _spawn_card(data: CardData, parent: Node) -> Card:
	var card = load("res://scenes/Card.tscn").instantiate()
	parent.add_child(card)
	card.setup(data)
	# Default position scatter
	card.global_position = Vector2(960, 540) + Vector2(randf_range(-200, 200), randf_range(-100, 100))
	return card

func _spawn_verb_from_data(data: VerbData, parent: Node) -> void:
	var verb = load("res://scenes/Verb.tscn").instantiate()
	parent.add_child(verb)
	verb.setup(data)
	verb.global_position = Vector2(960, 540) + Vector2(randf_range(-300, 300), randf_range(-200, 200))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Audio Overlap Fix: Ensure we are NOT interacting with a Token
		if dragging_token != null:
			return
		if not hovered_tokens.is_empty():
			return
		
		# Check if clicking on UI (this is _unhandled, so UI should have consumed it if hit)
		# But wait, unhandled input means nothing handled it.
		# If we click background, this fires.
		if AudioManager:
			AudioManager.play_sfx("table_click")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_debug_print_under_mouse()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_clear_selection()
				selecting = true
				var tabletop = get_tree().root.get_node_or_null("Tabletop")
				if tabletop:
					selection_start_world = tabletop.get_global_mouse_position()
					selection_end_world = selection_start_world
			else:
				if selecting:
					var tabletop = get_tree().root.get_node_or_null("Tabletop")
					if tabletop:
						selection_end_world = tabletop.get_global_mouse_position()
					_finalize_selection()
					selecting = false
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if selecting:
				return
			var top = get_top_token_at_mouse()
			if top == null or not _is_selected(top):
				_clear_selection()
	elif event is InputEventMouseMotion:
		if selecting:
			var tabletop = get_tree().root.get_node_or_null("Tabletop")
			if tabletop:
				selection_end_world = tabletop.get_global_mouse_position()

func get_top_token_at_mouse() -> Token:
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop:
		return null
	var world_pos = tabletop.get_global_mouse_position()
	return get_top_token_at_world_pos(tabletop, world_pos)

func get_top_token_at_world_pos(tabletop: Node, world_pos: Vector2) -> Token:
	if tabletop == null:
		return null
	var space_state: PhysicsDirectSpaceState2D = tabletop.get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF
	var hits = space_state.intersect_point(params, 64)
	if hits.is_empty():
		return null
	var best: Token = null
	for h in hits:
		var collider = h.get("collider")
		if collider == null or not is_instance_valid(collider):
			continue
		if not (collider is Token):
			continue
		if collider.input_pickable == false:
			continue
		if best == null:
			best = collider
			continue
		if collider.z_index > best.z_index:
			best = collider
		elif collider.z_index == best.z_index and collider.get_index() > best.get_index():
			best = collider
	return best

func _process(_delta: float) -> void:
	if dragging_token:
		if not is_instance_valid(dragging_token):
			dragging_token = null
		elif not dragging_token.dragging:
			dragging_token = null
	_update_group_drag()

func get_selection_rect_world() -> Rect2:
	if not selecting:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var p0 = selection_start_world
	var p1 = selection_end_world
	var pos = Vector2(min(p0.x, p1.x), min(p0.y, p1.y))
	var size = Vector2(abs(p1.x - p0.x), abs(p1.y - p0.y))
	return Rect2(pos, size)

func _finalize_selection() -> void:
	var rect = get_selection_rect_world()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var candidates = get_tree().get_nodes_in_group("selectables")
	for n in candidates:
		if not (n is Token):
			continue
		var t: Token = n
		if not is_instance_valid(t):
			continue
		if t.input_pickable == false:
			continue
		if t.has_meta("slot_locked") and bool(t.get_meta("slot_locked")):
			continue
		var half = t._get_half_size() if t.has_method("_get_half_size") else Vector2(60, 80)
		var t_rect = Rect2(t.global_position - half, half * 2.0)
		if rect.intersects(t_rect):
			_add_selected(t)

func _add_selected(t: Token) -> void:
	if selected_tokens.has(t):
		return
	_selected_modulate[t] = t.modulate
	t.modulate = Color(1.0, 1.0, 0.65, 1.0)
	selected_tokens.append(t)

func _clear_selection() -> void:
	for t in selected_tokens:
		if is_instance_valid(t) and _selected_modulate.has(t):
			t.modulate = _selected_modulate[t]
	_selected_modulate.clear()
	selected_tokens.clear()
	_group_drag_leader = null
	_group_drag_start_positions.clear()

func _is_selected(t: Token) -> bool:
	return selected_tokens.has(t)

func is_token_selected(t: Token) -> bool:
	return _is_selected(t)

func _update_group_drag() -> void:
	if _last_dragging_token != dragging_token:
		_last_dragging_token = dragging_token
		_group_drag_leader = null
		_group_drag_start_positions.clear()
		if dragging_token and is_instance_valid(dragging_token) and _is_selected(dragging_token):
			_group_drag_leader = dragging_token
			_group_drag_leader_start = dragging_token.global_position
			for t in selected_tokens:
				if is_instance_valid(t):
					_group_drag_start_positions[t] = t.global_position
	if _group_drag_leader == null:
		return
	if not is_instance_valid(_group_drag_leader) or not _group_drag_leader.dragging:
		_group_drag_leader = null
		_group_drag_start_positions.clear()
		return
	var delta = _group_drag_leader.global_position - _group_drag_leader_start
	for t in _group_drag_start_positions.keys():
		if t == _group_drag_leader:
			continue
		if not is_instance_valid(t):
			continue
		if t.has_meta("slot_locked") and bool(t.get_meta("slot_locked")):
			continue
		t.global_position = _group_drag_start_positions[t] + delta
		if t.has_method("_clamp_to_table_bounds"):
			t._clamp_to_table_bounds()

func schedule_post_drop_resolution(token: Token) -> void:
	_post_drop_resolution(token)

func _post_drop_resolution(token: Token) -> void:
	await get_tree().create_timer(0.12).timeout
	if token == null or not is_instance_valid(token):
		return
	if token.has_meta("slot_locked") and bool(token.get_meta("slot_locked")):
		return
	if token.dragging:
		return
	if token is Card:
		var card: Card = token
		if card.data and card.data.stackable and _try_merge_into_stack(card):
			return
		if card.overlap_enabled:
			resolve_card_overlaps(card)
			resolve_card_verb_overlaps(card)
	elif token is Verb:
		var verb: Verb = token
		# Verbs use overlap resolution instead of stacking
		if verb.overlap_enabled:
			resolve_verb_overlaps(verb)
			resolve_card_verb_overlaps(verb)

func resolve_verb_overlaps(verb: Verb) -> void:
	if verb == null or not is_instance_valid(verb):
		return
	if verb.dragging:
		return
	if verb.overlap_enabled == false:
		return
		
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var bounds_node = tabletop.get_node_or_null("TableBounds")
	var bounds = bounds_node if (bounds_node != null and bounds_node.has_method("clamp_point_to_card_bounds")) else null
	
	# Use standard size for Verbs
	var verb_size = Vector2(120, 120) # Approx size of verb token
	var verb_core_rect = Rect2(verb.global_position - verb_size * 0.45, verb_size * 0.9)
	
	var max_iters = 8
	for _i in range(max_iters):
		var moved = false
		for v in active_verbs:
			if v == verb or not is_instance_valid(v):
				continue
			if v.dragging:
				continue
			if v.overlap_enabled == false:
				continue
				
			var other_size = Vector2(120, 120)
			var other_core = Rect2(v.global_position - other_size * 0.45, other_size * 0.9)
			
			if not verb_core_rect.intersects(other_core):
				continue
				
			var dir = verb.global_position - v.global_position
			if dir.length_squared() < 0.001:
				dir = Vector2.RIGHT.rotated(randf() * TAU)
			dir = dir.normalized()
			
			var min_push = verb_size.x * 0.1
			verb.global_position += dir * min_push
			
			if bounds:
				# Reuse card bounds logic if applicable, or just clamp to screen
				verb.global_position = bounds.clamp_point_to_card_bounds(verb.global_position, verb_size * 0.5)
				
			moved = true
			verb_core_rect = Rect2(verb.global_position - verb_size * 0.45, verb_size * 0.9)
			
		if not moved:
			break

func resolve_card_verb_overlaps(token: Token) -> void:
	if token == null or not is_instance_valid(token):
		return
	if token.dragging:
		return
	if token.overlap_enabled == false:
		return
	if token.has_meta("slot_locked") and bool(token.get_meta("slot_locked")):
		return
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var bounds_node = tabletop.get_node_or_null("TableBounds")
	var bounds = bounds_node if (bounds_node != null and bounds_node.has_method("clamp_point_to_card_bounds")) else null
	var max_iters = 8
	if token is Card:
		var card: Card = token
		for _i in range(max_iters):
			var moved = false
			var card_core = _get_card_core_rect(card)
			for v in active_verbs:
				if not is_instance_valid(v):
					continue
				if v.dragging:
					continue
				if v.overlap_enabled == false:
					continue
				if not v.visible:
					continue
				var verb_size = Vector2(120, 120)
				var verb_core = Rect2(v.global_position - verb_size * 0.45, verb_size * 0.9)
				if not card_core.intersects(verb_core):
					continue
				var dir = card.global_position - v.global_position
				if dir.length_squared() < 0.001:
					dir = Vector2.RIGHT.rotated(randf() * TAU)
				dir = dir.normalized()
				var min_push = max(6.0, card_core.size.x * 0.08)
				card.global_position += dir * min_push
				if bounds:
					card.global_position = bounds.clamp_point_to_card_bounds(card.global_position, card._get_half_size())
				moved = true
				card_core = _get_card_core_rect(card)
			if not moved:
				break
	elif token is Verb:
		var verb: Verb = token
		if not verb.visible:
			return
		var all_cards = get_tree().get_nodes_in_group("cards")
		var verb_size = Vector2(120, 120)
		for _i in range(max_iters):
			var moved = false
			var verb_core = Rect2(verb.global_position - verb_size * 0.45, verb_size * 0.9)
			for n in all_cards:
				if not (n is Card):
					continue
				var other: Card = n
				if not is_instance_valid(other):
					continue
				if other.dragging:
					continue
				if other.overlap_enabled == false:
					continue
				if other.has_meta("slot_locked") and bool(other.get_meta("slot_locked")):
					continue
				var other_core = _get_card_core_rect(other)
				if not verb_core.intersects(other_core):
					continue
				var dir = verb.global_position - other.global_position
				if dir.length_squared() < 0.001:
					dir = Vector2.RIGHT.rotated(randf() * TAU)
				dir = dir.normalized()
				var min_push = max(6.0, verb_size.x * 0.08)
				verb.global_position += dir * min_push
				if bounds:
					verb.global_position = bounds.clamp_point_to_card_bounds(verb.global_position, verb_size * 0.5)
				moved = true
			if not moved:
				break

func _try_merge_into_stack(card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	if card.data == null or not card.data.stackable:
		return false
	if card.has_meta("slot_locked") and bool(card.get_meta("slot_locked")):
		return false
	var best: Card = null
	var best_dist := INF
	var core = _get_card_core_rect(card)
	for n in get_tree().get_nodes_in_group("cards"):
		if n == card or not (n is Card):
			continue
		var other: Card = n
		if not is_instance_valid(other):
			continue
		if other.dragging:
			continue
		if other.has_meta("slot_locked") and bool(other.get_meta("slot_locked")):
			continue
		if other.data == null or other.data.id != card.data.id or not other.data.stackable:
			continue
		if not core.intersects(_get_card_core_rect(other)):
			continue
		var d = card.global_position.distance_squared_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	if best == null:
		return false
	if best.has_method("add_to_stack"):
		best.add_to_stack(card.get_stack_count() if card.has_method("get_stack_count") else 1)
	_remove_from_selection(card)
	card.queue_free()
	return true

func _remove_from_selection(t: Token) -> void:
	if not selected_tokens.has(t):
		return
	selected_tokens.erase(t)
	if is_instance_valid(t) and _selected_modulate.has(t):
		t.modulate = _selected_modulate[t]
	_selected_modulate.erase(t)

func resolve_card_overlaps(card: Card) -> void:
	if card == null or not is_instance_valid(card):
		return
	if card.dragging:
		return
	if card.overlap_enabled == false:
		return
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop == null:
		return
	var bounds_node = tabletop.get_node_or_null("TableBounds")
	var bounds = bounds_node if (bounds_node != null and bounds_node.has_method("clamp_point_to_card_bounds")) else null
	var all_cards = get_tree().get_nodes_in_group("cards")

	var max_iters = 8
	for _i in range(max_iters):
		var moved = false
		var card_core = _get_card_core_rect(card)
		for n in all_cards:
			if n == card:
				continue
			if not (n is Card):
				continue
			var other: Card = n
			if not is_instance_valid(other):
				continue
			if other.dragging:
				continue
			if other.overlap_enabled == false:
				continue
			var other_core = _get_card_core_rect(other)
			if not card_core.intersects(other_core):
				continue
			var dir = card.global_position - other.global_position
			if dir.length_squared() < 0.001:
				dir = Vector2.RIGHT.rotated(randf() * TAU)
			dir = dir.normalized()
			var half = card_core.size * 0.5
			var min_push = half.x * 0.18
			card.global_position += dir * min_push
			if bounds:
				card.global_position = bounds.clamp_point_to_card_bounds(card.global_position, card._get_half_size())
			moved = true
			card_core = _get_card_core_rect(card)
		if not moved:
			break

func _get_card_core_rect(card: Card) -> Rect2:
	var half: Vector2 = card._get_half_size()
	var core_half = half * 0.88
	return Rect2(card.global_position - core_half, core_half * 2.0)

func _has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.name == property_name:
			return true
	return false

func _debug_print_under_mouse() -> void:
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	var viewport_pos = get_viewport().get_mouse_position()
	print("=== Debug Under Mouse (P) ===")
	print("viewport_mouse=", viewport_pos)
	print("dragging_token=", dragging_token if is_instance_valid(dragging_token) else null)
	print("hovered_tokens=", hovered_tokens.size())
	if not hovered_tokens.is_empty():
		var parts: Array[String] = []
		for t in hovered_tokens:
			if is_instance_valid(t):
				parts.append(t.name + "(z=" + str(t.z_index) + ")")
		print("hovered_list=", ", ".join(parts))
	if not tabletop:
		Log.debug("[Debug] Tabletop not found.")
		return
	var world_pos = tabletop.get_global_mouse_position()
	print("world_mouse=", world_pos)
	var top_token = get_top_token_at_world_pos(tabletop, world_pos)
	print("top_token_at_mouse=", top_token.name if is_instance_valid(top_token) else null)

	var space_state: PhysicsDirectSpaceState2D = tabletop.get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF

	var hits = space_state.intersect_point(params, 64)
	if hits.is_empty():
		print("hits=0")
	else:
		print("hits=", hits.size())
		for i in range(hits.size()):
			var h = hits[i]
			var collider = h.get("collider")
			if collider == null:
				continue
			if not is_instance_valid(collider):
				continue
			var z = collider.z_index if collider is CanvasItem else null
			var gp = collider.global_position if (collider is Node2D or collider is Control) else null
			var pickable = collider.input_pickable if collider is CollisionObject2D else null
			var dragging = collider.get("dragging") if _has_property(collider, "dragging") else null
			print("#", i, " name=", collider.name, " type=", collider.get_class(), " z=", z, " global_pos=", gp, " input_pickable=", pickable, " dragging=", dragging, " parent=", collider.get_parent().name if collider.get_parent() else null)

	var panels: Array = []
	for child in tabletop.get_children():
		if child is EventPanel:
			panels.append(child)
	if panels.is_empty():
		print("event_panels=0")
	else:
		print("event_panels=", panels.size())
		for p in panels:
			var rect_hit = p.get_global_rect().has_point(viewport_pos)
			print("panel name=", p.name, " z=", p.z_index, " visible=", p.visible, " mouse_filter=", p.mouse_filter, " rect_hit=", rect_hit)

# Active Verbs management
var active_verbs: Array[Verb] = []

# Hovered Tokens management for Top-Card-Only interaction
var hovered_tokens: Array[Token] = []

func add_hovered_token(token: Token) -> void:
	if not hovered_tokens.has(token):
		hovered_tokens.append(token)
		_sort_hovered_tokens()

func remove_hovered_token(token: Token) -> void:
	if hovered_tokens.has(token):
		hovered_tokens.erase(token)

func get_top_hovered_token() -> Token:
	# Filter out invalid instances first
	hovered_tokens = hovered_tokens.filter(func(token): return is_instance_valid(token))
	
	if hovered_tokens.is_empty():
		return null
	return hovered_tokens.back() # Last one is on top (sorted by z-index/tree order)

func _sort_hovered_tokens() -> void:
	# Filter out invalid instances first
	hovered_tokens = hovered_tokens.filter(func(token): return is_instance_valid(token))
	
	# Sort by z_index first, then by tree order (implicit in array append for same parent)
	# Assuming higher z_index is on top.
	hovered_tokens.sort_custom(func(a, b):
		if a.z_index != b.z_index:
			return a.z_index < b.z_index
		else:
			# If z_index is same, use get_index() relative to siblings if possible,
			# or just rely on append order which roughly correlates to tree order for siblings.
			return a.get_index() < b.get_index()
	)

func register_verb(verb: Verb) -> void:
	if not active_verbs.has(verb):
		active_verbs.append(verb)
		print("[GameManager] Registered verb: ", verb.name)

func unregister_verb(verb: Verb) -> void:
	if active_verbs.has(verb):
		active_verbs.erase(verb)
		print("[GameManager] Unregistered verb: ", verb.name)

func spawn_verb(verb_id: String) -> Verb:
	# Load VerbData from Cache
	var verb_data = verb_db.get(verb_id)
	
	if not verb_data:
		# Fallback to old path logic just in case, or warn
		var data_path = "res://data/Verbs/" + verb_id + ".tres"
		if ResourceLoader.exists(data_path):
			verb_data = load(data_path)
			
	if not verb_data:
		print("[Error] VerbData not found for ID: ", verb_id)
		return null
		
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if not tabletop: return null
	
	var verb_scene = load("res://scenes/Verb.tscn")
	var verb = verb_scene.instantiate()
	tabletop.add_child(verb)
	verb.setup(verb_data)
	
	# Position in a free spot or near center
	verb.position = Vector2(400, 300) + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	print("[GameManager] Spawned verb: ", verb_id)
	return verb

func delete_verb(verb_id: String) -> void:
	# Find verb with matching ID
	# Note: There could be multiple instances of the same verb ID. 
	# This simple implementation deletes the first match.
	for verb in active_verbs:
		if verb.id == verb_id:
			verb.queue_free()
			print("[GameManager] Deleted verb: ", verb_id)
			return
	print("[Warning] Verb not found for deletion: ", verb_id)

func delete_specific_verb(verb: Verb) -> void:
	if is_instance_valid(verb):
		verb.queue_free()
		print("[GameManager] Deleted specific verb: ", verb.name)
