extends CanvasLayer

## Crafting (v1.2): turn wood, stone, ores and monster drops into gear.
##   WORKBENCH (outside your farmhouse): buildables, defenses, tonics.
##   ANVIL (inside Ben's Forge): tools and weapons from ore.
## Recipes unlock as soon as you have ever held one of their ingredients, so the
## list grows as you explore deeper into the mines.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const V12 := "res://Assets/Generated/v12/"

const ROW_H := 62.0
const VISIBLE_ROWS := 6

## station -> [result id, amount, {ingredient: count}]
const RECIPES := {
	"workbench": [
		["barricade", 2, {"wood_log": 6}],
		["torch", 3, {"wood_log": 2}],
		["bread", 1, {"wheat": 3}],
		["stone_wall", 1, {"stone_rock": 6, "wood_log": 2}],
		["sprinkler", 1, {"copper_ore": 4, "stone_rock": 3}],
		["lantern_post", 1, {"copper_ore": 2, "wood_log": 3, "torch": 1}],
		["herbal_tonic", 2, {"wild_mushroom": 2, "slime_gel": 1}],
		["scarecrow_turret", 1, {"wood_log": 10, "iron_ore": 3, "bone": 2}],
		["spike_trap", 2, {"stone_rock": 3, "bone": 1}],
	],
	"anvil": [
		["copper_sword", 1, {"copper_ore": 6, "wood_log": 2}],
		["steel_pickaxe", 1, {"iron_ore": 6, "wood_log": 3}],
		["steel_axe", 1, {"iron_ore": 5, "wood_log": 3}],
		["steel_sword", 1, {"iron_ore": 8, "copper_ore": 2}],
		["iron_spikes", 2, {"iron_ore": 4, "stone_rock": 2}],
		["war_hammer", 1, {"iron_ore": 10, "stone_rock": 6, "wood_log": 4}],
		["gold_sword", 1, {"gold_ore": 8, "iron_ore": 3}],
		["gold_pickaxe", 1, {"gold_ore": 7, "iron_ore": 3}],
		["gold_axe", 1, {"gold_ore": 6, "iron_ore": 2}],
		["crystal_sword", 1, {"crystal_shard": 6, "gold_ore": 4}],
		["crystal_pickaxe", 1, {"crystal_shard": 6, "gold_ore": 4}],
		["hollow_blade", 1, {"hollow_crown": 1, "crystal_shard": 8, "gold_ore": 5}],
	],
}
const TITLES := {"workbench": "WORKBENCH", "anvil": "BEN'S ANVIL"}

var is_open := false
var _station := "workbench"
var _stage: Control
var _panel: Panel
var _title: Label
var _list: Control
var _info: Label
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
	_panel = UIKit.panel(_stage, Vector2(156, 30), Vector2(840, 588))
	var pf := UIKit.panel(_panel, Vector2(24, 18), Vector2(64, 64), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	_icon = UIKit.tex(pf, null, Vector2(8, 8), Vector2(48, 48))
	_title = UIKit.label(_panel, "", UIKit.F_HEAD, UIKit.C_TEXT, Vector2(104, 22))
	UIKit.label(_panel, "TURN WHAT YOU GATHER INTO GEAR", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(104, 62))
	UIKit.color_rect(_panel, UIKit.C_LINE, Vector2(24, 96), Vector2(792, 3))
	_info = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(24, 110))
	_list = Control.new()
	_list.position = Vector2(24, 140)
	_list.size = Vector2(792, ROW_H * VISIBLE_ROWS)
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_list)
	_list.gui_input.connect(_on_list_input)
	var close := UIKit.button(_panel, "CLOSE  ESC", Vector2(24, 528))
	close.pressed.connect(close_crafting)
	UIKit.label(_panel, "WHEEL / W S: SCROLL", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(560, 541))
	visible = false


func open_crafting(station: String) -> void:
	_station = station if RECIPES.has(station) else "workbench"
	_title.text = TITLES.get(_station, "CRAFTING")
	_icon.texture = load(V12 + ("anvil.png" if _station == "anvil" else "workbench.png"))
	_scroll = 0
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
	var need: Dictionary = recipe[2]
	for id in need:
		if count_item(id) < int(need[id]):
			return false
	return true


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var rows: Array = RECIPES.get(_station, [])
	var ready := 0
	for r in rows:
		if can_craft(r):
			ready += 1
	_info.text = "%d RECIPE%s READY · GATHER MORE IN THE HOLLOW MINES" % [ready, "" if ready == 1 else "S"]
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
	UIKit.tex(slot, item.icon, Vector2(5, 5), Vector2(32, 32))
	var name := str(item.display_name).to_upper()
	if int(r[1]) > 1:
		name += " x%d" % int(r[1])
	UIKit.label(row, name, UIKit.F_SMALL, UIKit.C_GOLD_LIGHT if ok else UIKit.C_TEXT, Vector2(62, 6))
	# Ingredients with icons
	var x := 62.0
	var need: Dictionary = r[2]
	for id in need:
		var ing = ItemDB.get_item(id)
		var have := count_item(id)
		var n := int(need[id])
		var ic := UIKit.tex(row, ing.icon if ing else null, Vector2(x, 28), Vector2(22, 22))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var txt := "%d/%d" % [mini(have, 99), n]
		UIKit.label(row, txt, UIKit.F_SMALL, UIKit.C_GREEN if have >= n else UIKit.C_RED, Vector2(x + 25, 30))
		x += 30.0 + UIKit.text_w(txt) + 14.0
	var desc := str(item.description).to_upper()
	if desc != "" and x < 420.0:
		UIKit.label(row, _fit(desc, int((560.0 - x) / 12.0)), UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(x + 6, 30))
	var b := UIKit.button(row, "CRAFT", Vector2(668, 6), ok, false, 112)
	b.disabled = not ok
	var rec := r
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


func _craft(r: Array) -> void:
	if not can_craft(r):
		return
	var inv := _inv()
	var item = ItemDB.get_item(str(r[0]))
	if not inv or item == null:
		return
	var need: Dictionary = r[2]
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


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
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
		return "USE ANVIL" if station == "anvil" else "USE WORKBENCH"

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
	var spr := Sprite2D.new()
	var file := "anvil.png" if station == "anvil" else "workbench.png"
	spr.texture = load(V12 + file)
	spr.offset = Vector2(0, -spr.texture.get_height() * 0.5)
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
