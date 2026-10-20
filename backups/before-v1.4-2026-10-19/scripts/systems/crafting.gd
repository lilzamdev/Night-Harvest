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

const ROW_H := 62.0
const VISIBLE_ROWS := 5

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
	],
	"furnace": [
		["copper_bar", 1, {"copper_ore": 2, "wood_log": 1}, "items"],
		["iron_bar", 1, {"iron_ore": 2, "wood_log": 1}, "items"],
		["gold_bar", 1, {"gold_ore": 2, "wood_log": 1}, "items"],
		["brick", 2, {"stone_rock": 2, "wood_log": 1}, "items"],
		["baked_potato", 2, {"potato": 2, "wood_log": 1}, "items"],
		["pumpkin_pie", 1, {"pumpkin": 1, "wheat": 2}, "items"],
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
const TAB_NAMES := {"all": "ALL", "tools": "TOOLS", "build": "BUILD", "defense": "DEFENSE", "items": "ITEMS"}

var is_open := false
var _station := "workbench"
var _tab := "all"
var _stage: Control
var _panel: Panel
var _title: Label
var _sub: Label
var _list: Control
var _info: Label
var _tabs: Control
var _scroll := 0
var _icon: TextureRect


func _ready() -> void:
	layer = 62
	add_to_group("crafting_ui")
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = UIKit.stage(self)
	var dim := UIKit.color_rect(_stage, Color(0, 0, 0, 0.45), Vector2(-2000, -2000), Vector2(6000, 6000))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UIKit.panel(_stage, Vector2(156, 50), Vector2(840, 566))
	var pf := UIKit.panel(_panel, Vector2(24, 18), Vector2(64, 64), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	_icon = UIKit.tex(pf, null, Vector2(8, 8), Vector2(48, 48))
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title = UIKit.label(_panel, "", UIKit.F_HEAD, UIKit.C_TEXT, Vector2(104, 22))
	_sub = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(104, 62))
	UIKit.color_rect(_panel, UIKit.C_LINE, Vector2(24, 96), Vector2(792, 3))
	_tabs = Control.new()
	_tabs.position = Vector2(24, 106)
	_tabs.size = Vector2(792, 34)
	_tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_tabs)
	_info = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(24, 158))
	_list = Control.new()
	_list.position = Vector2(24, 186)
	_list.size = Vector2(792, ROW_H * VISIBLE_ROWS)
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_list)
	_list.gui_input.connect(_on_list_input)
	var close := UIKit.button(_panel, "CLOSE  ESC", Vector2(24, 504))
	close.pressed.connect(close_crafting)
	UIKit.label(_panel, "WHEEL: SCROLL · A / D: TABS", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(430, 517))
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
	visible = true
	is_open = true
	_refresh()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
	_event("crafting_opened", {"station": _station})


func close_crafting() -> void:
	is_open = false
	visible = false


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
	var order := {"tools": 0, "build": 1, "defense": 2, "items": 3}
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
		var bm := get_tree().get_first_node_in_group("build_manager")
		if bm and bm.handles(str(it.item_id)):
			return "build"
		return "defense"
	return "items"


func _rows() -> Array:
	var all := recipes_for(_station)
	if _tab == "all":
		return all
	var out: Array = []
	for r in all:
		if r.size() > 3 and r[3] == _tab:
			out.append(r)
	return out


func _tab_list() -> Array:
	var have := {"all": true}
	for r in recipes_for(_station):
		if r.size() > 3:
			have[r[3]] = true
	var out: Array = []
	for t in ["all", "tools", "build", "defense", "items"]:
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
			var w := UIKit.text_w(TAB_NAMES[t]) + 28.0
			var b := UIKit.button(_tabs, TAB_NAMES[t], Vector2(x, 0), t == _tab, false, w)
			var tid: String = t
			b.pressed.connect(func() -> void:
				_tab = tid
				_scroll = 0
				_refresh())
			x += w + 6.0
	elif _tab != "all":
		_tab = "all"
	for c in _list.get_children():
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
			hint = "PLACE A WORKBENCH TO CRAFT TOOLS AND BLOCKS"
		_info.text = "%d RECIPE%s READY · %s" % [ready, "" if ready == 1 else "S", hint]
	_scroll = clampi(_scroll, 0, maxi(0, rows.size() - VISIBLE_ROWS))
	for i in range(_scroll, mini(rows.size(), _scroll + VISIBLE_ROWS)):
		_build_row(rows[i], float(i - _scroll) * ROW_H)


