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
	_restart_button.text = "WAKE UP"
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
	# v1.3.1: wake up at your bed (or where you first arrived) right away. Reloading the
	# whole scene here crashed the game on some graphics drivers.
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.has_method("revive_at"):
		var pos := _respawn_position(p)
		var mines := get_tree().get_first_node_in_group("mines")
		if mines and mines.get("active") and mines.has_method("_exit_to_surface"):
			mines._exit_to_surface(p)
		var world := get_tree().get_first_node_in_group("nh_world")
		if world and world.has_method("is_player_indoors") and world.is_player_indoors() and world.has_method("_exit_room_state"):
			world._exit_room_state(p)
		p.revive_at(pos)
		var wg := get_tree().get_first_node_in_group("worldgen")
		if wg and wg.has_method("load_around_now"):
			wg.load_around_now(pos)
		# zombies standing right where you wake up are pushed back to the dark
		for z in get_tree().get_nodes_in_group("zombies"):
			if is_instance_valid(z) and (z as Node2D).global_position.distance_to(pos) < 140.0:
				var away := ((z as Node2D).global_position - pos).normalized()
				(z as Node2D).global_position = pos + (away if away != Vector2.ZERO else Vector2.RIGHT) * 170.0
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud and hud.has_method("show_hud_message"):
			hud.show_hud_message("You wake up, sore but alive.", 3.0)
		for bus in get_tree().get_nodes_in_group("event_bus"):
			if bus.has_signal("gameplay_event"):
				bus.gameplay_event.emit("player_respawned", {"pos": pos})
				break
		return
	# fallback (no player found): reload as before
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").set_meta("respawn_pending", true)
	get_tree().reload_current_scene()


func _respawn_position(p: Node2D) -> Vector2:
	var wg := get_tree().get_first_node_in_group("worldgen")
	if wg and wg.has_method("_starts_in_wilds") and wg._starts_in_wilds():
		return wg.respawn_world_pos()
	# Harvest Village farms (older saves): wake up at the farm where the game starts
	return p.get_meta("start_pos") if p.has_meta("start_pos") else p.global_position
