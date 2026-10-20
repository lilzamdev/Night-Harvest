extends Node

## WeatherManager (v1.2) — sunny, cloudy, rain, thunderstorms and fog.
##
## Gameplay:
##   * Rain waters every planted crop on its own (and keeps doing so while it rains).
##   * Thunderstorms: lightning can strike zombies near you at night.
##   * Fog: zombies spot you from closer, but you can't see far either.
## The weather is rolled each morning (day 1 is always sunny) and may change at 1 PM.
## Saved with the game as part of the save "ext" section.

signal weather_changed(kind: String)

const SKY_SHADER := preload("res://shaders/sky_overlay.gdshader")
const KINDS := ["clear", "cloudy", "rain", "storm", "fog"]
const LABELS := {"clear": "SUNNY", "cloudy": "CLOUDY", "rain": "RAIN", "storm": "THUNDERSTORM", "fog": "FOG"}
const WIND := {"clear": 0.6, "cloudy": 1.0, "rain": 1.5, "storm": 2.6, "fog": 0.25}
const TINT := {
	"clear": Color(1, 1, 1),
	"cloudy": Color(0.9, 0.91, 0.95),
	"rain": Color(0.74, 0.78, 0.88),
	"storm": Color(0.6, 0.63, 0.75),
	"fog": Color(0.9, 0.92, 0.95),
}
const WEIGHTS := {"clear": 40, "cloudy": 22, "rain": 20, "storm": 8, "fog": 10}

var kind: String = "clear"
var tomorrow: String = "clear"
var save_key := "weather"

var _game: Node2D
var _layer: CanvasLayer
var _rain: CPUParticles2D
var _splash: CPUParticles2D
var _flash: ColorRect
var _sky: ColorRect
var _sky_mat: ShaderMaterial
var _rain_sound: AudioStreamPlayer
var _wind_sound: AudioStreamPlayer
var _hud_label: Label
var _drift := Vector2.ZERO
var _water_t := 0.0
var _bolt_t := 12.0
var _changed_today := false
var _rng := RandomNumberGenerator.new()
var _rain_amount := 0.0   # smoothed 0..1
var _fog_amount := 0.0
var _cloud_amount := 0.0


func _ready() -> void:
	add_to_group("weather")
	add_to_group("save_extension")
	_game = get_parent() as Node2D
	_rng.randomize()
	tomorrow = _roll()
	_build()
	call_deferred("_connect_clock")


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "WeatherLayer"
	_layer.layer = 3
	add_child(_layer)
	_sky = ColorRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	nt.noise = fn
	_sky_mat.set_shader_parameter("noise", nt)
	_sky.material = _sky_mat
	_layer.add_child(_sky)

	_rain = CPUParticles2D.new()
	_rain.texture = _streak_texture()
	_rain.amount = 260
	_rain.lifetime = 0.55
	_rain.preprocess = 0.6
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.direction = Vector2(0.18, 1.0)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 900.0
	_rain.initial_velocity_max = 1150.0
	_rain.scale_amount_min = 2.0
	_rain.scale_amount_max = 3.0
	_rain.color = Color(0.75, 0.85, 1.0, 0.55)
	_rain.emitting = false
	_rain.local_coords = false
	_layer.add_child(_rain)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.92, 0.95, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)

	# Ground splashes live in the world, around the camera
	_splash = CPUParticles2D.new()
	_splash.texture = load("res://Assets/Generated/v12/splash.png")
	var cm := CanvasItemMaterial.new()
	cm.particles_animation = true
	cm.particles_anim_h_frames = 3
	cm.particles_anim_v_frames = 1
	cm.particles_anim_loop = false
	_splash.material = cm
	_splash.anim_speed_min = 1.0
	_splash.anim_speed_max = 1.0
	_splash.amount = 90
	_splash.lifetime = 0.3
	_splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash.gravity = Vector2.ZERO
	_splash.initial_velocity_min = 0.0
	_splash.initial_velocity_max = 0.0
	_splash.color = Color(0.8, 0.9, 1.0, 0.7)
	_splash.z_index = 1
	_splash.emitting = false
	_splash.local_coords = false
	_game.add_child.call_deferred(_splash)

	_rain_sound = _loop_player("res://Assets/Audio/SFX/rain_loop.wav")
	_wind_sound = _loop_player("res://Assets/Audio/SFX/wind_loop.wav")


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	p.stream = load(path) if ResourceLoader.exists(path) else null
	p.volume_db = -60.0
	p.finished.connect(func() -> void:
		if p.volume_db > -55.0:
			p.play())
	add_child(p)
	return p


