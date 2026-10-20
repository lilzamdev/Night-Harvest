extends Node

const ItemDataScript = preload("res://scripts/item_data.gd")
const ItemDatabaseScript = preload("res://scripts/item_database.gd")
const WorldItemScript = preload("res://scripts/world_item.gd")
const HotbarScript = preload("res://scripts/hotbar.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const MenuScript = preload("res://scripts/menu.gd")
const KenScript = preload("res://Scenes/ken_idle_front.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const FullMapScript = preload("res://scripts/full_map.gd")
const HUDScript = preload("res://scripts/hud.gd")
const TreeScript = preload("res://scripts/tree.gd")

func _ready() -> void:
	print("--- Running Night Harvest Milestone 1 Full Verification Suite ---")
	test_item_database()
	test_inventory_system()
	test_inventory_slot_swapping()
	test_inventory_to_hotbar_assignment()
	test_hotbar_reactive_to_inventory()
	test_minimap()
	test_full_map()
	test_hud()
	test_menu()
	test_ken()
	test_held_item_system_and_directions()
	test_directional_swings_and_flips()
	test_action_state_locking_and_timing()
	test_deterministic_drop_and_held_clear()
	test_camera_follow_settings()
	test_camera_panning()
	test_tree_cutting_and_wood_harvesting()
	test_pickup_drop_cycle()
	test_universal_item_swing_and_swoosh()
	test_hold_to_swing_repeat_and_release()
	test_rpg_chest_7_and_ui()
	test_game_scene()
	test_health_and_defense_system()
	test_game_clock_and_periods()
	test_event_bus_and_daily_quests()
	test_environment_lighting()
	test_zombie_spawner_and_marker2d()
	test_zombie_ai_and_combat()
	test_4_direction_movement_and_facing()
	test_spawn_manager_scene_and_spawning()
	test_torch_world_item_and_inventory()
	test_bed_and_sleeping_system()
	test_depth_sorting_and_trunk_collisions()
	print("--- ALL NIGHT HARVEST TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)


func test_item_database() -> void:
	print("1. Testing Item Database & Action Types...")
	var wood = ItemDatabaseScript.get_item("wood_log")
	assert(wood != null, "Wood Log item exists")
	assert(wood.display_name == "Wood", "Wood name is correct (renamed in v1.3)")
	assert(wood.icon != null, "Wood Log has icon")
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	assert(axe != null, "Wood Axe exists")
	assert(axe.action_type == ItemDataScript.ActionType.CHOP, "Wood axe has CHOP action type")
	assert(axe.tool_power >= 1, "Wood axe has tool power")
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	assert(sword != null, "Iron Sword exists")
	assert(sword.max_stack == 1, "Iron sword max stack is 1")
	assert(sword.action_type == ItemDataScript.ActionType.ATTACK, "Iron sword has ATTACK action type")
	assert(sword.weapon_damage == 15, "Iron sword damage is 15")
	print("Item Database tests: OK")


func test_inventory_system() -> void:
	print("2. Testing Inventory Stacking & Remainder Math...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	assert(inv_scene != null, "Inventory scene failed to load")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var wood = ItemDatabaseScript.get_item("wood_log")
	var stone = ItemDatabaseScript.get_item("stone_rock")
	
	# Add 10 wood
	var leftover = inv.add_item(wood, 10)
	assert(leftover == 0, "All 10 wood added")
	assert(inv.get_item_at(0)["amount"] == 10, "Slot 0 has 10 wood")
	
	# Add 5 more wood (should stack into slot 0)
	inv.add_item(wood, 5)
	assert(inv.get_item_at(0)["amount"] == 15, "Slot 0 has 15 wood")
	
	# Add stone (should go to slot 1)
	inv.add_item(stone, 3)
	assert(inv.get_item_at(1)["item"].item_id == "stone_rock", "Slot 1 has stone")
	assert(inv.get_item_at(1)["amount"] == 3, "Slot 1 has 3 stone")
	
	# Test direct setters
	inv.set_item_at(5, stone, 2)
	assert(inv.get_item_at(5)["item"].item_id == "stone_rock", "Direct slot 5 set to stone")
	assert(inv.get_item_at(5)["amount"] == 2, "Direct slot 5 amount is 2")
	
	inv.set_hotbar_item_at(2, wood, 7)
	assert(inv.get_hotbar_item_at(2)["item"].item_id == "wood_log", "Hotbar slot 2 set to wood")
	assert(inv.get_hotbar_item_at(2)["amount"] == 7, "Hotbar slot 2 amount is 7")
	
	inv.queue_free()
	print("Inventory tests: OK")


func test_inventory_slot_swapping() -> void:
	print("3. Testing Interactive Inventory Slot Swapping...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	var axe = ItemDatabaseScript.get_item("wood_axe")
	
	inv.add_item(sword, 1) # Slot 0
	inv.add_item(axe, 1)   # Slot 1
	
	assert(inv.get_item_at(0)["item"].item_id == "iron_sword", "Slot 0 has sword")
	assert(inv.get_item_at(1)["item"].item_id == "wood_axe", "Slot 1 has axe")
	
	# Swap slot 0 and slot 1
	inv.swap_slots(0, 1)
	assert(inv.get_item_at(0)["item"].item_id == "wood_axe", "Slot 0 now has axe after swap")
	assert(inv.get_item_at(1)["item"].item_id == "iron_sword", "Slot 1 now has sword after swap")
	
	# Move to a non-hotbar slot (e.g. Slot 5)
	inv.swap_slots(0, 5)
	assert(inv.get_item_at(0)["item"] == null, "Slot 0 is now empty")
	assert(inv.get_item_at(5)["item"].item_id == "wood_axe", "Slot 5 now has axe")
	
	inv.queue_free()
	print("Slot Swapping tests: OK")


func test_inventory_to_hotbar_assignment() -> void:
	print("4. Testing Inventory to Hotbar Assignment & Space Saving...")
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	add_child(inv)
	
	var seed = ItemDatabaseScript.get_item("wheat_seed")
	# Place seed in backpack slot 7
	inv.slots[7] = { "item": seed, "amount": 5 }
	
	# Move from backpack slot 7 to hotbar slot 0
	inv.move_to_hotbar(7, 0)
	assert(inv.get_hotbar_item_at(0)["item"].item_id == "wheat_seed", "Hotbar slot 0 now has wheat seed")
	assert(inv.get_hotbar_item_at(0)["amount"] == 5, "Hotbar slot 0 has 5 wheat seed")
	assert(inv.get_item_at(7)["item"] == null, "Backpack slot 7 is now empty, saving space for other items")
	
	inv.queue_free()
	print("Hotbar Assignment & Space Saving tests: OK")


func test_hotbar_reactive_to_inventory() -> void:
	print("5. Testing Hotbar Reactive Integration...")
	var root = Node2D.new()
	add_child(root)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	root.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar: HotbarUI = hotbar_scene.instantiate()
	root.add_child(hotbar)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	var sword = ItemDatabaseScript.get_item("iron_sword")
	
	inv.add_item(axe, 1)   # Goes to hotbar slot 0
	inv.add_item(sword, 1) # Goes to hotbar slot 1
	
	# Hotbar slot 0 should instantly reflect axe
	hotbar.select_slot(0)
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 0 is wood axe")
	
	# Hotbar slot 1 should instantly reflect sword
	hotbar.select_slot(1)
	assert(hotbar.get_selected_item() == sword, "Hotbar slot 1 is iron sword")
	
	# Swap in hotbar: slot 0 and slot 1
	inv.swap_hotbar_slots(0, 1)
	# Hotbar slot 1 should now instantly be axe
	assert(hotbar.get_selected_item() == axe, "Hotbar slot 1 is now axe after swap")
	
	root.queue_free()
	print("Hotbar Reactive Integration tests: OK")


func test_minimap() -> void:
	print("6. Testing Minimap Foundation...")
	var minimap_scene = load("res://Scenes/UI/minimap.tscn")
	var minimap = minimap_scene.instantiate()
	add_child(minimap)
	
	var dummy = Node2D.new()
	add_child(dummy)
	dummy.position = Vector2(100, 200)
	minimap.set_target(dummy)
	assert(minimap.target == dummy, "Minimap target is dummy")
	
	minimap.queue_free()
	dummy.queue_free()
	print("Minimap tests: OK")


func test_full_map() -> void:
	print("6b. Testing Full Map System & POIs...")
	var full_map_scene = load("res://Scenes/UI/full_map.tscn")
	var full_map: FullMapUI = full_map_scene.instantiate()
	add_child(full_map)
	
	var dummy = Node2D.new()
	add_child(dummy)
	dummy.position = Vector2(50, -50)
	dummy.set("last_direction", Vector2.UP)
	full_map.target = dummy
	
	# 1. Test Open / Close
	assert(full_map.is_open == false, "Full Map initially closed")
	full_map.open_map()
	assert(full_map.is_open == true, "Full Map opens")
	assert(full_map.visible == true, "Full Map becomes visible")
	
	# 2. Test World to Map coordinate conversion
	var map_pos := full_map.world_to_map_position(dummy.position)
	assert(map_pos != Vector2.ZERO, "World position converted to map position")
	
	# 3. Test Close
	full_map.close_map()
	assert(full_map.is_open == false, "Full Map closes")
	
	full_map.queue_free()
	dummy.queue_free()
	print("Full Map tests: OK")


func test_hud() -> void:
	print("7. Testing HUD Presentation...")
	var hud_scene = load("res://Scenes/UI/hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	assert(hud.get_node_or_null("TopLeft/PlayerStatus") != null, "PlayerStatus exists")
	assert(hud.get_node_or_null("BottomCenter/Hotbar") != null, "Hotbar exists")
	hud.queue_free()
	print("HUD tests: OK")


func test_menu() -> void:
	print("8. Testing Pause Menu...")
	var menu_scene = load("res://Scenes/UI/menu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	assert(menu.is_open == false, "Menu initially closed")
	menu.open()
	assert(menu.is_open == true, "Menu open")
	assert(get_tree().paused == true, "Paused when menu open")
	menu.close()
	assert(menu.is_open == false, "Menu closed")
	assert(get_tree().paused == false, "Unpaused when menu closed")
	menu.queue_free()
	print("Menu tests: OK")


func test_ken() -> void:
	print("9. Testing Ken Animations...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	var sprite = ken.get_node("AnimatedSprite2D")
	assert(sprite != null, "Ken has AnimatedSprite2D")
	
	var frames = sprite.sprite_frames
	assert(frames.get_frame_count("swing") == 6, "Swing animation should have 6 frames")
	
	ken.queue_free()
	print("Ken tests: OK")


func test_held_item_system_and_directions() -> void:
	print("10. Testing Data-Driven Held Item & Directional Offsets...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	assert(ken.current_held_item == axe, "Ken held item set to axe")
	assert(ken.held_item_sprite.visible == true, "Held item sprite visible")
	
	# Direction DOWN (Front)
	ken.last_direction = Vector2.DOWN
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(6, 4), "Front position offset correct")
	assert(ken.is_held_item_in_front() and ken.held_item_anchor.z_index == 0, "Front: item drawn over Ken, still depth-sorted")
	assert(ken.held_item_sprite.flip_h == false, "Front flip_h is false")
	
	# Direction UP (Back)
	ken.last_direction = Vector2.UP
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(-5, -2), "Back position offset correct")
	assert(not ken.is_held_item_in_front() and ken.held_item_anchor.z_index == 0, "Back: item drawn behind Ken, still depth-sorted")
	
	# Direction LEFT
	ken.last_direction = Vector2.LEFT
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(-7, 3), "Left position offset correct")
	assert(ken.held_item_sprite.flip_h == true, "Left flip_h is true")
	
	# Direction RIGHT
	ken.last_direction = Vector2.RIGHT
	ken._update_held_item_position()
	assert(ken.held_item_anchor.position == Vector2(7, 3), "Right position offset correct")
	assert(ken.held_item_sprite.flip_h == false, "Right flip_h is false")
	
	ken.queue_free()
	print("Held Item & Directional offsets tests: OK")


func test_directional_swings_and_flips() -> void:
	print("11. Testing Directional Swings and Sprite Flipping...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	
	# Swing facing LEFT
	ken.last_direction = Vector2.LEFT
	ken.trigger_primary_action()
	assert(ken.animated_sprite.flip_h == true, "Sprite flipped horizontally when swinging left")
	ken._on_animation_finished()
	assert(ken.animated_sprite.flip_h == false, "Flip reset after action finished")
	
	# Swing facing RIGHT
	ken.last_direction = Vector2.RIGHT
	ken.trigger_primary_action()
	assert(ken.animated_sprite.flip_h == false, "Sprite not flipped when swinging right")
	ken._on_animation_finished()
	
	ken.queue_free()
	print("Directional Swings tests: OK")


func test_action_state_locking_and_timing() -> void:
	print("12. Testing Action State Locking & Impact Timing...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken is acting")
	assert(ken.current_state == KenScript.State.ACTING, "State is ACTING")
	assert(ken.current_action_type == ItemDataScript.ActionType.CHOP, "Action type is CHOP")
	
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.impact_executed == true, "Impact executed on frame 3")
	
	ken._on_animation_finished()
	assert(ken.is_acting == false, "Action lock cleared after animation finishes")
	
	ken.queue_free()
	print("Action state locking tests: OK")


func test_deterministic_drop_and_held_clear() -> void:
	print("13. Testing Deterministic Drop & Instant Held Item Clearing...")
	var world = Node2D.new()
	add_child(world)
	
	var canvas = CanvasLayer.new()
	world.add_child(canvas)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv: InventoryUI = inv_scene.instantiate()
	canvas.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar: HotbarUI = hotbar_scene.instantiate()
	canvas.add_child(hotbar)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	# Add exactly 1 seed to inventory slot 0
	var seed = ItemDatabaseScript.get_item("wheat_seed")
	inv.add_item(seed, 1)
	
	hotbar.select_slot(0)
	assert(ken.current_held_item == seed, "Ken is holding seed")
	assert(ken.held_item_sprite.visible == true, "Held sprite visible")
	
	# Drop the 1 seed
	ken.trigger_drop_item()
	
	# Slot 0 in hotbar is now empty (count 0)
	assert(inv.get_hotbar_item_at(0)["item"] == null, "Hotbar slot 0 is empty")
	# Hotbar slot 0 returns null
	assert(hotbar.get_selected_item() == null, "Hotbar selected item is null")
	# Ken held item must immediately be cleared and invisible
	assert(ken.current_held_item == null, "Ken held item cleared immediately")
	assert(ken.held_item_sprite.visible == false, "Ken held sprite is invisible")
	
	world.queue_free()
	print("Deterministic Drop & Held Clear tests: OK")


func test_camera_follow_settings() -> void:
	print("14. Testing Camera Follow Settings...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var cam: Camera2D = ken.get_node_or_null("Camera2D")
	assert(cam != null, "Ken has Camera2D child node")
	assert(cam.zoom == Vector2(3, 3), "Camera zoom is 3x3")
	assert(cam.position_smoothing_enabled == true, "Camera smoothing enabled")
	
	ken.queue_free()
	print("Camera follow settings tests: OK")


func test_camera_panning() -> void:
	print("14b. Testing Middle Mouse Camera Drag Panning...")
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	add_child(ken)
	
	var cam: Camera2D = ken.get_node_or_null("Camera2D")
	assert(cam != null, "Ken has Camera2D")
	
	# Simulate Middle Mouse Drag Start
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_MIDDLE
	press_event.pressed = true
	press_event.position = Vector2(400, 300)
	ken._unhandled_input(press_event)
	assert(ken.is_panning_camera == true, "Camera panning active on middle press")
	
	# Simulate Motion
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(460, 300)
	ken._unhandled_input(motion_event)
	assert(cam.offset.x < 0, "Camera offset translated on drag")
	
	# Simulate Release
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_MIDDLE
	release_event.pressed = false
	ken._unhandled_input(release_event)
	assert(ken.is_panning_camera == false, "Camera panning stopped on release")
	
	ken.queue_free()
	print("Camera panning tests: OK")


func test_tree_cutting_and_wood_harvesting() -> void:
	print("15. Testing Tree Cutting & Wood Harvesting Pipeline...")
	var world_scene = Node2D.new()
	add_child(world_scene)
	
	var tree_scene = load("res://Scenes/tree.tscn")
	var tree: TreeEntity = tree_scene.instantiate()
	tree.position = Vector2(20, 0)
	world_scene.add_child(tree)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	ken.position = Vector2(0, 0)
	ken.last_direction = Vector2.RIGHT
	world_scene.add_child(ken)
	
	# 1. Try hitting tree with Sword -> Must NOT damage tree
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 4, "Sword does NOT damage tree (must be axe only)")
	ken._on_animation_finished()
	
	# 2. Equip Wood Axe
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	
	# Hit 1
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 3, "Tree health is 3 after Axe Hit 1")
	ken._on_animation_finished()
	
	# Hit 2
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 2, "Tree health is 2 after Axe Hit 2")
	ken._on_animation_finished()
	
	# Hit 3
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health == 1, "Tree health is 1 after Axe Hit 3")
	ken._on_animation_finished()
	
	# Hit 4 (Fell tree)
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(tree.current_health <= 0, "Tree health <= 0 after Axe Hit 4")
	assert(tree.is_dead == true, "Tree marked as dead after 4 hits")
	
	world_scene.queue_free()
	print("Tree Cutting tests: OK")



func test_pickup_drop_cycle() -> void:
	print("16. Testing Pickup / Drop Cycle...")
	var world_scene = Node2D.new()
	add_child(world_scene)
	
	var canvas = CanvasLayer.new()
	world_scene.add_child(canvas)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv = inv_scene.instantiate()
	canvas.add_child(inv)
	
	var hotbar_scene = load("res://Scenes/UI/hotbar.tscn")
	var hotbar = hotbar_scene.instantiate()
	canvas.add_child(hotbar)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world_scene.add_child(ken)
	
	var w_item_scene = load("res://Scenes/world_item.tscn")
	var w_item = w_item_scene.instantiate()
	w_item.position = Vector2(10, 0)
	world_scene.add_child(w_item)
	
	var mushroom = ItemDatabaseScript.get_item("wild_mushroom")
	w_item.set_item(mushroom, 3)
	
	ken.trigger_interact()
	var picked_slot = inv.get_hotbar_item_at(0) if inv.get_hotbar_item_at(0)["item"] != null else inv.get_item_at(0)
	assert(picked_slot["item"].item_id == "wild_mushroom", "Item is wild mushroom")
	assert(picked_slot["amount"] == 3, "Item amount is 3")
	
	world_scene.queue_free()
	print("Pickup cycle tests: OK")


func test_universal_item_swing_and_swoosh() -> void:
	print("17. Testing Universal Item Swing & Directional Air-Swoosh...")
	var world = Node2D.new()
	add_child(world)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	assert(sword.swing_speed_scale > 1.0, "Sword has high swing speed scale")
	assert(sword.swoosh_scale.x >= 1.0, "Sword has configured swoosh scale")
	
	# Equip sword and swing RIGHT
	ken._on_hotbar_slot_selected(0, sword)
	ken.last_direction = Vector2.RIGHT
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken is acting with sword")
	
	# Frame 3 trigger (Impact & Swoosh)
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.swoosh_effect != null, "Ken has swoosh effect")
	assert(ken.swoosh_effect.is_active == true, "Swoosh effect is active on impact frame")
	assert(ken.swoosh_effect.current_direction == Vector2.RIGHT, "Swoosh points RIGHT")
	
	ken._on_animation_finished()
	
	# Equip axe and swing UP
	var axe = ItemDatabaseScript.get_item("wood_axe")
	ken._on_hotbar_slot_selected(0, axe)
	ken.last_direction = Vector2.UP
	ken.trigger_primary_action()
	ken.animated_sprite.frame = 3
	ken._on_sprite_frame_changed()
	assert(ken.swoosh_effect.is_active == true, "Swoosh effect active on UP swing")
	assert(ken.swoosh_effect.current_direction == Vector2.UP, "Swoosh points UP")
	
	ken._on_animation_finished()
	world.queue_free()
	print("Universal item swing & swoosh tests: OK")


func test_hold_to_swing_repeat_and_release() -> void:
	print("18. Testing Hold-to-Swing Repeat Logic & Release Stop...")
	var world = Node2D.new()
	add_child(world)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	world.add_child(ken)
	
	var sword = ItemDatabaseScript.get_item("iron_sword")
	ken._on_hotbar_slot_selected(0, sword)
	
	# 1. Cooldown calculation
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken starts swing")
	ken._on_animation_finished()
	assert(ken.is_acting == false, "Ken finishes swing")
	assert(ken._current_item_cooldown == sword.swing_cooldown, "Item cooldown correctly set")
	
	# 2. v1.3: with empty hands Ken punches (that is how you get your first wood)
	ken._on_hotbar_slot_selected(0, null)
	ken.trigger_primary_action()
	assert(ken.is_acting == true, "Ken punches when his hands are empty")
	ken._on_animation_finished()
	
	world.queue_free()
	print("Hold-to-swing & empty-hand tests: OK")


func test_rpg_chest_7_and_ui() -> void:
	print("19. Testing RPG Chest #7 Slicing, Open/Close Animation & Transfers...")
	var world = Node2D.new()
	add_child(world)
	
	# 1. Texture Slicing Test
	var tex = ItemDatabaseScript.get_rpg_chest_texture(7, 0)
	assert(tex != null, "Chest 7 closed texture loaded")
	assert(tex.region.size.x > 0 and tex.region.size.y > 0, "Texture region is valid")
	
	# 2. Chest Entity Test
	var chest_scene = load("res://Scenes/Objects/chest.tscn")
	var chest: ChestEntity = chest_scene.instantiate()
	world.add_child(chest)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	ken.position = Vector2(0, 0)
	world.add_child(ken)
	
	chest.position = Vector2(20, 0)
	assert(chest.can_interact(ken) == true, "Chest can interact within 32px")
	
	# 3. Storage & Stacking Test (24 Slots)
	assert(chest.storage_slots.size() == 24, "Chest has 24 storage slots")
	var wood = ItemDatabaseScript.get_item("wood_log")
	var leftover = chest.add_item(wood, 12)
	assert(leftover == 0, "Stored 12 wood logs in chest")
	assert(chest.get_item_at(0)["item"].item_id == "wood_log", "Chest slot 0 has wood")
	assert(chest.get_item_at(0)["amount"] == 12, "Chest slot 0 count is 12")
	
	# 4. Open/Close sequence
	chest.open_chest(ken)
	assert(chest.is_open == true, "Chest opens")
	chest.close_chest()
	assert(chest.is_open == false, "Chest closes")
	
	world.queue_free()
	print("RPG Chest #7 tests: OK")


func test_game_scene() -> void:
	print("20. Testing Game Scene Integration...")
	var game_scene = load("res://Scenes/game.tscn")
	var game = game_scene.instantiate()
	add_child(game)
	
	var ui = game.get_node_or_null("UI")
	assert(ui != null, "UI exists")
	assert(ui.get_node_or_null("HUD") != null, "HUD exists")
	assert(ui.get_node_or_null("Inventory") != null, "Inventory exists")
	assert(ui.get_node_or_null("ChestUI") != null, "ChestUI exists")
	assert(ui.get_node_or_null("FullMap") != null, "FullMap exists")
	
	var ken = game.get_node_or_null("CharacterBody2D3")
	assert(ken != null, "Ken exists")
	
	var chest = game.get_node_or_null("Chest")
	assert(chest != null, "Chest exists in game scene")
	
	game.queue_free()
	print("Game scene tests: OK")


func test_health_and_defense_system() -> void:
	print("21. Testing Priority 1: Health, Defense & Death System...")
	var stats_script = load("res://scripts/player_stats.gd")
	var stats = stats_script.new()
	add_child(stats)
	
	assert(stats.max_health == 100, "Max HP is 100")
	assert(stats.current_health == 100, "Initial HP is 100")
	assert(stats.current_defense == 0, "Initial defense is 0")
	
	# Zombie base damage is 3. At 0 defense, damage should be 3 (~33 hits to die)
	var dmg = stats.take_damage(3)
	assert(dmg == 3, "Zombie deals 3 damage at 0 defense")
	assert(stats.current_health == 97, "HP is 97 after hit")
	
	# Cooldown invulnerability: immediately taking damage again should deal 0
	var dmg2 = stats.take_damage(3)
	assert(dmg2 == 0, "Damage cooldown prevents consecutive frame damage")
	assert(stats.current_health == 97, "HP remains 97 during cooldown")
	
	# Test defense reduction: formula max(1, base - defense/20)
	stats._is_invulnerable = false
	stats.set_defense(20) # 20 / 20 = 1 reduction -> damage is 3 - 1 = 2
	var dmg_def = stats.take_damage(3)
	assert(dmg_def == 2, "Defense reduces damage by 1 (deals 2)")
	assert(stats.current_health == 95, "HP is 95")
	
	# Test minimum damage clamp (always >= 1)
	stats._is_invulnerable = false
	stats.set_defense(100)
	var dmg_min = stats.take_damage(1)
	assert(dmg_min == 1, "Defense never makes player completely immune (min 1)")
	
	# Test death
	stats._is_invulnerable = false
	var died := [false]
	stats.player_died.connect(func(): died[0] = true)
	stats.take_damage(1000)
	assert(stats.current_health == 0, "HP is 0 after fatal damage")
	assert(stats.is_dead == true, "Player is in dead state")
	assert(died[0] == true, "player_died signal fired")
	
	stats.queue_free()
	print("Health & Defense tests: OK")


func test_game_clock_and_periods() -> void:
	print("22. Testing Priority 2: Game Clock & Day/Night Progression...")
	var clock_script = load("res://scripts/game_clock.gd")
	var clock = clock_script.new()
	add_child(clock)
	
	assert(clock.start_hour == 6, "Clock starts at 6 AM")
	assert(clock.get_period_name() == "MORNING", "6 AM is Morning")
	assert(clock.get_time_string() == "06:00 AM", "Time string is 06:00 AM")
	assert(clock.is_night() == false, "Morning is not night")
	
	# Advance to 12 PM (Afternoon)
	clock.current_hour = 12
	clock.current_minute = 0
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "AFTERNOON", "12 PM is Afternoon")
	assert(clock.get_time_string() == "12:00 PM", "Time string is 12:00 PM")
	
	# Advance to 5 PM (Sunset)
	clock.current_hour = 17
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "SUNSET", "5 PM is Sunset")
	
	# Advance to 7 PM (Night)
	clock.current_hour = 19
	clock.current_period = clock._calculate_period()
	assert(clock.get_period_name() == "NIGHT", "7 PM is Night")
	assert(clock.is_night() == true, "7 PM is night")
	
	# Countdown test
	clock.current_hour = 15
	clock.current_minute = 30
	assert(clock.get_nightfall_countdown() == "03:30", "Countdown to 7 PM is 03:30 at 3:30 PM")
	
	# Day roll-over test
	clock.current_day = 1
	clock.current_hour = 23
	clock.current_minute = 59
	clock._advance_minute()
	assert(clock.current_day == 2, "Day advances to 2 at midnight")
	assert(clock.current_hour == 0 and clock.current_minute == 0, "Time resets to 00:00")
	
	clock.queue_free()
	print("Game Clock tests: OK")


