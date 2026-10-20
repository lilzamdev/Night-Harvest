extends Node

## GameSettings — player settings for Night Harvest (audio, video, graphics).
##
## Registered as an autoload ("GameSettings"). Settings are saved to
## user://settings.cfg and applied on startup, so they work in the title menu
## and in-game. Graphics presets are also applied to lights and particles that
## appear later (e.g. when game.tscn loads), without changing any scene files.

signal changed

const PATH := "user://settings.cfg"

## Graphics presets.
## max_fps: 0 = unlimited. particles: amount ratio (0 = off).
## menu_fx: 0 = still menu, 1 = reduced, 2 = full.
const PRESETS := {
	"low": {"max_fps": 30, "shadows": false, "particles": 0.0, "menu_fx": 0},
	"medium": {"max_fps": 60, "shadows": true, "particles": 0.5, "menu_fx": 1},
	"high": {"max_fps": 0, "shadows": true, "particles": 1.0, "menu_fx": 2},
}

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var fullscreen: bool = false
var vsync: bool = true
var pixel_perfect: bool = false
var quality: String = "high"

## v1.3.1 gameplay options
var camera_zoom: float = 3.0      # 2.5 far · 3 normal · 4 near
var show_coords: bool = true      # X / Y under the clock
var screen_shake: bool = true
var damage_numbers: bool = true

## v1.3.1 rebindable controls: [action, label]. Saved in settings.cfg [keybinds].
const REBINDABLE := [
	["move_up", "MOVE UP"], ["move_down", "MOVE DOWN"],
	["move_left", "MOVE LEFT"], ["move_right", "MOVE RIGHT"],
	["sprint", "SPRINT"], ["swing", "USE / SWING"],
	["harvest", "USE (MOUSE)"], ["interact", "INTERACT"],
	["place_torch", "PLACE LANTERN"], ["watering", "WATER CROPS"],
	["drop_item", "DROP ITEM"], ["toggle_inventory", "INVENTORY"],
	["open_crafting", "CRAFTING"], ["open_map", "MAP"],
]
var _default_binds := {}

## Title-menu extras (zombie easter egg). Not saved: they start at zero on every launch.
var menu_kills: int = 0
var blood_moon: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_actions()
	load_settings()
	apply_all()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_route_game_audio")


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		fullscreen = _is_fullscreen_now()
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	pixel_perfect = bool(cfg.get_value("video", "pixel_perfect", pixel_perfect))
	quality = str(cfg.get_value("graphics", "quality", quality))
	if not PRESETS.has(quality):
		quality = "high"
	camera_zoom = clampf(float(cfg.get_value("gameplay", "camera_zoom", camera_zoom)), 2.0, 4.0)
	show_coords = bool(cfg.get_value("gameplay", "show_coords", show_coords))
	screen_shake = bool(cfg.get_value("gameplay", "screen_shake", screen_shake))
	damage_numbers = bool(cfg.get_value("gameplay", "damage_numbers", damage_numbers))
	if cfg.has_section("keybinds"):
		for a in cfg.get_section_keys("keybinds"):
			if InputMap.has_action(a):
				var evs: Array = []
				for d in cfg.get_value("keybinds", a, []):
					var ev := _deserialize(d)
					if ev:
						evs.append(ev)
				if not evs.is_empty():
					InputMap.action_erase_events(a)
					for ev in evs:
						InputMap.action_add_event(a, ev)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "pixel_perfect", pixel_perfect)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("gameplay", "camera_zoom", camera_zoom)
	cfg.set_value("gameplay", "show_coords", show_coords)
	cfg.set_value("gameplay", "screen_shake", screen_shake)
	cfg.set_value("gameplay", "damage_numbers", damage_numbers)
	for pair in REBINDABLE:
		var a: String = pair[0]
		if InputMap.has_action(a) and _binds_changed(a):
			var arr: Array = []
			for ev in InputMap.action_get_events(a):
				var d := _serialize(ev)
				if not d.is_empty():
					arr.append(d)
			cfg.set_value("keybinds", a, arr)
	cfg.save(PATH)


func reset_to_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.6
	sfx_volume = 0.9
	fullscreen = false
	vsync = true
	pixel_perfect = false
	quality = "high"
	camera_zoom = 3.0
	show_coords = true
	screen_shake = true
	damage_numbers = true
	apply_all()
	save_settings()
	changed.emit()


## Change one setting by name, apply it, save, and notify listeners.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply_all()
	save_settings()
	changed.emit()


# --------------------------------------------------------------------------
# Applying
# --------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_graphics()
	apply_gameplay()


func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want_fs := fullscreen
	if want_fs != _is_fullscreen_now():
		if want_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var root := get_tree().root
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## v1.3.1: gameplay options that live on scene nodes (camera zoom).
func apply_gameplay() -> void:
	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if p and "camera_zoom" in p:
		p.set("camera_zoom", Vector2(camera_zoom, camera_zoom))
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam and not p.has_meta("on_tower"):
			cam.zoom = Vector2(camera_zoom, camera_zoom)


func apply_graphics() -> void:
	var p: Dictionary = PRESETS[quality]
	Engine.max_fps = int(p["max_fps"])
	for n in _all_nodes(get_tree().root):
		_apply_node(n)


## Current preset values (max_fps, shadows, particles, menu_fx).
func preset() -> Dictionary:
	return PRESETS[quality]


