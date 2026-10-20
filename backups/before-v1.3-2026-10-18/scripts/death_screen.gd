extends CanvasLayer
class_name DeathScreen

## Simple death overlay shown when the player dies.
## Freezes the game and provides a restart button.
## Designed to be modular for future expansion (respawn location, penalties, etc.)

var _overlay: ColorRect
var _title_label: Label
var _restart_button: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_overlay.visible = false


func _build_ui() -> void:
	# Dark red overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	
	# Panel with dark wood border style (matches existing HUD aesthetic)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.7, 0.15, 0.15, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	# Margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	
	# VBox
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)
	
	# "YOU DIED" title
	_title_label = Label.new()
	_title_label.text = "YOU DIED"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	
	# Restart button
	_restart_button = Button.new()
	_restart_button.text = "RESTART"
	_restart_button.custom_minimum_size = Vector2(140, 40)
	_restart_button.add_theme_font_size_override("font_size", 14)
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_button)


func show_death_screen() -> void:
	_overlay.visible = true
	get_tree().paused = true
	
	# Fade in the dark overlay
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_overlay.color = Color(0.05, 0.0, 0.0, 0.0)
	tween.tween_property(_overlay, "color", Color(0.05, 0.0, 0.0, 0.85), 0.5)


func hide_death_screen() -> void:
	_overlay.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	hide_death_screen()
	get_tree().reload_current_scene()
