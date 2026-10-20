extends RefCounted

## Items added in 1.3.1 / 1.4: decorations (furniture, lamps, flowers, rugs, wall pieces).
## Registered from items_v13.register(), so every item lookup sees them.

const ItemDataClass = preload("res://scripts/item_data.gd")
const DecorScript = preload("res://scripts/systems/decor.gd")

const FLOWERS := ["red_flower", "yellow_flower", "daisy", "buttercup", "blue_flower", "pink_flower"]


const V131 := "res://Assets/Generated/v131/"
## Items whose icon showed the wrong thing (a crystal for the tomato, a rock for the potato...)
const ICON_FIX := ["tomato", "potato", "baked_potato", "watermelon", "corn", "wheat", "pumpkin_pie",
	"tomato_seed", "potato_seed", "watermelon_seed", "corn_seed"]


static func register(items: Dictionary) -> void:
	for id in ICON_FIX:
		var path := V131 + "icon_%s.png" % id
		if items.has(id) and ResourceLoader.exists(path):
			items[id].icon = load(path)
			items[id].world_texture = null
			items[id].held_texture = null
	# meat from hunting (cook it in the furnace - much more filling)
	for f in [
		["raw_beef", "Raw Beef", 8.0, 0.0, "From a cow. Cook it in the furnace."],
		["steak", "Steak", 34.0, 8.0, "A juicy cooked steak."],
		["raw_pork", "Raw Pork", 7.0, 0.0, "From a pig. Cook it in the furnace."],
		["cooked_pork", "Cooked Pork", 30.0, 6.0, "Crispy roast pork."],
		["raw_mutton", "Raw Mutton", 6.0, 0.0, "From a sheep or goat. Cook it in the furnace."],
		["cooked_mutton", "Cooked Mutton", 26.0, 5.0, "Tender roast mutton."],
		["raw_chicken", "Raw Chicken", 5.0, 0.0, "From a chicken or duck. Cook it first!"],
		["cooked_chicken", "Roast Chicken", 22.0, 4.0, "Golden roast chicken."],
		["raw_rabbit", "Raw Rabbit", 4.0, 0.0, "From a rabbit or hare. Cook it in the furnace."],
		["cooked_rabbit", "Rabbit Stew Meat", 18.0, 4.0, "Lean cooked rabbit."],
		["venison", "Raw Venison", 8.0, 0.0, "From a deer. Cook it in the furnace."],
		["cooked_venison", "Venison Steak", 32.0, 8.0, "A rich, gamey steak."],
	]:
		var m := ItemDataClass.new(f[0], f[1], ItemDataClass.ItemType.FOOD, load(V131 + "icon_%s.png" % f[0]), 99, ItemDataClass.ActionType.EAT)
		m.edible = true
		m.hunger_restore = f[2]
		m.health_restore = f[3]
		m.description = f[4]
		items[f[0]] = m
	# biome building blocks + the materials they're made from
	for m in [["sandstone", "Sandstone", "Soft desert stone. Mine rocks in the DESERT. Builds sandstone walls and floors."],
			["ice_chunk", "Ice Chunk", "Clear ice. Mine rocks in the SNOWFIELDS. Builds ice walls and floors."],
			["mossy_cobble", "Mossy Cobble", "Old stone with moss. Mine rocks in the HIGHLANDS."],
			["driftwood", "Driftwood", "Sea-bleached wood. From island trees, or fished out of the sea."],
			["pine_log", "Pine Log", "Dark red wood from pine trees."]]:
		var mi := ItemDataClass.new(m[0], m[1], ItemDataClass.ItemType.MATERIAL, load(V131 + "icon_%s.png" % m[0]), 99)
		mi.description = m[2]
		items[m[0]] = mi
	for b in [["sandstone", "Sandstone", "A warm desert wall."], ["ice", "Ice", "A cold, shining wall."],
			["mossy", "Mossy Stone", "An old, overgrown stone wall. Very tough."], ["driftwood", "Driftwood", "Pale, sea-bleached planks."],
			["pine", "Pine", "Dark red pine planks."]]:
		for part in ["wall", "floor"]:
			var bid := "%s_%s" % [part, b[0]]
			var bi := ItemDataClass.new(bid, "%s %s" % [b[1], part.capitalize()], ItemDataClass.ItemType.PLACEABLE, load(V131 + "icon_%s.png" % bid), 99)
			bi.placeable = true
			bi.description = (b[2] if part == "wall" else "A %s floor for your house." % b[1].to_lower()) + " Place with LEFT CLICK."
			bi.swing_cooldown = 0.12
			items[bid] = bi

	var gate := ItemDataClass.new("gate_wood", "Fence Gate", ItemDataClass.ItemType.PLACEABLE, load(V131 + "icon_gate_wood.png"), 99)
	gate.placeable = true
	gate.description = "A fence you can walk through: press E to open or close it. Place with LEFT CLICK."
	gate.swing_cooldown = 0.12
	items["gate_wood"] = gate

	var br := ItemDataClass.new("bridge_wood", "Wooden Bridge", ItemDataClass.ItemType.PLACEABLE, load(V131 + "icon_bridge_wood.png"), 99)
	br.placeable = true
	br.description = "Place it on water to build a bridge you can walk across. Place with LEFT CLICK."
	br.swing_cooldown = 0.12
	items["bridge_wood"] = br
	# the weapon that brings down the Rotting Giant
	var V13W = load("res://scripts/systems/items_v13.gd")
	V13W._weapon(items, "sunforged_greatsword", "Sunforged Greatsword", V131 + "icon_sunforged_greatsword.png", 58, 140.0, items.get("iron_sword"),
		"Forged from gold and crystal in the sun. Deals TRIPLE damage to the Rotting Giant and the Plague Mother.")
	if items.has("sunforged_greatsword"):
		var sg = items["sunforged_greatsword"]
		sg.swoosh_color = Color(1.0, 0.86, 0.4, 0.95)
		sg.swoosh_scale *= 1.2

	# fishing
	var rod := ItemDataClass.new("fishing_rod", "Fishing Rod", ItemDataClass.ItemType.TOOL, load(V131 + "icon_fishing_rod.png"), 1, ItemDataClass.ActionType.NONE)
	rod.usable = true
	rod.description = "Face water and LEFT CLICK to cast. When the float dips, click again to reel in!"
	items["fishing_rod"] = rod
	var boat := ItemDataClass.new("boat", "Rowing Boat", ItemDataClass.ItemType.TOOL, load(V131 + "icon_boat.png"), 1, ItemDataClass.ActionType.NONE)
	boat.usable = true
	boat.description = "Hold it and LEFT CLICK on water to put it in. Press E to get in, row with WASD and sail to the islands. Hit it with an axe to pick it up."
	items["boat"] = boat
	for f in [
		["minnow", "Minnow", 4.0, "A tiny river fish."], ["perch", "Perch", 8.0, "A striped lake fish. Grill it at the furnace."],
		["trout", "Trout", 10.0, "Lives in clear rivers. Grill it at the furnace."], ["catfish", "Catfish", 12.0, "Bites best at night."],
		["salmon", "Salmon", 12.0, "Loves cold snowfield rivers. Smoke it at the furnace."], ["golden_carp", "Golden Carp", 6.0, "A rare, shining fish. Worth a lot of gold."],
		["sea_bass", "Sea Bass", 10.0, "A fish of the open sea. Grill it at the furnace."], ["tuna", "Tuna", 16.0, "A big sea fish. Very filling."],
		["grilled_perch", "Grilled Perch", 26.0, "Crispy grilled perch."], ["grilled_trout", "Grilled Trout", 30.0, "Smoky grilled trout."],
		["smoked_salmon", "Smoked Salmon", 34.0, "Rich and smoky."], ["grilled_sea_bass", "Grilled Sea Bass", 30.0, "Fresh from the sea and the fire."],
	]:
		var fi := ItemDataClass.new(f[0], f[1], ItemDataClass.ItemType.FOOD, load(V131 + "icon_%s.png" % f[0]), 99, ItemDataClass.ActionType.EAT)
		fi.edible = true
		fi.hunger_restore = f[2]
		fi.description = f[3]
		items[f[0]] = fi
	for j in [["pufferfish", "Pufferfish", "Don't eat it! Collectors pay well for one."],
			["seaweed", "Seaweed", "Washed up from the water. Good compost."],
			["old_boot", "Old Boot", "Someone lost this a long time ago."]]:
		var ji := ItemDataClass.new(j[0], j[1], ItemDataClass.ItemType.MATERIAL, load(V131 + "icon_%s.png" % j[0]), 99)
		ji.description = j[2]
		items[j[0]] = ji
	for mat in [["leather", "Leather", "Tanned hide from cows, goats and deer."],
			["wool", "Wool", "Soft wool from sheep. Weave it into rugs and beds."],
			["feather", "Feather", "From chickens and ducks. Light as air."]]:
		var mi := ItemDataClass.new(mat[0], mat[1], ItemDataClass.ItemType.MATERIAL, load(V131 + "icon_%s.png" % mat[0]), 99)
		mi.description = mat[2]
		items[mat[0]] = mi
	for sp in [["sapling", "Oak Sapling", "Plant it on grass. In two days it grows into a tree."],
			["pine_sapling", "Pine Sapling", "Plant it on grass or snow. In two days it grows into a pine."]]:
		var si := ItemDataClass.new(sp[0], sp[1], ItemDataClass.ItemType.PLACEABLE, load("res://Assets/Generated/v131/%s.png" % sp[0]), 20)
		si.placeable = true
		si.description = sp[2] + " Place with LEFT CLICK."
		si.swing_cooldown = 0.12
		items[sp[0]] = si
	for id in DecorScript.KINDS:
		if items.has(id):
			continue
		var info: Dictionary = DecorScript.KINDS[id]
		var stack := 99 if id in FLOWERS else 20
		var it := ItemDataClass.new(id, str(info["name"]), ItemDataClass.ItemType.PLACEABLE, DecorScript.texture_of(id), stack)
		it.placeable = true
		var how := "Hang it on a wall with LEFT CLICK." if DecorScript.is_wall_kind(id) else "Place with LEFT CLICK."
		it.description = str(info.get("desc", "")) + " " + how
		it.swing_cooldown = 0.12
		items[id] = it
