extends RefCounted
class_name QuestData

## Data structure for a single quest objective.
## Supports XP, gold, and optional item rewards.

var quest_id: String = ""
var description: String = ""
var event_type: String = ""       # Signal name on EventBus (e.g., "carrot_planted")
var filter_id: String = ""        # Optional item/crop filter (e.g., "carrot" for crop_harvested)
var target_count: int = 1
var current_count: int = 0
var is_completed: bool = false

# --- Rewards (all optional, 0 means no reward of that type) ---
var xp_reward: int = 0
var gold_reward: int = 0
var item_reward_id: String = ""   # Item ID from ItemDatabase (empty = no item reward)
var item_reward_amount: int = 0


func _init(p_id: String = "", p_desc: String = "", p_event: String = "", p_target: int = 1) -> void:
	quest_id = p_id
	description = p_desc
	event_type = p_event
	target_count = p_target


func increment(amount: int = 1) -> bool:
	if is_completed:
		return false
	current_count = mini(current_count + amount, target_count)
	if current_count >= target_count:
		is_completed = true
		return true  # Just completed
	return false


func get_progress_text() -> String:
	if is_completed:
		return "✓ %s — %d/%d" % [description, current_count, target_count]
	return "□ %s — %d/%d" % [description, current_count, target_count]