func test_event_bus_and_daily_quests() -> void:
	print("23. Testing Priority 3: EventBus & Real-Time Quests...")
	var bus_script = load("res://scripts/event_bus.gd")
	var bus = bus_script.new()
	bus.name = "EventBus"
	add_child(bus)
	
	var qm_script = load("res://scripts/quest_manager.gd")
	var qm = qm_script.new()
	qm.name = "QuestManager"
	add_child(qm)
	qm._connect_event_bus()
	
	# Create a controlled test quest: Plant 3 Carrots
	var q_data_script = load("res://scripts/quest_data.gd")
	var quest = q_data_script.new("test_carrot", "Plant 3 Carrots", "carrot_planted", 3)
	quest.xp_reward = 50
	quest.gold_reward = 100
	qm.active_quests.clear()
	qm.active_quests.append(quest)
	
	assert(quest.current_count == 0, "Quest starts at 0/3")
	assert(quest.is_completed == false, "Quest not completed")
	
	# Emit carrot_planted event 1
	bus.carrot_planted.emit()
	assert(quest.current_count == 1, "Quest progress is 1/3")
	assert(quest.is_completed == false, "Quest not completed at 1/3")
	
	# Emit carrot_planted event 2
	bus.carrot_planted.emit()
	assert(quest.current_count == 2, "Quest progress is 2/3")
	
	# Emit carrot_planted event 3 (Target reached!)
	var quest_finished := [false]
	qm.quest_completed.connect(func(qid): quest_finished[0] = true)
	bus.carrot_planted.emit()
	assert(quest.current_count == 3, "Quest progress reached 3/3")
	assert(quest.is_completed == true, "Quest marked completed")
	assert(quest_finished[0] == true, "quest_completed signal fired")
	
	qm.queue_free()
	bus.queue_free()
	print("EventBus & Quests tests: OK")


