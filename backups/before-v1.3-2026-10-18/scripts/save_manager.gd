extends Node

## SaveManager — save slots, new-game setup and gameplay save/load for Night Harvest.
##
## Registered as an autoload ("SaveManager").
##
## Flow:
##   Title menu  -> create_new_game(slot, setup)  (New Game: writes the slot right away)
##               -> prepare_load(slot)            (Continue / Load Game)
##               -> change scene to game.tscn
##   game.gd     -> begin_session(self)           (restores the saved state, starts autosave)
##   In game     -> save_game() runs automatically: every AUTOSAVE_INTERVAL seconds,
##                  after sleeping, at midnight, and when the game is closed.
##
## Each slot is user://saves/slot_<n>.json. Top-level keys are read by the title menu:
##   farm_name, farmer_name, difficulty, day_length, starter_kit, portrait,
##   day, nights_survived, crops (Array of String), playtime_sec, created_at,
##   saved_at (added automatically), state (the full game state, added once played).
##
## Difficulty and day length are applied to zombies, the spawner, player hunger and
## the game clock as they enter the scene, so no scene files need changing.

signal slots_changed
## Emitted once the game scene's saved state has been restored (or a new farm is ready).
## Arguments: the game root and whether this is a brand-new farm.
signal session_started(root: Node, is_new_farm: bool)

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const AUTOSAVE_INTERVAL := 120.0
const PIXEL_FONT := "res://Assets/Fonts/nh_pixel_font.png"
const ItemDB = preload("res://scripts/item_database.gd")

## zombie_hp / zombie_dmg / wave: multipliers on zombie health, zombie damage and
## zombies per wave. hunger: multiplier on the time between hunger ticks (higher = slower).
const DIFFICULTIES := {
	"easy": {"label": "EASY", "zombie_hp": 0.7, "zombie_dmg": 0.5, "wave": 0.6, "hunger": 1.5},
	"normal": {"label": "NORMAL", "zombie_hp": 1.0, "zombie_dmg": 1.0, "wave": 1.0, "hunger": 1.0},
	"hard": {"label": "HARD", "zombie_hp": 1.4, "zombie_dmg": 1.67, "wave": 1.5, "hunger": 0.75},
}

## Game minutes per real second (1.0 = 24 real minutes per in-game day).
const DAY_LENGTHS := {"short": 2.0, "normal": 1.0, "long": 0.5}

## Slot the player chose from the menu (-1 = none). Kept for older code.
var pending_slot: int = -1
## Slot the current game saves into (-1 = not playing a saved game).
var active_slot: int = -1
## Slot info of the current game (farm name, difficulty, ...).
var active_info: Dictionary = {}

var _game: Node = null
var _session_ready: bool = false
var _autosave_t: float = 0.0
var _playtime: float = 0.0
var _nights: int = 0

var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


# ==========================================================================
# Slot files
# ==========================================================================

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


## Returns the slot info, or an empty Dictionary if the slot is empty.
func get_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


func has_any_save() -> bool:
	return latest_slot() != -1


## Most recently saved slot, or -1 if there are no saves.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for i in SLOT_COUNT:
		var d := get_slot(i)
		if d.is_empty():
			continue
		var t := float(d.get("saved_at", 0))
		if t > best_time:
			best_time = t
			best = i
	return best


## Slot to suggest for a new farm: the first empty one, otherwise the oldest save.
func suggest_new_slot() -> int:
	var oldest := 0
	var oldest_time := INF
	for i in SLOT_COUNT:
		var d := get_slot(i)
		if d.is_empty():
			return i
		var t := float(d.get("saved_at", 0))
		if t < oldest_time:
			oldest_time = t
			oldest = i
	return oldest


