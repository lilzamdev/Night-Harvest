extends Node

## Fullscreen toggle handler for Night Harvest.
## Registered as an autoload so it works globally across all scenes.
## Uses the "toggle_fullscreen" InputMap action (F11).
##
## Call FullscreenToggle.toggle() from any script (e.g. a Settings menu)
## to reuse this without duplicating logic.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle()
		get_viewport().set_input_as_handled()


## Toggles between windowed and fullscreen mode.
## Callable from any script: FullscreenToggle.toggle()
func toggle() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Returns true if currently in fullscreen mode.
func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
