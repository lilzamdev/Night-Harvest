extends CanvasLayer

## Crafting (v1.3): turn what you gather into tools, blocks and gear.
##   C anywhere   HAND crafting: a workbench and torches, enough to get started.
##   WORKBENCH    tools, building blocks, furniture, defenses, food, boss idols.
##   FURNACE      smelt ore into bars, fire bricks, cook food.
##   ANVIL        forge copper, iron, gold and crystal tools and weapons.
## In Creative mode C opens the catalog of every item instead, and crafting is free.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const V12 := "res://Assets/Generated/v12/"
const V13 := "res://Assets/Generated/v13/"

const COLS := 7
const TILE := 54.0
const GAP := 6.0

## station -> [result id, amount, {ingredient: count}, tab]
const RECIPES := {
	"hand": [
		["workbench", 1, {"wood_log": 6}, "build"],
		["torch", 2, {"wood_log": 1, "fiber": 1}, "items"],
	],
	"workbench": [
		# tools & weapons
		["wooden_sword", 1, {"wood_log": 4}, "tools"],
		["wood_axe", 1, {"wood_log": 3}, "tools"],
		["pickaxe", 1, {"wood_log": 3}, "tools"],
		["hoe", 1, {"wood_log": 2}, "tools"],
		["fishing_rod", 1, {"wood_log": 3, "fiber": 4}, "tools"],
		["boat", 1, {"wood_log": 24, "fiber": 8}, "tools"],
		["watering_can", 1, {"wood_log": 3, "stone_rock": 2}, "tools"],
		["stone_sword", 1, {"stone_rock": 3, "wood_log": 1}, "tools"],
		["stone_axe", 1, {"stone_rock": 3, "wood_log": 2}, "tools"],
		["stone_pickaxe", 1, {"stone_rock": 3, "wood_log": 2}, "tools"],
		# building
		["wall_wood", 4, {"wood_log": 2}, "build"],
		["floor_wood", 4, {"wood_log": 1}, "build"],
		["door_wood", 1, {"wood_log": 4}, "build"],
		["fence_wood", 4, {"wood_log": 2, "fiber": 1}, "build"],
		["wall_stone", 4, {"stone_rock": 3}, "build"],
		["floor_stone", 4, {"stone_rock": 2}, "build"],
		["gate_wood", 1, {"wood_log": 3}, "build"],
		["wall_sandstone", 4, {"sandstone": 3}, "build"],
		["floor_sandstone", 4, {"sandstone": 2}, "build"],
		["wall_ice", 4, {"ice_chunk": 3}, "build"],
		["floor_ice", 4, {"ice_chunk": 2}, "build"],
		["wall_mossy", 4, {"mossy_cobble": 3}, "build"],
		["floor_mossy", 4, {"mossy_cobble": 2}, "build"],
		["wall_driftwood", 4, {"driftwood": 2}, "build"],
		["floor_driftwood", 4, {"driftwood": 1}, "build"],
		["wall_pine", 4, {"pine_log": 2}, "build"],
		["floor_pine", 4, {"pine_log": 1}, "build"],
		["wall_brick", 4, {"brick": 4}, "build"],
		["floor_brick", 4, {"brick": 2}, "build"],
		["chest", 1, {"wood_log": 8}, "build"],
		["bed", 1, {"wood_log": 6, "fiber": 6}, "build"],
		["watch_tower", 1, {"wood_log": 20, "fiber": 6}, "build"],
		["furnace", 1, {"stone_rock": 12}, "build"],
		["anvil", 1, {"iron_bar": 5, "stone_rock": 4}, "build"],
		["torch", 3, {"wood_log": 2, "fiber": 1}, "build"],
		# defenses
		["barricade", 2, {"wood_log": 6, "fiber": 1}, "defense"],
		["spike_trap", 2, {"stone_rock": 3, "fiber": 2}, "defense"],
		["stone_wall", 1, {"stone_rock": 6, "wood_log": 2}, "defense"],
		["lantern_post", 1, {"copper_bar": 1, "wood_log": 3, "torch": 1}, "defense"],
		["sprinkler", 1, {"copper_bar": 2, "stone_rock": 3}, "defense"],
		["scarecrow_turret", 1, {"wood_log": 10, "iron_bar": 2, "bone": 2}, "defense"],
		# items
		["bread", 1, {"wheat": 3}, "items"],
		["herbal_tonic", 2, {"wild_mushroom": 2, "slime_gel": 1}, "items"],
		["rotten_totem", 1, {"rotten_flesh": 12, "bone": 6, "wood_log": 4}, "items"],
		["plague_idol", 1, {"rotten_flesh": 20, "gold_bar": 3, "crystal_shard": 4, "slime_gel": 4}, "items"],
		# decorations (v1.3.1) - make the house and the farm your own
		["wooden_chair", 1, {"wood_log": 3}, "decor"],
		["stool", 1, {"wood_log": 2}, "decor"],
		["armchair", 1, {"wood_log": 3, "fiber": 4, "red_flower": 1}, "decor"],
		["round_table", 1, {"wood_log": 4}, "decor"],
		["long_table", 1, {"wood_log": 6}, "decor"],
		["bench", 1, {"wood_log": 5}, "decor"],
		["bookshelf", 1, {"wood_log": 6, "fiber": 2}, "decor"],
		["cupboard", 1, {"wood_log": 7}, "decor"],
		["pantry_shelf", 1, {"wood_log": 6, "stone_rock": 1}, "decor"],
		["nightstand", 1, {"wood_log": 4}, "decor"],
		["barrel", 1, {"wood_log": 6, "stone_rock": 1}, "decor"],
		["grain_sack", 1, {"fiber": 6, "wheat": 2}, "decor"],
		["firewood", 1, {"wood_log": 8}, "decor"],
		["water_bucket", 1, {"wood_log": 3}, "decor"],
		["wooden_sign", 1, {"wood_log": 3}, "decor"],
		["crate_lantern", 1, {"wood_log": 3, "torch": 1}, "decor"],
		["street_lamp", 1, {"iron_bar": 2, "torch": 1}, "decor"],
		["window", 1, {"wood_log": 2, "stone_rock": 2}, "decor"],
		["curtain_window", 1, {"wood_log": 2, "stone_rock": 2, "fiber": 2}, "decor"],
		["painting", 1, {"wood_log": 2, "fiber": 2, "red_flower": 1, "blue_flower": 1}, "decor"],
		["mirror", 1, {"wood_log": 2, "copper_bar": 1, "stone_rock": 2}, "decor"],
		["flower_box_red", 1, {"wood_log": 2, "red_flower": 2}, "decor"],
		["flower_box_pink", 1, {"wood_log": 2, "pink_flower": 2}, "decor"],
		["flower_box_white", 1, {"wood_log": 2, "daisy": 2}, "decor"],
		["flower_box_yellow", 1, {"wood_log": 2, "yellow_flower": 2}, "decor"],
		["pot_red", 1, {"stone_rock": 2, "red_flower": 1}, "decor"],
		["pot_yellow", 1, {"stone_rock": 2, "yellow_flower": 1}, "decor"],
		["rug_red", 1, {"fiber": 8, "red_flower": 2}, "decor"],
		["rug_blue", 1, {"fiber": 8, "blue_flower": 2}, "decor"],
	],
	"furnace": [
		["copper_bar", 1, {"copper_ore": 2, "wood_log": 1}, "items"],
		["iron_bar", 1, {"iron_ore": 2, "wood_log": 1}, "items"],
		["gold_bar", 1, {"gold_ore": 2, "wood_log": 1}, "items"],
		["brick", 2, {"stone_rock": 2, "wood_log": 1}, "items"],
		["baked_potato", 2, {"potato": 2, "wood_log": 1}, "items"],
		["pumpkin_pie", 1, {"pumpkin": 1, "wheat": 2}, "items"],
		# v1.4 cooking meat
		["steak", 1, {"raw_beef": 1, "wood_log": 1}, "items"],
		["cooked_pork", 1, {"raw_pork": 1, "wood_log": 1}, "items"],
		["cooked_mutton", 1, {"raw_mutton": 1, "wood_log": 1}, "items"],
		["cooked_chicken", 1, {"raw_chicken": 1, "wood_log": 1}, "items"],
		["cooked_rabbit", 1, {"raw_rabbit": 1, "wood_log": 1}, "items"],
		["cooked_venison", 1, {"venison": 1, "wood_log": 1}, "items"],
		["grilled_perch", 1, {"perch": 1, "wood_log": 1}, "items"],
		["grilled_trout", 1, {"trout": 1, "wood_log": 1}, "items"],
		["smoked_salmon", 1, {"salmon": 1, "wood_log": 2}, "items"],
		["grilled_sea_bass", 1, {"sea_bass": 1, "wood_log": 1}, "items"],
	],
	"anvil": [
		["copper_sword", 1, {"copper_bar": 3, "wood_log": 1}, "tools"],
		["copper_axe", 1, {"copper_bar": 3, "wood_log": 2}, "tools"],
		["copper_pickaxe", 1, {"copper_bar": 3, "wood_log": 2}, "tools"],
		["steel_sword", 1, {"iron_bar": 4, "wood_log": 1}, "tools"],
		["steel_axe", 1, {"iron_bar": 3, "wood_log": 2}, "tools"],
		["steel_pickaxe", 1, {"iron_bar": 3, "wood_log": 2}, "tools"],
		["war_hammer", 1, {"iron_bar": 6, "stone_rock": 6, "wood_log": 4}, "tools"],
		["gold_sword", 1, {"gold_bar": 4, "iron_bar": 1}, "tools"],
		["gold_axe", 1, {"gold_bar": 3, "iron_bar": 1}, "tools"],
		["gold_pickaxe", 1, {"gold_bar": 3, "iron_bar": 1}, "tools"],
		["crystal_sword", 1, {"crystal_shard": 6, "gold_bar": 2}, "tools"],
		["crystal_pickaxe", 1, {"crystal_shard": 6, "gold_bar": 2}, "tools"],
		["hollow_blade", 1, {"hollow_crown": 1, "crystal_shard": 8, "gold_bar": 3}, "tools"],
		["iron_spikes", 2, {"iron_bar": 2, "stone_rock": 2}, "defense"],
	],
}
const TITLES := {"hand": "CRAFTING", "workbench": "WORKBENCH", "anvil": "ANVIL", "furnace": "FURNACE", "creative": "CREATIVE CATALOG"}
const SUBTITLES := {
	"hand": "BY HAND · BUILD A WORKBENCH FOR MORE",
	"workbench": "TOOLS, BLOCKS, FURNITURE AND MORE",
	"anvil": "FORGE METAL TOOLS AND WEAPONS",
	"furnace": "SMELT ORE, FIRE BRICKS, COOK FOOD",
	"creative": "EVERY ITEM IN THE GAME · CLICK TO TAKE",
}
const TAB_NAMES := {"all": "ALL", "tools": "TOOLS", "build": "BUILD", "decor": "DECOR", "defense": "DEFENSE", "items": "ITEMS"}
const TAB_ORDER := ["all", "tools", "build", "decor", "defense", "items"]

