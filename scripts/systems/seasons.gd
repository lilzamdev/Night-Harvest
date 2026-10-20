extends Node

## Seasons (v1.4): Spring -> Summer -> Fall -> Winter, DAYS_PER_SEASON days each.
##
##  * The world changes: summer grass is warm and golden, fall trees turn amber, gold and
##    red and drop their leaves, winter covers the ground in snow and frosts the lakes.
##    Pines stay green until the snow comes. (Colours live in shaders/season.gdshaderinc.)
##  * The weather follows the season: rainy springs, stormy summers, foggy falls and
##    snowy winters (snow does not water crops).
##  * The weather affects you:
##      COLD     winter, outside and away from a fire: hunger drops much faster, and in a
##               snowfall at night the cold slowly hurts. Stand near a lantern, a furnace
##               or go indoors to warm up.
##      HOT      summer midday sun: hunger drops faster.
##      WET      rain and storms slow you down a little (mud), snow slows you more.
##  * Crops grow 25% faster in spring and at half speed in winter.
## The season comes from the day number, so nothing extra is saved.

signal season_changed(index: int)

const NAMES := ["SPRING", "SUMMER", "FALL", "WINTER"]
const COLORS := [Color("9BE38A"), Color("FFD36B"), Color("F08A3C"), Color("BFE3FF")]
const DAYS_PER_SEASON := 5
const TINTS := [Color(1, 1, 1), Color(1.04, 1.0, 0.93), Color(1.02, 0.95, 0.88), Color(0.93, 0.97, 1.06)]
const GROWTH := [1.25, 1.0, 1.0, 0.5]
## weather weights per season: clear, cloudy, rain, storm, fog, snow
const WEATHER := [
	{"clear": 38, "cloudy": 22, "rain": 28, "storm": 4, "fog": 8},
	{"clear": 55, "cloudy": 15, "rain": 10, "storm": 14, "fog": 6},
	{"clear": 32, "cloudy": 26, "rain": 22, "storm": 4, "fog": 16},
	{"clear": 30, "cloudy": 24, "fog": 12, "snow": 34},
]
const SUBTITLES := [
	"Flowers bloom and crops grow faster. Plant everything!",
	"Long hot days - the midday sun makes you hungry. Watch for storms.",
	"The leaves turn and fall. Harvest and stock up for winter.",
	"Snow and cold. Crops grow slowly - stay near a fire, eat well.",
]

var index := 0
var status := ""          # "", "COLD", "HOT", "WET", "SNOWY"
var _weights := Vector4(1, 0, 0, 0)
var _target := Vector4(1, 0, 0, 0)
var _tick := 0.0
var _hurt_t := 0.0
var _breath_t := 0.0
var _status_label: Label
var _forced := -1
var _last_day := 1


func _ready() -> void:
	add_to_group("seasons")
	call_deferred("_connect")


func _connect() -> void:
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock:
		clock.day_changed.connect(_on_day)
	index = season_for_day(_day())
	_last_day = _day()
	_target = _vec(index)
	_weights = _target
	_push()
	_add_status_label()
	var weather := get_tree().get_first_node_in_group("weather")
	if weather and weather.has_method("on_season"):
		weather.on_season(index)


func _day() -> int:
	var clock := get_tree().get_first_node_in_group("game_clock")
	return int(clock.get("current_day")) if clock else 1


static func season_for_day(day: int) -> int:
	return int(floor(float(maxi(day, 1) - 1) / DAYS_PER_SEASON)) % 4


func season_name() -> String:
	return NAMES[index]


func day_in_season() -> int:
	return (maxi(_day(), 1) - 1) % DAYS_PER_SEASON + 1


func is_winter() -> bool:
	return index == 3


func growth_mult() -> float:
	return GROWTH[index]


func tint() -> Color:
	return TINTS[index]


func weather_weights(day: int) -> Dictionary:
	return WEATHER[season_for_day(day) if _forced < 0 else _forced]


## Dev / tests: jump to a season right away.
func force(i: int) -> void:
	_forced = i
	_set_index(i, true)


func _vec(i: int) -> Vector4:
	var v := Vector4.ZERO
	v[i] = 1.0
	return v


func _on_day(d: int) -> void:
	var i := season_for_day(d) if _forced < 0 else _forced
	_last_day = d
	if i != index:
		_set_index(i, false)


## A loaded save sets the day without a day_changed signal: catch up quietly.
func _check_day() -> void:
	var d := _day()
	var i := season_for_day(d) if _forced < 0 else _forced
	if i != index:
		_set_index(i, absi(d - _last_day) > 1)
	_last_day = d


func _set_index(i: int, instant: bool) -> void:
	index = i
	_target = _vec(i)
	if instant:
		_weights = _target
		_push()
	var weather := get_tree().get_first_node_in_group("weather")
	if weather and weather.has_method("on_season"):
		weather.on_season(i)
	season_changed.emit(i)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("season_changed", {"season": NAMES[i]})
			break
	if not instant and is_inside_tree():
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud and hud.has_method("_show_zombie_banner"):
			hud._show_zombie_banner(NAMES[i] + " HAS COME", SUBTITLES[i], COLORS[i], 4.5)


