extends Node
class_name EnvironmentManager

## Manages time-of-day environmental lighting via CanvasModulate.
## Connects to the GameClock and gradually transitions colors
## between time periods to give the player a visual sense of
## day progression without relying only on the HUD.
##
## Preserves the pixel-art visual style — no post-processing, just
## world color modulation.

# --- Color Targets for Each Period ---
## Bright, neutral daylight
@export var morning_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Slight warm tint as the day progresses
@export var afternoon_color: Color = Color(1.0, 0.95, 0.88, 1.0)
## Warm orange-gold sunset glow
@export var sunset_color: Color = Color(0.85, 0.65, 0.45, 1.0)
## Dark blue-purple night atmosphere
@export var night_color: Color = Color(0.22, 0.22, 0.38, 1.0)

## How fast the color transitions (higher = faster)
@export var transition_speed: float = 2.0

var _canvas_modulate: CanvasModulate = null
var _target_color: Color = Color.WHITE
var _game_clock: Node = null


func _ready() -> void:
	add_to_group("environment_manager")
	call_deferred("_setup")


func _setup() -> void:
	# Find or create the CanvasModulate node
	_canvas_modulate = _find_canvas_modulate()
	if not _canvas_modulate:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "DayNightModulate"
		# Add to the game scene root (parent of this node)
		var parent := get_parent()
		if parent:
			parent.add_child(_canvas_modulate)
		else:
			add_child(_canvas_modulate)
	
	_canvas_modulate.color = morning_color
	_target_color = morning_color
	
	# Find the game clock
	var clock_nodes := get_tree().get_nodes_in_group("game_clock")
	for node in clock_nodes:
		if is_instance_valid(node):
			_game_clock = node
			break
	
	if _game_clock:
		_game_clock.time_updated.connect(_on_time_updated)
		# Initial color based on starting time
		_update_target_color()
		_canvas_modulate.color = _target_color


func _process(delta: float) -> void:
	if not _canvas_modulate:
		return
	
	# Smoothly lerp toward target color
	_canvas_modulate.color = _canvas_modulate.color.lerp(_target_color, delta * transition_speed)


func _on_time_updated(_hour: int, _minute: int) -> void:
	_update_target_color()


func _update_target_color() -> void:
	if not _game_clock:
		return
	
	var hour: int = _game_clock.current_hour
	var minute: int = _game_clock.current_minute
	var sunrise: int = _game_clock.sunrise_hour       # 6
	var afternoon: int = _game_clock.afternoon_hour    # 12
	var sunset: int = _game_clock.sunset_hour          # 17
	var night: int = _game_clock.night_hour            # 19
	
	var total_minutes := hour * 60 + minute
	
	# Calculate target color based on smooth interpolation between periods
	if hour >= sunrise and hour < afternoon:
		# MORNING (6:00 - 11:59): morning_color → afternoon_color
		var t := float(total_minutes - sunrise * 60) / float((afternoon - sunrise) * 60)
		_target_color = morning_color.lerp(afternoon_color, t)
	
	elif hour >= afternoon and hour < sunset:
		# AFTERNOON (12:00 - 16:59): afternoon_color → sunset_color
		var t := float(total_minutes - afternoon * 60) / float((sunset - afternoon) * 60)
		_target_color = afternoon_color.lerp(sunset_color, t)
	
	elif hour >= sunset and hour < night:
		# SUNSET (17:00 - 18:59): sunset_color → night_color
		var t := float(total_minutes - sunset * 60) / float((night - sunset) * 60)
		_target_color = sunset_color.lerp(night_color, t)
	
	elif hour >= night or hour < sunrise:
		# NIGHT (19:00 - 5:59): solid night_color with slight midnight variation
		if hour >= 0 and hour < sunrise:
			# Pre-dawn: very slowly lighten toward sunrise
			var pre_dawn_minutes := hour * 60 + minute
			var total_pre_dawn := sunrise * 60
			var t := float(pre_dawn_minutes) / float(total_pre_dawn)
			# Last 30% of pre-dawn starts transitioning to morning
			if t > 0.7:
				var dawn_t := (t - 0.7) / 0.3
				_target_color = night_color.lerp(morning_color, dawn_t * 0.4)
			else:
				_target_color = night_color
		else:
			_target_color = night_color


func _find_canvas_modulate() -> CanvasModulate:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is CanvasModulate:
				return child
	return null