func test_environment_lighting() -> void:
	print("24. Testing Priority 4: Environment Lighting...")
	var env_script = load("res://scripts/environment_manager.gd")
	var env = env_script.new()
	add_child(env)
	env._setup()
	
	assert(env.morning_color == Color(1.0, 1.0, 1.0, 1.0), "Morning color is bright neutral")
	assert(env.night_color.b > env.night_color.r, "Night color has cool blue-purple tone")
	
	env.queue_free()
	print("Environment lighting tests: OK")


func test_zombie_spawner_and_marker2d() -> void:
	print("25. Testing Single ZombieSpawnPoint Marker2D & Wave Configuration...")
	var spawner_script = load("res://scripts/SpawnManager.gd")
	var spawner = spawner_script.new()
	add_child(spawner)
	
	# Create single ZombieSpawnPoint Marker2D
	var marker = Marker2D.new()
	marker.name = "ZombieSpawnPoint"
	marker.position = Vector2(250, 150)
	spawner.add_child(marker)
	
	assert(spawner.get_zombie_spawn_point() == marker, "Spawner discovered single ZombieSpawnPoint")
	assert(spawner.zombies_per_wave == 10, "10 zombies per wave configured")
	assert(spawner.spawn_interval == 60.0, "60-second spawn interval configured")
	
	marker.queue_free()
	spawner.queue_free()
	print("Zombie Spawner & Marker2D tests: OK")