func write_slot(slot: int, info: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := info.duplicate()
	data["saved_at"] = Time.get_unix_time_from_system()
	# Write to a temp file first so a crash mid-save can't corrupt the slot.
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: could not write %s" % tmp)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
	slots_changed.emit()


func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if slot == active_slot:
		active_slot = -1
		active_info = {}
	slots_changed.emit()


func delete_all() -> void:
	for i in SLOT_COUNT:
		delete_slot(i)


# ==========================================================================
# Starting a game (called by the title menu)
# ==========================================================================

## Creates a fresh farm in `slot` (overwriting it) and makes it the active game.
## setup keys: farmer_name, farm_name, difficulty, day_length, starter_kit.
func create_new_game(slot: int, setup: Dictionary) -> void:
	var info := {
		"farmer_name": str(setup.get("farmer_name", "KEN")),
		"farm_name": str(setup.get("farm_name", "KEN'S FARM")),
		"difficulty": str(setup.get("difficulty", "normal")),
		"day_length": str(setup.get("day_length", "normal")),
		"starter_kit": str(setup.get("starter_kit", "full")),
		"character": str(setup.get("character", "ken")),
		"portrait": "river" if slot % 2 == 1 else "farm",
		"day": 1,
		"nights_survived": 0,
		"crops": [],
		"playtime_sec": 0,
		"created_at": Time.get_unix_time_from_system(),
	}
	write_slot(slot, info)
	prepare_load(slot)


## Makes `slot` the game that game.tscn will load and save into.
func prepare_load(slot: int) -> void:
	pending_slot = slot
	active_slot = slot
	active_info = get_slot(slot)


## Called when returning to the title screen.
func end_session() -> void:
	_session_ready = false
	_game = null
	active_slot = -1
	active_info = {}
	pending_slot = -1


func difficulty() -> Dictionary:
	return DIFFICULTIES.get(str(active_info.get("difficulty", "normal")), DIFFICULTIES["normal"])


func starter_kit() -> String:
	return str(active_info.get("starter_kit", "full"))


## Playable character id of the active farm ("ken", "mira", "rico").
func character_id() -> String:
	return str(active_info.get("character", "ken"))


func has_saved_state() -> bool:
	return active_info.has("state")


# ==========================================================================
# Session (called by game.gd once its systems exist)
# ==========================================================================

func begin_session(root: Node) -> void:
	_game = root
	_session_ready = false
	if active_slot < 0:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(root):
			session_started.emit(root, true)
		return
	var info := get_slot(active_slot)
	if not info.is_empty():
		active_info = info
	_playtime = float(active_info.get("playtime_sec", 0))
	_nights = int(active_info.get("nights_survived", 0))
	# Let the deferred setup of FarmingManager / SpawnManager / HUD finish first.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(root) or root != _game:
		return
	var state: Dictionary = active_info.get("state", {})
	if not state.is_empty():
		_apply_state(root, state)
	_connect_session_signals(root)
	_session_ready = true
	_autosave_t = 0.0
	session_started.emit(root, state.is_empty())
	# A brand-new farm gets its starting state written right away.
	save_game(state.is_empty())


func _connect_session_signals(root: Node) -> void:
	var clock = _first(root, "game_clock")
	if clock:
		clock.night_ended.connect(func() -> void: _nights += 1)
		clock.day_changed.connect(func(_d: int) -> void: save_game.call_deferred())
	for bed in get_tree().get_nodes_in_group("beds"):
		if root.is_ancestor_of(bed) and bed.has_signal("sleep_finished"):
			bed.sleep_finished.connect(func() -> void: save_game())


func _process(delta: float) -> void:
	if not _session_ready or not is_instance_valid(_game):
		return
	_playtime += delta
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(false)


## Saves the current game into the active slot. Returns true on success.
func save_game(show_toast: bool = true) -> bool:
	if active_slot < 0 or not _session_ready or not is_instance_valid(_game):
		return false
	var stats = _first(_game, "player_stats")
	if stats and bool(stats.get("is_dead")):
		return false
	var state := _collect_state(_game)
	var info := active_info.duplicate()
	info.erase("saved_at")
	info["state"] = state
	info["day"] = int(state.get("clock", {}).get("day", info.get("day", 1)))
	info["nights_survived"] = _nights
	info["playtime_sec"] = int(_playtime)
	info["crops"] = _crop_names(state)
	write_slot(active_slot, info)
	active_info = info
	if show_toast:
		_show_toast("GAME SAVED")
	return true


# ==========================================================================
# Collect / apply game state
# ==========================================================================

func _collect_state(root: Node) -> Dictionary:
	var s := {}
	var player = _first(root, "player")
	if player:
		s["player"] = {"x": player.global_position.x, "y": player.global_position.y}
	var stats = _first(root, "player_stats")
	if stats:
		s["stats"] = {
			"current_health": stats.current_health,
			"max_health": stats.max_health,
			"current_hunger": stats.current_hunger,
			"current_defense": stats.current_defense,
			"level": stats.level,
			"xp": stats.xp,
			"xp_to_next_level": stats.xp_to_next_level,
			"gold": stats.gold,
		}
	var clock = _first(root, "game_clock")
	if clock:
		s["clock"] = {"day": clock.current_day, "hour": clock.current_hour, "minute": clock.current_minute}
	var inv = _first(root, "inventory_ui")
	if inv:
		s["inventory"] = {"hotbar": _ser_slots(inv.hotbar_slots), "backpack": _ser_slots(inv.slots)}
	var hotbar = _first(root, "hotbar_ui")
	if hotbar:
		s["hotbar_selected"] = hotbar.selected_slot
	var chests := {}
	for c in get_tree().get_nodes_in_group("chests"):
		if root.is_ancestor_of(c):
			chests[str(root.get_path_to(c))] = _ser_slots(c.storage_slots)
	s["chests"] = chests
	var farm = _first(root, "farming_manager")
	if farm and farm.has_method("get_save_data"):
		s["farm"] = farm.get_save_data()
	# Newer systems (defenses, progression, tutorial, villagers...) save themselves.
	var ext := {}
	for n in get_tree().get_nodes_in_group("save_extension"):
		if is_instance_valid(n) and root.is_ancestor_of(n) and n.has_method("get_save_data"):
			ext[str(n.get("save_key"))] = n.get_save_data()
	s["ext"] = ext
	return s


func _apply_state(root: Node, s: Dictionary) -> void:
	# Clock first, so the farm isn't affected by the time jump.
	var clock = _first(root, "game_clock")
	if clock and s.has("clock"):
		_apply_clock(clock, s["clock"])

	var player = _first(root, "player")
	if player and s.has("player"):
		player.global_position = Vector2(float(s["player"].get("x", 0)), float(s["player"].get("y", 0)))
		for c in player.get_children():
			if c is Camera2D:
				(c as Camera2D).reset_smoothing()

	var stats = _first(root, "player_stats")
	if stats and s.has("stats"):
		var st: Dictionary = s["stats"]
		stats.max_health = int(st.get("max_health", stats.max_health))
		stats.current_health = clampi(int(st.get("current_health", stats.max_health)), 1, stats.max_health)
		stats.current_hunger = clampf(float(st.get("current_hunger", stats.max_hunger)), 0.0, stats.max_hunger)
		stats.current_defense = int(st.get("current_defense", 0))
		stats.level = int(st.get("level", 1))
		stats.xp = int(st.get("xp", 0))
		stats.xp_to_next_level = int(st.get("xp_to_next_level", 100))
		stats.gold = int(st.get("gold", 0))
		stats._last_hunger_state = stats.get_hunger_state()
		stats.health_changed.emit(stats.current_health, stats.max_health)
		stats.hunger_changed.emit(stats.current_hunger, stats.max_hunger)
		stats.defense_changed.emit(stats.current_defense, stats.max_defense)
		stats.xp_changed.emit(stats.xp, stats.xp_to_next_level)
		stats.gold_changed.emit(stats.gold)

	var inv = _first(root, "inventory_ui")
	if inv and s.has("inventory"):
		_deser_into(inv.hotbar_slots, s["inventory"].get("hotbar", []))
		_deser_into(inv.slots, s["inventory"].get("backpack", []))
		inv._update_slot_visuals()
		inv.inventory_changed.emit()

	var hotbar = _first(root, "hotbar_ui")
	if hotbar:
		var sel := int(s.get("hotbar_selected", hotbar.selected_slot))
		if sel != hotbar.selected_slot:
			hotbar.selected_slot = sel
		hotbar._update_slot_visuals()
		hotbar.slot_selected.emit(hotbar.selected_slot, hotbar.get_selected_item())

	var chests: Dictionary = s.get("chests", {})
	for path in chests:
		var c = root.get_node_or_null(NodePath(str(path)))
		if c and "storage_slots" in c:
			_deser_into(c.storage_slots, chests[path])

	var farm = _first(root, "farming_manager")
	if farm and s.has("farm") and farm.has_method("load_save_data"):
		farm.load_save_data(s["farm"])

	var ext: Dictionary = s.get("ext", {})
	for n in get_tree().get_nodes_in_group("save_extension"):
		if is_instance_valid(n) and root.is_ancestor_of(n) and n.has_method("load_save_data"):
			var key := str(n.get("save_key"))
			if ext.has(key):
				n.load_save_data(ext[key])


func _apply_clock(clock, d: Dictionary) -> void:
	clock.current_day = int(d.get("day", 1))
	clock.current_hour = int(d.get("hour", 6))
	clock.current_minute = int(d.get("minute", 0))
	clock.current_period = clock._calculate_period()
	clock._previous_period = clock.current_period
	clock._minute_accumulator = 0.0
	var night: bool = clock.is_night()
	clock._was_night = night
	clock.period_changed.emit(clock.get_period_name())
	if night:
		clock.night_started.emit()
	clock.time_updated.emit(clock.current_hour, clock.current_minute)


func _ser_slots(arr: Array) -> Array:
	var out: Array = []
	for slot in arr:
		var item = slot.get("item")
		if item != null and int(slot.get("amount", 0)) > 0:
			out.append({"id": str(item.get("item_id")), "n": int(slot["amount"])})
		else:
			out.append({})
	return out


func _deser_into(target: Array, data: Array) -> void:
	for i in target.size():
		var entry: Dictionary = data[i] if i < data.size() and data[i] is Dictionary else {}
		var item: Resource = null
		var amount := 0
		if entry.has("id"):
			item = ItemDB.get_item(str(entry["id"]))
			amount = int(entry.get("n", 0))
		if item == null or amount <= 0:
			target[i] = {"item": null, "amount": 0}
		else:
			target[i] = {"item": item, "amount": amount}


func _crop_names(state: Dictionary) -> Array:
	var names: Array = []
	for c in state.get("farm", {}).get("crops", []):
		var id := str(c.get("crop_id", ""))
		if id != "" and not names.has(id):
			names.append(id)
		if names.size() >= 3:
			break
	return names


## First node of `group` inside root (untyped on purpose: these are scripted nodes).
func _first(root: Node, group: String):
	for n in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n) and root.is_ancestor_of(n):
			return n
	return null


