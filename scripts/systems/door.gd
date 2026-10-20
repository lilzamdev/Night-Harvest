extends Node2D

## A house door. Outside doors teleport the player into an interior room, the
## exit mat inside sends them back out. Locked doors just say so.
##
## Group "interactables": the player presses E (or G) when standing in range.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

var door_id: String = ""
var display_name: String = "House"
var locked: bool = false
var locked_text: String = "It's locked."
## Where the player appears on the other side (global position).
var target_position: Vector2 = Vector2.ZERO
## The interior room this door leads into (null for exit doors -> outdoors).
var target_room: Node2D = null
var is_exit: bool = false
var interact_range: float = 22.0
## Hours (inclusive start, exclusive end) the door is open. -1 = always open.
var open_from: int = -1
var open_until: int = -1

var _world: Node = null


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("doors")
	_world = get_tree().get_first_node_in_group("nh_world")


func can_interact(_player: Node2D) -> bool:
	return true


func get_prompt() -> String:
	if is_exit:
		return "LEAVE"
	if locked or not _is_open_now():
		return "LOCKED"
	return "ENTER " + display_name.to_upper()


func interact(player: Node2D) -> void:
	if not _world:
		_world = get_tree().get_first_node_in_group("nh_world")
	if locked:
		_say(locked_text)
		return
	if not _is_open_now():
		_say("%s is closed. Come back at %d:00." % [display_name, open_from])
		return
	if _world and _world.has_method("travel"):
		_world.travel(player, self)


func _is_open_now() -> bool:
	if open_from < 0:
		return true
	var clock := get_tree().get_first_node_in_group("game_clock")
	if not clock:
		return true
	var h: int = clock.current_hour
	return h >= open_from and h < open_until


func _say(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud and hud.has_method("show_hud_message"):
		hud.show_hud_message(text, 2.0)
