extends CanvasLayer

## New-player tutorial. Offered on every brand-new farm; can be skipped at any time.
## Steps complete themselves when the player actually does the thing.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

const STEPS := [
	{"id": "move", "title": "FIND YOUR FEET", "text": "WALK WITH W A S D OR THE ARROW KEYS. HOLD SHIFT TO RUN."},
	{"id": "hoe", "title": "TILL THE SOIL", "text": "PRESS F TO OPEN YOUR BAG. CLICK THE HOE, THEN A HOTBAR SLOT. SELECT IT (1-4), AIM AT THE DIRT FIELD AND LEFT CLICK."},
	{"id": "plant", "title": "PLANT A SEED", "text": "PUT A SEED PACKET ON YOUR HOTBAR, SELECT IT AND LEFT CLICK THE TILLED SOIL."},
	{"id": "water", "title": "WATER IT", "text": "SELECT THE WATERING CAN AND CLICK YOUR SEEDS. DRY SEEDS NEVER GROW."},
	{"id": "chop", "title": "GATHER WOOD", "text": "SELECT THE WOOD AXE AND HIT A TREE UNTIL IT FALLS."},
	{"id": "shop", "title": "MEET THE VILLAGE", "text": "FOLLOW THE ROAD WEST TO THE VILLAGE. TALK TO ROSA AT HER STALL WITH E."},
	{"id": "trade", "title": "TRADE", "text": "SELL SOME CROPS FOR GOLD, OR BUY SEEDS AND BREAD."},
	{"id": "defend", "title": "BUILD A DEFENSE", "text": "BEN SENT YOU 2 BARRICADES. PUT ONE ON THE HOTBAR, AIM NEAR YOUR CROPS AND LEFT CLICK TO BUILD."},
	{"id": "night", "title": "SURVIVE THE NIGHT", "text": "AT 7 PM ZOMBIES RISE AND RAID YOUR CROPS. FIGHT WITH THE SWORD, OR HIDE INSIDE AND SLEEP IN YOUR BED. EACH NIGHT GETS HARDER.", "manual": true},
]

var save_key := "tutorial"
var done: bool = false
var step: int = 0
var active: bool = false
var is_open: bool = false   ## only true while the welcome popup is up (blocks the player)

var _loaded := false
var _game: Node
var _stage: Control
var _card: Panel
var _card_title: Label
var _card_text: Label
var _card_count: Label
var _ok_button: Button
var _welcome: Panel
var _player: Node2D
var _start_pos := Vector2.ZERO
var _moved := 0.0
var _last_pos := Vector2.ZERO
var _baseline := {}
var _poll := 0.0
var _advancing := false


func _ready() -> void:
	layer = 55
	add_to_group("tutorial")
	add_to_group("save_extension")
	add_to_group("menu_ui")
	_game = get_parent()
	_stage = UIKit.stage(self)
	_build_card()
	_build_welcome()
	if has_node("/root/SaveManager"):
		SaveManager.session_started.connect(_on_session_started)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		_connect_bus(bus)
	call_deferred("_late_bus")


func _late_bus() -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		_connect_bus(bus)


func _connect_bus(bus: Node) -> void:
	if bus.has_meta("tutorial_hooked"):
		return
	bus.set_meta("tutorial_hooked", true)
	bus.crop_watered.connect(func() -> void: _event("water"))
	bus.tree_cut.connect(func() -> void: _event("chop"))
	bus.gameplay_event.connect(_on_gameplay_event)


func _on_gameplay_event(t: String, _d: Dictionary) -> void:
	match t:
		"shop_opened":
			_event("shop")
		"item_sold", "item_bought":
			_event("trade")
		"defense_built":
			_event("defend")


func _on_session_started(root: Node, is_new: bool) -> void:
	if root != _game:
		return
	if not is_new and not _loaded:
		done = true   # farms from before this update: don't nag
	if done:
		return
	if is_new and step == 0:
		_show_welcome()
	else:
		_begin(step)


# --------------------------------------------------------------------------

func _build_card() -> void:
	_card = UIKit.panel(_stage, Vector2(716, 210), Vector2(420, 150), UIKit.box(Color(0.08, 0.06, 0.04, 0.93), UIKit.C_GOLD, 3, true))
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_count = UIKit.label(_card, "", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(18, 12))
	_card_title = UIKit.label(_card, "", UIKit.F_SMALL, UIKit.C_GOLD_LIGHT, Vector2(18, 36))
	_card_text = UIKit.wrap_label(_card, "", UIKit.F_SMALL, UIKit.C_TEXT, Vector2(18, 62), 384)
	var skip := UIKit.button(_card, "SKIP", Vector2(330, 6), false, true, 76)
	skip.size = Vector2(76, 30)
	(skip.get_node("Text") as Label).position.y = 6
	skip.pressed.connect(skip_tutorial)
	_ok_button = UIKit.button(_card, "GOT IT", Vector2(290, 100), true, false, 112)
	_ok_button.size.y = 38
	(_ok_button.get_node("Text") as Label).position.y = 10
	_ok_button.pressed.connect(func() -> void: _complete_step())
	_card.visible = false


