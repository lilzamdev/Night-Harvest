extends Node
class_name GameClock

## Internal game clock for Night Harvest.
## Drives the day/night cycle, HUD time display, and nightfall countdown.
##
## Time speed is configurable via GAME_MINUTES_PER_REAL_SECOND.
## Default: 1.0 (1 real second = 1 game minute → full day ~24 min).
##
## Time Periods:
##   MORNING:   06:00 – 11:59
##   AFTERNOON: 12:00 – 16:59
##   SUNSET:    17:00 – 18:59
##   NIGHT:     19:00 – 05:59

signal time_updated(hour: int, minute: int)
signal period_changed(new_period: String)
signal day_changed(new_day: int)
signal night_started()
signal night_ended()

enum TimePeriod { MORNING, AFTERNOON, SUNSET, NIGHT }

# --- Configurable Time Speed ---
## Change this single value to control how fast game time passes.
## 1.0 = 1 real second per game minute (~24 min full day)
## 2.0 = 2 game minutes per real second (~12 min full day)
@export var GAME_MINUTES_PER_REAL_SECOND: float = 1.0

# --- Configurable Period Boundaries (24h format) ---
@export var sunrise_hour: int = 6       # Morning starts
@export var afternoon_hour: int = 12    # Afternoon starts
@export var sunset_hour: int = 17       # Sunset starts
@export var night_hour: int = 19        # Night starts

# --- Starting Time ---
@export var start_hour: int = 6
@export var start_minute: int = 0
@export var start_day: int = 1

# --- State ---
var current_day: int = 1
var current_hour: int = 6
var current_minute: int = 0
var current_period: TimePeriod = TimePeriod.MORNING
var _minute_accumulator: float = 0.0
var _previous_period: TimePeriod = TimePeriod.MORNING
var _was_night: bool = false


func _ready() -> void:
	add_to_group("game_clock")
	current_day = start_day
	current_hour = start_hour
	current_minute = start_minute
	current_period = _calculate_period()
	_previous_period = current_period
	_was_night = is_night()


func _process(delta: float) -> void:
	_minute_accumulator += delta * GAME_MINUTES_PER_REAL_SECOND
	
	while _minute_accumulator >= 1.0:
		_minute_accumulator -= 1.0
		_advance_minute()


func _advance_minute() -> void:
	current_minute += 1
	
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		
		if current_hour >= 24:
			current_hour = 0
			current_day += 1
			day_changed.emit(current_day)
	
	# Update period
	current_period = _calculate_period()
	
	# Check for period transitions
	if current_period != _previous_period:
		period_changed.emit(get_period_name())
		_previous_period = current_period
	
	# Check for night start/end transitions
	var currently_night := is_night()
	if currently_night and not _was_night:
		night_started.emit()
	elif not currently_night and _was_night:
		night_ended.emit()
	_was_night = currently_night
	
	time_updated.emit(current_hour, current_minute)


func _calculate_period() -> TimePeriod:
	if current_hour >= night_hour or current_hour < sunrise_hour:
		return TimePeriod.NIGHT
	elif current_hour >= sunset_hour:
		return TimePeriod.SUNSET
	elif current_hour >= afternoon_hour:
		return TimePeriod.AFTERNOON
	else:
		return TimePeriod.MORNING


## Returns formatted time string like "09:30 AM"
func get_time_string() -> String:
	var display_hour := current_hour % 12
	if display_hour == 0:
		display_hour = 12
	var ampm := "AM" if current_hour < 12 else "PM"
	return "%02d:%02d %s" % [display_hour, current_minute, ampm]


## Returns "MORNING", "AFTERNOON", "SUNSET", or "NIGHT"
func get_period_name() -> String:
	match current_period:
		TimePeriod.MORNING:
			return "MORNING"
		TimePeriod.AFTERNOON:
			return "AFTERNOON"
		TimePeriod.SUNSET:
			return "SUNSET"
		TimePeriod.NIGHT:
			return "NIGHT"
	return "UNKNOWN"


## Returns the nightfall countdown string like "03:30" (hours:minutes until night).
## Returns "00:00" if already night.
func get_nightfall_countdown() -> String:
	if is_night():
		return "00:00"
	
	# Calculate minutes until night_hour
	var current_total_minutes := current_hour * 60 + current_minute
	var night_total_minutes := night_hour * 60
	var remaining := night_total_minutes - current_total_minutes
	
	if remaining <= 0:
		return "00:00"
	
	var hours := remaining / 60
	var minutes := remaining % 60
	return "%02d:%02d" % [hours, minutes]


## True during the NIGHT period (night_hour to sunrise_hour).
func is_night() -> bool:
	return _calculate_period() == TimePeriod.NIGHT


## Returns a 0.0–1.0 value representing the day's progress (6 AM = 0, 6 AM next = 1).
func get_day_progress() -> float:
	var total_minutes := (current_hour - sunrise_hour) * 60 + current_minute
	if total_minutes < 0:
		total_minutes += 1440  # 24 * 60
	return clampf(float(total_minutes) / 1440.0, 0.0, 1.0)


## Advances the clock to a target hour/minute on the appropriate day.
## Properly handles midnight crossing (does NOT double-increment day).
## Emits all intermediate signals so farming/environment/spawn systems update.
## Used by the Bed sleeping system (Phase 7).
func advance_to_time(target_hour: int, target_minute: int = 0) -> void:
	var current_total := current_hour * 60 + current_minute
	var target_total := target_hour * 60 + target_minute
	
	if target_total <= current_total:
		# Target is tomorrow (e.g., 10 PM → 6 AM = need to cross midnight)
		target_total += 1440  # +24 hours in minutes
	
	var minutes_to_advance := target_total - current_total
	
	# Advance minute-by-minute to fire all signals correctly
	# (time_updated, period_changed, day_changed, night_started/ended)
	for i in range(minutes_to_advance):
		_advance_minute()
	
	_minute_accumulator = 0.0  # Reset fractional accumulator

