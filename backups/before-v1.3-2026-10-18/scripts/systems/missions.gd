extends CanvasLayer

## Missions (v1.2) — the village quest board and the main story.
##
##  * Three villager requests at a time: deliveries, mining depth, monster hunts,
##    zombie kills, crafting and building. New requests post every morning.
##  * Completing requests earns gold, EXP and TOWN REPUTATION. Reputation unlocks
##    new seeds and gear in the shops (see economy.gd "rep").
##  * Story: "The Hollow Below" — five chapters that lead down to the Hollow King.
## Saved in the save file's "ext" section.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const V12 := "res://Assets/Generated/v12/"
const BOARD_POS := Vector2(-805, 305)

const STORY := [
	{"text": "Enter the Hollow Mines (old quarry, north-east)", "short": "Find the mine in the NE quarry", "event": "mine_floor_reached", "need": 1, "gold": 40, "rep": 1},
	{"text": "Reach floor 5 of the mines", "short": "Reach mine floor 5", "event": "mine_depth", "need": 5, "gold": 120, "rep": 1},
	{"text": "Find Old Tomas' 3 journal pages", "short": "Find Tomas' journal pages", "event": "journal_found", "need": 3, "gold": 200, "rep": 2},
	{"text": "Defeat the Hollow King on floor 15", "short": "Slay the Hollow King (F15)", "event": "boss_defeated", "need": 1, "gold": 500, "rep": 3},
	{"text": "Forge the Hollow Blade at Ben's anvil", "short": "Forge the Hollow Blade", "event": "crafted:hollow_blade", "need": 1, "gold": 300, "rep": 2},
]
const GIVERS := ["Rosa", "Ben", "Mayor Pedro", "Lina"]

signal missions_changed

var reputation: int = 0
var active: Array = []         ## [{id, giver, text, kind, item, need, have, gold, xp, rep, done}]
var story_step: int = 0
var story_progress: int = 0
var completed_total: int = 0
var save_key := "missions"
var is_open := false

var _game: Node2D
var _stage: Control
var _panel: Panel
var _list: Control
var _rep_label: Label
var _story_label: Label
var _hud_story: Label
var _rng := RandomNumberGenerator.new()
var _day := 1


func _ready() -> void:
	layer = 62
	add_to_group("missions")
	add_to_group("save_extension")
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent() as Node2D
	_rng.randomize()
	_build_ui()
	call_deferred("_late_setup")


func _late_setup() -> void:
	var bus := get_tree().get_first_node_in_group("event_bus")
	if bus:
		bus.gameplay_event.connect(_on_event)
		if bus.has_signal("zombie_killed"):
			bus.zombie_killed.connect(func() -> void: _progress("zombies", "", 1))
		if bus.has_signal("crop_harvested"):
			bus.crop_harvested.connect(func(id: String) -> void: _progress("harvest", id, 1))
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock:
		clock.day_changed.connect(_on_new_day)
		_day = clock.current_day
	_build_board()
	_add_hud_line()
	if active.is_empty():
		_fill_requests()
	_update_hud()


# ==========================================================================
# Requests
# ==========================================================================

func _deepest() -> int:
	var m := get_tree().get_first_node_in_group("mines")
	return int(m.get("deepest")) if m else 0


func _make_request() -> Dictionary:
	var deep := _deepest()
	var pool: Array = []
	# Deliveries scale with what the player can reach
	var crops := ["carrot", "wheat", "potato", "tomato", "corn", "watermelon"]
	if reputation >= 1:
		crops.append("strawberry")
	if reputation >= 3:
		crops.append("pumpkin")
	var c: String = crops[_rng.randi() % crops.size()]
	var n := _rng.randi_range(4, 10) if c in ["carrot", "wheat", "strawberry"] else _rng.randi_range(2, 6)
	pool.append({"kind": "deliver", "item": c, "need": n, "gold": int(_sell(c) * n * 1.7) + 15, "xp": 25 + n * 3, "rep": 1})
	pool.append({"kind": "deliver", "item": "wood_log", "need": _rng.randi_range(10, 20), "gold": 45, "xp": 25, "rep": 1})
	pool.append({"kind": "zombies", "item": "", "need": _rng.randi_range(5, 12), "gold": 90, "xp": 60, "rep": 1})
	pool.append({"kind": "build", "item": "", "need": _rng.randi_range(2, 4), "gold": 60, "xp": 40, "rep": 1})
	if deep >= 1:
		pool.append({"kind": "depth", "item": "", "need": deep + _rng.randi_range(2, 4), "gold": 80 + deep * 12, "xp": 60 + deep * 6, "rep": 1})
		pool.append({"kind": "hunt", "item": "", "need": _rng.randi_range(6, 14), "gold": 70 + deep * 6, "xp": 50, "rep": 1})
		pool.append({"kind": "deliver", "item": "copper_ore", "need": _rng.randi_range(6, 12), "gold": 90, "xp": 40, "rep": 1})
	if deep >= 5:
		pool.append({"kind": "deliver", "item": "iron_ore", "need": _rng.randi_range(5, 10), "gold": 160, "xp": 60, "rep": 2})
		pool.append({"kind": "craft", "item": "sprinkler", "need": 1, "gold": 70, "xp": 50, "rep": 1})
	if deep >= 10:
		pool.append({"kind": "deliver", "item": "gold_ore", "need": _rng.randi_range(4, 8), "gold": 260, "xp": 90, "rep": 2})
	if reputation >= 2:
		pool.append({"kind": "deliver", "item": "sunflower", "need": _rng.randi_range(2, 4), "gold": 140, "xp": 50, "rep": 1})
	if reputation >= 5:
		pool.append({"kind": "deliver", "item": "moonflower", "need": _rng.randi_range(1, 3), "gold": 320, "xp": 120, "rep": 2})
	var r: Dictionary = pool[_rng.randi() % pool.size()].duplicate()
	r["id"] = str(Time.get_ticks_usec()) + str(_rng.randi() % 1000)
	r["giver"] = GIVERS[_rng.randi() % GIVERS.size()]
	r["have"] = 0
	r["done"] = false
	r["text"] = _describe(r)
	return r


