extends Node2D

const ItemDatabaseClass = preload("res://scripts/item_database.gd")


func _ready() -> void:
	call_deferred("_setup_gameplay_items")
	call_deferred("_setup_player_systems")
	call_deferred("_begin_save_session")


## Hands the scene to SaveManager: restores a loaded save and starts autosaving.
func _begin_save_session() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.begin_session(self)


## "full" (default) or "basic", chosen on the New Game screen.
func _starter_kit() -> String:
	if has_node("/root/SaveManager"):
		return SaveManager.starter_kit()
	return "full"


func _setup_gameplay_items() -> void:
	_give_initial_tools()
	_populate_starter_chest()
	_spawn_bed()
	
	# Explicit sync for first frame
	var hotbar = get_node_or_null("UI/HUD/BottomCenter/Hotbar")
	var ken = get_node_or_null("CharacterBody2D3")
	if hotbar and ken:
		hotbar.call("_update_slot_visuals")
		ken.call("_on_hotbar_slot_selected", hotbar.get("selected_slot"), hotbar.call("get_selected_item"))


func _give_initial_tools() -> void:
	var inv: Control = get_node_or_null("UI/Inventory")
	if inv and inv.has_method("add_item"):
		var sword = ItemDatabaseClass.get_item("iron_sword")
		var axe = ItemDatabaseClass.get_item("wood_axe")
		var can = ItemDatabaseClass.get_item("watering_can")
		var pick = ItemDatabaseClass.get_item("pickaxe")
		var hoe = ItemDatabaseClass.get_item("hoe")
		
		if sword: inv.call("add_item", sword, 1)
		if axe: inv.call("add_item", axe, 1)
		if can: inv.call("add_item", can, 1)
		if pick: inv.call("add_item", pick, 1)
		if hoe: inv.call("add_item", hoe, 1)
		
		# Basic starter kit: tools plus a handful of carrot seeds only
		if _starter_kit() == "basic":
			var basic_seed = ItemDatabaseClass.get_item("carrot_seed")
			if basic_seed:
				inv.call("add_item", basic_seed, 5)
			return
		
		# All independent harvested crops
		var crop_ids := ["carrot", "wheat", "watermelon", "corn", "potato", "tomato"]
		for cid in crop_ids:
			var crop_res = ItemDatabaseClass.get_item(cid)
			if crop_res:
				inv.call("add_item", crop_res, 5)
		
		# All independent crop seeds
		var seed_ids := ["carrot_seed", "wheat_seed", "watermelon_seed", "corn_seed", "potato_seed", "tomato_seed"]
		for sid in seed_ids:
			var seed_res = ItemDatabaseClass.get_item(sid)
			if seed_res:
				inv.call("add_item", seed_res, 5)



func _populate_starter_chest() -> void:
	var chest: Node = get_node_or_null("Chest")
	if chest and chest.has_method("add_item"):
		if _starter_kit() == "basic":
			return
		var wood = ItemDatabaseClass.get_item("wood_log")
		var stone = ItemDatabaseClass.get_item("stone_rock")
		var carrot_seed = ItemDatabaseClass.get_item("carrot_seed")
		
		if wood: chest.call("add_item", wood, 8)
		if stone: chest.call("add_item", stone, 5)
		if carrot_seed: chest.call("add_item", carrot_seed, 4)


func _spawn_bed() -> void:
	# 1. Regular non-sleep furniture stool at (70, -138)
	if not has_node("Stool"):
		var stool_scene = preload("res://Scenes/Objects/Stool.tscn")
		var stool = stool_scene.instantiate()
		stool.name = "Stool"
		stool.position = Vector2(70, -138)
		add_child(stool)
	
	# 2. Real Red Bed at (30, -182)
	if has_node("Bed") or not get_tree().get_nodes_in_group("beds").is_empty():
		return
	var bed_scene = preload("res://Scenes/Objects/Bed.tscn")
	var bed = bed_scene.instantiate()
	bed.name = "Bed"
	bed.position = Vector2(30, -182)
	add_child(bed)


