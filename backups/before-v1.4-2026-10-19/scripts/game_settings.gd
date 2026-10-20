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

## Title-menu extras (zombie easter egg). Not saved: they start at zero on every launch.
var menu_kills: int = 0
var blood_moon: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
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


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "pixel_perfect", pixel_perfect)
	cfg.set_value("graphics", "quality", quality)
	cfg.save(PATH)


func reset_to_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.6
	sfx_volume = 0.9
	fullscreen = false
	vsync = true
	pixel_perfect = false
	quality = "high"
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