# ==========================================================================
# Difficulty / day length (applied as nodes enter the game)
# ==========================================================================

func _on_node_added(node: Node) -> void:
	if active_slot < 0:
		return
	var sc: Script = node.get_script()
	if sc == null or node.has_meta("nh_difficulty_applied"):
		return
	var n = node  # untyped: these are scripted nodes with custom properties
	var path := sc.resource_path
	var d := difficulty()
	if path.ends_with("/zombie.gd"):
		n.set_meta("nh_difficulty_applied", true)
		n.max_health = maxi(1, roundi(n.max_health * float(d["zombie_hp"])))
		n.current_health = n.max_health
		n.attack_damage = maxi(1, roundi(n.attack_damage * float(d["zombie_dmg"])))
	elif path.ends_with("/SpawnManager.gd"):
		n.set_meta("nh_difficulty_applied", true)
		n.zombies_per_wave = maxi(1, roundi(n.zombies_per_wave * float(d["wave"])))
	elif path.ends_with("/player_stats.gd"):
		n.set_meta("nh_difficulty_applied", true)
		n.hunger_drain_interval = n.hunger_drain_interval * float(d["hunger"])
	elif path.ends_with("/game_clock.gd"):
		n.set_meta("nh_difficulty_applied", true)
		n.GAME_MINUTES_PER_REAL_SECOND = float(DAY_LENGTHS.get(str(active_info.get("day_length", "normal")), 1.0))


# ==========================================================================
# "Game saved" toast
# ==========================================================================

func _show_toast(text: String) -> void:
	if _toast_layer == null:
		_build_toast()
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = _toast_panel.create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 95
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)
	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.anchor_left = 1.0
	_toast_panel.anchor_right = 1.0
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = -16.0
	_toast_panel.offset_right = -16.0
	_toast_panel.offset_top = 96.0
	_toast_panel.offset_bottom = 96.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.106, 0.075, 0.055, 0.92)
	sb.border_color = Color("F0C266")
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_layer.add_child(_toast_panel)
	_toast_label = Label.new()
	var font: Font = load(PIXEL_FONT)
	if font:
		_toast_label.add_theme_font_override("font", font)
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color("FFDB80"))
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
