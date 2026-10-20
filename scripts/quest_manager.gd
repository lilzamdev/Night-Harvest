extends Node
class_name QuestManager

## Manages active daily quests, listens to EventBus signals,
## tracks progress in real-time, and grants rewards on completion.

const QuestDataClass = preload("res://scripts/quest_data.gd")
const ItemDatabaseClass = preload("res://scripts/item_database.gd")

signal quest_progress_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String)
signal daily_quests_refreshed()

@export var max_daily_quests: int = 3

var active_quests: Array = []  # Array of QuestData
var _event_bus: Node = null


func _ready() -> void:
	add_to_group("quest_manager")
	call_deferred("_connect_event_bus")
	call_deferred("_generate_daily_quests")


func _connect_event_bus() -> void:
	var bus_nodes := get_tree().get_nodes_in_group("event_bus")
	for node in bus_nodes:
		if is_instance_valid(node):
			_event_bus = node
			break
	
	if not _event_bus:
		return
	
	# Connect all relevant signals
	if _event_bus.has_signal("carrot_planted"):
		_event_bus.carrot_planted.connect(func(): _on_event("carrot_planted", ""))
	if _event_bus.has_signal("crop_watered"):
		_event_bus.crop_watered.connect(func(): _on_event("crop_watered", ""))
	if _event_bus.has_signal("crop_harvested"):
		_event_bus.crop_harvested.connect(func(crop_id: String): _on_event("crop_harvested", crop_id))
	if _event_bus.has_signal("tree_cut"):
		_event_bus.tree_cut.connect(func(): _on_event("tree_cut", ""))
	if _event_bus.has_signal("item_collected"):
		_event_bus.item_collected.connect(func(item_id: String): _on_event("item_collected", item_id))
	if _event_bus.has_signal("zombie_killed"):
		_event_bus.zombie_killed.connect(func(): _on_event("zombie_killed", ""))
	if _event_bus.has_signal("item_crafted"):
		_event_bus.item_crafted.connect(func(item_id: String): _on_event("item_crafted", item_id))
	if _event_bus.has_signal("item_sold"):
		_event_bus.item_sold.connect(func(item_id: String, amount: int): _on_event("item_sold", item_id))


func _on_event(event_type: String, filter_id: String) -> void:
	for quest in active_quests:
		if quest.is_completed:
			continue
		if quest.event_type != event_type:
			continue
		# If quest has a filter, check it matches
		if quest.filter_id != "" and quest.filter_id != filter_id:
			continue
		
		var just_completed: bool = quest.increment(1)
		quest_progress_updated.emit(quest.quest_id, quest.current_count, quest.target_count)
		
		if just_completed:
			quest_completed.emit(quest.quest_id)
			_grant_rewards(quest)


func _grant_rewards(quest: QuestData) -> void:
	var stats_nodes := get_tree().get_nodes_in_group("player_stats")
	var stats: Node = null
	for node in stats_nodes:
		if is_instance_valid(node):
			stats = node
			break
	
	if stats:
		if quest.xp_reward > 0 and stats.has_method("add_xp"):
			stats.add_xp(quest.xp_reward)
		if quest.gold_reward > 0 and stats.has_method("add_gold"):
			stats.add_gold(quest.gold_reward)
	
	# Item reward
	if quest.item_reward_id != "" and quest.item_reward_amount > 0:
		var item_data = ItemDatabaseClass.get_item(quest.item_reward_id)
		if item_data:
			var inv_nodes := get_tree().get_nodes_in_group("inventory_ui")
			for inv in inv_nodes:
				if is_instance_valid(inv) and inv.has_method("add_item"):
					inv.add_item(item_data, quest.item_reward_amount)
					break
	
	print("[QuestManager] Quest completed: %s — Rewards: %dXP, %dG" % [quest.quest_id, quest.xp_reward, quest.gold_reward])


## Generate random daily quests from the template pool.
func _generate_daily_quests() -> void:
	active_quests.clear()
	
	var templates := _get_quest_templates()
	templates.shuffle()
	
	var count := mini(max_daily_quests, templates.size())
	for i in range(count):
		active_quests.append(templates[i])
	
	daily_quests_refreshed.emit()


## Refresh daily quests (called on new day).
func refresh_daily_quests() -> void:
	_generate_daily_quests()


## Quest template pool — add more templates here for variety.
func _get_quest_templates() -> Array:
	var templates: Array = []
	
	# Plant carrots
	var q1 := QuestDataClass.new("plant_carrots", "Plant 17 Carrots", "carrot_planted", 17)
	q1.xp_reward = 50
	q1.gold_reward = 100
	q1.item_reward_id = "carrot_seed"
	q1.item_reward_amount = 5
	templates.append(q1)
	
	# Chop trees
	var q2 := QuestDataClass.new("chop_trees", "Chop 5 Trees", "tree_cut", 5)
	q2.xp_reward = 40
	q2.gold_reward = 75
	templates.append(q2)
	
	# Kill zombies
	var q3 := QuestDataClass.new("kill_zombies", "Kill 10 Zombies", "zombie_killed", 10)
	q3.xp_reward = 80
	q3.gold_reward = 150
	templates.append(q3)
	
	# Water crops
	var q4 := QuestDataClass.new("water_crops", "Water 12 Crops", "crop_watered", 12)
	q4.xp_reward = 30
	q4.gold_reward = 60
	templates.append(q4)
	
	# Collect items
	var q5 := QuestDataClass.new("collect_items", "Collect 8 Items", "item_collected", 8)
	q5.xp_reward = 35
	q5.gold_reward = 50
	templates.append(q5)
	
	return templates