var is_open := false
var _station := "workbench"
var _tab := "all"
var _stage: Control
var _panel: Panel
var _title: Label
var _sub: Label
var _info: Label
var _tabs: Control
var _scroll := 0
var _icon: TextureRect
var _search: LineEdit
var _grid_box: ScrollContainer
var _grid: GridContainer
var _detail: Panel
var _sel_id := ""
var _query := ""


func _ready() -> void:
	layer = 62
	add_to_group("crafting_ui")
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = UIKit.stage(self)
	var dim := UIKit.color_rect(_stage, Color(0, 0, 0, 0.45), Vector2(-2000, -2000), Vector2(6000, 6000))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UIKit.panel(_stage, Vector2(156, 40), Vector2(840, 580))
	var pf := UIKit.panel(_panel, Vector2(24, 16), Vector2(60, 60), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	_icon = UIKit.tex(pf, null, Vector2(8, 8), Vector2(44, 44))
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title = UIKit.label(_panel, "", UIKit.F_HEAD, UIKit.C_TEXT, Vector2(98, 16))
	_sub = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(98, 56))
	UIKit.color_rect(_panel, UIKit.C_LINE, Vector2(24, 88), Vector2(792, 3))
	# v1.3.1: search box + category tabs
	var sb := UIKit.panel(_panel, Vector2(24, 100), Vector2(214, 34), UIKit.box(Color("120C08"), Color("574029"), 2, false))
	sb.mouse_filter = Control.MOUSE_FILTER_PASS
	_search = LineEdit.new()
	_search.position = Vector2(4, 2)
	_search.size = Vector2(206, 30)
	_search.placeholder_text = "SEARCH..."
	_search.add_theme_font_override("font", UIKit.font())
	_search.add_theme_font_size_override("font_size", UIKit.F_SMALL)
	_search.add_theme_color_override("font_color", UIKit.C_TEXT)
	_search.add_theme_color_override("font_placeholder_color", Color("6E5A40"))
	_search.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_search.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(t: String) -> void:
		_query = t.strip_edges().to_lower()
		_refresh())
	_search.text_submitted.connect(func(_t: String) -> void: _search.release_focus())
	sb.add_child(_search)
	_tabs = Control.new()
	_tabs.position = Vector2(248, 100)
	_tabs.size = Vector2(568, 34)
	_tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_tabs)
	_info = UIKit.label(_panel, "", UIKit.F_TINY, UIKit.C_TEXT_DIM, Vector2(24, 144))
	# recipe grid (left)
	_grid_box = ScrollContainer.new()
	_grid_box.position = Vector2(24, 160)
	_grid_box.size = Vector2(COLS * (TILE + GAP) + 10, 352)
	_grid_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_grid_box)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid_box.add_child(_grid)
	# what the selected recipe needs (right)
	_detail = UIKit.panel(_panel, Vector2(456, 160), Vector2(360, 352), UIKit.box(UIKit.C_ROW, Color("3A2818"), 2, false))
	_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	var close := UIKit.button(_panel, "CLOSE  ESC", Vector2(24, 522))
	close.pressed.connect(close_crafting)
	UIKit.label(_panel, "CLICK A RECIPE TO SEE WHAT IT NEEDS · CLICK AGAIN OR ENTER: CRAFT · A / D: TABS", UIKit.F_TINY, UIKit.C_TEXT_DIM, Vector2(232, 540))
	visible = false