func _streak_texture() -> ImageTexture:
	var img := Image.create(1, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		img.set_pixel(0, y, Color(1, 1, 1, float(y + 1) / 6.0))
	return ImageTexture.create_from_image(img)


func _connect_clock() -> void:
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock:
		clock.day_changed.connect(_on_day_changed)
		clock.time_updated.connect(_on_time)
	_add_hud_label()
	_apply(true)


func _add_hud_label() -> void:
	var box := _game.get_node_or_null("UI/HUD/TopCenter/Calendar/Margin/VBox") as VBoxContainer
	if not box:
		return
	_hud_label = Label.new()
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 10)
	_hud_label.add_theme_color_override("font_color", Color(0.72, 0.85, 1.0))
	box.add_child(_hud_label)


# ==========================================================================
# Rolling the weather
# ==========================================================================

func _roll() -> String:
	var total := 0
	for k in WEIGHTS:
		total += int(WEIGHTS[k])
	var r := _rng.randi_range(1, total)
	for k in WEIGHTS:
		r -= int(WEIGHTS[k])
		if r <= 0:
			return k
	return "clear"


func _on_day_changed(_d: int) -> void:
	kind = tomorrow
	tomorrow = _roll()
	_changed_today = false
	_apply()


func _on_time(hour: int, minute: int) -> void:
	if minute != 0:
		return
	if hour == 11 and kind == "fog":
		set_weather("cloudy")
	elif hour == 13 and not _changed_today:
		_changed_today = true
		if kind in ["rain", "storm"] and _rng.randf() < 0.45:
			set_weather("cloudy")
		elif kind in ["clear", "cloudy"] and _rng.randf() < 0.15:
			set_weather("rain")


func set_weather(k: String) -> void:
	if not KINDS.has(k):
		return
	kind = k
	_apply()


func is_raining() -> bool:
	return kind == "rain" or kind == "storm"


func label() -> String:
	return LABELS.get(kind, "")


func forecast_label() -> String:
	return LABELS.get(tomorrow, "")


func _blood_moon_tonight() -> bool:
	var d := get_tree().get_first_node_in_group("night_director")
	return d != null and bool(d.get("blood_moon"))


func _apply(instant: bool = false) -> void:
	if _hud_label:
		_hud_label.text = LABELS.get(kind, "")
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw:
		lw.wind = WIND.get(kind, 1.0)
	_update_tint()
	if instant:
		_rain_amount = 1.0 if is_raining() else 0.0
		_fog_amount = 1.0 if kind == "fog" else 0.0
		_cloud_amount = 1.0 if kind in ["cloudy", "rain", "storm"] else 0.25
	weather_changed.emit(kind)
	_notify("weather_changed", {"weather": kind})
	if is_raining():
		_water_t = 0.5  # water the crops almost right away


func _update_tint() -> void:
	var env := get_tree().get_first_node_in_group("environment_manager")
	if env and "weather_tint" in env:
		env.weather_tint = TINT.get(kind, Color.WHITE)
		if env.has_method("_update_target_color"):
			env._update_target_color()


# ==========================================================================
# Per frame
# ==========================================================================

func _outdoors() -> bool:
	var w := get_tree().get_first_node_in_group("nh_world")
	if w and w.has_method("is_player_indoors") and w.is_player_indoors():
		return false
	var mines := get_tree().get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return false
	return true


func _quality() -> float:
	if has_node("/root/GameSettings"):
		return float(get_node("/root/GameSettings").preset()["particles"])
	return 1.0


