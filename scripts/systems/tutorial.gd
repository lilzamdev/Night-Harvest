extends CanvasLayer

## New-player tutorial. Offered on every brand-new farm; can be skipped at any time.
## Steps complete themselves when the player actually does the thing.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

const STEPS := [
	{"id": "move", "title": "FIND YOUR FEET", "text": "WALK WITH W A S D OR THE ARROW KEYS. HOLD SHIFT TO RUN. ITEMS ON THE GROUND FLY TO YOU."},
	{"id": "hoe", "title": "TILL THE SOIL", "text": "PRESS F TO OPEN YOUR BAG. CLICK THE HOE, THEN A HOTBAR SLOT. SELECT IT (1-4), AIM AT THE DIRT FIELD (OR ANY GRASS) AND LEFT CLICK."},
	{"id": "plant", "title": "PLANT A SEED", "text": "PUT A SEED PACKET ON YOUR HOTBAR, SELECT IT AND LEFT CLICK THE TILLED SOIL."},
	{"id": "water", "title": "WATER IT", "text": "SELECT THE WATERING CAN AND CLICK YOUR SEEDS. DRY SEEDS NEVER GROW."},
	{"id": "chop", "title": "GATHER WOOD", "text": "SELECT THE WOOD AXE AND HIT A TREE UNTIL IT FALLS."},
	{"id": "shop", "title": "MEET THE VILLAGE", "text": "FOLLOW THE ROAD WEST TO THE VILLAGE. TALK TO ROSA AT HER STALL WITH E."},
	{"id": "trade", "title": "TRADE", "text": "SELL SOME CROPS FOR GOLD, OR BUY SEEDS AND BREAD."},
	{"id": "defend", "title": "BUILD A DEFENSE", "text": "BEN SENT YOU 2 BARRICADES. PUT ONE ON THE HOTBAR, AIM NEAR YOUR CROPS AND LEFT CLICK TO BUILD."},
	{"id": "night", "title": "SURVIVE THE NIGHT", "text": "AT 7 PM ZOMBIES RISE AND RAID YOUR CROPS. FIGHT WITH THE SWORD, OR HIDE INSIDE AND SLEEP IN YOUR BED. EACH NIGHT GETS HARDER.", "manual": true},
]

## v1.3 endless worlds: you start out in the wild with only a hoe, a can and seeds.
const STEPS_WILD := [
	{"id": "move", "title": "FIND YOUR FEET", "text": "WALK WITH W A S D. HOLD SHIFT TO RUN. YOU START OUT IN THE WILD - THIS LAND IS YOURS TO SETTLE."},
	{"id": "punch", "title": "PUNCH A TREE", "text": "PRESS 8 FOR EMPTY HANDS, STAND NEXT TO A TREE AND KEEP CLICKING (OR SPACE). IT FALLS AFTER 8 PUNCHES AND DROPS WOOD."},
	{"id": "fiber", "title": "CUT TALL GRASS", "text": "HIT TALL GRASS WITH ANYTHING FOR PLANT FIBER. YOU NEED IT FOR TORCHES, FENCES AND A BED."},
	{"id": "bench", "title": "CRAFT A WORKBENCH", "text": "PRESS C TO CRAFT BY HAND. A WORKBENCH COSTS 6 WOOD."},
	{"id": "place", "title": "PLACE IT", "text": "PUT THE WORKBENCH IN YOUR HOTBAR, SELECT IT AND LEFT CLICK THE GROUND."},
	{"id": "tools", "title": "MAKE TOOLS", "text": "STAND AT THE WORKBENCH AND PRESS E. CRAFT A WOODEN PICKAXE, THEN AN AXE AND A SWORD."},
	{"id": "hoe", "title": "START YOUR FARM", "text": "SELECT THE HOE AND LEFT CLICK GRASS TO TILL IT. THEN PLANT A SEED ON THE SOIL."},
	{"id": "water", "title": "WATER IT", "text": "SELECT THE WATERING CAN AND CLICK YOUR SEEDS. DRY SEEDS NEVER GROW."},
	{"id": "shelter", "title": "BUILD A SHELTER", "text": "CRAFT WOODEN WALLS AND A DOOR AT THE WORKBENCH AND BUILD A HUT AROUND YOUR BED AND CROPS."},
	{"id": "night", "title": "SURVIVE THE NIGHT", "text": "AT 7 PM ZOMBIES RISE WHEREVER YOU ARE AND CHEW THROUGH WALLS FOR YOUR CROPS. FIGHT, OR SLEEP IN YOUR BED. THE SIGNPOST POINTS TO THE VILLAGE AND ITS SHOP.", "manual": true},
]

var steps: Array = STEPS
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
	process_mode = Node.PROCESS_MODE_ALWAYS   # v1.4.1: so it can hide itself while paused
	add_to_group("tutorial")
	add_to_group("save_extension")
	add_to_group("menu_ui")
	_game = get_parent()
	if has_node("/root/SaveManager") and int(SaveManager.active_info.get("world_version", 0)) >= 13:
		steps = STEPS_WILD
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
	bus.tree_cut.connect(func() -> void:
		_event("chop")
		_event("punch"))
	bus.gameplay_event.connect(_on_gameplay_event)