func _build_welcome() -> void:
	_welcome = UIKit.panel(_stage, Vector2(326, 170), Vector2(500, 290))
	var name := "FARMER"
	if has_node("/root/SaveManager"):
		name = str(SaveManager.active_info.get("farmer_name", "FARMER"))
	var t := UIKit.label(_welcome, "WELCOME, %s!" % name.to_upper(), UIKit.F_BIG, UIKit.C_GOLD_LIGHT, Vector2(0, 24))
	t.size = Vector2(500, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.wrap_label(_welcome, "THIS FARM IS YOURS NOW. BY DAY YOU GROW CROPS AND TRADE IN THE VILLAGE. BY NIGHT THE DEAD COME FOR YOUR HARVEST.", UIKit.F_SMALL, UIKit.C_TEXT, Vector2(30, 74), 440)
	UIKit.wrap_label(_welcome, "NEW HERE? THE TUTORIAL TAKES ABOUT 5 MINUTES.", UIKit.F_SMALL, UIKit.C_TEXT_DIM, Vector2(30, 170), 440)
	var start := UIKit.button(_welcome, "START TUTORIAL", Vector2(40, 218), true, false, 230)
	start.pressed.connect(func() -> void:
		_hide_welcome()
		_begin(0))
	var skip := UIKit.button(_welcome, "SKIP", Vector2(290, 218), false, false, 170)
	skip.pressed.connect(func() -> void:
		_hide_welcome()
		skip_tutorial())
	_welcome.visible = false


func _show_welcome() -> void:
	_welcome.visible = true
	is_open = true
	_welcome.modulate.a = 0.0
	create_tween().tween_property(_welcome, "modulate:a", 1.0, 0.3)


func _hide_welcome() -> void:
	_welcome.visible = false
	is_open = false


func _begin(i: int) -> void:
	if i >= STEPS.size():
		_finish()
		return
	step = i
	active = true
	_advancing = false
	var s: Dictionary = STEPS[i]
	_card_count.text = "TUTORIAL %d / %d" % [i + 1, STEPS.size()]
	_card_title.text = s["title"]
	_card_text.text = s["text"]
	_ok_button.visible = s.get("manual", false)
	var lines := ceili(float(str(s["text"]).length()) / 29.0)
	_card.size.y = 76 + 24 * lines + (52 if s.get("manual", false) else 0)
	_ok_button.position.y = _card.size.y - 48
	_card.visible = true
	_card.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)
	_capture_baseline()
	if s["id"] == "defend":
		_gift_barricades()


func _capture_baseline() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_last_pos = _player.global_position
	_moved = 0.0
	_baseline = {"tilled": _tilled_count(), "crops": get_tree().get_nodes_in_group("crops").size()}


func _tilled_count() -> int:
	var fm := get_tree().get_first_node_in_group("farming_manager")
	if not fm:
		return 0
	var n := 0
	var tiles: Dictionary = fm.get("_farm_tiles")
	for k in tiles:
		if int(tiles[k].get("state", 0)) != 0:
			n += 1
	return n


func _gift_barricades() -> void:
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var item = load("res://scripts/item_database.gd").get_item("barricade")
	if inv and item:
		inv.add_item(item, 2)
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud:
			hud.show_hud_message("Ben sent you 2 Wooden Barricades!", 3.0)


func _process(delta: float) -> void:
	if not active or _advancing:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.25
	var id: String = STEPS[step]["id"]
	match id:
		"move":
			if _player:
				_moved += _player.global_position.distance_to(_last_pos)
				_last_pos = _player.global_position
				if _moved > 140.0:
					_complete_step()
		"hoe":
			if _tilled_count() > int(_baseline.get("tilled", 0)):
				_complete_step()
		"plant":
			if get_tree().get_nodes_in_group("crops").size() > int(_baseline.get("crops", 0)):
				_complete_step()


func _event(id: String) -> void:
	if active and not _advancing and STEPS[step]["id"] == id:
		_complete_step()


func _complete_step() -> void:
	if _advancing:
		return
	_advancing = true
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("xp_gain", -6.0)
	_card_title.text = "DONE! " + str(STEPS[step]["title"])
	_card_title.add_theme_color_override("font_color", UIKit.C_GREEN)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		_card_title.add_theme_color_override("font_color", UIKit.C_GOLD_LIGHT)
		_begin(step + 1))


func _finish() -> void:
	active = false
	done = true
	_card.visible = false
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_gold(50)
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message("Tutorial complete! +50 gold. Good luck tonight.", 4.0)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("quest_complete")


func skip_tutorial() -> void:
	active = false
	done = true
	_card.visible = false
	_hide_welcome()
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message("Tutorial skipped. Talk to the villagers for tips!", 3.0)


func get_save_data() -> Dictionary:
	return {"done": done, "step": step}


func load_save_data(d: Dictionary) -> void:
	_loaded = true
	done = bool(d.get("done", false))
	step = int(d.get("step", 0))
