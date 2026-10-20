extends CanvasLayer

## Sleep confirmation dialog for Night Harvest.
## Shows "Sleep until morning?" with YES/NO buttons.
## Matches the project's pixel-art UI style.

signal confirmed()
signal cancelled()

var is_open: bool = false

var _panel: PanelContainer
var _yes_button: Button
var _no_button: Button


func _ready() -> void:
	add_to_group("sleep_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	
	_build_ui()
	visible = true
	is_open = true
	
	if _yes_button:
		_yes_button.grab_focus()


func _build_ui() -> void:
	# Full-screen darkening overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Panel
	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	panel_style.border_color = Color(0.55, 0.45, 0.30, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# VBox layout
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)
	
	# Question label
	var label := Label.new()
	label.text = "Sleep until morning?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
	vbox.add_child(label)
	
	# Button row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	# YES button
	_yes_button = Button.new()
	_yes_button.text = "  YES  "
	_yes_button.add_theme_font_size_override("font_size", 12)
	_yes_button.custom_minimum_size = Vector2(70, 28)
	var yes_style := StyleBoxFlat.new()
	yes_style.bg_color = Color(0.22, 0.50, 0.28, 1.0)
	yes_style.border_color = Color(0.35, 0.65, 0.40, 1.0)
	yes_style.border_width_left = 1
	yes_style.border_width_right = 1
	yes_style.border_width_top = 1
	yes_style.border_width_bottom = 1
	yes_style.corner_radius_top_left = 3
	yes_style.corner_radius_top_right = 3
	yes_style.corner_radius_bottom_left = 3
	yes_style.corner_radius_bottom_right = 3
	_yes_button.add_theme_stylebox_override("normal", yes_style)
	var yes_hover := yes_style.duplicate() as StyleBoxFlat
	yes_hover.bg_color = Color(0.28, 0.58, 0.34, 1.0)
	_yes_button.add_theme_stylebox_override("hover", yes_hover)
	_yes_button.pressed.connect(_on_yes_pressed)
	hbox.add_child(_yes_button)
	
	# NO button
	_no_button = Button.new()
	_no_button.text = "  NO  "
	_no_button.add_theme_font_size_override("font_size", 12)
	_no_button.custom_minimum_size = Vector2(70, 28)
	var no_style := StyleBoxFlat.new()
	no_style.bg_color = Color(0.50, 0.22, 0.20, 1.0)
	no_style.border_color = Color(0.65, 0.35, 0.30, 1.0)
	no_style.border_width_left = 1
	no_style.border_width_right = 1
	no_style.border_width_top = 1
	no_style.border_width_bottom = 1
	no_style.corner_radius_top_left = 3
	no_style.corner_radius_top_right = 3
	no_style.corner_radius_bottom_left = 3
	no_style.corner_radius_bottom_right = 3
	_no_button.add_theme_stylebox_override("normal", no_style)
	var no_hover := no_style.duplicate() as StyleBoxFlat
	no_hover.bg_color = Color(0.58, 0.28, 0.26, 1.0)
	_no_button.add_theme_stylebox_override("hover", no_hover)
	_no_button.pressed.connect(_on_no_pressed)
	hbox.add_child(_no_button)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# ESC cancels
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_no_pressed()
		get_viewport().set_input_as_handled()


func _on_yes_pressed() -> void:
	is_open = false
	confirmed.emit()
	queue_free()


func _on_no_pressed() -> void:
	is_open = false
	cancelled.emit()
	queue_free()
