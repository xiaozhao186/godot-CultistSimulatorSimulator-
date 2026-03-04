extends Panel

@onready var title: Label = $Title
@onready var desc: RichTextLabel = $Desc
@onready var icon: TextureRect = $Icon
@onready var close_button: Button = $CloseButton
@onready var attributes_container: HBoxContainer = $AttributesContainer

# Attribute Icon Configuration
const IconMappingScript = preload("res://scripts/IconMapping.gd")

# Cache for loaded textures to avoid repeated loading
var _icon_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.token_clicked.connect(_on_token_clicked)
	if close_button:
		close_button.pressed.connect(func(): 
			visible = false
			if AudioManager:
				AudioManager.play_sfx("panel_close")
		)

func _on_token_clicked(token):
	visible = true
	if AudioManager:
		# Only play sound if it's NOT a verb (since Verb handles its own open sound via EventPanel)
		if not (token is Verb):
			AudioManager.play_sfx("panel_open")
		
	# Ensure we bring to front if needed, though CanvasLayer order usually handles this.
	# But if SettingsPanel is also in the same CanvasLayer (or just above), we don't want to hide it.
	# SettingsPanel is Z=100 in Tabletop.tscn, DetailsPanel is default (0).
	# However, if DetailsPanel is "move_to_front" it changes index in parent?
	# Both are in CanvasLayer.
	# move_to_front() on a CanvasItem changes its draw order (index in parent).
	# If SettingsPanel is a sibling, move_to_front might put DetailsPanel ABOVE SettingsPanel if they are siblings.
	# Let's remove move_to_front() or ensure SettingsPanel stays on top.
	# Ideally, DetailsPanel should not cover SettingsPanel.
	# If SettingsPanel has Z-Index 100, it *should* be on top regardless of tree order?
	# CanvasLayer children: Z-index is relative to CanvasLayer?
	# Control nodes use tree order for drawing, Z-index affects input?
	# Actually, for Control nodes, tree order usually dictates input handling unless Z-index is used.
	# But mixing Z-index in Controls can be tricky.
	# Let's try removing move_to_front() first, as Z=100 on SettingsPanel should handle it.
	# move_to_front() might be fighting with Z-index or just irrelevant.
	# move_to_front()
	
	# Clear previous attributes
	for child in attributes_container.get_children():
		child.queue_free()
	
	if token is Card:
		title.text = token.data.name
		desc.text = token.data.description
		icon.texture = token.data.icon
		
		_populate_attributes(token.data.tags, token.data.attributes)
		
	elif token is Verb:
		title.text = token.event_data.title
		desc.text = token.event_data.description
		if token.event_data.image:
			icon.texture = token.event_data.image
		
		# Verbs usually don't have attributes/tags in current design, 
		# but if they do in future, we can populate them here.

func _populate_attributes(tags: Array[String], attributes: Dictionary) -> void:
	# Add Tags
	for tag in tags:
		_create_attribute_icon(tag, "", "Tag: " + tag)
		
	# Add Attributes
	for key in attributes:
		var value = attributes[key]
		var k = String(key)
		_create_attribute_icon(k, str(value), k.capitalize() + ": " + str(value))

func _create_attribute_icon(key: String, value_text: String, tooltip: String) -> void:
	var container = HBoxContainer.new()
	container.tooltip_text = tooltip
	
	var icon_rect = TextureRect.new()
	icon_rect.texture = _get_icon_for_attribute(key)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(30, 30)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(icon_rect)
	
	if value_text != "":
		var label = Label.new()
		label.text = value_text
		label.add_theme_color_override("font_color", Color.BLACK)
		container.add_child(label)
		
	attributes_container.add_child(container)

func _get_icon_for_attribute(key: String) -> Texture2D:
	var lower_key = key.to_lower()
	
	# Check cache first
	if _icon_cache.has(lower_key):
		return _icon_cache[lower_key]
	
	var path = IconMappingScript.DEFAULT_ICON_PATH
	if IconMappingScript.ICON_MAP.has(lower_key):
		path = IconMappingScript.ICON_MAP[lower_key]
	
	# Load and cache
	var texture = null
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		if path != IconMappingScript.DEFAULT_ICON_PATH:
			push_warning("Attribute icon not found: " + path + " (for attribute '" + key + "'). Using default.")
		
		# Fallback to default if specific failed
		if ResourceLoader.exists(IconMappingScript.DEFAULT_ICON_PATH):
			texture = load(IconMappingScript.DEFAULT_ICON_PATH)
		else:
			push_error("Default attribute icon missing: " + IconMappingScript.DEFAULT_ICON_PATH)
			return null # Or return a placeholder GradientTexture
			
	_icon_cache[lower_key] = texture
	return texture
