extends RefCounted
class_name ItemDatabase

const ItemDataClass = preload("res://scripts/item_data.gd")
const DECOR_TEXTURE_PATH := "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png"
const TOOLS_TEXTURE_PATH := "res://Assets/Items/tools.png"
const RPG_CHESTS_TEXTURE_PATH := "res://Assets/Outdoor decoration/RPG Chests.png"

static var _items: Dictionary = {}
static var _decor_texture: Texture2D = null
static var _tools_texture: Texture2D = null
static var _rpg_chests_texture: Texture2D = null


static func get_rpg_chest_texture(chest_index: int = 7, frame_idx: int = 0) -> AtlasTexture:
	if not _rpg_chests_texture:
		_rpg_chests_texture = load(RPG_CHESTS_TEXTURE_PATH)
	
	var total_w := _rpg_chests_texture.get_width()
	var total_h := _rpg_chests_texture.get_height()
	var frame_w: int = int(total_w / 9.0)
	var frame_h: int = int(total_h / 4.0)
	
	var col: int = clamp(chest_index - 1, 0, 8) # Chest 7 is index 6
	var row: int = clamp(frame_idx, 0, 3)
	
	var atlas := AtlasTexture.new()
	atlas.atlas = _rpg_chests_texture
	atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	return atlas


static func get_decor_texture(col: int, row: int, tile_w: int = 16, tile_h: int = 16) -> AtlasTexture:
	if not _decor_texture:
		_decor_texture = load(DECOR_TEXTURE_PATH)
	
	var atlas := AtlasTexture.new()
	atlas.atlas = _decor_texture
	atlas.region = Rect2(col * tile_w, row * tile_h, tile_w, tile_h)
	return atlas


static func get_tool_texture(col: int, tile_w: int = 16, tile_h: int = 16) -> AtlasTexture:
	if not _tools_texture:
		_tools_texture = load(TOOLS_TEXTURE_PATH)
	
	var atlas := AtlasTexture.new()
	atlas.atlas = _tools_texture
	atlas.region = Rect2(col * tile_w, 0, tile_w, tile_h)
	return atlas


static func get_item(item_id: String) -> Resource:
	_init_database_if_needed()
	if _items.has(item_id):
		return _items[item_id]
	return null