func _creative() -> bool:
	var gm := get_tree().get_first_node_in_group("game_mode")
	return gm != null and gm.get("creative") == true


func open_crafting(station: String) -> void:
	_station = station if (RECIPES.has(station) or station == "creative") else "workbench"
	_title.text = TITLES.get(_station, "CRAFTING")
	_sub.text = SUBTITLES.get(_station, "")
	var icon_file := {"anvil": V13 + "icon_anvil.png", "furnace": V13 + "icon_furnace.png", "workbench": V13 + "icon_workbench.png", "hand": V13 + "icon_wooden_axe.png", "creative": V13 + "icon_chest.png"}
	_icon.texture = load(icon_file.get(_station, V13 + "icon_workbench.png"))
	_scroll = 0
	_tab = "all"
	_query = ""
	_search.text = ""
	_sel_id = ""
	visible = true
	is_open = true
	_refresh()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
	_event("crafting_opened", {"station": _station})


func close_crafting() -> void:
	is_open = false
	visible = false
	if _search and _search.has_focus():
		_search.release_focus()


func _inv() -> Node:
	return get_tree().get_first_node_in_group("inventory_ui")


func count_item(id: String) -> int:
	var inv := _inv()
	if not inv:
		return 0
	var n := 0
	for s in inv.hotbar_slots + inv.slots:
		if s["item"] != null and s["item"].get("item_id") == id:
			n += int(s["amount"])
	return n


