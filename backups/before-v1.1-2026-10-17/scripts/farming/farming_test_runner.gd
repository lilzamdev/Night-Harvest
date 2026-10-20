extends Node

const ItemDatabaseScript = preload("res://scripts/item_database.gd")
const ItemDataScript = preload("res://scripts/item_data.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const HotbarScript = preload("res://scripts/hotbar.gd")
const KenScript = preload("res://Scenes/ken_idle_front.gd")
const GameClockScript = preload("res://scripts/game_clock.gd")
const PlayerStatsScript = preload("res://scripts/player_stats.gd")
const EventBusScript = preload("res://scripts/event_bus.gd")
const FarmingManagerScript = preload("res://scripts/farming/FarmingManager.gd")
const CropEntityScript = preload("res://scripts/farming/CropEntity.gd")
const SoilStateScript = preload("res://scripts/farming/SoilState.gd")
const CropDataScript = preload("res://scripts/farming/CropData.gd")

func _ready() -> void:
	print("==================================================")
	print("--- NIGHT HARVEST: PHASE 1.5 FARMING TEST SUITE ---")
	print("==================================================")
	
	test_1_hoe_system()
	test_2_seed_planting()
	test_3_invalid_planting_validation()
	test_4_watering_revision()
	test_5_water_once_and_30s_growth()
	test_6_renewable_seeds_and_harvest()
	test_7_unhoeing_empty_soil()
	test_8_crop_protection_unhoe_blocked()
	test_9_all_six_crops_independent_growth()
	test_10_farming_xp_and_clock()
	test_11_multi_layer_pipeline_phase_1_5()
	test_12_starter_inventory_all_crops_and_seeds()
	
	print("==================================================")
	print("--- ALL 12 PHASE 1.5 ACCEPTANCE TESTS PASSED! ---")
	print("==================================================")
	get_tree().quit(0)


func test_1_hoe_system() -> void:
	print("\n[TEST 1] Testing Hoe System & Soil Conversion...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var target_pos := Vector2(32, 32)
	assert(farm_mgr.get_soil_state(target_pos) == SoilStateScript.State.UNTILLED, "Initial soil is UNTILLED")
	assert(farm_mgr.can_hoe_tile(target_pos) == true, "Normal ground can be hoed")
	
	# Hoe the soil
	var hoed = farm_mgr.hoe_tile(target_pos)
	assert(hoed == true, "Hoeing soil succeeded")
	assert(farm_mgr.get_soil_state(target_pos) == SoilStateScript.State.HOED, "Soil state is now HOED")
	
	# Prevent repeatedly hoeing already-hoed tile
	assert(farm_mgr.can_hoe_tile(target_pos) == false, "Cannot re-hoe an already hoed tile")
	assert(farm_mgr.hoe_tile(target_pos) == false, "Re-hoe action returns false")
	
	test_root.free()
	print("Test 1 (Hoe System): OK")


func test_2_seed_planting() -> void:
	print("\n[TEST 2] Testing Seed Planting...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var target_pos := Vector2(48, 48)
	farm_mgr.hoe_tile(target_pos)
	
	assert(farm_mgr.can_plant_seed(target_pos, "carrot_seed") == true, "Can plant carrot seed on hoed soil")
	
	var crop = farm_mgr.plant_seed(target_pos, "carrot_seed")
	assert(crop != null, "Crop entity successfully created")
	assert(crop.crop_id == "carrot", "Planted crop ID is carrot")
	assert(crop.growth_stage == 0, "Crop starts at Stage 0 (Seed)")
	assert(crop.watered == false, "Crop starts dry/unwatered")
	assert(crop.mature == false, "Crop is not mature initially")
	assert(farm_mgr.get_crop_at(target_pos) == crop, "FarmingManager tracks crop at target position")
	
	test_root.free()
	print("Test 2 (Planting): OK")


func test_3_invalid_planting_validation() -> void:
	print("\n[TEST 3] Testing Invalid Planting Validation...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var unhoed_pos := Vector2(100, 100)
	# 1. Normal dirt cannot be planted
	assert(farm_mgr.can_plant_seed(unhoed_pos, "carrot_seed") == false, "Cannot plant on normal unhoed dirt")
	var crop_fail = farm_mgr.plant_seed(unhoed_pos, "carrot_seed")
	assert(crop_fail == null, "Planting on normal dirt returns null")
	
	# 2. Cannot plant on already occupied hoed soil
	var hoed_pos := Vector2(64, 64)
	farm_mgr.hoe_tile(hoed_pos)
	var first_crop = farm_mgr.plant_seed(hoed_pos, "carrot_seed")
	assert(first_crop != null, "First crop planted")
	
	assert(farm_mgr.can_plant_seed(hoed_pos, "carrot_seed") == false, "Cannot plant on occupied soil")
	var second_crop = farm_mgr.plant_seed(hoed_pos, "carrot_seed")
	assert(second_crop == null, "Second planting on same tile returns null")
	
	test_root.free()
	print("Test 3 (Invalid Planting Validation): OK")


func test_4_watering_revision() -> void:
	print("\n[TEST 4] Testing Watering Revision (Ground Tile Untouched)...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	# Empty hoed soil CANNOT be watered
	var empty_hoed_pos := Vector2(80, 80)
	farm_mgr.hoe_tile(empty_hoed_pos)
	assert(farm_mgr.can_water(empty_hoed_pos) == false, "Cannot water empty hoed soil with no crop")
	assert(farm_mgr.water_tile(empty_hoed_pos) == false, "Watering empty soil returns false")
	
	# Now plant a crop on hoed soil
	var crop = farm_mgr.plant_seed(empty_hoed_pos, "carrot_seed")
	assert(crop != null, "Crop planted")
	assert(crop.watered == false, "Crop starts unwatered")
	assert(farm_mgr.can_water(empty_hoed_pos) == true, "Can water hoed soil with planted unwatered crop")
	
	# Water the crop
	var watered = farm_mgr.water_tile(empty_hoed_pos)
	assert(watered == true, "Watering action succeeded")
	assert(crop.watered == true, "Crop internal state is now watered = true")
	
	# Ground tile MUST REMAIN HOED! (DO NOT change ground tile)
	assert(farm_mgr.get_soil_state(empty_hoed_pos) == SoilStateScript.State.HOED, "Soil state remains HOED")
	
	# Crop is already watered -> cannot water again
	assert(farm_mgr.can_water(empty_hoed_pos) == false, "Cannot re-water an already watered crop")
	
	test_root.free()
	print("Test 4 (Watering Revision): OK")


func test_5_water_once_and_30s_growth() -> void:
	print("\n[TEST 5] Testing Single Watering & 30-Second Continuous Growth...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var pos := Vector2(16, 16)
	farm_mgr.hoe_tile(pos)
	var crop = farm_mgr.plant_seed(pos, "carrot_seed")
	
	# Stage 0: Seed (unwatered) -> advancing time does nothing!
	farm_mgr.advance_growth_minutes(10.0)
	assert(crop.growth_stage == 0, "Unwatered crop does not grow")
	assert(crop.growth_progress_minutes == 0.0, "Progress remains 0")
	
	# Water the plant ONCE
	farm_mgr.water_tile(pos)
	assert(crop.watered == true, "Crop is watered")
	
	# Advance 10 seconds -> Reaches Stage 1 (Sprout)
	farm_mgr.advance_growth_minutes(10.0)
	assert(crop.growth_stage == 1, "Crop reached Stage 1 (Sprout) at 10s")
	# Stays watered! Water only needed once:
	assert(crop.watered == true, "Crop remains watered without requiring re-watering!")
	
	# Advance 10 more seconds (total 20s) -> Reaches Stage 2 (Growing)
	farm_mgr.advance_growth_minutes(10.0)
	assert(crop.growth_stage == 2, "Crop reached Stage 2 (Growing) at 20s")
	assert(crop.watered == true, "Crop remains watered")
	
	# Advance 10 more seconds (total 30s) -> Reaches Stage 3 (Mature)
	farm_mgr.advance_growth_minutes(10.0)
	assert(crop.growth_stage == 3, "Crop reached Stage 3 (Mature) after 30 seconds")
	assert(crop.mature == true, "Crop is mature after 30 seconds")
	assert(crop.can_harvest() == true, "Mature crop is ready to harvest")
	
	test_root.free()
	print("Test 5 (Water Once & 30s Growth): OK")


func test_6_renewable_seeds_and_harvest() -> void:
	print("\n[TEST 6] Testing Renewable Seed Production & Harvesting...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv = inv_scene.instantiate()
	test_root.add_child(inv)
	
	var pos := Vector2(32, 32)
	farm_mgr.hoe_tile(pos)
	var crop = farm_mgr.plant_seed(pos, "carrot_seed")
	
	# Water once and grow to maturity (30 seconds)
	farm_mgr.water_tile(pos)
	farm_mgr.advance_growth_minutes(30.0)
	assert(crop.mature == true, "Crop is mature after 30s")
	
	# Harvest crop
	var harvest_res = farm_mgr.harvest_crop(pos, inv)
	assert(not harvest_res.is_empty(), "Harvest returned yield data")
	assert(harvest_res.get("item_id") == "carrot", "Harvest yielded carrot")
	assert(harvest_res.get("amount") >= 1, "Harvested at least 1 carrot")
	assert(harvest_res.has("seed_id"), "Harvest data includes replacement seed ID")
	assert(harvest_res.get("seed_id") == "carrot_seed", "Replacement seed is carrot_seed")
	assert(harvest_res.get("seed_amount", 0) >= 1, "Harvest produced at least 1 replacement seed")
	
	# Verify both items added to inventory
	var has_carrot := false
	var has_seed := false
	for i in range(inv.slots.size()):
		var slot: Dictionary = inv.get_item_at(i)
		if slot.get("item"):
			if slot["item"].item_id == "carrot": has_carrot = true
			elif slot["item"].item_id == "carrot_seed": has_seed = true
	for i in range(inv.hotbar_slots.size()):
		var slot: Dictionary = inv.get_hotbar_item_at(i)
		if slot.get("item"):
			if slot["item"].item_id == "carrot": has_carrot = true
			elif slot["item"].item_id == "carrot_seed": has_seed = true
	
	assert(has_carrot == true, "Harvested carrot placed in player inventory")
	assert(has_seed == true, "Replacement seed placed in player inventory")
	
	# Soil remains hoed and ready for replanting the replacement seed immediately!
	assert(farm_mgr.get_crop_at(pos) == null, "Soil is empty")
	assert(farm_mgr.get_soil_state(pos) == SoilStateScript.State.HOED, "Soil is hoed and ready for replanting")
	assert(farm_mgr.can_plant_seed(pos, "carrot_seed") == true, "Can replant replacement seed immediately")
	
	test_root.free()
	print("Test 6 (Renewable Seeds & Harvest): OK")


func test_7_unhoeing_empty_soil() -> void:
	print("\n[TEST 7] Testing Unhoeing / Undo Hoeing...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var pos := Vector2(64, 64)
	
	assert(farm_mgr.can_unhoe_tile(pos) == false, "Cannot unhoe normal untilled ground")
	
	farm_mgr.hoe_tile(pos)
	assert(farm_mgr.get_soil_state(pos) == SoilStateScript.State.HOED, "Soil is HOED")
	assert(farm_mgr.can_unhoe_tile(pos) == true, "Empty hoed soil CAN be unhoed")
	
	var unhoed = farm_mgr.unhoe_tile(pos)
	assert(unhoed == true, "Unhoe action succeeded")
	assert(farm_mgr.get_soil_state(pos) == SoilStateScript.State.UNTILLED, "Soil reverted to UNTILLED normal ground")
	assert(farm_mgr.can_unhoe_tile(pos) == false, "Cannot unhoe already reverted ground")
	
	test_root.free()
	print("Test 7 (Unhoeing Empty Soil): OK")


func test_8_crop_protection_unhoe_blocked() -> void:
	print("\n[TEST 8] Testing Crop Protection Against Unhoeing...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var pos := Vector2(96, 96)
	farm_mgr.hoe_tile(pos)
	var crop = farm_mgr.plant_seed(pos, "carrot_seed")
	
	# 1. Hoed Soil + Seed -> CANNOT UNHOE!
	assert(crop.growth_stage == 0, "Crop is at Stage 0 (Seed)")
	assert(farm_mgr.can_unhoe_tile(pos) == false, "CRITICAL: Cannot unhoe soil with planted seed!")
	assert(farm_mgr.unhoe_tile(pos) == false, "Unhoe returns false when crop is present")
	assert(farm_mgr.get_crop_at(pos) == crop, "Planted seed is safely preserved")
	
	# 2. Hoed Soil + Sprout -> CANNOT UNHOE!
	farm_mgr.water_tile(pos)
	farm_mgr.advance_growth_minutes(10.0)
	assert(crop.growth_stage == 1, "Crop is at Stage 1 (Sprout)")
	assert(farm_mgr.can_unhoe_tile(pos) == false, "CRITICAL: Cannot unhoe soil with growing sprout!")
	
	# 3. Hoed Soil + Mature Crop -> CANNOT UNHOE!
	farm_mgr.advance_growth_minutes(20.0)
	assert(crop.mature == true, "Crop is mature")
	assert(farm_mgr.can_unhoe_tile(pos) == false, "CRITICAL: Cannot unhoe soil with mature crop!")
	
	# After harvest, empty soil CAN be unhoed
	farm_mgr.harvest_crop(pos)
	assert(farm_mgr.get_crop_at(pos) == null, "Crop harvested and soil empty")
	assert(farm_mgr.can_unhoe_tile(pos) == true, "Now that crop is harvested, empty soil CAN be unhoed")
	var unhoed = farm_mgr.unhoe_tile(pos)
	assert(unhoed == true, "Empty soil safely unhoed after harvest")
	
	test_root.free()
	print("Test 8 (Crop Protection Unhoe Blocked): OK")


func test_9_all_six_crops_independent_growth() -> void:
	print("\n[TEST 9] Testing All 6 Crops (Carrot, Wheat, Watermelon, Corn, Potato, Tomato)...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	
	var crops_to_test := [
		{ "seed": "carrot_seed", "crop": "carrot" },
		{ "seed": "wheat_seed", "crop": "wheat" },
		{ "seed": "watermelon_seed", "crop": "watermelon" },
		{ "seed": "corn_seed", "crop": "corn" },
		{ "seed": "potato_seed", "crop": "potato" },
		{ "seed": "tomato_seed", "crop": "tomato" }
	]
	
	var idx := 0
	for entry in crops_to_test:
		var pos := Vector2(16 * idx, 0)
		farm_mgr.hoe_tile(pos)
		
		# Plant seed
		assert(farm_mgr.can_plant_seed(pos, entry["seed"]) == true, "Can plant " + entry["seed"])
		var crop = farm_mgr.plant_seed(pos, entry["seed"])
		assert(crop != null, "Planted " + entry["crop"])
		assert(crop.crop_id == entry["crop"], "Crop entity has matching crop_id: " + entry["crop"])
		
		# Water once
		farm_mgr.water_tile(pos)
		
		# Advance 30 seconds to maturity
		farm_mgr.advance_growth_minutes(30.0)
		assert(crop.mature == true, entry["crop"] + " successfully reached maturity after 30s")
		
		# Harvest
		var harvest_res = farm_mgr.harvest_crop(pos)
		assert(harvest_res.get("item_id") == entry["crop"], "Yielded " + entry["crop"])
		assert(harvest_res.get("seed_id") == entry["seed"], "Yielded replacement " + entry["seed"])
		assert(harvest_res.get("seed_amount") >= 1, "Guaranteed replacement seed")
		
		idx += 1
	
	test_root.free()
	print("Test 9 (All 6 Crops Independent Growth): OK")


func test_10_farming_xp_and_clock() -> void:
	print("\n[TEST 10] Testing Farming XP & GameClock Minute Progression...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var clock = GameClockScript.new()
	clock.name = "GameClock"
	clock.start_hour = 8
	clock.start_minute = 0
	test_root.add_child(clock)
	
	var farm_mgr = FarmingManagerScript.new()
	farm_mgr.name = "FarmingManager"
	test_root.add_child(farm_mgr)
	farm_mgr._connect_game_clock()
	
	var stats = PlayerStatsScript.new()
	stats.name = "PlayerStats"
	test_root.add_child(stats)
	
	var pos := Vector2(32, 32)
	farm_mgr.hoe_tile(pos) # +1 XP
	assert(farm_mgr.total_farming_xp == 1, "Hoe gives +1 XP")
	
	var crop = farm_mgr.plant_seed(pos, "carrot_seed") # +2 XP
	assert(farm_mgr.total_farming_xp == 3, "Plant gives +2 XP")
	
	farm_mgr.water_tile(pos) # +1 XP
	assert(farm_mgr.total_farming_xp == 4, "Water gives +1 XP")
	
	# Advance GameClock by 30 minutes (30 seconds real time)
	for i in range(30):
		clock._advance_minute()
	
	assert(crop.growth_progress_minutes >= 30.0, "GameClock advanced growth progress by 30 minutes")
	assert(crop.mature == true, "Crop matured directly after 30 clock ticks")
	
	test_root.free()
	print("Test 10 (XP & Clock): OK")


func test_11_multi_layer_pipeline_phase_1_5() -> void:
	print("\n[TEST 11] Testing Multi-Layer Visual Pipeline...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var terrain := TileMapLayer.new()
	terrain.name = "TerrainLayer"
	var things := TileMapLayer.new()
	things.name = "ThingsLayer"
	var overlay := TileMapLayer.new()
	overlay.name = "ThingsOverlayLayer"
	
	test_root.add_child(terrain)
	terrain.add_child(things)
	things.add_child(overlay)
	
	var terrain_ts := TileSet.new()
	terrain_ts.tile_size = Vector2i(16, 16)
	var terrain_src := TileSetAtlasSource.new()
	var farmland_tex = load("res://Assets/Tiles/FarmLand_Tile.png")
	if farmland_tex:
		terrain_src.texture = farmland_tex
		terrain_src.texture_region_size = Vector2i(16, 16)
		terrain_src.create_tile(Vector2i(1, 1))
	terrain_ts.add_source(terrain_src, 9)
	terrain.tile_set = terrain_ts
	
	var things_ts := TileSet.new()
	things_ts.tile_size = Vector2i(16, 16)
	var things_src := TileSetAtlasSource.new()
	var tile3_tex = load("res://Assets/Tiles/tile3.png")
	if tile3_tex:
		things_src.texture = tile3_tex
		things_src.texture_region_size = Vector2i(16, 16)
		for r in [8, 9, 12, 13]:
			for c in [10, 11]:
				things_src.create_tile(Vector2i(c, r))
	things_ts.add_source(things_src, 4)
	things.tile_set = things_ts
	
	var farm_mgr = FarmingManagerScript.new()
	test_root.add_child(farm_mgr)
	farm_mgr.set_map_layers(terrain, things, overlay)
	
	var target_pos := Vector2(0, 0)
	var grid_pos := farm_mgr.world_to_grid(target_pos)
	
	# 1. Hoe
	farm_mgr.hoe_tile(target_pos)
	assert(terrain.get_cell_source_id(grid_pos) == 9, "TerrainLayer has FarmLand dirt source 9")
	assert(things.get_cell_source_id(grid_pos) == 4, "ThingsLayer has tile3.png source 4")
	var initial_furrow_coords := things.get_cell_atlas_coords(grid_pos)
	
	# 2. Plant
	var crop = farm_mgr.plant_seed(target_pos, "carrot_seed")
	assert(crop != null, "Crop planted")
	
	# 3. Water once -> Ground tile stays unchanged!
	farm_mgr.water_tile(target_pos)
	var post_water_furrow_coords := things.get_cell_atlas_coords(grid_pos)
	assert(post_water_furrow_coords == initial_furrow_coords, "ThingsLayer furrow tile UNCHANGED after watering!")
	assert(crop.watered == true, "Crop internal state is watered")
	
	# 4. Advance 30s to mature & harvest
	farm_mgr.advance_growth_minutes(30.0)
	assert(crop.mature == true, "Crop is mature")
	
	farm_mgr.harvest_crop(target_pos)
	assert(farm_mgr.get_crop_at(target_pos) == null, "Crop harvested")
	
	# 5. Unhoe after harvest reverts tiles
	farm_mgr.unhoe_tile(target_pos)
	assert(things.get_cell_source_id(grid_pos) == -1, "Furrow removed on ThingsLayer")
	
	test_root.free()
	print("Test 11 (Multi-Layer Pipeline): OK")


func test_12_starter_inventory_all_crops_and_seeds() -> void:
	print("\n[TEST 12] Testing Initial Inventory with All 6 Crops and 6 Seeds...")
	var test_root := Node2D.new()
	add_child(test_root)
	
	var game_script = preload("res://scripts/game.gd")
	var game = Node2D.new()
	game.set_script(game_script)
	test_root.add_child(game)
	
	var inv_scene = load("res://Scenes/UI/inventory.tscn")
	var inv = inv_scene.instantiate()
	inv.name = "Inventory"
	
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.add_child(inv)
	game.add_child(ui)

	
	# Call initial tools setup
	game._give_initial_tools()
	
	var expected_crops := ["carrot", "wheat", "watermelon", "corn", "potato", "tomato"]
	var expected_seeds := ["carrot_seed", "wheat_seed", "watermelon_seed", "corn_seed", "potato_seed", "tomato_seed"]
	
	var found_items: Array[String] = []
	for i in range(inv.slots.size()):
		var slot: Dictionary = inv.get_item_at(i)
		if slot.get("item"):
			found_items.append(slot["item"].item_id)
	for i in range(inv.hotbar_slots.size()):
		var slot: Dictionary = inv.get_hotbar_item_at(i)
		if slot.get("item"):
			found_items.append(slot["item"].item_id)
	
	for cid in expected_crops:
		assert(found_items.has(cid), "Player inventory has crop: " + cid)
	for sid in expected_seeds:
		assert(found_items.has(sid), "Player inventory has seed: " + sid)
	
	test_root.free()
	print("Test 12 (All Crops & Seeds in Inventory): OK")
