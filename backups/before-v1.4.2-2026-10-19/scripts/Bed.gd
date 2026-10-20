extends Node2D
class_name BedEntity

## Bed interactable for Night Harvest (Phase 7).
## Allows Ken to sleep through the night, advancing GameClock to morning (6:00 AM).
## Applies hunger cost, HP restore, clears night zombies, and updates farming/crops.

signal sleep_started()
signal sleep_finished()

@export_group("Sleep Schedule")
@export var sleep_allowed_start_hour: int = 19  # 7:00 PM
@export var sleep_allowed_end_hour: int = 6     # 6:00 AM (05:59 last sleep minute)
@export var wake_hour: int = 6                 # 6:00 AM
@export var wake_minute: int = 0

@export_group("Sleep Effects")
@export var overnight_hunger_cost: float = 10.0
@export var overnight_hp_restore: int = 20
@export var fade_duration: float = 0.8

@export_group("Interaction")
@export var interaction_range: float = 38.0

var _is_sleeping_sequence: bool = false

@onready var interaction_label: Label = get_node_or_null("InteractionLabel")
@onready var sleep_pos_marker: Marker2D = get_node_or_null("SleepPosition")
@onready var wake_pos_marker: Marker2D = get_node_or_null("WakePosition")


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("beds")
	
	if interaction_label:
		interaction_label.visible = false
		interaction_label.text = "[G] Sleep"


func _process(_delta: float) -> void:
	if _is_sleeping_sequence:
		if interaction_label:
			interaction_label.visible = false
		return
	
	# Floating prompt proximity detection
	var player := _find_player()
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= interaction_range:
			if interaction_label:
				if is_sleep_allowed():
					interaction_label.text = "[G] Sleep"
				else:
					interaction_label.text = "[G] Bed"
				interaction_label.visible = true
			return
	
	if interaction_label:
		interaction_label.visible = false


func can_interact(player: Node2D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if _is_sleeping_sequence:
		return false
	var dist := global_position.distance_to(player.global_position)
	return dist <= interaction_range


func get_prompt() -> String:
	return "[G] Sleep" if is_sleep_allowed() else "[G] Bed"


func is_sleep_allowed() -> bool:
	var clock := _get_game_clock()
	if not clock:
		return true
	var h: int = clock.current_hour
	if sleep_allowed_start_hour > sleep_allowed_end_hour:
		return h >= sleep_allowed_start_hour or h < sleep_allowed_end_hour
	else:
		return h >= sleep_allowed_start_hour and h < sleep_allowed_end_hour


func interact(player: Node2D) -> void:
	if _is_sleeping_sequence:
		return
	
	if not is_sleep_allowed():
		var hud := _get_hud()
		if hud and hud.has_method("show_hud_message"):
			hud.show_hud_message("It's too early to sleep.")
		elif interaction_label:
			interaction_label.text = "Too early to sleep"
			interaction_label.visible = true
		print("Bed: It is too early to sleep.")
		return
	
	_show_confirm_dialog(player)


func _show_confirm_dialog(player: Node2D) -> void:
	var sleep_ui_script = preload("res://scripts/SleepConfirmUI.gd")
	var sleep_ui: CanvasLayer = sleep_ui_script.new()
	get_tree().root.add_child(sleep_ui)
	sleep_ui.confirmed.connect(_on_sleep_confirmed.bind(player))


func _on_sleep_confirmed(player: Node2D) -> void:
	_start_sleep_sequence(player)


func _start_sleep_sequence(player: Node2D) -> void:
	if _is_sleeping_sequence:
		return
	_is_sleeping_sequence = true
	sleep_started.emit()
	
	if interaction_label:
		interaction_label.visible = false
	
	# 1. Put player into sleeping state and reposition
	var previous_player_z_index: int = 0
	if player and is_instance_valid(player):
		previous_player_z_index = player.z_index
		if player.has_method("enter_sleep_state"):
			player.enter_sleep_state()
		player.global_position = get_sleep_position()
		# Temporarily raise player z_index above bed to render visibly on top of mattress
		player.z_index = z_index + 1
	
	# 2. Fade to black
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	var color_rect := ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_layer.add_child(color_rect)
	get_tree().root.add_child(fade_layer)
	
	var tween_fade_out := create_tween()
	tween_fade_out.tween_property(color_rect, "color:a", 1.0, fade_duration)
	await tween_fade_out.finished
	
	# 3. Overnight pause while screen is black
	await get_tree().create_timer(0.4).timeout
	
	# 4. Stop zombie spawning — burning is handled by night_ended signal
	# when advance_to_time() crosses the night→morning boundary
	var spawn_mgr := _get_spawn_manager()
	if spawn_mgr:
		if spawn_mgr.has_method("_stop_zombie_spawning"):
			spawn_mgr.call("_stop_zombie_spawning")
	
	# 5. Advance GameClock to morning (emits intermediate signals for crops, lighting, HUD)
	var clock := _get_game_clock()
	if clock and clock.has_method("advance_to_time"):
		clock.advance_to_time(wake_hour, wake_minute)
	
	# 6. Apply overnight hunger cost & HP restore
	var stats := _get_player_stats()
	if stats:
		if stats.has_method("drain_hunger"):
			stats.drain_hunger(overnight_hunger_cost)
		if stats.has_method("heal"):
			stats.heal(overnight_hp_restore)
		# Prevent immediate tick by resetting accumulator
		if "_hunger_drain_elapsed" in stats:
			stats._hunger_drain_elapsed = 0.0
	
	# 7. Move player beside the bed and restore normal draw order
	if player and is_instance_valid(player):
		player.global_position = get_wake_position()
		player.z_index = previous_player_z_index
	
	# 8. Fade in from black
	var tween_fade_in := create_tween()
	tween_fade_in.tween_property(color_rect, "color:a", 0.0, fade_duration)
	await tween_fade_in.finished
	
	fade_layer.queue_free()
	
	# 9. Wake player
	if player and is_instance_valid(player):
		if player.has_method("exit_sleep_state"):
			player.exit_sleep_state()
	
	_is_sleeping_sequence = false
	sleep_finished.emit()
	print("Bed: Good morning! Woke up at %02d:%02d" % [wake_hour, wake_minute])


func get_sleep_position() -> Vector2:
	if sleep_pos_marker:
		return sleep_pos_marker.global_position
	# Pillow + mattress: atlas Rect2(135, 45, 19, 27), relative to bed center (144, 57).
	return to_global(Vector2(0.5, 1.5))


func get_wake_position() -> Vector2:
	if wake_pos_marker:
		return wake_pos_marker.global_position
	return global_position + Vector2(26, 4)


func _find_player() -> Node2D:
	var player_nodes := get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if p is Node2D and is_instance_valid(p) and not p.is_queued_for_deletion():
			return p
	return null


func _get_game_clock() -> Node:
	var clocks := get_tree().get_nodes_in_group("game_clock")
	for c in clocks:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			return c
	return null


func _get_spawn_manager() -> Node:
	var sms := get_tree().get_nodes_in_group("spawn_manager")
	for sm in sms:
		if is_instance_valid(sm) and not sm.is_queued_for_deletion():
			return sm
	return null


func _get_player_stats() -> Node:
	var stats_nodes := get_tree().get_nodes_in_group("player_stats")
	for s in stats_nodes:
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			return s
	return null


func _get_hud() -> Node:
	var hud_nodes := get_tree().get_nodes_in_group("hud_ui")
	for h in hud_nodes:
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			return h
	return null