func can_craft(recipe: Array) -> bool:
	if _creative():
		return true
	var need: Dictionary = recipe[2]
	for id in need:
		if count_item(id) < int(need[id]):
			return false
	return true


## Recipes shown at a station. The workbench also offers everything you can make by hand.
func recipes_for(station: String) -> Array:
	if station == "creative":
		return _catalog()
	var out: Array = []
	if station == "workbench":
		for r in RECIPES["hand"]:
			if r[0] != "torch":
				out.append(r)
	out.append_array(RECIPES.get(station, []))
	return out


func _catalog() -> Array:
	var ids: Array = ItemDB._items.keys()
	ids.sort()
	var order := {"tools": 0, "build": 1, "decor": 2, "defense": 3, "items": 4}
	var rows: Array = []
	for id in ids:
		var it = ItemDB.get_item(id)
		if it == null:
			continue
		rows.append([id, int(it.max_stack), {}, _tab_of(it)])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		if order[a[3]] != order[b[3]]:
			return order[a[3]] < order[b[3]]
		return str(a[0]) < str(b[0]))
	return rows


func _tab_of(it) -> String:
	var ItemData = load("res://scripts/item_data.gd")
	var t: int = int(it.item_type)
	if t == ItemData.ItemType.TOOL or t == ItemData.ItemType.WEAPON:
		return "tools"
	if t == ItemData.ItemType.PLACEABLE:
		if load("res://scripts/systems/decor.gd").KINDS.has(str(it.item_id)):
			return "decor"
		var bm := get_tree().get_first_node_in_group("build_manager")
		if bm and bm.handles(str(it.item_id)):
			return "build"
		return "defense"
	return "items"


