extends RefCounted

## Night Harvest 1.3 items: wooden & stone tools, copper tools, metal bars, bricks,
## building blocks and furniture, wild food, zombie drops, boss summons and boss
## weapons. Also tidies up names and puts every tool on one clear tier ladder:
##
##   Wooden -> Stone -> Copper -> Iron -> Golden -> Crystal   (+ boss weapons)
##
## Pickaxe power decides which rocks break: stone 1, copper 2, iron 3, gold 4,
## crystal/gem 5. Registered at the end of items_v12.register().

const ItemDataClass = preload("res://scripts/item_data.gd")
const V12 := "res://Assets/Generated/v12/"
const V13 := "res://Assets/Generated/v13/"
const GEN := "res://Assets/Generated/"


static func _icon(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


static func register(items: Dictionary) -> void:
	var sword = items.get("iron_sword")
	var pick = items.get("pickaxe")
	var axe = items.get("wood_axe")
	var hoe = items.get("hoe")

	# ---------------------------------------------------------------- names
	var names := {
		"wood_log": ["Wood", "Logs from a felled tree. The start of everything."],
		"stone_rock": ["Stone", "Broken from rocks with a pickaxe."],
		"wood_axe": ["Wooden Axe", "Chops trees. Four swings each."],
		"pickaxe": ["Wooden Pickaxe", "Breaks stone. Too soft for ore."],
		"hoe": ["Wooden Hoe", "Tills grass into farm soil."],
		"iron_sword": ["Rusty Sword", "An old blade. Better than your fists."],
		"steel_sword": ["Iron Sword", "Forged from iron bars. Hits hard."],
		"steel_axe": ["Iron Axe", "Fells trees in two quick swings."],
		"steel_pickaxe": ["Iron Pickaxe", "Breaks iron and gold ore."],
		"copper_sword": ["Copper Sword", "Sharper than stone. Forged from copper bars."],
		"gold_pickaxe": ["Golden Pickaxe", "Breaks Hollow crystal and rose gems."],
		"gold_axe": ["Golden Axe", "Fells a tree in one swing."],
		"crystal_pickaxe": ["Crystal Pickaxe", "The best pickaxe there is. Breaks everything fast."],
		"bone": ["Bone", "Dropped by skeletons and zombies. Useful for crafting."],
		"bread": ["Bread", "Baked from wheat. Very filling."],
		"stone_wall": ["Stone Barricade", "A tough barricade. Zombies chew it slowly."],
		"barricade": ["Wooden Barricade", "Blocks zombies. They must chew through it."],
		"wild_mushroom": ["Wild Mushroom", "Grows in forests. Edible, and used for tonics."],
		"watering_can": ["Watering Can", "Waters crops so they grow."],
		"torch": ["Torch", "Light in the darkness. Right-click to place it."],
	}
	for id in names:
		var it = items.get(id)
		if it:
			it.display_name = names[id][0]
			it.description = names[id][1]
	for sid in ["carrot_seed", "wheat_seed", "watermelon_seed", "corn_seed", "potato_seed", "tomato_seed"]:
		var s = items.get(sid)
		if s:
			s.display_name = str(s.display_name).replace(" Seed", "") + " Seeds"
			if str(s.description) == "":
				s.description = "Plant on tilled soil and water every day."
	var mush = items.get("wild_mushroom")
	if mush:
		mush.item_type = ItemDataClass.ItemType.FOOD
		mush.action_type = ItemDataClass.ActionType.EAT
		mush.edible = true
		mush.hunger_restore = 6.0
	# Placeable wording
	for id in ["barricade", "stone_wall", "spike_trap", "scarecrow_turret", "iron_spikes", "lantern_post", "sprinkler"]:
		var p = items.get(id)
		if p and not str(p.description).ends_with("LEFT CLICK."):
			p.description = str(p.description) + " Place with LEFT CLICK."

	# ---------------------------------------------------------------- tool ladder
	if pick:
		pick.tool_power = 1
	if axe:
		axe.tool_power = 1
	_set_power(items, "steel_pickaxe", 4)
	_set_power(items, "gold_pickaxe", 5)
	_set_power(items, "crystal_pickaxe", 6)
	_set_power(items, "steel_axe", 2)
	_set_power(items, "gold_axe", 4)
	if items.has("steel_axe") and axe:
		items["steel_axe"].swing_cooldown = maxf(0.08, axe.swing_cooldown * 0.75)

	_tool(items, "stone_pickaxe", "Stone Pickaxe", V13 + "icon_stone_pickaxe.png", 2, ItemDataClass.ActionType.MINE, pick, "Breaks copper ore as well as stone.")
	_tool(items, "copper_pickaxe", "Copper Pickaxe", V12 + "icon_copper_pickaxe.png", 3, ItemDataClass.ActionType.MINE, pick, "Breaks iron ore.")
	_tool(items, "stone_axe", "Stone Axe", V13 + "icon_stone_axe.png", 2, ItemDataClass.ActionType.CHOP, axe, "Fells trees in two swings.")
	_tool(items, "copper_axe", "Copper Axe", V12 + "icon_copper_axe.png", 2, ItemDataClass.ActionType.CHOP, axe, "Fells trees in two swings. Quick.")
	if items.has("copper_axe") and axe:
		items["copper_axe"].swing_cooldown = maxf(0.08, axe.swing_cooldown * 0.85)
	if items.has("stone_axe") and axe:
		items["stone_axe"].swing_cooldown = axe.swing_cooldown * 1.15
	# Hoe / watering can icons stay; a stone hoe tills nothing better, so only wooden.

	_weapon(items, "wooden_sword", "Wooden Sword", V13 + "icon_wooden_sword.png", 8, 35.0, sword, "Carved from wood. Better than nothing.")
	_weapon(items, "stone_sword", "Stone Sword", V13 + "icon_stone_sword.png", 12, 45.0, sword, "A sharp stone edge on a wooden grip.")
	_weapon(items, "bone_cleaver", "Bone Cleaver", V13 + "icon_bone_cleaver.png", 46, 120.0, sword, "Torn from the Rotting Giant. Heavy and brutal.")
	_weapon(items, "plague_scythe", "Plague Scythe", V13 + "icon_plague_scythe.png", 64, 80.0, sword, "The Plague Mother's scythe. Wide, poisonous swings.")
	if items.has("bone_cleaver"):
		var bc = items["bone_cleaver"]
		bc.swing_cooldown += 0.15
		bc.swing_speed_scale *= 0.85
		bc.swoosh_scale *= 1.25
		bc.swoosh_color = Color(1.0, 0.95, 0.85, 0.95)
	if items.has("plague_scythe"):
		var ps = items["plague_scythe"]
		ps.swing_range += 6.0
		ps.hitbox_radius += 4.0
		ps.swoosh_scale *= 1.4
		ps.swoosh_color = Color(0.6, 1.0, 0.45, 0.95)
	if sword:
		sword.weapon_damage = 15

	# ---------------------------------------------------------------- materials
	for m in [
		["copper_bar", "Copper Bar", V12 + "icon_copper_bar.png", "Smelted copper. Forge copper tools at an anvil."],
		["iron_bar", "Iron Bar", V12 + "icon_iron_bar.png", "Smelted iron. For iron tools, the anvil and turrets."],
		["gold_bar", "Gold Bar", V12 + "icon_gold_bar.png", "Smelted gold. For golden gear and boss idols."],
		["brick", "Brick", V13 + "brick_item.png", "Fired in a furnace from stone. Builds brick walls."],
		["fiber", "Plant Fiber", V13 + "icon_fiber.png", "Cut from tall grass. For torches, fences, traps and beds."],
		["rotten_flesh", "Rotten Flesh", V13 + "icon_rotten_flesh.png", "Dropped by zombies. Eat only if you must."],
		["giant_heart", "Giant's Heart", V13 + "icon_giant_heart.png", "Still beating. Eat it to grow stronger for good."],
	]:
		var it := ItemDataClass.new(m[0], m[1], ItemDataClass.ItemType.MATERIAL, _icon(m[2]), 99)
		it.description = m[3]
		items[m[0]] = it
	var flesh = items["rotten_flesh"]
	flesh.item_type = ItemDataClass.ItemType.FOOD
	flesh.action_type = ItemDataClass.ActionType.EAT
	flesh.edible = true
	flesh.hunger_restore = 8.0
	flesh.health_restore = -4.0
	var heart = items["giant_heart"]
	heart.item_type = ItemDataClass.ItemType.FOOD
	heart.action_type = ItemDataClass.ActionType.EAT
	heart.edible = true
	heart.hunger_restore = 40.0
	heart.health_restore = 100.0
	heart.food_category = "heart"
	heart.max_stack = 5

	# ---------------------------------------------------------------- food
	for f in [
		["berries", "Wild Berries", V13 + "icon_berries.png", 7.0, 0.0, "Picked from berry bushes. Sweet and quick."],
		["cactus_fruit", "Cactus Fruit", V13 + "cactus.png", 10.0, 2.0, "Cut from a desert cactus. Juicy."],
		["baked_potato", "Baked Potato", "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png", 28.0, 6.0, "Hot from the furnace. Very filling."],
		["pumpkin_pie", "Pumpkin Pie", V12 + "icon_pumpkin.png", 45.0, 15.0, "A whole pie. Fills you up and heals a little."],
	]:
		var it2 := ItemDataClass.new(f[0], f[1], ItemDataClass.ItemType.FOOD, _icon(f[2]), 99, ItemDataClass.ActionType.EAT)
		it2.edible = true
		it2.hunger_restore = f[3]
		it2.health_restore = f[4]
		it2.description = f[5]
		items[f[0]] = it2
	var potato = items.get("potato")
	if potato and potato.icon:
		items["baked_potato"].icon = potato.icon
		items["baked_potato"].world_texture = potato.icon
		items["baked_potato"].held_texture = potato.icon
		items["baked_potato"].icon = _tinted(potato.icon)
	var cac := AtlasTexture.new()
	cac.atlas = _icon(V13 + "cactus.png")
	cac.region = Rect2(0, 0, 16, 16)
	for k in ["icon", "world_texture", "held_texture"]:
		items["cactus_fruit"].set(k, cac)

	# ---------------------------------------------------------------- boss summons
	for s in [
		["rotten_totem", "Rotten Totem", V13 + "icon_rotten_totem.png", "Use at night to call the Rotting Giant. Only if you're ready."],
		["plague_idol", "Plague Idol", V13 + "icon_plague_idol.png", "Use at night to call the Plague Mother. She is far worse."],
	]:
		var si := ItemDataClass.new(s[0], s[1], ItemDataClass.ItemType.TOOL, _icon(s[2]), 5, ItemDataClass.ActionType.USE)
		si.usable = true
		si.description = s[3]
		si.weapon_damage = 5
		items[s[0]] = si

	# ---------------------------------------------------------------- building
	for b in [
		["wall_wood", "Wooden Wall", V13 + "icon_wall_wood.png", "Build walls for your house. Zombies can chew through."],
		["wall_stone", "Stone Wall", V13 + "icon_wall_stone.png", "Twice as tough as wood."],
		["wall_brick", "Brick Wall", V13 + "icon_wall_brick.png", "The toughest wall you can build."],
		["floor_wood", "Wooden Floor", V13 + "icon_floor_wood.png", "Floor for your house. On water it makes a bridge."],
		["floor_stone", "Stone Floor", V13 + "icon_floor_stone.png", "A sturdy stone floor."],
		["floor_brick", "Brick Floor", V13 + "icon_floor_brick.png", "A warm brick floor."],
		["door_wood", "Wooden Door", V13 + "icon_door_wood.png", "Press E to open or close. Zombies try to break it."],
		["fence_wood", "Wooden Fence", V13 + "icon_fence_wood.png", "Keeps animals in and slows zombies down."],
		["chest", "Chest", V13 + "icon_chest.png", "Stores 24 stacks of items."],
		["bed", "Bed", V13 + "icon_bed.png", "Sleep through the night. You wake up here if you fall."],
		["workbench", "Workbench", V13 + "icon_workbench.png", "Craft tools, blocks and furniture."],
		["furnace", "Furnace", V13 + "icon_furnace.png", "Smelt ore into bars, fire bricks and cook food."],
		["anvil", "Anvil", V13 + "icon_anvil.png", "Forge metal tools and weapons."],
		["watch_tower", "Watch Tower", V13 + "icon_watch_tower.png", "Climb it (E) at night to spot zombies coming."],
	]:
		var bi := ItemDataClass.new(b[0], b[1], ItemDataClass.ItemType.PLACEABLE, _icon(b[2]), 99 if not b[0] in ["bed", "workbench", "furnace", "anvil", "chest", "watch_tower"] else 10)
		bi.placeable = true
		bi.description = b[3] + " Place with LEFT CLICK."
		bi.swing_cooldown = 0.12
		items[b[0]] = bi


static func _tinted(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.r * 0.85 + 0.12, c.g * 0.7 + 0.05, c.b * 0.45, c.a))
	return ImageTexture.create_from_image(img)


