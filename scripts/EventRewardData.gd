class_name EventRewardData
extends Resource

enum RewardType { FIXED, RANDOM }

@export var type: RewardType = RewardType.FIXED
@export var card_ids: Array[String] = [] # For FIXED
@export var pool_tag: String = "" # For RANDOM (e.g., "common_loot")
@export var count: int = 1

## Verb Manipulation
@export var verb_ids_to_spawn: Array[String] = []
@export var verb_ids_to_delete: Array[String] = []
@export var delete_source_verb: bool = false

@export var ending_index: int = -1

## Card Transformations (for pending 'reward' slot cards)
@export var transformations: Array[CardTransformation] = []
