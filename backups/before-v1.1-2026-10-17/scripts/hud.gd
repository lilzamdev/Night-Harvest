extends Control
class_name HUDUI

@onready var hp_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/HPBar
@onready var hp_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/HPBar/HPLabel
@onready var hunger_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/EnergyBar
@onready var hunger_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/EnergyBar/EnergyLabel
@onready var level_label: Label = $TopLeft/PlayerStatus/Margin/HBox/VBox/LevelRow/LevelLabel
@onready var xp_bar: ProgressBar = $TopLeft/PlayerStatus/Margin/HBox/VBox/LevelRow/XPBar

@onready var hud_message_label: Label = $BottomLeft/HUDMessage

@onready var day_label: Label = $TopCenter/Calendar/Margin/VBox/DayLabel
@onready var time_label: Label = $TopCenter/Calendar/Margin/VBox/TimeLabel

@onready var gold_label: Label = $TopRight/VBox/Resources/Margin/HBox/GoldLabel
@onready var wood_label: Label = $TopRight/VBox/Resources/Margin/HBox/WoodLabel
@onready var stone_label: Label = $TopRight/VBox/Resources/Margin/HBox/StoneLabel
@onready var minimap: Control = $TopRight/VBox/Minimap

@onready var nightfall_title_label: Label = $BottomRight/Nightfall/Margin/VBox/TitleLabel
@onready var nightfall_timer_label: Label = $BottomRight/Nightfall/Margin/VBox/TimeLabel
@onready var hotbar: Control = $BottomCenter/Hotbar

const GOLD := Color(0.95, 0.77, 0.40)
const CREAM := Color(0.94, 0.88, 0.75)
const COMPLETE := Color(0.60, 0.82, 0.48)

@onready var xp_label: Label = xp_bar.get_node("XPLabel")
@onready var xp_feedback: Label = xp_bar.get_node("FeedbackLabel")

var _hunger_fill_normal: StyleBoxFlat
var _hunger_fill_warning: StyleBoxFlat
var _hud_message_timer := 0.0
var _tweens: Dictionary = {}
var _initialized := false
var _last_hp := -1
var _last_hunger := -1.0
var _last_level := -1
var _last_xp := -1
var _last_max_xp := -1
var _last_day := -1
var _last_resources: Array[int] = []
var _quest_state: Dictionary = {}
var _night_stage := -1
var _level_feedback := false
var _pending_xp := 0
var _zombie_warning_shown := false
var _zombie_arrival_shown := false
var _zombie_banner_layer: CanvasLayer = null


func _ready() -> void:
	add_to_group("hud_ui")
	_hunger_fill_normal = hunger_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_hunger_fill_warning = _hunger_fill_normal.duplicate() as StyleBoxFlat
	_hunger_fill_warning.bg_color = Color(0.78, 0.30, 0.17)
	xp_feedback.modulate.a = 0.0
	set_hp(100, 100)
	set_hunger(100.0, 100.0)
	set_level_xp(1, 0, 100)
	set_calendar(1, "06:00 AM")
	set_resources(0, 0, 0)
	set_nightfall_warning("13:00")
	_initialized = true
	get_viewport().size_changed.connect(_fit_small_viewport)
	call_deferred("_fit_small_viewport")


func _fit_small_viewport() -> void:
	# Keep small windows from shrinking HUD text below its designed pixel size.
	# The world and other UI retain the project's existing canvas stretch settings.
	var stretch := get_viewport().get_stretch_transform().get_scale()
	var correction := maxf(1.0, 1.0 / maxf(stretch.x, 0.01))
	scale = Vector2.ONE * correction
	size = get_viewport_rect().size / correction


func _process(delta: float) -> void:
	if _hud_message_timer > 0.0:
		_hud_message_timer -= delta
		if _hud_message_timer <= 0.0:
			_clear_hud_message()


# Each effect owns one tween. Rapid updates replace it, never stack or change layout.
func _replace_tween(key: String) -> Tween:
	_cancel_tween(key)
	var tween := create_tween()
	_tweens[key] = tween
	return tween


func _cancel_tween(key: String) -> void:
	if _tweens.has(key):
		var previous: Tween = _tweens[key]
		if previous and previous.is_valid():
			previous.kill()
		_tweens.erase(key)


