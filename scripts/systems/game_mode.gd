extends Node

## Game mode (v1.3): SURVIVAL or CREATIVE, picked on the New Game screen.
##   Survival  start with (almost) nothing, gather, craft, build and survive.
##   Creative  every item from the catalog (press C), no damage, no hunger,
##             everything breaks in one hit and crafting is free. Zombies still
##             come at night but leave you alone.
## Also shows where you are (biome) under the clock.

var creative := false
var _label: Label
var _coords: Label
var _t := 0.0
var _game: Node


func _ready() -> void:
	add_to_group("game_mode")
	_game = get_parent()
	if has_node("/root/SaveManager"):
		creative = str(get_node("/root/SaveManager").active_info.get("mode", "survival")) == "creative"
	call_deferred("_add_hud_label")


func mode_name() -> String:
	return "CREATIVE" if creative else "SURVIVAL"


func _add_hud_label() -> void:
	var box := _game.get_node_or_null("UI/HUD/TopCenter/Calendar/Margin/VBox") as VBoxContainer
	if not box:
		return
	_label = Label.new()
	_label.name = "AreaLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.78, 0.9, 0.7))
	box.add_child(_label)
	# v1.3.1: where am I? Map coordinates in tiles (the village square is X 0 Y 0)
	_coords = Label.new()
	_coords.name = "CoordsLabel"
	_coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coords.add_theme_font_size_override("font_size", 9)
	_coords.add_theme_color_override("font_color", Color(0.86, 0.82, 0.7))
	box.add_child(_coords)
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var wg := get_tree().get_first_node_in_group("worldgen")
	var area := ""
	if p and wg:
		var pos := p.global_position
		var mines := get_tree().get_first_node_in_group("mines")
		var world := get_tree().get_first_node_in_group("nh_world")
		if mines and mines.get("active"):
			area = ""
		elif world and world.has_method("is_player_indoors") and world.is_player_indoors():
			area = "INDOORS"
		elif absf(pos.x) < 150000.0 and absf(pos.y) < 150000.0:
			area = wg.biome_name_at(pos)
	var txt := area
	if creative:
		txt = (area + " · " if area != "" else "") + "CREATIVE"
	_label.text = txt
	_label.visible = txt != ""
	if _coords:
		var gs := get_node_or_null("/root/GameSettings")
		var show_xy: bool = p != null and wg != null and area != "" and area != "INDOORS" and (gs == null or bool(gs.show_coords))
		_coords.visible = show_xy
		if show_xy:
			_coords.text = wg.coords_text(wg.coords_of(p.global_position))


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	_update_label()
	if not creative:
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats and not stats.is_dead:
		if stats.current_hunger < stats.max_hunger:
			stats.current_hunger = stats.max_hunger
			stats.hunger_changed.emit(stats.current_hunger, stats.max_hunger)
		if stats.current_health < stats.max_health:
			stats.heal(stats.max_health)