func _rows() -> Array:
	var all := recipes_for(_station)
	var out: Array = []
	for r in all:
		if _tab != "all" and not (r.size() > 3 and r[3] == _tab):
			continue
		if _query != "" and not _matches(r):
			continue
		out.append(r)
	# things you can make right now come first
	if _station != "creative":
		var ready: Array = []
		var rest: Array = []
		for r in out:
			(ready if can_craft(r) else rest).append(r)
		out = ready + rest
	return out


func _matches(r: Array) -> bool:
	var it = ItemDB.get_item(str(r[0]))
	var nm := (str(it.display_name) if it else str(r[0])).to_lower()
	if nm.contains(_query) or str(r[0]).contains(_query):
		return true
	# also find recipes by what they use ("flower", "iron")
	for id in r[2]:
		var ing = ItemDB.get_item(id)
		if ing and str(ing.display_name).to_lower().contains(_query):
			return true
	return false


func _tab_list() -> Array:
	var have := {"all": true}
	for r in recipes_for(_station):
		if r.size() > 3:
			have[r[3]] = true
	var out: Array = []
	for t in TAB_ORDER:
		if have.has(t):
			out.append(t)
	return out


func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var x := 0.0
	var tabs := _tab_list()
	if tabs.size() > 2:
		for t in tabs:
			var w := UIKit.text_w(TAB_NAMES[t]) + 22.0
			var b := UIKit.button(_tabs, TAB_NAMES[t], Vector2(x, 0), t == _tab, false, w)
			b.size.y = 34
			(b.get_node("Text") as Label).position.y = 8
			b.focus_mode = Control.FOCUS_NONE
			var tid: String = t
			b.pressed.connect(func() -> void:
				_tab = tid
				_refresh())
			x += w + 4.0
	elif _tab != "all":
		_tab = "all"
	for c in _grid.get_children():
		c.queue_free()
	var rows: Array = _rows()
	var ready := 0
	for r in rows:
		if can_craft(r):
			ready += 1
	if _station == "creative":
		_info.text = "%d ITEMS · CREATIVE MODE: EVERYTHING IS FREE" % rows.size()
	elif _creative():
		_info.text = "%d RECIPES · CREATIVE MODE: CRAFTING IS FREE" % rows.size()
	else:
		var hint := "GATHER MORE IN THE WILD AND THE HOLLOW MINES"
		if _station == "hand":
			hint = "PLACE A WORKBENCH TO CRAFT TOOLS, BLOCKS AND DECORATIONS"
		_info.text = "%d RECIPES · %d READY TO CRAFT (GOLD BORDER) · %s" % [rows.size(), ready, hint]
	if rows.is_empty():
		_sel_id = ""
	elif _sel_id == "" or not rows.any(func(r: Array) -> bool: return str(r[0]) == _sel_id):
		_sel_id = str(rows[0][0])
	for r in rows:
		_build_tile(r)
	_build_detail(_selected_recipe(rows))