func _pulse(control: Control, tint: Color = Color(1.22, 1.12, 0.78)) -> void:
	if not _initialized:
		return
	var tween := _replace_tween("pulse_%s" % control.get_instance_id())
	control.self_modulate = tint
	tween.tween_property(control, "self_modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


func _fill(bar: ProgressBar, target: float, smooth: bool) -> void:
	var key := "fill_%s" % bar.get_instance_id()
	_cancel_tween(key)
	if smooth and _initialized:
		var tween := _replace_tween(key)
		tween.tween_property(bar, "value", target, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		bar.value = target


func set_hp(current: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "HP  %d / %d" % [current, max_val]
	if _last_hp >= 0 and current < _last_hp:
		_pulse(hp_bar, Color(1.35, 0.68, 0.60))
	_last_hp = current


func set_hunger(current: float, max_val: float) -> void:
	hunger_bar.max_value = max_val
	_fill(hunger_bar, current, _last_hunger >= 0.0 and current > _last_hunger)
	hunger_bar.add_theme_stylebox_override("fill", _hunger_fill_warning if current <= 20.0 else _hunger_fill_normal)
	hunger_label.text = "HUNGER  %d / %d" % [int(current), int(max_val)]
	_last_hunger = current


## Kept for compatibility. Defense is not displayed on the HUD.
func set_defense(_current: int, _max_val: int) -> void:
	pass


func set_level_xp(level: int, current_xp: int, max_xp: int) -> void:
	if level == _last_level and current_xp == _last_xp and max_xp == _last_max_xp:
		return
	var leveled_up := _last_level >= 0 and level > _last_level
	level_label.text = "LV %d" % level
	level_label.tooltip_text = "Level %d" % level
	xp_label.text = "EXP %d / %d" % [current_xp, max_xp]
	xp_bar.tooltip_text = "%d / %d EXP to next level" % [current_xp, max_xp]
	xp_bar.max_value = max_xp
	if leveled_up:
		xp_bar.value = 0.0
		_pulse($TopLeft/PlayerStatus, Color(1.30, 1.15, 0.75))
		_show_xp_feedback("LEVEL UP!", true)
	_fill(xp_bar, current_xp, _last_level >= 0)
	_last_level = level
	_last_xp = current_xp
	_last_max_xp = max_xp


func notify_xp_gain(amount: int) -> void:
	if amount <= 0:
		return
	if _level_feedback:
		_pending_xp += amount
		return
	_show_xp_feedback("+%d EXP" % amount)


func _show_xp_feedback(text: String, is_level: bool = false) -> void:
	var tween := _replace_tween("xp_feedback")
	_level_feedback = is_level
	xp_feedback.text = text
	xp_feedback.add_theme_color_override("font_color", GOLD)
	xp_feedback.modulate.a = 1.0
	xp_label.modulate.a = 0.0
	tween.tween_interval(1.1)
	tween.tween_property(xp_feedback, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		xp_label.modulate.a = 1.0
		_level_feedback = false
		if _pending_xp > 0:
			var pending := _pending_xp
			_pending_xp = 0
			notify_xp_gain(pending)
	)


func set_calendar(day: int, time_str: String) -> void:
	day_label.text = "DAY %d" % day
	time_label.text = time_str
	if _last_day >= 0 and day != _last_day:
		_pulse(day_label)
	_last_day = day


func set_resources(gold: int, wood: int, stone: int) -> void:
	var totals: Array[int] = [gold, wood, stone]
	var labels: Array[Label] = [gold_label, wood_label, stone_label]
	var names := ["Gold", "Wood", "Stone"]
	for i in range(labels.size()):
		labels[i].text = "%s\n%s" % [names[i].to_upper(), _compact_number(totals[i])]
		labels[i].tooltip_text = "%s: %s" % [names[i], _format_number(totals[i])]
		if not _last_resources.is_empty() and totals[i] > _last_resources[i]:
			_pulse(labels[i])
	_last_resources = totals


func set_quests(quests: Array) -> void:
	var next_state := {}
	for i in range(3):
		var row: HBoxContainer = get_node("MidLeft/QuestTracker/Margin/VBox/Quest%d" % (i + 1))
		var title: Label = row.get_node("Title")
		var progress: Label = row.get_node("Progress")
		# Keep reserved row sizes, including when there are fewer daily quests.
		row.modulate.a = 1.0 if i < quests.size() else 0.0
		if i >= quests.size():
			continue
		var quest = quests[i]
		var id: String = quest.quest_id
		var old: Dictionary = _quest_state.get(id, {})
		var description: String = quest.description.replace("%d " % quest.target_count, "")
		title.text = ("%s " % ("✓" if quest.is_completed else "·")) + description
		title.tooltip_text = quest.get_progress_text()
		progress.text = "%d/%d" % [quest.current_count, quest.target_count]
		progress.tooltip_text = "Completed" if quest.is_completed else quest.get_progress_text()
		var color := COMPLETE if quest.is_completed else CREAM
		title.add_theme_color_override("font_color", color)
		progress.add_theme_color_override("font_color", color if quest.is_completed else GOLD)
		if old.is_empty():
			for control in [title, progress]:
				_cancel_tween("pulse_%s" % control.get_instance_id())
				control.self_modulate = Color.WHITE
		elif quest.current_count != old["count"] or quest.is_completed != old["complete"]:
			_pulse(progress)
			if quest.is_completed:
				_pulse(title)
		next_state[id] = {"count": quest.current_count, "complete": quest.is_completed}
	_quest_state = next_state


func set_nightfall_warning(time_str: String) -> void:
	nightfall_title_label.text = "NIGHTFALL IN"
	nightfall_timer_label.text = time_str
	nightfall_timer_label.tooltip_text = "Game hours : minutes until night"
	var parts := time_str.split(":")
	if parts.size() != 2:
		return
	# GameClock reports hours:minutes; keep that meaning and its timing unchanged.
	var remaining := int(parts[0]) * 60 + int(parts[1])
	var stage := 0
	for threshold in [300, 120, 60, 30]:
		if remaining < threshold:
			stage += 1
	_set_night_stage(stage)


func set_nightfall_status(status: String) -> void:
	if status == "ARRIVED":
		nightfall_title_label.text = "NIGHT HAS ARRIVED"
		nightfall_timer_label.text = ""
		_set_night_stage(5)


func _set_night_stage(stage: int) -> void:
	if stage == _night_stage:
		return
	_night_stage = stage
	var colors := [CREAM, GOLD, Color(0.96, 0.64, 0.32), Color(0.96, 0.46, 0.29), Color(1.0, 0.31, 0.25), Color(0.93, 0.48, 0.37)]
	var target: Color = colors[stage]
	var previous := nightfall_timer_label.get_theme_color("font_color")
	var tween := _replace_tween("night_color")
	tween.tween_method(func(color: Color):
		nightfall_timer_label.add_theme_color_override("font_color", color)
		nightfall_title_label.add_theme_color_override("font_color", color)
	, previous, target, 0.5)
	# Only react at a threshold crossing; no looping flashes.
	_pulse(nightfall_title_label)


func _compact_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


func _format_number(n: int) -> String:
	var s := str(n)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return result


func show_hud_message(text: String, duration: float = 2.0) -> void:
	hud_message_label.text = text
	hud_message_label.visible = true
	_hud_message_timer = duration


func _clear_hud_message() -> void:
	hud_message_label.text = ""
	hud_message_label.visible = false


# ==============================================================================
# ZOMBIE WARNING BANNER
# ==============================================================================

## Shows a centered warning banner 1 minute before night.
## Called once per night cycle — duplicate calls are ignored.
func show_zombie_warning() -> void:
	if _zombie_warning_shown:
		return
	_zombie_warning_shown = true
	_show_zombie_banner("⚠  ZOMBIES ARE COMING  ⚠", "Prepare yourself!", Color(0.96, 0.46, 0.29), 2.5)
	GameAudio.play("zombie_warning")
	print("[HUD] Zombie warning shown")


## Shows a centered arrival banner when night officially starts.
## Called once per night cycle — duplicate calls are ignored.
func show_zombie_arrival() -> void:
	if _zombie_arrival_shown:
		return
	_zombie_arrival_shown = true
	_show_zombie_banner("ZOMBIES HAVE ARRIVED", "", Color(1.0, 0.31, 0.25), 1.8)
	GameAudio.play("night_arrival")
	print("[HUD] Zombie arrival shown")


## Resets warning flags so they can trigger again next night.
## Called when morning begins.
func reset_zombie_warnings() -> void:
	_zombie_warning_shown = false
	_zombie_arrival_shown = false


## Creates a procedural centered banner overlay with fade in/out and subtle pulse.
func _show_zombie_banner(title_text: String, subtitle_text: String, accent_color: Color, display_time: float) -> void:
	# Clean up any existing banner
	if _zombie_banner_layer and is_instance_valid(_zombie_banner_layer):
		_zombie_banner_layer.queue_free()
		_zombie_banner_layer = null
	
	# CanvasLayer on top of everything
	var layer := CanvasLayer.new()
	layer.layer = 90
	_zombie_banner_layer = layer
	
	# Full-screen container (non-interactive)
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(container)
	
	# Center panel
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 80
	panel.offset_left = -160
	panel.offset_right = 160
	panel.modulate.a = 0.0  # Start invisible for fade-in
	
	# Dark semi-transparent background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.88)
	style.border_color = accent_color
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	panel.add_theme_stylebox_override("panel", style)
	container.add_child(panel)
	
	# VBox for title + subtitle
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Title label
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", accent_color)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	# Subtitle label (optional)
	if subtitle_text != "":
		var subtitle := Label.new()
		subtitle.text = subtitle_text
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.9))
		subtitle.add_theme_font_size_override("font_size", 12)
		vbox.add_child(subtitle)
	
	get_tree().root.add_child(layer)
	
	# Animation: fade in → hold with subtle pulse → fade out → cleanup
	var tween := create_tween()
	# Fade in
	tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	# Subtle scale pulse while visible
	tween.tween_property(panel, "scale", Vector2(1.03, 1.03), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	# Hold
	tween.tween_interval(display_time - 1.2)
	# Fade out
	tween.tween_property(panel, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		if layer and is_instance_valid(layer):
			layer.queue_free()
		if _zombie_banner_layer == layer:
			_zombie_banner_layer = null
	)