static func _init_database_if_needed() -> void:
	if not _items.is_empty():
		return
	
	# Wood Log (Row 7, Col 0 - 32x16 log)
	var wood_log = ItemDataClass.new(
		"wood_log",
		"Wood Log",
		ItemDataClass.ItemType.MATERIAL,
		get_decor_texture(0, 7, 32, 16),
		99
	)
	wood_log.swing_speed_scale = 1.0
	wood_log.swing_cooldown = 0.2
	_items["wood_log"] = wood_log
	
	# Stone Rock (Row 2, Col 2 - medium rock)
	var stone_rock = ItemDataClass.new(
		"stone_rock",
		"Stone Rock",
		ItemDataClass.ItemType.MATERIAL,
		get_decor_texture(2, 2),
		99
	)
	stone_rock.swing_speed_scale = 1.0
	stone_rock.swing_cooldown = 0.2
	_items["stone_rock"] = stone_rock
	
	# Wild Mushroom (Row 7, Col 2 - red mushroom)
	var wild_mushroom = ItemDataClass.new(
		"wild_mushroom",
		"Wild Mushroom",
		ItemDataClass.ItemType.CROP,
		get_decor_texture(2, 7),
		99
	)
	_items["wild_mushroom"] = wild_mushroom
	
	# Wheat Seed (Row 0, Col 6 - wheat seed pouch)
	var wheat_seed = ItemDataClass.new(
		"wheat_seed",
		"Wheat Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(6, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["wheat_seed"] = wheat_seed
	
	# Carrot Seed (Row 0, Col 4 - carrot seed pouch)
	var carrot_seed = ItemDataClass.new(
		"carrot_seed",
		"Carrot Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(4, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["carrot_seed"] = carrot_seed
	
	# Watermelon Seed
	var watermelon_seed = ItemDataClass.new(
		"watermelon_seed",
		"Watermelon Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(3, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["watermelon_seed"] = watermelon_seed
	
	# Corn Seed
	var corn_seed = ItemDataClass.new(
		"corn_seed",
		"Corn Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(5, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["corn_seed"] = corn_seed
	
	# Potato Seed
	var potato_seed = ItemDataClass.new(
		"potato_seed",
		"Potato Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(4, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["potato_seed"] = potato_seed
	
	# Tomato Seed
	var tomato_seed = ItemDataClass.new(
		"tomato_seed",
		"Tomato Seed",
		ItemDataClass.ItemType.SEED,
		get_decor_texture(3, 0),
		99,
		ItemDataClass.ActionType.PLANT
	)
	_items["tomato_seed"] = tomato_seed

	
	# Iron Sword (Col 0 in tools.png) - Fast, wide combat slash with high damage
	var sword = ItemDataClass.new(
		"iron_sword",
		"Iron Sword",
		ItemDataClass.ItemType.WEAPON,
		get_tool_texture(0),
		1,
		ItemDataClass.ActionType.ATTACK
	)
	sword.usable = true
	sword.weapon_damage = 15
	sword.tool_power = 1
	sword.swing_speed_scale = 1.35
	sword.swing_cooldown = 0.12
	sword.swing_range = 28.0
	sword.hitbox_radius = 16.0
	sword.swoosh_scale = Vector2(1.2, 1.2)
	sword.swoosh_color = Color(0.95, 0.98, 1.0, 0.95)
	sword.knockback_force = 50.0
	_items["iron_sword"] = sword
	
	# Wood Axe (Col 1 in tools.png) - Medium-heavy rhythm tree chopping
	var axe = ItemDataClass.new(
		"wood_axe",
		"Wood Axe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(1),
		1,
		ItemDataClass.ActionType.CHOP
	)
	axe.usable = true
	axe.tool_power = 1
	axe.weapon_damage = 8
	axe.swing_speed_scale = 1.0
	axe.swing_cooldown = 0.22
	axe.swing_range = 24.0
	axe.hitbox_radius = 14.0
	axe.swoosh_scale = Vector2(1.0, 1.0)
	axe.swoosh_color = Color(1.0, 0.92, 0.75, 0.9)
	axe.knockback_force = 35.0
	_items["wood_axe"] = axe
	
	# Watering Can (Col 2 in tools.png)
	var can = ItemDataClass.new(
		"watering_can",
		"Watering Can",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(2),
		1,
		ItemDataClass.ActionType.WATER
	)
	can.usable = true
	can.swing_speed_scale = 1.0
	can.swing_cooldown = 0.2
	_items["watering_can"] = can
	
	# Pickaxe (Col 3 in tools.png) - Heavy deliberate mining swing
	var pick = ItemDataClass.new(
		"pickaxe",
		"Pickaxe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(3),
		1,
		ItemDataClass.ActionType.MINE
	)
	pick.usable = true
	pick.tool_power = 1
	pick.weapon_damage = 7
	pick.swing_speed_scale = 0.85
	pick.swing_cooldown = 0.28
	pick.swing_range = 22.0
	pick.hitbox_radius = 13.0
	pick.swoosh_scale = Vector2(0.9, 0.9)
	pick.swoosh_color = Color(0.85, 0.85, 0.9, 0.85)
	pick.knockback_force = 30.0
	_items["pickaxe"] = pick
	
	# Hoe (Col 4 in tools.png) - Medium tilling rhythm
	var hoe = ItemDataClass.new(
		"hoe",
		"Hoe",
		ItemDataClass.ItemType.TOOL,
		get_tool_texture(4),
		1,
		ItemDataClass.ActionType.TILL
	)
	hoe.usable = true
	hoe.tool_power = 1
	hoe.weapon_damage = 5
	hoe.swing_speed_scale = 1.1
	hoe.swing_cooldown = 0.18
	hoe.swing_range = 22.0
	hoe.hitbox_radius = 12.0
	hoe.swoosh_scale = Vector2(0.95, 0.95)
	hoe.swoosh_color = Color(0.9, 0.85, 0.7, 0.85)
	hoe.knockback_force = 25.0
	_items["hoe"] = hoe
	
	# Torch (Utility / Light source)
	var torch_tex: Texture2D = null
	if ResourceLoader.exists("res://Assets/Items/torch.png"):
		torch_tex = load("res://Assets/Items/torch.png")
	if not torch_tex and FileAccess.file_exists("res://Assets/Items/torch.png"):
		var img := Image.load_from_file("res://Assets/Items/torch.png")
		if img:
			torch_tex = ImageTexture.create_from_image(img)
	
	var torch = ItemDataClass.new(
		"torch",
		"Torch",
		ItemDataClass.ItemType.TOOL,
		torch_tex,
		99,
		ItemDataClass.ActionType.NONE
	)
	torch.description = "A wooden torch that provides warm light in the darkness."
	torch.usable = false
	_items["torch"] = torch
	
	# Carrot (Row 3, Col 4 in Outdoor_Decor_Free.png - fresh harvested carrot)
	var carrot = ItemDataClass.new(
		"carrot",
		"Carrot",
		ItemDataClass.ItemType.FOOD,
		get_decor_texture(4, 3),
		99,
		ItemDataClass.ActionType.EAT
	)
	carrot.description = "A crisp, freshly harvested orange carrot."
	carrot.edible = true
	carrot.hunger_restore = 8.0
	_items["carrot"] = carrot
	
	# Wheat
	var wheat = ItemDataClass.new(
		"wheat",
		"Wheat",
		ItemDataClass.ItemType.CROP,
		get_decor_texture(5, 3),
		99,
		ItemDataClass.ActionType.NONE
	)
	wheat.description = "Golden stalks of freshly harvested wheat."
	_items["wheat"] = wheat
	
	# Watermelon
	var watermelon = ItemDataClass.new(
		"watermelon",
		"Watermelon",
		ItemDataClass.ItemType.FOOD,
		get_decor_texture(6, 3),
		99,
		ItemDataClass.ActionType.EAT
	)
	watermelon.description = "A juicy, sweet harvested watermelon."
	watermelon.edible = true
	watermelon.hunger_restore = 18.0
	_items["watermelon"] = watermelon
	
	# Corn
	var corn = ItemDataClass.new(
		"corn",
		"Corn",
		ItemDataClass.ItemType.FOOD,
		get_decor_texture(6, 2),
		99,
		ItemDataClass.ActionType.EAT
	)
	corn.description = "Freshly picked ear of golden sweet corn."
	corn.edible = true
	corn.hunger_restore = 12.0
	_items["corn"] = corn
	
	# Potato
	var potato = ItemDataClass.new(
		"potato",
		"Potato",
		ItemDataClass.ItemType.FOOD,
		get_decor_texture(2, 2),
		99,
		ItemDataClass.ActionType.EAT
	)
	potato.description = "A hearty, freshly dug earthy potato."
	potato.edible = true
	potato.hunger_restore = 10.0
	_items["potato"] = potato
	
	# Tomato
	var tomato = ItemDataClass.new(
		"tomato",
		"Tomato",
		ItemDataClass.ItemType.FOOD,
		get_decor_texture(3, 3),
		99,
		ItemDataClass.ActionType.EAT
	)
	tomato.description = "A ripe, vibrant red garden tomato."
	tomato.edible = true
	tomato.hunger_restore = 8.0
	_items["tomato"] = tomato
