extends CanvasLayer

## Shop window: BUY from Rosa (seeds, food, torches) or Ben (defenses, steel),
## SELL your harvest to anyone. Gold is the PlayerStats gold shown on the HUD.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const Economy = preload("res://scripts/systems/economy.gd")
const ItemDB = preload("res://scripts/item_database.gd")

const SHOP_NAMES := {"general": "ROSA'S GOODS", "smith": "BEN'S FORGE"}
const ROW_H := 58.0
const VISIBLE_ROWS := 6

var is_open: bool = false

var _stage: Control
var _panel: Panel
var _title: Label
var _gold_label: Label
var _portrait: TextureRect
var _list: Control
var _tab_buttons: Dictionary = {}
var _tab := "buy"
var _shop_id := "general"
var _keeper: Node = null
var _scroll := 0
var _info: Label
var _flash_t := 0.0


func _ready() -> void:
	layer = 62
	add_to_group("shop_ui")
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = UIKit.stage(self)
	var dim := UIKit.color_rect(_stage, Color(0, 0, 0, 0.45), Vector2(-2000, -2000), Vector2(6000, 6000))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UIKit.panel(_stage, Vector2(176, 40), Vector2(800, 568))
	var pf := UIKit.panel(_panel, Vector2(24, 18), Vector2(64, 64), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	_portrait = UIKit.tex(pf, null, Vector2(4, 4), Vector2(56, 56))
	_title = UIKit.label(_panel, "", UIKit.F_HEAD, UIKit.C_TEXT, Vector2(104, 22))
	var coin := UIKit.tex(_panel, load("res://Assets/Generated/icon_coin.png"), Vector2(600, 28), Vector2(36, 36))
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	_gold_label = UIKit.label(_panel, "0", UIKit.F_BIG, UIKit.C_GOLD_LIGHT, Vector2(644, 32))
	UIKit.color_rect(_panel, UIKit.C_LINE, Vector2(24, 96), Vector2(752, 3))
	var x := 24.0
	for t in [["buy", "BUY"], ["sell", "SELL"]]:
		var b := UIKit.button(_panel, t[1], Vector2(x, 108), false, false, 120)
		var id: String = t[0]
		b.pressed.connect(func() -> void: _select_tab(id))
		_tab_buttons[id] = b
		x += 128.0
	_info = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(300, 121))
	_list = Control.new()
	_list.position = Vector2(24, 164)
	_list.size = Vector2(752, ROW_H * VISIBLE_ROWS)
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_list)
	_list.gui_input.connect(_on_list_input)
	var close := UIKit.button(_panel, "CLOSE  ESC", Vector2(24, 510))
	close.pressed.connect(close_shop)
	UIKit.label(_panel, "WHEEL: SCROLL · SHIFT+CLICK: BUY 5", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(380, 523))
	visible = false


func open_shop(shop_id: String, keeper: Node = null) -> void:
	_shop_id = shop_id
	_keeper = keeper
	_title.text = SHOP_NAMES.get(shop_id, "SHOP")
	_portrait.texture = keeper.portrait() if keeper and keeper.has_method("portrait") else null
	_scroll = 0
	visible = true
	is_open = true
	_select_tab("buy")
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
	_event("shop_opened", {"shop": shop_id})


func close_shop() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if _keeper and is_instance_valid(_keeper) and _keeper.has_method("end_talk"):
		_keeper.end_talk()


func _select_tab(id: String) -> void:
	_tab = id
	_scroll = 0
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var on: bool = k == id
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.C_PANEL_HI if on else UIKit.C_ROW, UIKit.C_GOLD if on else UIKit.C_BTN_BORDER, 3, true))
		(b.get_node("Text") as Label).add_theme_color_override("font_color", UIKit.C_GOLD_LIGHT if on else UIKit.C_TEXT_DIM)
	_refresh()


# --------------------------------------------------------------------------

func _stats() -> Node:
	return get_tree().get_first_node_in_group("player_stats")


func _inv() -> Node:
	return get_tree().get_first_node_in_group("inventory_ui")


func _nights() -> int:
	var d := get_tree().get_first_node_in_group("night_director")
	return int(d.get("nights_survived")) if d else 0


func _price_of(entry: Dictionary) -> int:
	var base := int(entry["price"])
	if entry.get("defense", false):
		var extras := get_tree().get_first_node_in_group("game_extras")
		var mult: float = extras.defense_price_mult() if extras else 1.0
		return Economy.defense_price(base, _nights(), mult)
	return base


func _count_item(item_id: String) -> int:
	var inv := _inv()
	if not inv:
		return 0
	var n := 0
	for s in inv.hotbar_slots + inv.slots:
		if s["item"] != null and s["item"].get("item_id") == item_id:
			n += int(s["amount"])
	return n


