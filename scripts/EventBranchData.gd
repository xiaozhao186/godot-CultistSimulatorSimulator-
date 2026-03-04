class_name EventBranchData
extends Resource

@export var outcomes: Array[EventOutcome] = []

## Conditions Configuration
# Array of EventCondition resources determining if this branch should be taken.
# If array is empty, the branch is considered "Always True" (useful for default/fallback paths).
#
# Use the Inspector to add conditions. 
# Select "type" to see relevant fields:
# - HAS_TAG: Checks if ANY card has the specific tag.
# - SUM: Checks if sum of a specific attribute across all cards meets the value.
# - COUNT: Checks if count of cards with a specific tag meets the value.
@export var conditions: Array[EventCondition] = []

# Evaluate this branch against the current card stats
func evaluate(
	total_stats: Dictionary,
	tag_counts: Dictionary,
	present_tags: Dictionary,
	table_total_stats: Dictionary = {},
	table_tag_counts: Dictionary = {},
	table_present_tags: Dictionary = {},
	table_card_id_counts: Dictionary = {}
) -> bool:
	# If no conditions, it's a default path -> True
	if conditions.is_empty():
		return true
		
	for cond in conditions:
		if not cond: continue # Skip empty slots
		if not _check_condition(cond, total_stats, tag_counts, present_tags, table_total_stats, table_tag_counts, table_present_tags, table_card_id_counts):
			return false
			
	return true

func get_random_target() -> EventData:
	if outcomes.is_empty():
		return null # No outcomes defined
	
	if outcomes.size() == 1:
		return outcomes[0].target_event
		
	# Weighted random selection
	var total_weight = 0.0
	for outcome in outcomes:
		total_weight += outcome.probability
		
	var r = randf_range(0.0, total_weight)
	var current_weight = 0.0
	
	for outcome in outcomes:
		current_weight += outcome.probability
		if r <= current_weight:
			return outcome.target_event
			
	return outcomes.back().target_event # Should not happen, but safe fallback

func _check_condition(
	cond: EventCondition,
	total_stats: Dictionary,
	tag_counts: Dictionary,
	present_tags: Dictionary,
	table_total_stats: Dictionary,
	table_tag_counts: Dictionary,
	table_present_tags: Dictionary,
	table_card_id_counts: Dictionary
) -> bool:
	match cond.type:
		EventCondition.Type.HAS_TAG:
			return present_tags.has(cond.tag)
			
		EventCondition.Type.SUM:
			var current = total_stats.get(cond.attribute, 0)
			return _compare(current, cond.value, cond.op)
			
		EventCondition.Type.COUNT:
			var current = tag_counts.get(cond.tag, 0)
			return _compare(current, cond.value, cond.op)
			
		EventCondition.Type.TABLE_HAS_TAG:
			return table_present_tags.has(cond.tag)
			
		EventCondition.Type.TABLE_SUM:
			var current = table_total_stats.get(cond.attribute, 0)
			return _compare(current, cond.value, cond.op)
			
		EventCondition.Type.TABLE_COUNT:
			var current = table_tag_counts.get(cond.tag, 0)
			return _compare(current, cond.value, cond.op)
			
		EventCondition.Type.TABLE_HAS_CARD_ID:
			return table_card_id_counts.has(cond.card_id)
			
		EventCondition.Type.TABLE_COUNT_CARD_ID:
			var current = table_card_id_counts.get(cond.card_id, 0)
			return _compare(current, cond.value, cond.op)
			
		_:
			push_warning("Unknown condition type: " + str(cond.type))
			return false

func _compare(a, b, op) -> bool:
	match op:
		EventCondition.Op.GTE: return a >= b
		EventCondition.Op.LTE: return a <= b
		EventCondition.Op.GT: return a > b
		EventCondition.Op.LT: return a < b
		EventCondition.Op.EQ: return a == b
		EventCondition.Op.NEQ: return a != b
	return false