func _on_gameplay_event(t: String, _d: Dictionary) -> void:
	match t:
		"item_crafted":
			var cid := str(_d.get("id", ""))
			if cid == "workbench":
				_event("bench")
			elif cid in ["pickaxe", "wood_axe", "wooden_sword"]:
				_event("tools")
		"block_placed":
			var k := str(_d.get("kind", ""))
			if k == "workbench":
				_event("place")
			elif k in ["wall_wood", "door_wood", "wall_stone", "wall_brick"]:
				_event("shelter")
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
	# v1.4.1: no tutorial in Creative - you already have everything
	var gm := get_tree().get_first_node_in_group("game_mode")
	if gm and gm.get("creative") == true:
		done = true
		active = false
		if _card:
			_card.visible = false
	if done:
		return
	if is_new and step == 0:
		_show_welcome()
	else:
		_begin(step)


# --------------------------------------------------------------------------

func _build_card() -> void:
	# v1.3.1: a compact card under the minimap (it used to cover a third of the screen)
	_card = UIKit.panel(_stage, Vector2(CARD_X, 294), Vector2(CARD_W, 110), UIKit.box(Color(0.08, 0.06, 0.04, 0.9), UIKit.C_GOLD, 2, true))
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_count = UIKit.label(_card, "", UIKit.F_TINY, UIKit.C_TEXT_DIM, Vector2(12, 9))
	_card_title = UIKit.label(_card, "", UIKit.F_SMALL, UIKit.C_GOLD_LIGHT, Vector2(12, 22))
	_card_text = UIKit.wrap_label(_card, "", UIKit.F_TINY, UIKit.C_TEXT, Vector2(12, 46), CARD_W - 24)
	_card_text.add_theme_constant_override("line_spacing", 3)
	var skip := UIKit.button(_card, "SKIP", Vector2(CARD_W - 58, 6), false, true, 50)
	skip.size = Vector2(50, 22)
	var st := skip.get_node("Text") as Label
	st.add_theme_font_size_override("font_size", UIKit.F_TINY)
	st.position = Vector2(roundf((50 - UIKit.text_w("SKIP", UIKit.F_TINY)) * 0.5), 6)
	skip.pressed.connect(skip_tutorial)
	_ok_button = UIKit.button(_card, "GOT IT", Vector2(CARD_W - 104, 70), true, false, 92)
	_ok_button.size.y = 28
	var ot := _ok_button.get_node("Text") as Label
	ot.add_theme_font_size_override("font_size", UIKit.F_TINY)
	ot.position = Vector2(roundf((92 - UIKit.text_w("GOT IT", UIKit.F_TINY)) * 0.5), 9)
	_ok_button.pressed.connect(func() -> void: _complete_step())
	_card.visible = false


const CARD_W := 300.0
const CARD_X := 1152.0 - 300.0 - 8.0


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
	if i >= steps.size():
		_finish()
		return
	step = i
	active = true
	_advancing = false
	var s: Dictionary = steps[i]
	_card_count.text = "TUTORIAL %d / %d" % [i + 1, steps.size()]
	_card_title.text = s["title"]
	_card_text.text = s["text"]
	_ok_button.visible = s.get("manual", false)
	var per_line := int((CARD_W - 24.0) / 6.0) - 3
	var lines := ceili(float(str(s["text"]).length()) / float(per_line))
	_card.size.y = 56 + 12 * lines + (36 if s.get("manual", false) else 0)
	_ok_button.position.y = _card.size.y - 36
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
	var cr := get_tree().get_first_node_in_group("crafting_ui")
	_baseline = {"tilled": _tilled_count(), "crops": get_tree().get_nodes_in_group("crops").size(),
		"fiber": cr.count_item("fiber") if cr else 0,
		"wood": cr.count_item("wood_log") if cr else 0}


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


## v1.4.1: the card steps aside while a menu (settings, shop, crafting, a chat...) is open.
func _menu_open() -> bool:
	if get_tree().paused:
		return true
	for m in get_tree().get_nodes_in_group("menu_ui"):
		if m != self and m.get("is_open") == true:
			return true
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	return inv != null and inv.get("is_open") == true


func _process(delta: float) -> void:
	visible = not _menu_open() or is_open
	if get_tree().paused:
		return
	if not active or _advancing:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.25
	var id: String = steps[step]["id"]
	match id:
		"move":
			if _player:
				_moved += _player.global_position.distance_to(_last_pos)
				_last_pos = _player.global_position
				if _moved > 140.0:
					_complete_step()
		"punch", "fiber":
			# v1.3: done as soon as the player is carrying more wood / fiber than when the step began
			var cr := get_tree().get_first_node_in_group("crafting_ui")
			var key := "wood" if id == "punch" else "fiber"
			if cr and cr.count_item("wood_log" if id == "punch" else "fiber") > int(_baseline.get(key, 0)):
				_complete_step()
		"hoe":
			if _tilled_count() > int(_baseline.get("tilled", 0)):
				_complete_step()
		"plant":
			if get_tree().get_nodes_in_group("crops").size() > int(_baseline.get("crops", 0)):
				_complete_step()


func _event(id: String) -> void:
	if active and not _advancing and steps[step]["id"] == id:
		_complete_step()


func _complete_step() -> void:
	if _advancing:
		return
	_advancing = true
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("xp_gain", -6.0)
	_card_title.text = "DONE! " + str(steps[step]["title"])
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
		var nxt := "Next: read the QUEST BOARD in the village and explore the HOLLOW MINES (NE quarry)."
		if steps == STEPS_WILD:
			nxt = "Next: find Harvest Village (the signpost points the way) and caves into the HOLLOW MINES."
		hud.show_hud_message("Tutorial complete! +50 gold. " + nxt, 6.0)
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