func _selected_recipe(rows: Array) -> Array:
	for r in rows:
		if str(r[0]) == _sel_id:
			return r
	return []


func _build_tile(r: Array) -> void:
	var item = ItemDB.get_item(str(r[0]))
	if item == null:
		return
	var ok := can_craft(r)
	var sel := str(r[0]) == _sel_id
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(TILE, TILE)
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = str(item.display_name)
	var border := UIKit.C_GOLD_LIGHT if sel else (UIKit.C_GOLD if ok else Color("3A2818"))
	var bg := UIKit.C_PANEL_HI if sel else (Color("1E150D") if ok else Color(0.07, 0.05, 0.035, 0.9))
	var st := UIKit.box(bg, border, 3 if sel else 2, false)
	tile.add_theme_stylebox_override("normal", st)
	tile.add_theme_stylebox_override("hover", UIKit.box(UIKit.C_PANEL_HI, UIKit.C_GOLD_LIGHT, 2, false))
	tile.add_theme_stylebox_override("pressed", st)
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_grid.add_child(tile)
	var ic := UIKit.tex(tile, item.icon, Vector2(9, 7), Vector2(36, 36))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if (ok or _station == "creative") else Color(0.55, 0.5, 0.45, 0.85)
	if _station != "creative" and int(r[1]) > 1:
		UIKit.label(tile, "x%d" % int(r[1]), UIKit.F_TINY, UIKit.C_TEXT, Vector2(TILE - 22, TILE - 15))
	var id := str(r[0])
	tile.pressed.connect(func() -> void:
		if _sel_id == id:
			if _station == "creative":
				_give(r, 1)
			elif can_craft(r):
				_craft(r)
			return
		_sel_id = id
		_refresh())