func _push() -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("set_season"):
		lw.set_season(_weights)


func _process(delta: float) -> void:
	if not _weights.is_equal_approx(_target):
		# the world slowly changes colour over ~8 seconds after a new season starts
		var step := delta / 8.0
		for k in 4:
			_weights[k] = move_toward(_weights[k], _target[k], step)
		_push()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_check_day()
		_update_effects(0.5)


# --- How the weather feels -----------------------------------------------------

func _outdoors() -> bool:
	var w := get_tree().get_first_node_in_group("nh_world")
	if w and w.has_method("is_player_indoors") and w.is_player_indoors():
		return false
	var mines := get_tree().get_first_node_in_group("mines")
	return not (mines and mines.get("active"))


## Near a lit lantern, a furnace or a street lamp counts as warm.
func is_warm(pos: Vector2) -> bool:
	for t in get_tree().get_nodes_in_group("torches"):
		if t is Node2D and (t as Node2D).global_position.distance_squared_to(pos) < 70.0 * 70.0:
			return true
	for f in get_tree().get_nodes_in_group("furniture"):
		if f is Node2D and str(f.get("kind")) == "furnace" and (f as Node2D).global_position.distance_squared_to(pos) < 80.0 * 80.0:
			return true
	for d in get_tree().get_nodes_in_group("decor"):
		if d is Node2D and str(d.get("kind")) in ["street_lamp", "crate_lantern"] and (d as Node2D).global_position.distance_squared_to(pos) < 60.0 * 60.0:
			return true
	var p := get_tree().get_first_node_in_group("player")
	if p and p.get("current_held_item") != null and str(p.current_held_item.get("item_id")) == "torch":
		return true   # holding a lit lantern
	return false


func _update_effects(dt: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var stats := get_tree().get_first_node_in_group("player_stats")
	if p == null:
		return
	var gm := get_tree().get_first_node_in_group("game_mode")
	var creative: bool = gm != null and gm.get("creative") == true
	var weather := get_tree().get_first_node_in_group("weather")
	var wk: String = str(weather.get("kind")) if weather else "clear"
	var clock := get_tree().get_first_node_in_group("game_clock")
	var hour: int = int(clock.get("current_hour")) if clock else 12
	var night: bool = clock != null and clock.is_night()
	var out := _outdoors()
	var hunger := 1.0
	var speed := 1.0
	var st := ""
	if out and not creative:
		if wk == "rain":
			speed = 0.93
			st = "WET"
		elif wk == "storm":
			speed = 0.87
			st = "WET"
		elif wk == "snow":
			speed = 0.9
			st = "SNOWY"
		if index == 3 and not is_warm(p.global_position):
			hunger = 1.9 if (wk == "snow" or night) else 1.5
			st = "COLD"
			_breath_t -= dt
			if _breath_t <= 0.0:
				_breath_t = 2.2
				var juice := get_tree().get_first_node_in_group("juice")
				if juice and juice.has_method("burst"):
					juice.burst(p.global_position + Vector2(4, -26), Color(1, 1, 1, 0.55), 3, 12.0, 1.0, 0.3)
			if wk == "snow" and night and stats:
				_hurt_t += dt
				if _hurt_t >= 8.0:
					_hurt_t = 0.0
					if stats.has_method("take_damage"):
						stats.take_damage(1)
					_msg("You are freezing! Find a fire or go indoors.")
		elif index == 1 and wk == "clear" and hour >= 11 and hour < 16:
			hunger = 1.35
			st = "HOT"
	status = st
	if stats and "hunger_mult" in stats:
		stats.hunger_mult = hunger
	if "weather_speed_mult" in p:
		p.weather_speed_mult = speed
	_update_status_label()


func _msg(t: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 2.5)


func _add_status_label() -> void:
	var game := get_parent()
	var box := game.get_node_or_null("UI/HUD/TopCenter/Calendar/Margin/VBox") as VBoxContainer if game else null
	if not box:
		return
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.visible = false
	box.add_child(_status_label)


func _update_status_label() -> void:
	if not _status_label:
		return
	_status_label.visible = status != ""
	if status == "":
		return
	var info := {
		"COLD": ["COLD - GET WARM BY A FIRE", Color("9FD3FF")],
		"HOT": ["HOT - YOU GET HUNGRY FASTER", Color("FFB45A")],
		"WET": ["WET - THE MUD SLOWS YOU", Color("8FB8E8")],
		"SNOWY": ["DEEP SNOW - YOU MOVE SLOWER", Color("DDEEFF")],
	}
	var e: Array = info.get(status, [status, Color.WHITE])
	_status_label.text = e[0]
	_status_label.add_theme_color_override("font_color", e[1])