func test_zombie_ai_and_combat() -> void:
	print("26. Testing Priority 6: Zombie AI, Health Bars & Combat...")
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie_a = zombie_scene.instantiate()
	var zombie_b = zombie_scene.instantiate()
	add_child(zombie_a)
	add_child(zombie_b)
	
	# Verify initial state
	assert(zombie_a.max_health == 100, "Zombie A has 100 max HP")
	assert(zombie_a.current_health == 100, "Zombie A starts with 100 HP")
	assert(zombie_b.current_health == 100, "Zombie B starts with 100 HP")
	assert(zombie_a.health_bar != null, "Zombie A has health bar node")
	assert(zombie_a.health_bar.value == 100.0, "Health bar shows 100")
	
	# Attack Zombie A: 30 damage
	zombie_a.take_damage(30, Vector2.RIGHT, 20.0)
	assert(zombie_a.current_health == 70, "Zombie A HP is 70 after 30 damage")
	assert(zombie_a.health_bar.value == 70.0, "Zombie A health bar updated immediately to 70")
	
	# Crucial independence check: Zombie B must NOT be affected!
	assert(zombie_b.current_health == 100, "Zombie B is completely unaffected (still 100 HP)")
	assert(zombie_b.health_bar.value == 100.0, "Zombie B health bar remains 100")
	
	# Fatal damage to Zombie A
	zombie_a.take_damage(100)
	assert(zombie_a.current_health == 0, "Zombie A HP reaches 0")
	assert(zombie_a.is_dead == true, "Zombie A enters dead state")
	assert(zombie_a.health_bar.visible == false, "Zombie A health bar disappears on death")
	
	zombie_a.queue_free()
	zombie_b.queue_free()
	print("Zombie AI & Combat tests: OK")