func _build_detail(r: Array) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if r.is_empty():
		UIKit.wrap_label(_detail, "NOTHING MATCHES." if _query != "" else "NO RECIPES HERE.", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(18, 20), 324)
		return
	var item = ItemDB.get_item(str(r[0]))
	if item == null:
		return
	var ok := can_craft(r)
	var box := UIKit.panel(_detail, Vector2(14, 14), Vector2(64, 64), UIKit.box(Color("120C08"), UIKit.C_GOLD if ok else Color("574029"), 2, false))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.tex(box, item.icon, Vector2(8, 8), Vector2(48, 48))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var nm := UIKit.label(_detail, "", UIKit.F_SMALL, UIKit.C_GOLD_LIGHT, Vector2(90, 18))
	UIKit.fit_label(nm, str(item.display_name).to_upper(), 256.0, [18, 9])
	var makes := "STACKS UP TO %d" % int(item.max_stack) if _station == "creative" else "MAKES %d" % int(r[1])
	UIKit.label(_detail, makes, UIKit.F_TINY, UIKit.C_TEXT_DIM, Vector2(90, 44))
	var desc := UIKit.wrap_label(_detail, str(item.description), UIKit.F_TINY, UIKit.C_TEXT_SOFT, Vector2(90, 60), 256)
	desc.add_theme_constant_override("line_spacing", 3)
	var y := 108.0
	var need: Dictionary = r[2]
	if not need.is_empty():
		UIKit.label(_detail, "YOU NEED", UIKit.F_TINY, UIKit.C_TEXT_DIM, Vector2(16, y))
		y += 16.0
		for id in need:
			var ing = ItemDB.get_item(id)
			var have := count_item(id)
			var n := int(need[id])
			var enough := have >= n or _creative()
			var row := UIKit.panel(_detail, Vector2(14, y), Vector2(332, 30), UIKit.box(Color("120C08"), Color("2E2014"), 1, false))
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ii := UIKit.tex(row, ing.icon if ing else null, Vector2(5, 3), Vector2(24, 24))
			ii.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			UIKit.label(row, str(ing.display_name if ing else id).to_upper(), UIKit.F_TINY, UIKit.C_TEXT, Vector2(36, 11))
			var cnt := "%d / %d" % [mini(have, 999), n]
			UIKit.label(row, cnt, UIKit.F_TINY, UIKit.C_GREEN if enough else UIKit.C_RED, Vector2(324 - UIKit.text_w(cnt, UIKit.F_TINY), 11))
			y += 34.0
	var rec := r
	if _station == "creative":
		var b1 := UIKit.button(_detail, "GET 1", Vector2(14, 296), true, false, 120)
		b1.pressed.connect(func() -> void: _give(rec, 1))
		var b2 := UIKit.button(_detail, "GET STACK", Vector2(144, 296), true, false, 202)
		b2.pressed.connect(func() -> void: _give(rec, maxi(1, int(item.max_stack))))
		return
	var b := UIKit.button(_detail, "CRAFT", Vector2(14, 296), ok, false, 150)
	b.disabled = not ok
	b.pressed.connect(func() -> void: _craft(rec))
	var times := _max_crafts(r)
	var b5 := UIKit.button(_detail, "CRAFT x%d" % clampi(times, 2, 5), Vector2(174, 296), false, false, 172)
	b5.disabled = times < 2
	b5.pressed.connect(func() -> void:
		var n := mini(_max_crafts(rec), 5)
		for i in n:
			_craft(rec, i < n - 1))
	if not ok:
		UIKit.label(_detail, "MISSING ITEMS ARE IN RED", UIKit.F_TINY, UIKit.C_RED, Vector2(16, 278))


func _max_crafts(r: Array) -> int:
	if _creative():
		return 99
	var m := 999
	for id in r[2]:
		m = mini(m, count_item(id) / maxi(1, int(r[2][id])))
	return m


func _give(r: Array, n: int) -> void:
	var inv := _inv()
	var item = ItemDB.get_item(str(r[0]))
	if not inv or item == null:
		return
	var left: int = inv.add_item(item, n)
	if left >= n:
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud:
			hud.show_hud_message("Your bag is full.", 1.5)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ui_click")
	_sync_player()


func _craft(r: Array, batch: bool = false) -> void:
	if not can_craft(r):
		return
	var inv := _inv()
	var item = ItemDB.get_item(str(r[0]))
	if not inv or item == null:
		return
	var need: Dictionary = r[2]
	if not _creative():
		for id in need:
			_remove(inv, id, int(need[id]))
	var left: int = inv.add_item(item, int(r[1]))
	if left > 0:
		# Bag full: drop the rest at the player's feet
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			var w := (load("res://Scenes/world_item.tscn") as PackedScene).instantiate()
			p.get_parent().add_child(w)
			w.global_position = p.global_position
			w.call("set_item", item, left)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("craft", -6.0)
	var juice := get_tree().get_first_node_in_group("juice")
	var p2 := get_tree().get_first_node_in_group("player") as Node2D
	if juice and p2:
		juice.popup_text(p2.global_position + Vector2(0, -26), "+%d %s" % [int(r[1]), str(item.display_name).to_upper()], Color("FFDB80"))
	_event("item_crafted", {"id": str(r[0]), "amount": int(r[1])})
	_sync_player()
	if not batch:
		_refresh()