func _sell(id: String) -> int:
	var e = load("res://scripts/systems/economy.gd")
	return maxi(3, e.sell_price(id))


func _describe(r: Dictionary) -> String:
	match str(r["kind"]):
		"deliver":
			var it = ItemDB.get_item(str(r["item"]))
			var nm: String = str(it.display_name) if it else str(r["item"])
			return "Bring %s x%d" % [nm, int(r["need"])]
		"zombies":
			return "Kill %d zombies" % int(r["need"])
		"build":
			return "Build %d defenses" % int(r["need"])
		"depth":
			return "Reach mine floor %d" % int(r["need"])
		"hunt":
			return "Defeat %d cave monsters" % int(r["need"])
		"craft":
			var it2 = ItemDB.get_item(str(r["item"]))
			return "Craft a %s" % (str(it2.display_name) if it2 else str(r["item"]))
	return "Help out"


func _fill_requests() -> void:
	var keep: Array = []
	for r in active:
		if not r["done"]:
			keep.append(r)
	active = keep
	var guard := 0
	while active.size() < 3 and guard < 20:
		guard += 1
		var r := _make_request()
		var dup := false
		for a in active:
			if a["kind"] == r["kind"] and a["item"] == r["item"]:
				dup = true
		if not dup:
			active.append(r)
	missions_changed.emit()
	_refresh()


func _on_new_day(d: int) -> void:
	_day = d
	_fill_requests()


func _progress(kind: String, item: String, amount: int) -> void:
	var changed := false
	for r in active:
		if r["done"] or r["kind"] != kind:
			continue
		if kind == "craft" and r["item"] != item:
			continue
		if kind == "depth":
			r["have"] = maxi(int(r["have"]), amount)
		else:
			r["have"] = int(r["have"]) + amount
		changed = true
		if int(r["have"]) >= int(r["need"]):
			_complete(r)
	if changed:
		_refresh()


func _complete(r: Dictionary) -> void:
	r["done"] = true
	r["have"] = r["need"]
	completed_total += 1
	_reward(int(r["gold"]), int(r["xp"]), int(r["rep"]), "%s: \"Thank you!\"" % r["giver"])
	_event("mission_completed", {"kind": r["kind"]})


func _reward(gold: int, xp: int, rep: int, msg: String) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_gold(gold)
		stats.add_xp(xp)
	var before := reputation
	reputation += rep
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("mission", -4.0)
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		var extra := ""
		if _unlock_text(before, reputation) != "":
			extra = "  NEW IN SHOPS: " + _unlock_text(before, reputation)
		hud.show_hud_message("%s  +%d gold, +%d rep.%s" % [msg, gold, rep, extra], 4.0)
	var juice := get_tree().get_first_node_in_group("juice")
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if juice and p:
		juice.popup_text(p.global_position + Vector2(0, -30), "MISSION COMPLETE!", Color("FFDB80"), true)
	missions_changed.emit()


func _unlock_text(before: int, after: int) -> String:
	var unlocks := {1: "Strawberry seeds", 2: "Sunflower seeds", 3: "Pumpkin seeds", 4: "War Hammer", 5: "Moonflower seeds"}
	var parts: PackedStringArray = []
	for k in unlocks:
		if before < int(k) and after >= int(k):
			parts.append(unlocks[k])
	return ", ".join(parts)