func test_4_direction_movement_and_facing() -> void:
	print("27. Testing 4-Direction Movement, Directional Facing & Zombie Attack...")
	# 1. Test Animal Natural Movement
	var chicken_scene = load("res://Scenes/chicken.tscn")
	var chicken = chicken_scene.instantiate()
	add_child(chicken)
	
	chicken.start_walking()
	assert(chicken.direction.is_normalized(), "Chicken chooses a normalized wandering heading")
	assert(chicken.walk_speed == 25.0, "Wandering preserves configured base speed")
	
	# Test chicken sprite facing
	chicken._update_facing(Vector2.LEFT)
	assert(chicken.animated_sprite.flip_h == false, "Chicken faces LEFT with native artwork")
	chicken._update_facing(Vector2.RIGHT)
	assert(chicken.animated_sprite.flip_h == true, "Chicken faces RIGHT with mirrored artwork")
	
	# Test keeping last facing direction while idle
	chicken._update_facing(Vector2.LEFT)
	chicken.start_idle()
	assert(chicken.animated_sprite.flip_h == false, "Chicken keeps last facing direction (LEFT) while idle")
	chicken._update_facing(Vector2.RIGHT)
	chicken.start_idle()
	assert(chicken.animated_sprite.flip_h == true, "Chicken keeps last facing direction (RIGHT) while idle")
	
	# 2. Test Zombie Cardinal Movement & face_target()
	var zombie_scene = load("res://Scenes/zombie.tscn")
	var zombie = zombie_scene.instantiate()
	add_child(zombie)
	
	# Test cardinal calculation
	assert(zombie.get_cardinal_direction(Vector2(50, 10)) == Vector2.RIGHT, "Primary X right is Vector2.RIGHT")
	assert(zombie.get_cardinal_direction(Vector2(-50, 10)) == Vector2.LEFT, "Primary X left is Vector2.LEFT")
	assert(zombie.get_cardinal_direction(Vector2(10, 50)) == Vector2.DOWN, "Primary Y down is Vector2.DOWN")
	assert(zombie.get_cardinal_direction(Vector2(10, -50)) == Vector2.UP, "Primary Y up is Vector2.UP")
	
	# Test face_target on target node
	var dummy_target = Node2D.new()
	add_child(dummy_target)
	
	# Target to the right
	dummy_target.global_position = zombie.global_position + Vector2(40, 5)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.RIGHT, "Zombie faces RIGHT towards target")
	assert(zombie.animated_sprite.flip_h == true, "Zombie sprite flip_h is true when facing RIGHT")
	
	# Target to the left
	dummy_target.global_position = zombie.global_position + Vector2(-40, 5)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.LEFT, "Zombie faces LEFT towards target")
	assert(zombie.animated_sprite.flip_h == false, "Zombie sprite flip_h is false when facing LEFT")
	
	# Target directly above
	dummy_target.global_position = zombie.global_position + Vector2(0, -40)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.UP, "Zombie faces UP towards target")
	
	# Target directly below
	dummy_target.global_position = zombie.global_position + Vector2(0, 40)
	zombie.face_target(dummy_target)
	assert(zombie.facing_direction == Vector2.DOWN, "Zombie faces DOWN towards target")
	
	# 3. Test Zombie Wander is Cardinal Only
	zombie._enter_state(zombie.State.WANDER)
	assert(zombie._wander_direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], "Zombie wander direction is cardinal")
	assert(zombie.velocity.x == 0 or zombie.velocity.y == 0, "Zombie wander has no diagonal movement")
	
	dummy_target.queue_free()
	zombie.queue_free()
	chicken.queue_free()
	print("4-Direction movement & facing tests: OK")


