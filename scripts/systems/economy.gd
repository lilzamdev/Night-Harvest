extends RefCounted

## Night Harvest economy: shop catalogue, buy/sell prices and the v1.1 items.
##
## Faster crops sell for less; slow crops (corn, watermelon) are worth more, so
## planting is a real choice. Prices of defenses rise a little each night survived
## (supply gets scarcer as the zombies get worse), see defense_price().

const ItemDB = preload("res://scripts/item_database.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const GEN := "res://Assets/Generated/"

## Sell prices (gold per item). Items not listed cannot be sold.
const SELL := {
	"carrot": 6, "wheat": 5, "potato": 9, "tomato": 10, "corn": 14, "watermelon": 22,
	"wild_mushroom": 4, "wood_log": 2, "stone_rock": 3,
	"carrot_seed": 2, "wheat_seed": 2, "potato_seed": 3, "tomato_seed": 3, "corn_seed": 4, "watermelon_seed": 6,
	# v1.2
	"pumpkin": 60, "strawberry": 9, "sunflower": 26, "moonflower": 95,
	"pumpkin_seed": 12, "strawberry_seed": 4, "sunflower_seed": 7, "moonflower_seed": 25,
	"copper_ore": 6, "iron_ore": 12, "gold_ore": 22, "crystal_shard": 40, "gem": 75,
	"bone": 4, "slime_gel": 5,
	# v1.3
	"copper_bar": 16, "iron_bar": 30, "gold_bar": 55, "brick": 4, "fiber": 1, "berries": 2,
	"cactus_fruit": 4, "rotten_flesh": 1, "baked_potato": 20, "pumpkin_pie": 80,
	# v1.4
	"raw_beef": 6, "raw_pork": 5, "raw_mutton": 5, "raw_chicken": 4, "raw_rabbit": 3, "venison": 7,
	"steak": 14, "cooked_pork": 12, "cooked_mutton": 11, "cooked_chicken": 9, "cooked_rabbit": 7, "cooked_venison": 15,
	"leather": 8, "wool": 6, "feather": 2, "sapling": 3, "pine_sapling": 3,
	"boat": 40, "bridge_wood": 1, "sunforged_greatsword": 220, "gate_wood": 2, "sandstone": 2, "ice_chunk": 2, "mossy_cobble": 2, "driftwood": 2, "pine_log": 2, "fishing_rod": 6, "minnow": 3, "perch": 8, "trout": 12, "catfish": 16, "salmon": 18, "golden_carp": 120, "sea_bass": 14, "tuna": 26,
	"pufferfish": 45, "seaweed": 1, "old_boot": 1, "grilled_perch": 16, "grilled_trout": 22, "smoked_salmon": 30, "grilled_sea_bass": 24,
	"red_flower": 1, "yellow_flower": 1, "daisy": 1, "buttercup": 1, "blue_flower": 2, "pink_flower": 2,
}

## Shop catalogue per shopkeeper. unlock_night: available after surviving N nights.
const STOCK := {
	"general": [
		{"id": "carrot_seed", "price": 5},
		{"id": "wheat_seed", "price": 4},
		{"id": "potato_seed", "price": 8},
		{"id": "tomato_seed", "price": 9},
		{"id": "corn_seed", "price": 12},
		{"id": "watermelon_seed", "price": 18},
		{"id": "bread", "price": 12},
		{"id": "herbal_tonic", "price": 35},
		{"id": "torch", "price": 6},
		# v1.2: unlocked by town reputation (complete missions on the quest board)
		{"id": "strawberry_seed", "price": 10, "rep": 1},
		{"id": "sunflower_seed", "price": 18, "rep": 2},
		{"id": "pumpkin_seed", "price": 30, "rep": 3},
		{"id": "moonflower_seed", "price": 60, "rep": 5},
	],
	"smith": [
		{"id": "barricade", "price": 15, "defense": true},
		{"id": "spike_trap", "price": 30, "defense": true},
		{"id": "scarecrow_turret", "price": 90, "defense": true, "unlock_night": 1},
		{"id": "steel_sword", "price": 220, "unlock_night": 2},
		{"id": "steel_axe", "price": 120, "unlock_night": 1},
		{"id": "steel_pickaxe", "price": 160, "unlock_night": 1},
		{"id": "war_hammer", "price": 320, "rep": 4},
		{"id": "hoe", "price": 20},
		{"id": "wood_axe", "price": 25},
		{"id": "pickaxe", "price": 25},
		{"id": "watering_can", "price": 20},
		{"id": "torch", "price": 6},
	],
}

static var _registered := false


## Adds the v1.1 items to ItemDatabase (safe to call many times).
static func register_items() -> void:
	if _registered and ItemDB.get_item("barricade") != null:
		return
	_registered = true
	ItemDB.get_item("wood_log")  # make sure the base database is built first

	var barricade := ItemDataClass.new("barricade", "Wooden Barricade", ItemDataClass.ItemType.PLACEABLE,
		_frame(GEN + "barricade.png", 0, 16, 16), 20)
	barricade.description = "Blocks zombies. They must chew through it. Place with LEFT CLICK."
	barricade.placeable = true
	ItemDB._items["barricade"] = barricade

	var spikes := ItemDataClass.new("spike_trap", "Spike Trap", ItemDataClass.ItemType.PLACEABLE,
		_frame(GEN + "spikes.png", 0, 16, 16), 20)
	spikes.description = "Hurts and slows every zombie that steps on it."
	spikes.placeable = true
	ItemDB._items["spike_trap"] = spikes

	var turret := ItemDataClass.new("scarecrow_turret", "Scarecrow Crossbow", ItemDataClass.ItemType.PLACEABLE,
		load(GEN + "icon_turret.png"), 10)
	turret.description = "A scarecrow with a crossbow. Shoots the nearest zombie at night."
	turret.placeable = true
	ItemDB._items["scarecrow_turret"] = turret

	var bread := ItemDataClass.new("bread", "Fresh Bread", ItemDataClass.ItemType.FOOD,
		load(GEN + "icon_bread.png"), 99, ItemDataClass.ActionType.EAT)
	bread.description = "Rosa's bread. Very filling."
	bread.edible = true
	bread.hunger_restore = 30.0
	ItemDB._items["bread"] = bread

	var tonic := ItemDataClass.new("herbal_tonic", "Herbal Tonic", ItemDataClass.ItemType.FOOD,
		load(GEN + "icon_tonic.png"), 20, ItemDataClass.ActionType.EAT)
	tonic.description = "Restores 40 HP."
	tonic.edible = true
	tonic.hunger_restore = 2.0
	tonic.health_restore = 40.0
	tonic.food_category = "potion"
	ItemDB._items["herbal_tonic"] = tonic

	var sword = ItemDB.get_item("iron_sword")
	var steel := ItemDataClass.new("steel_sword", "Steel Sword", ItemDataClass.ItemType.WEAPON,
		load(GEN + "icon_steel_sword.png"), 1, ItemDataClass.ActionType.ATTACK)
	steel.description = "Ben's finest blade. Hits much harder."
	steel.usable = true
	steel.weapon_damage = 28
	steel.tool_power = 1
	if sword:
		steel.swing_speed_scale = sword.swing_speed_scale
		steel.swing_cooldown = sword.swing_cooldown
		steel.swing_range = sword.swing_range + 2.0
		steel.hitbox_radius = sword.hitbox_radius + 2.0
		steel.swoosh_scale = sword.swoosh_scale * 1.15
		steel.knockback_force = 65.0
	steel.swoosh_color = Color(0.8, 0.95, 1.0, 0.95)
	ItemDB._items["steel_sword"] = steel

	# Shop text for the starter tools (they had none).
	var tool_desc := {
		"hoe": "Spare hoe. Tills grass to soil.",
		"wood_axe": "Chops trees. Four swings each.",
		"pickaxe": "Breaks rocks for stone.",
		"watering_can": "Waters crops so they grow.",
		"iron_sword": "Your trusty blade.",
	}
	for tid in tool_desc:
		var t = ItemDB.get_item(tid)
		if t and str(t.description) == "":
			t.description = tool_desc[tid]

	var axe = ItemDB.get_item("wood_axe")
	var steel_axe := ItemDataClass.new("steel_axe", "Steel Axe", ItemDataClass.ItemType.TOOL,
		load(GEN + "icon_steel_axe.png"), 1, ItemDataClass.ActionType.CHOP)
	steel_axe.description = "Fells trees in two swings."
	steel_axe.usable = true
	steel_axe.tool_power = 2
	steel_axe.weapon_damage = 14
	if axe:
		steel_axe.swing_speed_scale = axe.swing_speed_scale * 1.1
		steel_axe.swing_cooldown = axe.swing_cooldown
		steel_axe.swing_range = axe.swing_range
		steel_axe.hitbox_radius = axe.hitbox_radius
		steel_axe.swoosh_scale = axe.swoosh_scale
	steel_axe.swoosh_color = Color(0.8, 0.95, 1.0, 0.95)
	ItemDB._items["steel_axe"] = steel_axe

	load("res://scripts/systems/items_v12.gd").register(ItemDB._items)


static func sell_price(item_id: String) -> int:
	return int(SELL.get(item_id, 0))


static func can_sell(item_id: String) -> bool:
	return SELL.has(item_id)


## Defenses get 10% pricier for every 3 nights survived (capped at +60%).
static func defense_price(base: int, nights: int, mult: float) -> int:
	var inflation := 1.0 + minf(0.6, 0.1 * float(nights / 3))
	return maxi(1, int(round(base * inflation * mult)))


static func _frame(path: String, idx: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(path)
	a.region = Rect2(idx * w, 0, w, h)
	return a
