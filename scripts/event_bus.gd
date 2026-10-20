extends Node
class_name EventBus

## Global event bus for gameplay actions.
## Connects gameplay systems (farming, combat, gathering) to the quest system.
## Any script can emit events here; the QuestManager listens and updates progress.

# --- Farming ---
signal carrot_planted()
signal crop_watered()
signal crop_harvested(crop_id: String)

# --- Gathering ---
signal tree_cut()
signal item_collected(item_id: String)
signal item_sold(item_id: String, amount: int)

# --- Combat ---
signal zombie_killed()

# --- Food (Phase 6) ---
signal food_eaten(food_id: String)

# --- Crafting ---
signal item_crafted(item_id: String)

# --- Generic ---
signal gameplay_event(event_type: String, data: Dictionary)


func _ready() -> void:
	add_to_group("event_bus")