func test_spawn_manager_scene_and_spawning() -> void:
	print("28. Testing Dedicated SpawnManager.tscn & 10 Zombies per 60s Rule...")
	var sm_scene = load("res://Scenes/SpawnManager.tscn")
	var sm = sm_scene.instantiate()
	add_child(sm)
	
	# Verify the primary marker and the four quarry spawn points.
	var z_point = sm.get_zombie_spawn_point()
	assert(z_point != null, "Found primary ZombieSpawnPoint marker")
	var points = sm.get_zombie_spawn_points()
	assert(points.size() == 4, "Four quarry spawn points")
	assert(sm.zombies_per_wave == 10, "Default zombies_per_wave is 10")
	assert(sm.spawn_interval == 60.0, "Default spawn_interval is 60.0s")
	
	var timer = sm.get_node_or_null("ZombieSpawnTimer")
	assert(timer != null, "ZombieSpawnTimer node exists")
	assert(timer.wait_time == 60.0, "Timer wait_time is 60 seconds")
	
	# Test spawning: quarry-only mode distributes exactly 10 zombies across the four platforms.
	sm.spread_spawns = false
	var spawned_zombies = sm.spawn_zombies()
	assert(spawned_zombies.size() == 10, "Spawned exactly 10 zombies in wave")
	for i in range(spawned_zombies.size()):
		assert(spawned_zombies[i].global_position == points[i % points.size()].global_position, "Zombies use all four platform markers")

	sm.clear_zombies()
	assert(sm._spawned_zombies.is_empty(), "All spawned zombies cleared")

	# Spread mode: field markers near the player, but never on top of them.
	sm.spread_spawns = true
	var field_points = sm.get_field_spawn_points()
	assert(field_points.size() >= 12, "Field spawn markers spread across the valley")
	var player_pos := Vector2(1, 14)
	var picked = sm.pick_field_spawn_points(player_pos)
	assert(picked.size() == sm.field_points_per_wave, "Picked the configured number of field markers")
	var last_dist := 0.0
	for p in picked:
		var dist: float = p.global_position.distance_to(player_pos)
		assert(dist >= sm.min_spawn_distance, "Field spawn is off-screen")
		assert(dist >= last_dist, "Field spawns sorted nearest first")
		last_dist = dist
	var far_west = sm.pick_field_spawn_points(Vector2(-1100, 300))
	assert(not far_west.is_empty() and far_west[0].global_position.x < -450, "Zombies also reach the west side")

	sm.queue_free()
	print("SpawnManager.tscn tests: OK")