func _build_row(r: Array, y: float) -> void:
	var item = ItemDB.get_item(str(r[0]))
	if item == null:
		return
	var ok := can_craft(r)
	var row := UIKit.panel(_list, Vector2(0, y), Vector2(792, ROW_H - 6), UIKit.box(UIKit.C_ROW if ok else Color(0.08, 0.06, 0.04, 0.9), UIKit.C_GOLD if ok else Color("3A2818"), 2, false))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var slot := UIKit.panel(row, Vector2(8, 7), Vector2(42, 42), UIKit.box(Color("120C08"), Color("574029"), 2, false))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic0 := UIKit.tex(slot, item.icon, Vector2(5, 5), Vector2(32, 32))
	ic0.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var name := str(item.display_name).to_upper()
	if _station != "creative" and int(r[1]) > 1:
		name += " x%d" % int(r[1])
	UIKit.label(row, name, UIKit.F_SMALL, UIKit.C_GOLD_LIGHT if ok else UIKit.C_TEXT, Vector2(62, 6))
	var x := 62.0
	var need: Dictionary = r[2]
	for id in need:
		var ing = ItemDB.get_item(id)
		var have := count_item(id)
		var n := int(need[id])
		var ic := UIKit.tex(row, ing.icon if ing else null, Vector2(x, 28), Vector2(22, 22))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var txt := "%d/%d" % [mini(have, 99), n]
		UIKit.label(row, txt, UIKit.F_SMALL, UIKit.C_GREEN if (have >= n or _creative()) else UIKit.C_RED, Vector2(x + 25, 30))
		x += 30.0 + UIKit.text_w(txt) + 14.0
	var desc := str(item.description).to_upper()
	if desc != "" and x < 420.0:
		UIKit.label(row, _fit(desc, int((560.0 - x) / 12.0)), UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(x + 6, 30))
	var rec := r
	if _station == "creative":
		var b1 := UIKit.button(row, "GET 1", Vector2(560, 6), true, false, 96)
		b1.pressed.connect(func() -> void: _give(rec, 1))
		var b2 := UIKit.button(row, "STACK", Vector2(668, 6), true, false, 112)
		b2.pressed.connect(func() -> void: _give(rec, maxi(1, int(item.max_stack))))
		return
	var b := UIKit.button(row, "CRAFT", Vector2(668, 6), ok, false, 112)
	b.disabled = not ok
	b.pressed.connect(func() -> void: _craft(rec))


func _fit(text: String, n: int) -> String:
	if n < 6:
		return ""
	if text.length() <= n:
		return text
	var cut := text.left(n - 2)
	var sp := cut.rfind(" ")
	if sp > n / 2:
		cut = cut.left(sp)
	return cut.strip_edges().trim_suffix(".") + ".."


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


func _craft(r: Array) -> void:
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


func _on_list_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll += 1
			_refresh()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(0, _scroll - 1)
			_refresh()


func _cycle_tab(d: int) -> void:
	var tabs := _tab_list()
	if tabs.size() <= 2:
		return
	var i := tabs.find(_tab)
	_tab = tabs[(i + d + tabs.size()) % tabs.size()]
	_scroll = 0
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
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C and _player_free():
			open_crafting("creative" if _creative() else "hand")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C):
		close_crafting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_scroll += 1
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_scroll = maxi(0, _scroll - 1)
		_refresh()
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