static func _set_power(items: Dictionary, id: String, p: int) -> void:
	if items.has(id):
		items[id].tool_power = p


static func _tool(items: Dictionary, id: String, name: String, icon: String, power: int, action: int, base, desc: String) -> void:
	var it := ItemDataClass.new(id, name, ItemDataClass.ItemType.TOOL, _icon(icon), 1, action)
	it.usable = true
	it.tool_power = power
	it.weapon_damage = 8 + power * 2
	it.description = desc
	if base:
		it.swing_speed_scale = base.swing_speed_scale
		it.swing_cooldown = base.swing_cooldown
		it.swing_range = base.swing_range
		it.hitbox_radius = base.hitbox_radius
		it.swoosh_scale = base.swoosh_scale
	items[id] = it


static func _weapon(items: Dictionary, id: String, name: String, icon: String, dmg: int, kb: float, base, desc: String) -> void:
	var it := ItemDataClass.new(id, name, ItemDataClass.ItemType.WEAPON, _icon(icon), 1, ItemDataClass.ActionType.ATTACK)
	it.usable = true
	it.weapon_damage = dmg
	it.knockback_force = kb
	it.description = desc
	if base:
		it.swing_speed_scale = base.swing_speed_scale
		it.swing_cooldown = base.swing_cooldown
		it.swing_range = base.swing_range
		it.hitbox_radius = base.hitbox_radius
		it.swoosh_scale = base.swoosh_scale
	items[id] = it