func test_torch_world_item_and_inventory() -> void:
	print("29. Testing Torch System: Asset, Light, Inventory & Drop/Pickup...")
	# 1. Test item database registration
	var db = load("res://scripts/item_database.gd")
	var torch_item = db.get_item("torch")
	assert(torch_item != null, "Torch is registered in ItemDatabase")
	assert(torch_item.display_name == "Lantern", "v1.3.1: the torch item is shown as a Lantern")
	assert(torch_item.icon != null, "Torch has an icon texture")
	assert(torch_item.max_stack == 99, "Torch max stack is 99")
	
	# 2. Test Torch.tscn instance
	var torch_scene = load("res://Scenes/Torch.tscn")
	var torch_node = torch_scene.instantiate()
	add_child(torch_node)
	
	assert(torch_node.is_in_group("world_items"), "Torch belongs to world_items group")
	assert(torch_node.is_in_group("torches"), "Torch belongs to torches group")
	assert(torch_node.point_light != null, "Torch has PointLight2D")
	assert(torch_node.animated_sprite != null, "Torch has AnimatedSprite2D with flame")
	assert(torch_node.animated_sprite.sprite_frames.has_animation("flicker"), "Torch has flicker animation")
	
	# 3. Test day/night lighting response
	torch_node._update_lighting_state(true)
	assert(torch_node.point_light.enabled == true, "Torch light is enabled at night")
	assert(is_equal_approx(torch_node._base_energy, torch_node.torch_light_energy), "Lantern light has full energy at night")
	torch_node._update_lighting_state(false)
	assert(torch_node.point_light.enabled == false, "v1.3.1: lantern light is off in daylight")
	assert(is_equal_approx(torch_node._base_energy, 0.0), "Lantern has no daytime glow")

	torch_node.queue_free()
	
	# 4. Test Player Held Torch & Light Following
	var test_container = Node2D.new()
	add_child(test_container)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv = inv_scene.instantiate()
	test_container.add_child(inv)
	inv.set_hotbar_item_at(0, torch_item, 4)
	
	var ken_scene = load("res://Scenes/ken.tscn")
	var ken = ken_scene.instantiate()
	test_container.add_child(ken)
	
	assert(ken.held_torch_flame != null, "Ken has HeldTorchFlame node")
	assert(ken.torch_light != null, "Ken has TorchLight node")
	assert(ken.torch_light.enabled == false, "TorchLight is disabled when no item held")
	
	# Equip torch
	ken.current_held_item = torch_item
	ken._update_held_item_visuals()
	assert(ken.held_torch_flame.visible == false and ken.held_item_sprite.visible, "v1.3.1: a lantern sprite is held (no torch flame)")
	assert(ken.torch_light.enabled == true, "TorchLight enabled when torch equipped")
	assert(ken._torch_base_energy >= 1.0, "TorchLight has rich base energy at night")
	
	# Verify light follows player movement
	ken.global_position = Vector2(150, 200)
	var light_pos: Vector2 = ken.torch_light.global_position
	assert(light_pos.distance_to(ken.global_position) < 30.0, "TorchLight follows player global_position")
	
	# Verify flame orients with player facing
	ken.last_direction = Vector2.LEFT
	ken._update_held_item_position()
	assert(ken.held_item_sprite.rotation_degrees == 0.0, "Held lantern hangs straight when facing LEFT")
	
	ken.last_direction = Vector2.RIGHT
	ken._update_held_item_position()
	assert(ken.held_item_sprite.rotation_degrees == 0.0, "Held lantern hangs straight when facing RIGHT")
	
	# 5. Test Right-Click Placement in ALL 4 Directions (DOWN, LEFT, RIGHT, UP)
	# Test placing DOWN (bottom)
	ken.last_direction = Vector2.DOWN
	var place_down: bool = ken.trigger_place_held_torch()
	assert(place_down == true, "Can place torch facing DOWN (bottom)")
	
	# Test placing LEFT (side)
	ken.last_direction = Vector2.LEFT
	var place_left: bool = ken.trigger_place_held_torch()
	assert(place_left == true, "Can place torch facing LEFT (side)")
	
	# Test placing RIGHT (side)
	ken.last_direction = Vector2.RIGHT
	var place_right: bool = ken.trigger_place_held_torch()
	assert(place_right == true, "Can place torch facing RIGHT (side)")
	
	# Test placing UP (top)
	ken.last_direction = Vector2.UP
	var place_up: bool = ken.trigger_place_held_torch()
	assert(place_up == true, "Can place torch facing UP (top)")
	
	# Since 4 torches were placed, player light should now be OFF
	assert(ken.torch_light.enabled == false, "Player torch light turns OFF after placing all 4 torches")
	assert(ken.held_torch_flame.visible == false, "Held torch flame hidden after placing all torches")
	
	# 6. Test Pickup Placed Torches
	for child in test_container.get_children():
		if child is Area2D and child.is_in_group("torches") and is_instance_valid(child) and not child.is_queued_for_deletion():
			ken.global_position = child.global_position
			ken.trigger_interact()
	
	var slot_after_pickup: Dictionary = inv.get_hotbar_item_at(0)
	assert(slot_after_pickup["amount"] == 4, "All 4 torches returned to inventory")
	
	# Equip again -> light comes back
	ken.current_held_item = slot_after_pickup["item"]
	ken._update_held_item_visuals()
	assert(ken.torch_light.enabled == true, "Player receives held torch light again after re-equipping")
	
	test_container.queue_free()
	print("Torch system tests: OK")


