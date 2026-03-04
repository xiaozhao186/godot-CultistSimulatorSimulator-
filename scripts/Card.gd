class_name Card
extends Token

signal timer_expired_in_slot(card)

@export var data: CardData

var current_lifetime: float = -1.0
var stack_count: int = 1
var is_timer_active: bool = true

@onready var background: TextureRect = $Background
@onready var card_image: TextureRect = $CardImage
@onready var label: Label = $Label
@onready var lifetime_bar: TextureProgressBar = $LifetimeBar
@onready var timer_label: Label = $TimerLabel
@onready var stack_badge: TextureRect = $StackBadge
@onready var stack_count_label: Label = $StackBadge/StackCount

func setup(card_data: CardData) -> void:
	data = card_data
	name = "Card_" + data.id
	if card_image and data.icon:
		card_image.texture = data.icon
	if label:
		label.text = data.name
	
	if data.lifetime > 0:
		current_lifetime = data.lifetime
		if lifetime_bar:
			lifetime_bar.max_value = data.lifetime
			lifetime_bar.value = data.lifetime
			lifetime_bar.visible = true
			if timer_label: timer_label.visible = true
	else:
		if lifetime_bar: lifetime_bar.visible = false
		if timer_label: timer_label.visible = false
	_update_stack_badge()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	add_to_group("cards")
	if data:
		setup(data)
	else:
		if lifetime_bar: lifetime_bar.visible = false
		if timer_label: timer_label.visible = false
	_update_stack_badge()

func get_stack_count() -> int:
	return stack_count

func add_to_stack(amount: int) -> void:
	stack_count = max(1, stack_count + amount)
	_update_stack_badge()

func _take_one_from_stack() -> Card:
	if stack_count <= 1:
		return self
	stack_count -= 1
	_update_stack_badge()
	var scene = load("res://scenes/Card.tscn")
	var new_card: Card = scene.instantiate()
	var tabletop = get_tree().root.get_node_or_null("Tabletop")
	if tabletop:
		tabletop.add_child(new_card)
	new_card.setup(data)
	new_card.stack_count = 1
	new_card.global_position = global_position
	new_card.z_index = z_index
	new_card.original_z_index = 0
	new_card._update_stack_badge()
	return new_card

func _update_stack_badge() -> void:
	if stack_badge == null:
		return
	var should_show = stack_count > 1
	stack_badge.visible = should_show
	if should_show and stack_count_label:
		stack_count_label.text = str(stack_count)

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if stack_count > 1 and not GameManager.is_token_selected(self):
			if GameManager.get_top_token_at_mouse() != self:
				return
			var new_card = _take_one_from_stack()
			if new_card != self:
				new_card.begin_drag(event.global_position)
			return
	super._input_event(_viewport, event, _shape_idx)

func _process(delta: float) -> void:
	super._process(delta)
	
	# Only update lifetime if not paused (even if node is set to Process Always)
	if not AppState.is_paused() and is_timer_active:
		if current_lifetime > 0:
			current_lifetime -= delta
			
			if lifetime_bar:
				lifetime_bar.value = current_lifetime
			if timer_label:
				timer_label.text = "%.1f" % current_lifetime
				
			if current_lifetime <= 0:
				if has_meta("in_event_slot") and bool(get_meta("in_event_slot")):
					# Notify holder to release me
					timer_expired_in_slot.emit(self)
					# Do not queue_free yet, wait for release
					return

				if data and data.transform_on_expire and data.transform_card_id != "":
					_transform_card(data.transform_card_id)
				else:
					queue_free()

func force_expire() -> void:
	if data and data.transform_on_expire and data.transform_card_id != "":
		_transform_card(data.transform_card_id)
	else:
		queue_free()

func _transform_card(target_id: String) -> void:
	var target_data = CardDatabase.get_card_data(target_id)
	if target_data:
		var scene = load("res://scenes/Card.tscn")
		var new_card: Card = scene.instantiate()
		
		# Add to the same parent
		get_parent().add_child(new_card)
		
		new_card.setup(target_data)
		new_card.global_position = global_position
		new_card.z_index = z_index
		
		# Transfer stack count if needed? Usually transform happens on single card.
		# If stack > 1, maybe only one transforms?
		# Logic: "Timer expired". Usually implies the whole stack if they share timer?
		# But Card.gd has `stack_count`.
		# If we have a stack, and lifetime expires...
		# Current logic: `queue_free()` destroys the whole stack object.
		# So we should probably spawn a stack of new cards?
		# Or just one new card with same stack count?
		new_card.stack_count = stack_count
		new_card._update_stack_badge()
		
		queue_free()
	else:
		print("[Warning] Transform target card not found: ", target_id)
		queue_free()

