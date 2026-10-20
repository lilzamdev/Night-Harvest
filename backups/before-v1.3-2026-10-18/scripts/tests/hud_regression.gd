extends SceneTree

## Run with --path . --script res://scripts/tests/hud_regression.gd.
## Add --headless for assertions only. Rendered runs save screenshots in .godot/.
const PANELS := ["TopLeft", "MidLeft", "TopCenter", "TopRight", "BottomRight", "BottomCenter/Hotbar/Container"]
var failures := 0
var hud: Control
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("HUD REGRESSION: " + message)

func settle(seconds: float = 0.55) -> void:
	await create_timer(seconds).timeout
	await process_frame
	await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud-" + label + ".png")

func panel_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for path in PANELS:
		result.append(hud.get_global_transform().affine_inverse() * hud.get_node(path).get_global_rect())
	return result

func assert_layout(label: String) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, hud.size)
	var rects := panel_rects()
	for i in range(rects.size()):
		check(viewport_rect.encloses(rects[i]), label + ": " + PANELS[i] + " stays inside viewport")
		for j in range(i + 1, rects.size()):
			check(not rects[i].intersects(rects[j]), label + ": panels do not overlap " + str(i) + "/" + str(j))
	check(hud.hp_bar.size == hud.hunger_bar.size, label + ": HP and Hunger bars have equal dimensions")
	var first_slot: Vector2 = hud.hotbar.slot_containers[0].size
	for slot in hud.hotbar.slot_containers:
		check(slot.size == first_slot, label + ": equal hotbar slots")
	var first_progress: Label = hud.get_node("MidLeft/QuestTracker/Margin/VBox/Quest1/Progress")
	for i in range(2, 4):
		var progress: Label = hud.get_node("MidLeft/QuestTracker/Margin/VBox/Quest%d/Progress" % i)
		check(is_equal_approx(progress.global_position.x, first_progress.global_position.x), label + ": quest counters align")

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await settle(0.1)
	hud = game.get_node("UI/HUD")
	var ken = get_first_node_in_group("player")
	var stats = get_first_node_in_group("player_stats")
	var clock = get_first_node_in_group("game_clock")
	var inventory = game.get_node("UI/Inventory")
	var quests = get_first_node_in_group("quest_manager")
	clock.GAME_MINUTES_PER_REAL_SECOND = 0.0
	ken.global_position = Vector2(58, -142)
	ken.camera.position_smoothing_enabled = false
	check(get_nodes_in_group("hud_ui").size() == 1, "One existing HUD")
	check(hud.minimap.target == ken, "Minimap follows actual player")
	check(hud.minimap.sub_viewport.world_2d == root.world_2d, "Minimap still renders the game world")
	var original_rects := panel_rects()
	stats.take_damage(15)
	check(hud.hp_bar.value == stats.current_health, "Damage signal updates HP")
	check(hud.hp_bar.self_modulate != Color.WHITE, "Damage reacts once")
	stats.drain_hunger(40.0)
	var before_hunger: float = hud.hunger_bar.value
	stats.restore_hunger(20.0)
	check(hud.hunger_bar.value == before_hunger and hud.hunger_label.text.contains("80"), "Eating updates text immediately and animates only visual fill")
	stats.add_xp(10)
	check(hud.xp_feedback.text == "+10 EXP", "XP gain feedback works before a level-up")
	await settle()
	check(hud.hunger_bar.value == 80.0 and hud.xp_bar.value == 10.0, "Hunger and EXP tweens reach authoritative values")
	check(hud.hp_bar.self_modulate == Color.WHITE, "Damage reaction settles")
	await capture("gain-feedback")
	stats.add_xp(95)
	check(stats.level == 2 and stats.xp == 5 and stats.xp_to_next_level == 120, "Existing EXP formula unchanged")
	check(hud.xp_feedback.text == "LEVEL UP!", "Level-up has reserved gold feedback")
	await capture("level-up")
	await settle(1.5)
	check(hud.xp_feedback.text == "+95 EXP", "Level-up preserves accompanying XP gain feedback")
	check(hud.xp_bar.value == 5.0 and hud.xp_bar.max_value == 120.0, "EXP resets and fills correctly after level-up")
	stats.add_gold(1250)
	var db = load("res://scripts/item_database.gd")
	inventory.add_item(db.get_item("wood_log"), 12)
	check(hud._last_resources == [1250, 12, 0], "Gold and inventory resource signals reach HUD")
	check(hud.wood_label.self_modulate != Color.WHITE and hud.stone_label.self_modulate == Color.WHITE, "Only gained resources react")
	inventory.add_item(db.get_item("stone_rock"), 8)
	await settle()
	check(hud._last_resources == [1250, 12, 8], "Stone count updates")
	check(hud.gold_label.tooltip_text.contains("1,250"), "Compact totals retain exact tooltip")
	# Drive the actual quest manager, including its completion/reward path.
	var quest = quests.active_quests[0]
	quests._on_event(quest.event_type, quest.filter_id)
	var progress: Label = hud.get_node("MidLeft/QuestTracker/Margin/VBox/Quest1/Progress")
	check(progress.text == "1/%d" % quest.target_count, "Quest event updates aligned progress")
	check(progress.self_modulate != Color.WHITE, "Changed quest progress reacts")
	for i in range(quest.target_count - 1):
		quests._on_event(quest.event_type, quest.filter_id)
	var title: Label = hud.get_node("MidLeft/QuestTracker/Margin/VBox/Quest1/Title")
	check(quest.is_completed and title.text.begins_with("✓"), "Completed quest displays a checkmark")
	await press_key(KEY_2)
	check(hud.hotbar.selected_slot == 1 and ken.current_held_item == hud.hotbar.get_selected_item(), "Hotbar keyboard selection and equipment remain connected")
	check(hud.hotbar.slot_containers[1].get_node("Highlight").visible, "Selected slot remains highlighted")
	await press_key(KEY_3)
	await settle(0.25)
	for slot in hud.hotbar.slot_containers:
		check(slot.get_node("Icon").scale == Vector2.ONE, "Rapid hotbar selection leaves no scaled icon")
	hud.hotbar.inventory_button.pressed.emit()
	check(inventory.is_open, "Inventory button opens existing inventory")
	await press_key(KEY_F)
	check(not inventory.is_open, "F closes inventory")
	await press_key(KEY_M)
	check(game.get_node("UI/FullMap").is_open, "Map shortcut opens existing map")
	await press_key(KEY_M)
	check(not game.get_node("UI/FullMap").is_open, "Map shortcut closes map")
	for entry in [["05:00", 0], ["04:59", 1], ["01:59", 2], ["00:59", 3], ["00:29", 4]]:
		hud.set_nightfall_warning(entry[0])
		check(hud._night_stage == entry[1], "Night urgency threshold " + entry[0])
	await settle()
	await capture("urgent")
	hud.set_nightfall_status("ARRIVED")
	await settle()
	check(hud.nightfall_timer_label.text.is_empty(), "Night arrival retains existing status behavior")
	check(panel_rects() == original_rects, "All action feedback and empty night timer preserve layout")
	clock.advance_to_time(6, 0)
	check(hud.day_label.text == "DAY 2", "GameClock new day still updates HUD")
	check(hud.day_label.self_modulate != Color.WHITE, "New day reacts once")
	await settle(1.8)
	for resolution in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		if DisplayServer.get_name() == "headless":
			root.size = resolution
		else:
			DisplayServer.window_set_size(resolution)
		await settle(0.15)
		var label := "%dx%d" % [resolution.x, resolution.y]
		assert_layout(label)
		await capture(label)
	print("HUD REGRESSION COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