func _process(delta: float) -> void:
	var outdoors := _outdoors()
	var q := _quality()
	var want_rain := 1.0 if (is_raining() and outdoors) else 0.0
	var want_fog := 1.0 if (kind == "fog" and outdoors) else 0.0
	var want_cloud := (1.0 if kind in ["cloudy", "rain", "storm"] else 0.3) if outdoors else 0.0
	_rain_amount = move_toward(_rain_amount, want_rain, delta * 0.5)
	_fog_amount = move_toward(_fog_amount, want_fog, delta * 0.25)
	_cloud_amount = move_toward(_cloud_amount, want_cloud, delta * 0.3)
	var w: float = WIND.get(kind, 1.0)
	_drift += Vector2(14.0, 4.0) * w * delta

	# Screen overlay
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom if cam else Vector2.ONE
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	_sky.visible = q > 0.0 and (_fog_amount > 0.01 or _cloud_amount > 0.01)
	if _sky.visible:
		_sky_mat.set_shader_parameter("cam_pos", center)
		_sky_mat.set_shader_parameter("view_size", vp / zoom)
		_sky_mat.set_shader_parameter("drift", _drift)
		_sky_mat.set_shader_parameter("fog_amount", _fog_amount)
		var night_dim := 1.0
		var env := get_tree().get_first_node_in_group("environment_manager")
		var cmod := _game.get_node_or_null("DayNightModulate") as CanvasModulate
		if cmod:
			night_dim = clampf(cmod.color.get_luminance() * 1.1, 0.2, 1.0)
		_sky_mat.set_shader_parameter("cloud_amount", _cloud_amount * night_dim)
		_sky_mat.set_shader_parameter("fog_color", Color(0.78, 0.82, 0.86) * night_dim)

	# Rain
	var raining_fx := _rain_amount > 0.05 and q > 0.0
	_rain.emitting = raining_fx
	if raining_fx:
		_rain.amount = maxi(20, int(260.0 * q * (1.4 if kind == "storm" else 1.0)))
		_rain.position = Vector2(vp.x * 0.5 - 60.0, -20.0)
		_rain.emission_rect_extents = Vector2(vp.x * 0.62, 4.0)
		_rain.direction = Vector2(0.12 + 0.08 * w, 1.0)
		_rain.modulate.a = _rain_amount
	if is_instance_valid(_splash):
		_splash.emitting = raining_fx
		if raining_fx:
			_splash.amount = maxi(10, int(90.0 * q))
			_splash.global_position = center
			_splash.emission_rect_extents = vp / zoom * 0.5
			_splash.modulate.a = _rain_amount

	# Sound (quieter indoors, silent in the mines)
	var mines := get_tree().get_first_node_in_group("mines")
	var in_mines: bool = mines != null and bool(mines.get("active"))
	var rain_db := -60.0
	if is_raining() and not in_mines:
		rain_db = (-8.0 if kind == "storm" else -11.0) - (0.0 if outdoors else 12.0)
	_fade_sound(_rain_sound, rain_db, delta)
	var wind_db := -60.0
	if kind == "storm" and not in_mines:
		wind_db = -12.0 - (0.0 if outdoors else 10.0)
	_fade_sound(_wind_sound, wind_db, delta)

	# Rain waters the farm
	if is_raining():
		_water_t -= delta
		if _water_t <= 0.0:
			_water_t = 20.0
			var fm := _game.get_node_or_null("FarmingManager")
			if fm and fm.has_method("water_all_from_rain"):
				fm.water_all_from_rain()

	# Lightning
	if kind == "storm":
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = _rng.randf_range(7.0, 18.0)
			_lightning(outdoors and not in_mines)


func _fade_sound(p: AudioStreamPlayer, target_db: float, delta: float) -> void:
	if p.stream == null:
		return
	p.volume_db = move_toward(p.volume_db, target_db, delta * 30.0)
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -59.0 and p.playing:
		p.stop()


func _lightning(visible_flash: bool) -> void:
	if visible_flash:
		var tw := create_tween()
		tw.tween_property(_flash, "color:a", 0.55, 0.04)
		tw.tween_property(_flash, "color:a", 0.05, 0.08)
		tw.tween_property(_flash, "color:a", 0.4, 0.04)
		tw.tween_property(_flash, "color:a", 0.0, 0.35)
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.shake(2.5, 0.35)
		_strike_zombie()
	get_tree().create_timer(_rng.randf_range(0.3, 1.4)).timeout.connect(func() -> void:
		if has_node("/root/GameAudio"):
			get_node("/root/GameAudio").play("thunder", -4.0 if visible_flash else -14.0))


## At night, lightning sometimes hits a zombie that is on screen.
func _strike_zombie() -> void:
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock == null or not clock.is_night() or _rng.randf() > 0.45:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	var best: Node2D = null
	for z in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(z) and z is Node2D and (z as Node2D).global_position.distance_to(p.global_position) < 200.0 and not bool(z.get("is_dead")):
			best = z
			break
	if best and best.has_method("take_damage"):
		best.take_damage(9999, Vector2.DOWN, 0.0)
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.bolt(best.global_position)
			juice.popup_text(best.global_position + Vector2(0, -24), "ZAPPED!", Color(0.8, 0.95, 1.0))


func _notify(event: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(event, data)
			break


# ==========================================================================
# Save
# ==========================================================================

func get_save_data() -> Dictionary:
	return {"kind": kind, "tomorrow": tomorrow, "changed": _changed_today}


func load_save_data(d: Dictionary) -> void:
	kind = str(d.get("kind", "clear"))
	tomorrow = str(d.get("tomorrow", _roll()))
	_changed_today = bool(d.get("changed", false))
	if not KINDS.has(kind):
		kind = "clear"
	_apply(true)