func _on_event(t: String, data: Dictionary) -> void:
	match t:
		"mine_floor_reached":
			_progress("depth", "", int(data.get("floor", 0)))
			_story_event("mine_floor_reached", 1)
			_story_event("mine_depth", maxi(int(data.get("floor", 0)), _deepest()), true)
		"cave_enemy_killed":
			_progress("hunt", "", 1)
		"defense_built":
			_progress("build", "", 1)
		"item_crafted":
			_progress("craft", str(data.get("id", "")), 1)
			_story_event("crafted:" + str(data.get("id", "")), 1)
		"journal_found":
			_story_event("journal_found", int(data.get("total", 0)), true)
		"boss_defeated":
			_story_event("boss_defeated", 1)


func _story_event(ev: String, value: int, absolute: bool = false) -> void:
	if story_step >= STORY.size():
		return
	var s: Dictionary = STORY[story_step]
	if s["event"] != ev:
		return
	story_progress = value if absolute else story_progress + value
	if story_progress >= int(s["need"]):
		story_progress = 0
		story_step += 1
		_reward(int(s["gold"]), 100, int(s["rep"]), "STORY: " + str(s["text"]) + " — done!")
		# Skip ahead if the next chapter is already satisfied (e.g. deep saves)
		if story_step < STORY.size():
			var nxt: Dictionary = STORY[story_step]
			if nxt["event"] == "mine_depth" and _deepest() >= int(nxt["need"]):
				_story_event("mine_depth", _deepest(), true)
			elif nxt["event"] == "journal_found":
				var m := get_tree().get_first_node_in_group("mines")
				if m and (m.get("journals") as Dictionary).size() >= 3:
					_story_event("journal_found", 3, true)
			elif nxt["event"] == "boss_defeated":
				var m2 := get_tree().get_first_node_in_group("mines")
				if m2 and m2.get("boss_defeated"):
					_story_event("boss_defeated", 1)
	_update_hud()
	_refresh()


func story_text() -> String:
	if story_step >= STORY.size():
		return "The Hollow is quiet. You saved Harvest Hollow!"
	var s: Dictionary = STORY[story_step]
	var t: String = s["text"]
	if int(s["need"]) > 1:
		t += " (%d/%d)" % [story_progress, int(s["need"])]
	return t


# ==========================================================================
# Delivering items at the board
# ==========================================================================

func _count(id: String) -> int:
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if not inv:
		return 0
	var n := 0
	for s in inv.hotbar_slots + inv.slots:
		if s["item"] != null and s["item"].get("item_id") == id:
			n += int(s["amount"])
	return n


func _deliver(r: Dictionary) -> void:
	var need := int(r["need"])
	if _count(str(r["item"])) < need:
		return
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var Shop = load("res://scripts/systems/shop_ui.gd")
	Shop._remove_items(inv, str(r["item"]), need)
	r["have"] = need
	_complete(r)
	_refresh()


# ==========================================================================
# UI
# ==========================================================================

