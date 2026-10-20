extends RefCounted

## Night Harvest 1.2 items: ores and monster drops from The Hollow Mines, tiered
## tools and weapons, crafted buildables and the four new crops.
## Registered into ItemDatabase by economy.gd (register_items()).

const ItemDB = preload("res://scripts/item_database.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const V12 := "res://Assets/Generated/v12/"

const MATERIALS := [
	# id, name, icon, description
	["copper_ore", "Copper Ore", "icon_copper_ore", "Soft orange ore from the upper mines."],
	["iron_ore", "Iron Ore", "icon_iron_ore", "Heavy ore from floor 5 and below."],
	["gold_ore", "Gold Ore", "icon_gold_ore", "Gleaming ore from floor 10 and below."],
	["crystal_shard", "Hollow Crystal", "icon_crystal", "Cold, humming crystal from the deepest floors."],
	["gem", "Rose Gem", "icon_gem", "A rare gem. Rosa pays very well for these."],
	["bone", "Old Bone", "icon_bone", "Dropped by skeletons. Useful for crafting."],
	["slime_gel", "Slime Gel", "icon_slime_gel", "Sticky. Makes tonics stronger."],
	["hollow_crown", "Hollow Crown", "icon_crown", "Taken from the Hollow King. It still feels warm."],
]

const CROPS := [
	# id, name, hunger, description
	["pumpkin", "Pumpkin", 25.0, "Huge and heavy. Sells for a fortune."],
	["strawberry", "Strawberry", 6.0, "Sweet! Each plant gives two or three."],
	["sunflower", "Sunflower", 0.0, "Pretty, and the town buys them for festivals."],
	["moonflower", "Moonflower", 0.0, "Only grows at night. Glows faintly. Very valuable."],
]


static func register(items: Dictionary) -> void:
	for m in MATERIALS:
		var it := ItemDataClass.new(m[0], m[1], ItemDataClass.ItemType.MATERIAL, _icon(m[2]), 99)
		it.description = m[3]
		if m[0] == "hollow_crown":
			it.max_stack = 1
		items[m[0]] = it

	for c in CROPS:
		var id: String = c[0]
		var edible: bool = float(c[2]) > 0.0
		var crop := ItemDataClass.new(id, c[1], ItemDataClass.ItemType.FOOD if edible else ItemDataClass.ItemType.CROP,
			_icon("icon_" + id), 99, ItemDataClass.ActionType.EAT if edible else ItemDataClass.ActionType.NONE)
		crop.description = c[3]
		crop.edible = edible
		crop.hunger_restore = float(c[2])
		items[id] = crop
		var seed := ItemDataClass.new(id + "_seed", c[1] + " Seeds", ItemDataClass.ItemType.SEED,
			_icon("icon_%s_seed" % id), 99, ItemDataClass.ActionType.PLANT)
		seed.description = "Plant on tilled soil and water." + (" Grows only at night." if id == "moonflower" else "")
		items[id + "_seed"] = seed

	var sword = items.get("iron_sword")
	var pick = items.get("pickaxe")
	var axe = items.get("wood_axe")
	# Weapons: id, name, icon, damage, knockback, desc
	for w in [
		["copper_sword", "Copper Sword", "icon_copper_sword", 18, 50.0, "Better than iron. Forged from copper ore."],
		["gold_sword", "Golden Sword", "icon_gold_sword", 38, 70.0, "Heavy, bright and brutal."],
		["crystal_sword", "Crystal Sword", "icon_crystal_sword", 54, 75.0, "Hums when the dead are near."],
		["hollow_blade", "Hollow Blade", "icon_hollow_blade", 80, 90.0, "Forged from the Hollow King's crown."],
		["war_hammer", "War Hammer", "icon_hammer", 34, 170.0, "Slow, but sends zombies flying."],
	]:
		var it := ItemDataClass.new(w[0], w[1], ItemDataClass.ItemType.WEAPON, _icon(w[2]), 1, ItemDataClass.ActionType.ATTACK)
		it.usable = true
		it.weapon_damage = w[3]
		it.knockback_force = w[4]
		it.description = w[5]
		if sword:
			it.swing_speed_scale = sword.swing_speed_scale
			it.swing_cooldown = sword.swing_cooldown
			it.swing_range = sword.swing_range + 2.0
			it.hitbox_radius = sword.hitbox_radius + 2.0
			it.swoosh_scale = sword.swoosh_scale * 1.15
		match w[0]:
			"gold_sword":
				it.swoosh_color = Color(1.0, 0.9, 0.5, 0.95)
			"crystal_sword", "hollow_blade":
				it.swoosh_color = Color(0.7, 1.0, 0.95, 0.95)
				it.swoosh_scale *= 1.15
			"war_hammer":
				it.swing_speed_scale *= 0.75
				it.swing_cooldown += 0.25
				it.swoosh_scale *= 1.3
				it.swoosh_color = Color(1.0, 0.85, 0.7, 0.9)
		items[w[0]] = it
	# Pickaxes / axes: id, name, icon, power, action, desc
	for t in [
		["steel_pickaxe", "Steel Pickaxe", "icon_steel_pickaxe", 2, ItemDataClass.ActionType.MINE, "Breaks iron and gold rocks."],
		["gold_pickaxe", "Golden Pickaxe", "icon_gold_pickaxe", 3, ItemDataClass.ActionType.MINE, "Breaks anything but Hollow crystal."],
		["crystal_pickaxe", "Crystal Pickaxe", "icon_crystal_pickaxe", 4, ItemDataClass.ActionType.MINE, "Cuts through crystal like butter."],
		["gold_axe", "Golden Axe", "icon_gold_axe", 4, ItemDataClass.ActionType.CHOP, "Fells a tree in one swing."],
	]:
		var it := ItemDataClass.new(t[0], t[1], ItemDataClass.ItemType.TOOL, _icon(t[2]), 1, t[4])
		it.usable = true
		it.tool_power = t[3]
		it.weapon_damage = 10 + t[3] * 3
		it.description = t[5]
		var base = pick if t[4] == ItemDataClass.ActionType.MINE else axe
		if base:
			it.swing_speed_scale = base.swing_speed_scale * (1.0 + 0.08 * t[3])
			it.swing_cooldown = base.swing_cooldown
			it.swing_range = base.swing_range
			it.hitbox_radius = base.hitbox_radius
			it.swoosh_scale = base.swoosh_scale
		items[t[0]] = it
	if pick and str(pick.description) == "":
		pick.description = "Breaks stone and copper rocks."

	# Crafted buildables
	for b in [
		["stone_wall", "Stone Wall", "icon_stone_wall", "Much tougher than a barricade."],
		["iron_spikes", "Iron Spikes", "icon_iron_spikes", "Spike trap that hurts twice as much and lasts longer."],
		["lantern_post", "Lantern Post", "icon_lantern_post", "Lights your farm at night and slows zombies in its glow."],
		["sprinkler", "Sprinkler", "icon_sprinkler", "Waters the 8 tiles around it by itself."],
	]:
		var it := ItemDataClass.new(b[0], b[1], ItemDataClass.ItemType.PLACEABLE, _icon(b[2]), 20)
		it.description = b[3] + " Place with LEFT CLICK."
		it.placeable = true
		items[b[0]] = it

	# v1.3: wooden/stone/copper tiers, building blocks, new food and tidy names
	load("res://scripts/systems/items_v13.gd").register(items)


static func _icon(name: String) -> Texture2D:
	var path := V12 + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null