func _remove(inv: Node, id: String, n: int) -> void:
	var left := n
	for arr in [inv.slots, inv.hotbar_slots]:
		for s in arr:
			if left <= 0:
				break
			if s["item"] != null and s["item"].get("item_id") == id:
				var take := mini(left, int(s["amount"]))
				s["amount"] = int(s["amount"]) - take
				left -= take
				if int(s["amount"]) <= 0:
					s["item"] = null
					s["amount"] = 0
	inv._update_slot_visuals()
	inv.inventory_changed.emit()


func _sync_player() -> void:
	var hb := get_tree().get_first_node_in_group("hotbar_ui")
	var p := get_tree().get_first_node_in_group("player")
	if hb and p and p.has_method("_on_hotbar_slot_selected"):
		hb._update_slot_visuals()
		p._on_hotbar_slot_selected(hb.selected_slot, hb.get_selected_item())


func _cycle_tab(d: int) -> void:
	var tabs := _tab_list()
	if tabs.size() <= 2:
		return
	var i := tabs.find(_tab)
	_tab = tabs[(i + d + tabs.size()) % tabs.size()]
	_refresh()


func _move_sel(d: int) -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var i := 0
	for k in rows.size():
		if str(rows[k][0]) == _sel_id:
			i = k
	_sel_id = str(rows[clampi(i + d, 0, rows.size() - 1)][0])
	_refresh()


func _player_free() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("is_ui_blocking"):
		return false
	if p.is_ui_blocking() or p.get("_is_dead") or p.get("_is_sleeping"):
		return false
	var dlg := get_tree().get_first_node_in_group("dialogue_ui")
	if dlg and dlg.get("is_open"):
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("open_crafting") and _player_free():
			open_crafting("creative" if _creative() else "hand")
			get_viewport().set_input_as_handled()
		return
	if _search.has_focus():
		if event.is_action_pressed("ui_cancel"):
			_search.release_focus()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or event.is_action_pressed("open_crafting"):
		close_crafting()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		var r := _selected_recipe(_rows())
		if not r.is_empty():
			if _station == "creative":
				_give(r, 1)
			else:
				_craft(r)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_move_sel(COLS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_move_sel(-COLS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_cycle_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_cycle_tab(1)
		get_viewport().set_input_as_handled()


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


# ==========================================================================
# Stations in the world
# ==========================================================================

class Station extends Node2D:
	var station := "workbench"
	var interact_range := 26.0

	func _ready() -> void:
		add_to_group("interactables")
		add_to_group("crafting_stations")

	func can_interact(_p: Node2D) -> bool:
		return true

	func get_prompt() -> String:
		match station:
			"anvil":
				return "USE ANVIL"
			"furnace":
				return "USE FURNACE"
		return "USE WORKBENCH"

	func interact(_p: Node2D) -> void:
		var ui := get_tree().get_first_node_in_group("crafting_ui")
		if ui:
			ui.open_crafting(station)


## Builds a station with sprite + collision at a global position.
static func make_station(parent: Node, station: String, pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = "Station_" + station
	parent.add_child(root)
	root.global_position = pos
	var tex: Texture2D
	match station:
		"anvil":
			tex = load(V12 + "anvil.png")
		"furnace":
			var a := AtlasTexture.new()
			a.atlas = load(V12 + "furnace.png")
			a.region = Rect2(0, 0, 24, 16)
			tex = a
		_:
			tex = load(V12 + "workbench.png")
	if station == "furnace":
		var anim := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		for i in 2:
			var fa := AtlasTexture.new()
			fa.atlas = load(V12 + "furnace.png")
			fa.region = Rect2(i * 24, 0, 24, 16)
			sf.add_frame("default", fa)
		sf.set_animation_speed("default", 5.0)
		anim.sprite_frames = sf
		anim.offset = Vector2(0, -8)
		root.add_child(anim)
		anim.play()
	else:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.offset = Vector2(0, -tex.get_height() * 0.5)
		root.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(28 if station == "workbench" else 20, 6)
	cs.shape = rs
	cs.position = Vector2(0, -3)
	body.add_child(cs)
	root.add_child(body)
	var st := Station.new()
	st.station = station
	root.add_child(st)
	st.position = Vector2(0, 2)
	return root