func _setup_player_systems() -> void:
	# --- PlayerStats ---
	var stats_script = preload("res://scripts/player_stats.gd")
	var stats: Node = stats_script.new()
	stats.name = "PlayerStats"
	add_child(stats)
	
	# --- DeathScreen ---
	var death_script = preload("res://scripts/death_screen.gd")
	var death_screen: CanvasLayer = death_script.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	
	# Wire death signal
	stats.player_died.connect(death_screen.show_death_screen)
	
	# --- Wire HUD ---
	var hud = get_node_or_null("UI/HUD")
	if hud:
		stats.health_changed.connect(hud.set_hp)
		# Defense display replaced by Hunger on HUD (Phase 6)
		# stats.defense_changed.connect(hud.set_defense)  # Kept for Phase 9
		stats.hunger_changed.connect(hud.set_hunger)
		stats.level_changed.connect(func(lvl: int):
			hud.set_level_xp(lvl, stats.xp, stats.xp_to_next_level)
			GameAudio.play("level_up")
		)
		stats.xp_changed.connect(func(current: int, maximum: int):
			hud.set_level_xp(stats.level, current, maximum)
		)
		stats.xp_gained.connect(hud.notify_xp_gain)
		stats.xp_gained.connect(func(_amount: int): GameAudio.play("xp_gain"))
		stats.gold_changed.connect(func(_total: int): _sync_hud_resources(hud, stats))
		var inventory := get_node_or_null("UI/Inventory")
		if inventory:
			inventory.inventory_changed.connect(func(): _sync_hud_resources(hud, stats))
		_sync_hud_resources(hud, stats)
		# Initial sync
		hud.set_hp(stats.current_health, stats.max_health)
		hud.set_hunger(stats.current_hunger, stats.max_hunger)
		hud.set_level_xp(stats.level, stats.xp, stats.xp_to_next_level)
	
	# --- GameClock ---
	var clock_script = preload("res://scripts/game_clock.gd")
	var clock: Node = clock_script.new()
	clock.name = "GameClock"
	add_child(clock)
	
	# Wire clock to HUD
	if hud:
		clock.time_updated.connect(func(hour: int, minute: int):
			hud.set_calendar(clock.current_day, clock.get_time_string())
			if clock.is_night():
				hud.set_nightfall_status("ARRIVED")
			else:
				hud.set_nightfall_warning(clock.get_nightfall_countdown())
				# Zombie warning: 1 game-minute (≤60 remaining) before official night
				var countdown_str: String = clock.get_nightfall_countdown()
				var parts := countdown_str.split(":")
				if parts.size() == 2:
					var remaining := int(parts[0]) * 60 + int(parts[1])
					if remaining > 0 and remaining <= 60:
						hud.show_zombie_warning()
		)
		clock.day_changed.connect(func(new_day: int):
			hud.set_calendar(new_day, clock.get_time_string())
		)
		clock.night_started.connect(func():
			hud.set_nightfall_status("ARRIVED")
			hud.show_zombie_arrival()
		)
		clock.night_ended.connect(func():
			hud.set_nightfall_warning(clock.get_nightfall_countdown())
			hud.reset_zombie_warnings()
		)
		# Initial sync
		hud.set_calendar(clock.current_day, clock.get_time_string())
		hud.set_nightfall_warning(clock.get_nightfall_countdown())
	
	# --- Hunger drain is now self-contained in PlayerStats._process() ---
	# (Real-time timer: 1 hunger point every 75 seconds, configurable)
	
	# --- EventBus ---
	var bus_script = preload("res://scripts/event_bus.gd")
	var event_bus: Node = bus_script.new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	
	# --- QuestManager ---
	var qm_script = preload("res://scripts/quest_manager.gd")
	var quest_mgr: Node = qm_script.new()
	quest_mgr.name = "QuestManager"
	add_child(quest_mgr)
	
	# Wire quest UI updates to HUD
	if hud:
		quest_mgr.quest_progress_updated.connect(func(_qid: String, _cur: int, _tgt: int):
			_update_quest_hud(hud, quest_mgr)
		)
		quest_mgr.quest_completed.connect(func(_qid: String):
			_update_quest_hud(hud, quest_mgr)
			GameAudio.play("quest_complete")
		)
		quest_mgr.daily_quests_refreshed.connect(func():
			_update_quest_hud(hud, quest_mgr)
		)
	
	# Refresh quests on new day
	clock.day_changed.connect(func(_day: int):
		quest_mgr.refresh_daily_quests()
	)
	
	# --- EnvironmentManager ---
	var env_script = preload("res://scripts/environment_manager.gd")
	var env_mgr: Node = env_script.new()
	env_mgr.name = "EnvironmentManager"
	add_child(env_mgr)
	
	# --- SpawnManager ---
	var spawn_mgr = get_node_or_null("SpawnManager")
	if not spawn_mgr:
		var spawn_scene = preload("res://Scenes/SpawnManager.tscn")
		spawn_mgr = spawn_scene.instantiate()
		add_child(spawn_mgr)
	# Scene-placed managers become ready before this deferred clock setup.
	# Bind every map spawner now that the clock exists.
	for manager in get_tree().get_nodes_in_group("spawn_manager"):
		if is_ancestor_of(manager):
			manager.bind_game_clock(clock)
	
	# --- FarmingManager ---
	var farming_script = preload("res://scripts/farming/FarmingManager.gd")
	var farming_mgr: Node2D = farming_script.new()
	farming_mgr.name = "FarmingManager"
	add_child(farming_mgr)


func _update_quest_hud(hud: Control, quest_mgr: Node) -> void:
	hud.set_quests(quest_mgr.active_quests)


func _sync_hud_resources(hud: Control, stats: Node) -> void:
	var inventory := get_node_or_null("UI/Inventory")
	var wood := 0
	var stone := 0
	if inventory:
		for slot in inventory.slots + inventory.hotbar_slots:
			var item: Resource = slot.get("item")
			if not item:
				continue
			match item.get("item_id"):
				"wood_log": wood += int(slot.get("amount", 0))
				"stone_rock": stone += int(slot.get("amount", 0))
	hud.set_resources(stats.gold, wood, stone)
