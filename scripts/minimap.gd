extends Control
class_name MinimapUI

@export var target: Node2D
@export var zoom: float = 0.22

@onready var sub_viewport: SubViewport = get_node_or_null("Frame/MapClip/MapArea/SubViewportContainer/SubViewport")
@onready var map_camera: Camera2D = get_node_or_null("Frame/MapClip/MapArea/SubViewportContainer/SubViewport/MapCamera")
@onready var map_area: Control = get_node_or_null("Frame/MapClip/MapArea")
@onready var player_marker: Control = get_node_or_null("Frame/MapClip/MapArea/PlayerMarker")
@onready var player_arrow: Label = get_node_or_null("Frame/MapClip/MapArea/PlayerMarker/ArrowLabel")


func _ready() -> void:
	add_to_group("minimap_ui")
	call_deferred("_setup_world_viewport")
	_locate_player()


func _setup_world_viewport() -> void:
	if not sub_viewport:
		return
	
	# Connect to active world_2d to render the real TileMap & environment in real time
	var parent_viewport := get_viewport()
	if parent_viewport and parent_viewport.find_world_2d():
		sub_viewport.world_2d = parent_viewport.find_world_2d()
	
	if map_camera:
		map_camera.zoom = Vector2(zoom, zoom)


func _locate_player() -> void:
	if not target:
		var ken := get_tree().get_first_node_in_group("player")
		if ken and ken is Node2D:
			target = ken
		else:
			var root_node := get_tree().current_scene
			if root_node:
				var candidate := root_node.find_child("CharacterBody2D3", true, false)
				if candidate and candidate is Node2D:
					target = candidate


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		_locate_player()
		return
	
	_sync_camera_and_marker()


func set_target(new_target: Node2D) -> void:
	target = new_target
	_sync_camera_and_marker()


func _sync_camera_and_marker() -> void:
	if not target:
		return
	
	# Center the SubViewport's camera on the player
	if map_camera:
		map_camera.global_position = target.global_position
	
	# Update player marker direction indicator
	if player_marker and map_area:
		player_marker.position = map_area.size * 0.5
		
		var facing_dir: Vector2 = target.get("last_direction") if target.get("last_direction") != null else Vector2.DOWN
		if player_arrow:
			if facing_dir == Vector2.UP:
				player_arrow.text = "▲"
			elif facing_dir == Vector2.RIGHT:
				player_arrow.text = "►"
			elif facing_dir == Vector2.LEFT:
				player_arrow.text = "◄"
			else:
				player_arrow.text = "▼"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking on minimap toggles the Full Map
		var full_maps := get_tree().get_nodes_in_group("full_map_ui")
		for fm in full_maps:
			if is_instance_valid(fm) and fm.has_method("toggle_map"):
				fm.call("toggle_map")
				accept_event()
				return
