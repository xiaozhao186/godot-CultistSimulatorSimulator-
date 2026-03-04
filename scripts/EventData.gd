class_name EventData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var image: Texture2D
@export var slots: Array[EventSlotData] = []
@export var duration: float = 10.0
@export var auto_start: bool = false # If true, event starts immediately upon transition
@export var auto_collect: bool = false # If true, automatically collects all items when event finishes

## Branches checked immediately upon card insertion (Configuring State).
## Used for "Recipe Preview" - changing the UI/Slots instantly.
@export var instant_branches: Array[EventBranchData] = []

@export var branches: Array[EventBranchData] = []
@export var rewards: Array[EventRewardData] = []
@export var default_next_event: EventData