func _refresh() -> void:
	var stats := _stats()
	_gold_label.text = str(int(stats.gold)) if stats else "0"
	for c in _list.get_children():
		c.queue_free()
	var rows: Array = []
	if _tab == "buy":
		for e in Economy.STOCK.get(_shop_id, []):
			rows.append(e)
		_info.text = "PRICES RISE AS NIGHTS GET WORSE." if _shop_id == "smith" else "EVERY HARVEST GIVES A SEED BACK."
	else:
		var seen := {}
		var inv := _inv()
		if inv:
			for s in inv.hotbar_slots + inv.slots:
				if s["item"] == null:
					continue
				var id: String = s["item"].get("item_id")
				if Economy.can_sell(id) and not seen.has(id):
					seen[id] = true
					rows.append({"id": id, "price": Economy.sell_price(id)})
		_info.text = "NOTHING TO SELL. GO HARVEST!" if rows.is_empty() else "CROPS, WOOD, STONE AND SEEDS."
	_scroll = clampi(_scroll, 0, maxi(0, rows.size() - VISIBLE_ROWS))
	for i in range(_scroll, mini(rows.size(), _scroll + VISIBLE_ROWS)):
		_build_row(rows[i], float(i - _scroll) * ROW_H)


## Cuts text at a word boundary so it fits `n` characters (pixel font is monospaced).
func _fit(text: String, n: int) -> String:
	if text.length() <= n:
		return text
	var cut := text.left(n - 2)
	var sp := cut.rfind(" ")
	if sp > n / 2:
		cut = cut.left(sp)
	return cut.strip_edges().trim_suffix(".").trim_suffix(",") + ".."


func _build_row(e: Dictionary, y: float) -> void:
	var item = ItemDB.get_item(str(e["id"]))
	if item == null:
		return
	var row := UIKit.panel(_list, Vector2(0, y), Vector2(752, ROW_H - 6), UIKit.box(UIKit.C_ROW, Color("3A2818"), 2, false))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var slot := UIKit.panel(row, Vector2(8, 6), Vector2(40, 40), UIKit.box(Color("120C08"), Color("574029"), 2, false))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.tex(slot, item.icon, Vector2(4, 4), Vector2(32, 32))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UIKit.label(row, str(item.display_name).to_upper(), UIKit.F_SMALL, UIKit.C_TEXT, Vector2(60, 6))
	var have := _count_item(str(e["id"]))
	var desc := str(item.description).to_upper()
	if desc == "":
		desc = "SELL VALUE %d" % Economy.sell_price(str(e["id"]))
	var sub := UIKit.label(row, _fit(desc, 33), UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(60, 28))
	sub.add_theme_font_size_override("font_size", UIKit.F_SMALL)
	UIKit.label(row, "OWN %d" % have, UIKit.F_SMALL, UIKit.C_TEXT_SOFT, Vector2(468, 16))
	var price := _price_of(e) if _tab == "buy" else int(e["price"])
	var coin := UIKit.tex(row, load("res://Assets/Generated/icon_coin.png"), Vector2(548, 12), Vector2(24, 24))
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	UIKit.label(row, str(price), UIKit.F_SMALL, UIKit.C_GOLD_LIGHT, Vector2(578, 16))
	var id := str(e["id"])
	if _tab == "buy":
		var unlock := int(e.get("unlock_night", 0))
		if _nights() < unlock:
			UIKit.label(row, "NIGHT %d+" % unlock, UIKit.F_SMALL, UIKit.C_RED, Vector2(642, 16))
			row.modulate = Color(0.7, 0.7, 0.7)
			return
		var b := UIKit.button(row, "BUY", Vector2(636, 4), true, false, 104)
		b.pressed.connect(func() -> void:
			var n := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
			_buy(id, price, n))
	else:
		var b1 := UIKit.button(row, "SELL", Vector2(626, 4), true, false, 56)
		b1.size.x = 56
		UIKit.set_button_text(b1, "1")
		b1.pressed.connect(func() -> void: _sell(id, price, 1))
		var b2 := UIKit.button(row, "ALL", Vector2(686, 4), false, false, 60)
		b2.pressed.connect(func() -> void: _sell(id, price, have))


func _buy(id: String, price: int, n: int) -> void:
	var stats := _stats()
	var inv := _inv()
	if not stats or not inv:
		return
	var affordable := mini(n, int(stats.gold) / maxi(1, price))
	if affordable <= 0:
		_toast("NOT ENOUGH GOLD.")
		_play("zombie_warning", -18.0)
		return
	var item = ItemDB.get_item(id)
	var left: int = inv.add_item(item, affordable)
	var bought := affordable - left
	if bought <= 0:
		_toast("YOUR BAG IS FULL.")
		return
	stats.add_gold(-bought * price)
	_play("xp_gain", -8.0)
	_event("item_bought", {"id": id, "amount": bought})
	_refresh()


func _sell(id: String, price: int, n: int) -> void:
	var stats := _stats()
	var inv := _inv()
	if not stats or not inv or n <= 0:
		return
	var removed := _remove_items(inv, id, n)
	if removed <= 0:
		return
	stats.add_gold(removed * price)
	_play("quest_complete", -12.0)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("item_sold"):
			bus.item_sold.emit(id, removed)
			break
	_event("item_sold", {"id": id, "amount": removed, "gold": removed * price})
	_refresh()


## Removes up to n items with this id (backpack first, then hotbar). Returns how many.
static func _remove_items(inv: Node, id: String, n: int) -> int:
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
	if left != n:
		inv._update_slot_visuals()
		inv.inventory_changed.emit()
	return n - left


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
		close_shop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_scroll += 1
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_scroll = maxi(0, _scroll - 1)
		_refresh()
		get_viewport().set_input_as_handled()


func _toast(t: String) -> void:
	_info.text = t
	_info.add_theme_color_override("font_color", UIKit.C_RED)
	_flash_t = 1.6


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_info.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
			_refresh()


func _play(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break