## Call when the player toggles fullscreen elsewhere (e.g. F11), to keep the menu in sync.
func refresh_fullscreen_state() -> void:
	fullscreen = _is_fullscreen_now()


# --------------------------------------------------------------------------
# Key bindings (v1.3.1)
# --------------------------------------------------------------------------

## Actions the game needs that are not in project.godot, plus second keys.
func _ensure_actions() -> void:
	_add_default("sprint", [_key(KEY_SHIFT)])
	_add_default("open_crafting", [_key(KEY_C)])
	for i in range(5, 9):
		_add_default("hotbar_%d" % i, [_key(KEY_0 + i)])
	_add_extra("interact", _key(KEY_G))
	_add_extra("watering", _key(KEY_META))
	for pair in REBINDABLE:
		var a: String = pair[0]
		if InputMap.has_action(a):
			_default_binds[a] = InputMap.action_get_events(a).duplicate()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _add_default(action: String, evs: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e in evs:
		InputMap.action_add_event(action, e)


func _add_extra(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if _same(e, ev):
			return
	InputMap.action_add_event(action, ev)


func _binds_changed(action: String) -> bool:
	var now := InputMap.action_get_events(action)
	var def: Array = _default_binds.get(action, [])
	if now.size() != def.size():
		return true
	for i in now.size():
		if not _same(now[i], def[i]):
			return true
	return false


static func _code(e: InputEventKey) -> int:
	return int(e.physical_keycode) if e.physical_keycode != KEY_NONE else int(e.keycode)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _code(a) == _code(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


static func _serialize(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"k": _code(e)}
	if e is InputEventMouseButton:
		return {"m": int(e.button_index)}
	return {}


static func _deserialize(d: Variant) -> InputEvent:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	if d.has("k"):
		var e := InputEventKey.new()
		e.physical_keycode = int(d["k"]) as Key
		return e
	if d.has("m"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d["m"]) as MouseButton
		return m
	return null


## Readable name of an input event: "E", "SHIFT", "LEFT CLICK"...
static func event_name(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LEFT CLICK"
			MOUSE_BUTTON_RIGHT: return "RIGHT CLICK"
			MOUSE_BUTTON_MIDDLE: return "MIDDLE CLICK"
			MOUSE_BUTTON_XBUTTON1: return "MOUSE 4"
			MOUSE_BUTTON_XBUTTON2: return "MOUSE 5"
		return "MOUSE %d" % int((e as InputEventMouseButton).button_index)
	if e is InputEventKey:
		var code := _code(e)
		var nm := OS.get_keycode_string(code as Key).to_upper()
		return nm if nm != "" else "?"
	return "?"


## Main key of an action (first binding) as text.
func primary_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var evs := InputMap.action_get_events(action)
	return event_name(evs[0]) if not evs.is_empty() else "-"


## Makes ev the main binding of action. Any other rebindable action using the same
## key loses it. Returns the label of that action, or "".
func rebind(action: String, ev: InputEvent) -> String:
	var clash := ""
	for pair in REBINDABLE:
		var other: String = pair[0]
		if other == action or not InputMap.has_action(other):
			continue
		for e in InputMap.action_get_events(other):
			if _same(e, ev):
				InputMap.action_erase_event(other, e)
				clash = pair[1]
	var evs := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for i in range(1, evs.size()):
		if not _same(evs[i], ev):
			InputMap.action_add_event(action, evs[i])
	save_settings()
	changed.emit()
	return clash


func reset_keybinds() -> void:
	for a in _default_binds:
		InputMap.action_erase_events(a)
		for e in _default_binds[a]:
			InputMap.action_add_event(a, e)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK and cfg.has_section("keybinds"):
		cfg.erase_section("keybinds")
		cfg.save(PATH)
	save_settings()
	changed.emit()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is Light2D or n is GPUParticles2D or n is CPUParticles2D:
		call_deferred("_apply_node", n)


func _apply_node(n: Variant) -> void:
	if not is_instance_valid(n):
		return
	var p: Dictionary = PRESETS[quality]
	if n is Light2D:
		var light := n as Light2D
		if not light.has_meta("nh_orig_shadow"):
			light.set_meta("nh_orig_shadow", light.shadow_enabled)
		var orig_shadow: bool = light.get_meta("nh_orig_shadow")
		light.shadow_enabled = orig_shadow and bool(p["shadows"])
	elif n is GPUParticles2D:
		var gp := n as GPUParticles2D
		if not gp.has_meta("nh_orig_ratio"):
			gp.set_meta("nh_orig_ratio", gp.amount_ratio)
		var orig_ratio: float = gp.get_meta("nh_orig_ratio")
		gp.amount_ratio = orig_ratio * float(p["particles"])
	elif n is CPUParticles2D:
		var cp := n as CPUParticles2D
		if not cp.has_meta("nh_orig_visible"):
			cp.set_meta("nh_orig_visible", cp.visible)
		var orig_vis: bool = cp.get_meta("nh_orig_visible")
		cp.visible = orig_vis and float(p["particles"]) > 0.0


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## Sends the existing GameAudio sounds through the "SFX" bus so the
## Sound Effects slider controls them (GameAudio itself is not modified).
func _route_game_audio() -> void:
	var ga := get_node_or_null("/root/GameAudio")
	if ga == null:
		return
	for c in ga.get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).bus = "SFX"


func _is_fullscreen_now() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