func test_bed_and_sleeping_system() -> void:
	print("Testing Phase 7: Bed & Sleeping System...")
	var GameClockScript = preload("res://scripts/game_clock.gd")
	var PlayerStatsScript = preload("res://scripts/player_stats.gd")
	var BedScene = preload("res://Scenes/Objects/Bed.tscn")
	
	# 1. Instantiate Bed Scene and verify groups and hierarchy
	var bed = BedScene.instantiate()
	add_child(bed)
	assert(bed.is_in_group("beds"), "Bed is in 'beds' group")
	assert(bed.is_in_group("interactables"), "Bed is in 'interactables' group")
	assert(bed.has_method("can_interact"), "Bed has can_interact method")
	assert(bed.has_method("interact"), "Bed has interact method")
	assert(bed.get_node_or_null("Sprite2D") != null, "Bed has Sprite2D")
	assert(bed.get_node_or_null("StaticBody2D") != null, "Bed has StaticBody2D")
	assert(bed.get_node_or_null("InteractionArea") != null, "Bed has InteractionArea")
	assert(bed.get_node_or_null("SleepPosition") != null, "Bed has SleepPosition marker")
	assert(bed.get_node("SleepPosition").position == Vector2(0.5, 1.5), "SleepPosition centers the pillow-to-mattress surface")
	assert(bed.get_node_or_null("WakePosition") != null, "Bed has WakePosition marker")
	assert(bed.get_node("WakePosition").position == Vector2(26, 4), "WakePosition is beside bed (26, 4)")
	assert(bed.get_node_or_null("InteractionLabel") != null, "Bed has InteractionLabel")
	
	# Verify Bed uses the real Red Bed atlas region from HouseInteriorA.png
	var sprite: Sprite2D = bed.get_node("Sprite2D")
	assert(sprite.texture is AtlasTexture, "Bed sprite uses AtlasTexture")
	var atlas_tex: AtlasTexture = sprite.texture
	assert(atlas_tex.region == Rect2(128, 33, 32, 48), "Bed uses real Red Bed atlas region Rect2(128, 33, 32, 48)")
	
	# Verify Stool is regular non-sleep furniture
	var StoolScene = preload("res://Scenes/Objects/Stool.tscn")
	var stool = StoolScene.instantiate()
	add_child(stool)
	assert(not stool.is_in_group("beds"), "Stool is NOT in 'beds' group")
	assert(not stool.is_in_group("interactables"), "Stool is NOT in 'interactables' group")
	assert(not stool.has_method("interact"), "Stool has NO interact method")
	assert(stool.get_node_or_null("InteractionArea") == null, "Stool has NO InteractionArea")
	assert(stool.get_node_or_null("SleepPosition") == null, "Stool has NO SleepPosition")
	stool.queue_free()
	
	# 2. Test GameClock.advance_to_time()
	var clock = GameClockScript.new()
	add_child(clock)
	clock.current_day = 1
	clock.current_hour = 22 # 10:00 PM
	clock.current_minute = 30
	
	# Sleep at 10:30 PM -> should advance to 6:00 AM on Day 2
	clock.advance_to_time(6, 0)
	assert(clock.current_hour == 6, "Clock advanced to 6:00 AM")
	assert(clock.current_minute == 0, "Clock minute reset to 0")
	assert(clock.current_day == 2, "Day incremented across midnight to Day 2")
	
	# Sleep at 2:00 AM on Day 2 -> should advance to 6:00 AM on Day 2 (NOT Day 3)
	clock.current_hour = 2
	clock.current_minute = 0
	clock.advance_to_time(6, 0)
	assert(clock.current_hour == 6, "Clock advanced to 6:00 AM")
	assert(clock.current_minute == 0, "Clock minute reset to 0")
	assert(clock.current_day == 2, "Day did NOT double-increment when sleeping after midnight")
	
	# 3. Test Sleep Schedule validation
	clock.current_hour = 12 # Midday
	assert(bed.is_sleep_allowed() == false, "Sleeping not allowed at 12:00 PM")
	clock.current_hour = 20 # 8:00 PM
	assert(bed.is_sleep_allowed() == true, "Sleeping allowed at 8:00 PM")
	clock.current_hour = 3 # 3:00 AM
	assert(bed.is_sleep_allowed() == true, "Sleeping allowed at 3:00 AM")
	
	# 4. Test PlayerStats overnight effects
	var stats = PlayerStatsScript.new()
	add_child(stats)
	stats.current_hunger = 80.0
	stats.current_health = 60
	stats.drain_hunger(bed.overnight_hunger_cost)
	stats.heal(bed.overnight_hp_restore)
	assert(stats.current_hunger == 70.0, "Overnight hunger cost applied (-10)")
	assert(stats.current_health == 80, "Overnight HP restore applied (+20)")
	
	# 5. Test Ken enter_sleep_state and exit_sleep_state
	var KenScene = preload("res://Scenes/ken.tscn")
	var ken = KenScene.instantiate()
	add_child(ken)
	ken.last_direction = Vector2.LEFT
	ken.play_idle_animation()
	var normal_offset: Vector2 = ken.animated_sprite.offset
	ken.enter_sleep_state()
	var col_shape: CollisionShape2D = ken.get_node("CollisionShape2D")
	assert(ken.current_state == KenScript.State.SLEEPING, "Ken is in SLEEPING state")
	assert(col_shape.disabled == true, "Collision shape disabled during sleep")
	assert(ken.rotation == 0.0, "Vertical bed keeps Ken upright")
	assert(ken.animated_sprite.animation == &"idle_front" and ken.animated_sprite.frame == 0, "Sleep uses existing front frame")
	assert(not ken.animated_sprite.is_playing(), "Sleep frame is frozen")
	assert(not ken.animated_sprite.flip_h and not ken.animated_sprite.flip_v, "Sleep face is unflipped")
	assert(ken.last_direction == Vector2.LEFT, "Sleep visual preserves real facing")
	assert(ken.animated_sprite.offset == Vector2(0, -1), "Only visible-frame origin is compensated")
	ken._on_hotbar_slot_selected(0, ItemDatabaseScript.get_item("iron_sword"))
	assert(not ken.held_item_sprite.visible, "Hotbar refresh keeps sleeping tool hidden")
	ken._on_hotbar_slot_selected(0, ItemDatabaseScript.get_item("torch"))
	ken._on_clock_time_updated(6, 0)
	assert(not ken.held_torch_flame.visible and not ken.torch_light.enabled, "Sleeping torch stays hidden during clock update")
	ken.trigger_primary_action()
	assert(not ken.is_acting, "Sleeping Ken cannot start an action")
	ken.exit_sleep_state()
	assert(ken.current_state == KenScript.State.IDLE, "Ken restored to IDLE state")
	assert(col_shape.disabled == false, "Collision shape re-enabled upon wake")
	assert(ken.rotation_degrees == 0.0, "Ken rotation restored to 0.0 upon wake")
	assert(ken.animated_sprite.animation == &"idle_left" and ken.animated_sprite.is_playing(), "Original facing animation resumes")
	assert(ken.animated_sprite.offset == normal_offset, "Normal sprite origin restored")
	assert(ken.held_torch_flame.visible and ken.torch_light.enabled, "Selected held item restored")
	ken.queue_free()
	
	# Clean up
	bed.queue_free()
	clock.queue_free()
	stats.queue_free()
	print("Bed & Sleeping System tests: OK")


func test_depth_sorting_and_trunk_collisions() -> void:
	print("Testing depth sorting (walk behind trees/roofs) & trunk-only tree collisions...")
	var game = load("res://Scenes/game.tscn").instantiate()
	assert(game.y_sort_enabled, "Game root is Y-sorted")
	var ground: Node2D = game.get_node("TileMap")
	assert(ground.z_index == -1, "Ground tile map always draws under characters")
	var tall: TileMapLayer = game.get_node_or_null("TallThingsLayer")
	assert(tall != null and tall.y_sort_enabled, "Trees/buildings live on a Y-sorted layer")
	assert(tall.get_used_cells().size() > 1000, "Tall objects moved to the Y-sorted layer")
	# Oak tree canopy (top row) sorts at the trunk, 3 rows lower.
	var oak := tall.tile_set.get_source(6) as TileSetAtlasSource
	assert(oak.get_tile_data(Vector2i(1, 0), 0).y_sort_origin == 48, "Canopy sorts at the trunk base")
	assert(oak.get_tile_data(Vector2i(1, 3), 0).y_sort_origin == 0, "Trunk row sorts at itself")
	# Farm furrows stay on ThingsLayer for FarmingManager.
	var things: TileMapLayer = game.get_node("TileMap/TerrainLayer/ThingsLayer")
	for cell in tall.get_used_cells():
		if tall.get_cell_source_id(cell) == 4:
			var ay := tall.get_cell_atlas_coords(cell).y
			assert(ay < 8 or ay > 13, "No farm furrow tiles moved off ThingsLayer")
	assert(things.get_used_cells().size() > 0, "Ground decorations stay on ThingsLayer")
	# Tree trunks block, canopies don't: 41 tile trees share one 10x10 trunk shape.
	var trunks := 0
	for shape in game.get_node("TileMap/MapCollisions").get_children():
		if shape is CollisionShape2D and shape.shape is RectangleShape2D and shape.shape.size == Vector2(10, 10):
			trunks += 1
	assert(trunks >= 41, "Every tile tree has a trunk-only collider")
	for shape in game.get_node("TileMap/MapCollisions").get_children():
		if shape is CollisionShape2D and shape.shape is CircleShape2D:
			assert(shape.shape.radius <= 10.0, "No canopy-sized circles: you can walk under the big trees")
	var bridge_cells := 0
	for cell in tall.get_used_cells():
		if tall.get_cell_source_id(cell) == 1:
			bridge_cells += 1
	assert(bridge_cells == 0, "Bridges stay on the ground layer so Ken walks on top of them")
	game.free()
	print("Depth sorting & trunk collision tests: OK")