func _build_ui() -> void:
	_stage = UIKit.stage(self)
	var dim := UIKit.color_rect(_stage, Color(0, 0, 0, 0.45), Vector2(-2000, -2000), Vector2(6000, 6000))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UIKit.panel(_stage, Vector2(156, 30), Vector2(840, 588))
	var pf := UIKit.panel(_panel, Vector2(24, 18), Vector2(64, 64), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	UIKit.tex(pf, load(V12 + "quest_board.png"), Vector2(4, 8), Vector2(56, 44))
	UIKit.label(_panel, "QUEST BOARD", UIKit.F_HEAD, UIKit.C_TEXT, Vector2(104, 22))
	_rep_label = UIKit.label(_panel, "", UIKit.F_SMALL, UIKit.C_GOLD_LIGHT, Vector2(104, 62))
	UIKit.color_rect(_panel, UIKit.C_LINE, Vector2(24, 96), Vector2(792, 3))
	var sp := UIKit.panel(_panel, Vector2(24, 110), Vector2(792, 76), UIKit.box(Color("2A1C10"), UIKit.C_GOLD, 2, false))
	UIKit.label(sp, "STORY · THE HOLLOW BELOW", UIKit.F_SMALL, UIKit.C_GOLD, Vector2(16, 10))
	_story_label = UIKit.label(sp, "", UIKit.F_SMALL, UIKit.C_TEXT, Vector2(16, 40))
	UIKit.label(_panel, "TOWN REQUESTS · NEW ONES EVERY MORNING", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(24, 200))
	_list = Control.new()
	_list.position = Vector2(24, 228)
	_list.size = Vector2(792, 290)
	_panel.add_child(_list)
	var close := UIKit.button(_panel, "CLOSE  ESC", Vector2(24, 528))
	close.pressed.connect(close_board)
	visible = false


func open_board() -> void:
	visible = true
	is_open = true
	_refresh()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


func close_board() -> void:
	visible = false
	is_open = false


func _refresh() -> void:
	if _rep_label == null:
		return
	_rep_label.text = "TOWN REPUTATION %d · MISSIONS DONE %d" % [reputation, completed_total]
	_story_label.text = story_text().to_upper()
	_update_hud()
	if not is_open:
		return
	for c in _list.get_children():
		c.queue_free()
	var y := 0.0
	for r in active:
		_row(r, y)
		y += 94.0


func _row(r: Dictionary, y: float) -> void:
	var done: bool = r["done"]
	var row := UIKit.panel(_list, Vector2(0, y), Vector2(792, 86), UIKit.box(UIKit.C_ROW, UIKit.C_GOLD if done else Color("3A2818"), 2, false))
	var icon: Texture2D = null
	if str(r["item"]) != "":
		var it = ItemDB.get_item(str(r["item"]))
		icon = it.icon if it else null
	else:
		match str(r["kind"]):
			"zombies":
				icon = load("res://Assets/Generated/skull.png")
			"depth", "hunt":
				icon = load(V12 + "icon_copper_pickaxe.png")
			"build":
				icon = load("res://Assets/Generated/barricade.png")
	var slot := UIKit.panel(row, Vector2(10, 14), Vector2(56, 56), UIKit.box(Color("120C08"), Color("574029"), 2, false))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		UIKit.tex(slot, icon, Vector2(8, 8), Vector2(40, 40))
	UIKit.label(row, str(r["giver"]).to_upper() + " ASKS:", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(80, 10))
	UIKit.label(row, str(r["text"]).to_upper(), UIKit.F_SMALL, UIKit.C_GOLD_LIGHT if not done else UIKit.C_GREEN, Vector2(80, 34))
	var have := int(r["have"])
	if r["kind"] == "deliver" and not done:
		have = _count(str(r["item"]))
	var reward := "+%d GOLD · +%d REP" % [int(r["gold"]), int(r["rep"])]
	UIKit.label(row, ("DONE! " if done else "%d/%d · " % [mini(have, int(r["need"])), int(r["need"])]) + reward, UIKit.F_SMALL, UIKit.C_TEXT_SOFT, Vector2(80, 58))
	if r["kind"] == "deliver" and not done:
		var ok := have >= int(r["need"])
		var b := UIKit.button(row, "DELIVER", Vector2(650, 20), ok, false, 124)
		b.disabled = not ok
		var rr := r
		b.pressed.connect(func() -> void: _deliver(rr))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_board()
		get_viewport().set_input_as_handled()


# --- HUD story line & world board ---

func _add_hud_line() -> void:
	var vbox := _game.get_node_or_null("UI/HUD/MidLeft/QuestTracker/Margin/VBox") as VBoxContainer
	if not vbox:
		return
	_hud_story = Label.new()
	_hud_story.add_theme_font_size_override("font_size", 10)
	_hud_story.add_theme_color_override("font_color", Color("F0C266"))
	_hud_story.clip_text = true
	vbox.add_child(_hud_story)


func _update_hud() -> void:
	if not _hud_story:
		return
	if story_step >= STORY.size():
		_hud_story.text = "★ Harvest Hollow is safe"
		return
	var s: Dictionary = STORY[story_step]
	var t: String = s.get("short", s["text"])
	if int(s["need"]) > 1 and s["event"] == "journal_found":
		t += " %d/%d" % [story_progress, int(s["need"])]
	_hud_story.text = "★ " + t


class Board extends Node2D:
	var interact_range := 26.0

	func _ready() -> void:
		add_to_group("interactables")

	func can_interact(_p: Node2D) -> bool:
		return true

	func get_prompt() -> String:
		return "READ QUEST BOARD"

	func interact(_p: Node2D) -> void:
		var m := get_tree().get_first_node_in_group("missions")
		if m:
			m.open_board()


func _build_board() -> void:
	var root := Node2D.new()
	root.name = "QuestBoard"
	_game.add_child(root)
	root.global_position = BOARD_POS
	var spr := Sprite2D.new()
	spr.texture = load(V12 + "quest_board.png")
	spr.offset = Vector2(0, -11)
	root.add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for x in [-8, 8]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(6, 4)
		cs.shape = rs
		cs.position = Vector2(x, -2)
		body.add_child(cs)
	root.add_child(body)
	var b := Board.new()
	root.add_child(b)
	b.position = Vector2(0, 4)


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


# ==========================================================================
# Save
# ==========================================================================

func get_save_data() -> Dictionary:
	return {"rep": reputation, "active": active, "story": story_step, "story_p": story_progress, "done": completed_total}


func load_save_data(d: Dictionary) -> void:
	reputation = int(d.get("rep", 0))
	active = d.get("active", [])
	story_step = int(d.get("story", 0))
	story_progress = int(d.get("story_p", 0))
	completed_total = int(d.get("done", 0))
	if active.is_empty():
		_fill_requests()
	_refresh()
