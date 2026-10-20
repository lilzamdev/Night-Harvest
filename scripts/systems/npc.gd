extends CharacterBody2D

## Villager NPC: wanders near a daytime spot, heads indoors at night, talks,
## and (for shopkeepers) opens the shop.
##
## Uses a sheet in Ken's 32x32 layout (see characters.gd), or a custom idle strip.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

var npc_id: String = ""
var display_name: String = "Villager"
var role: String = ""          ## "", "general" or "smith" (shop catalogue id)
var sheet: Texture2D
var idle_strip: Dictionary = {}  ## optional {"row": int, "frames": int, "w": 32, "h": 32}
var lines: Array = []          ## Array of String or Callable -> String
var day_spot: Vector2 = Vector2.ZERO
var day_radius: float = 28.0
var night_spot: Vector2 = Vector2.ZERO   ## inside their house
var day_from: int = 7
var day_until: int = 18
var interact_range: float = 26.0
var walk_speed: float = 26.0
var talks_today: int = 0

var _sprite: AnimatedSprite2D
var _name_tag: Label
var _target: Vector2
var _wait: float = 0.0
var _facing: String = "front"
var _talking: bool = false
var _line_index: int = 0
var _indoors: bool = false


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("npcs")
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 5)
	shape.shape = r
	shape.position = Vector2(0, 10)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.position = Vector2(0, 0)
	add_child(_sprite)
	_sprite.play("idle_front")
	_name_tag = UIKit.label(null, display_name.to_upper(), UIKit.F_TINY, UIKit.C_GOLD_LIGHT)
	_name_tag.position = Vector2(-UIKit.text_w(_name_tag.text, UIKit.F_TINY) * 0.5, -26)
	_name_tag.add_theme_constant_override("shadow_offset_y", 1)
	_name_tag.visible = false
	_name_tag.z_index = 20
	add_child(_name_tag)
	_target = global_position
	_wait = randf_range(0.5, 3.0)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	if not idle_strip.is_empty():
		for dir in ["front", "back", "left", "right"]:
			for kind in ["idle", "walk"]:
				var anim := "%s_%s" % [kind, dir]
				sf.add_animation(anim)
				sf.set_animation_speed(anim, 4.0 if kind == "idle" else 8.0)
				for i in int(idle_strip.get("frames", 1)):
					sf.add_frame(anim, UIKit.atlas(sheet, Rect2(i * 32, int(idle_strip["row"]) * 32, 32, 32)))
		return sf
	# Ken layout rows: 0 idle F, 1 walk F, 2 idle B, 3 walk B, 4 idle R, 5 walk R, 6 idle L, 7 walk L
	var rows := {"idle_front": [0, 2], "walk_front": [1, 6], "idle_back": [2, 2], "walk_back": [3, 6],
		"idle_right": [4, 2], "walk_right": [5, 6], "idle_left": [6, 2], "walk_left": [7, 6]}
	for anim in rows:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 2.5 if anim.begins_with("idle") else 8.0)
		for i in int(rows[anim][1]):
			sf.add_frame(anim, UIKit.atlas(sheet, Rect2(i * 32, int(rows[anim][0]) * 32, 32, 32)))
	return sf


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _talking:
		velocity = Vector2.ZERO
		if player:
			_face((player.global_position - global_position))
		_sprite.play("idle_" + _facing)
		return
	_update_schedule()
	var to := _target - global_position
	if to.length() > 2.0 and _wait <= 0.0:
		velocity = to.normalized() * walk_speed
		_face(to)
		_sprite.play("walk_" + _facing)
		move_and_slide()
		if get_slide_collision_count() > 0:
			_pick_new_target(true)
	else:
		velocity = Vector2.ZERO
		_sprite.play("idle_" + _facing)
		_wait -= delta
		if _wait <= 0.0 and to.length() <= 2.0:
			_pick_new_target()


func _face(v: Vector2) -> void:
	if absf(v.x) > absf(v.y):
		_facing = "right" if v.x > 0 else "left"
	else:
		_facing = "front" if v.y > 0 else "back"


func _pick_new_target(blocked: bool = false) -> void:
	var home := night_spot if _indoors else day_spot
	var radius := 18.0 if _indoors else day_radius
	_target = home + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
	_wait = randf_range(0.4, 1.0) if blocked else randf_range(1.5, 5.0)


func is_daytime_out() -> bool:
	var clock := get_tree().get_first_node_in_group("game_clock")
	if not clock:
		return true
	var h: int = clock.current_hour
	return h >= day_from and h < day_until


func _update_schedule() -> void:
	var should_be_in := not is_daytime_out() and night_spot != Vector2.ZERO
	if should_be_in == _indoors:
		return
	_indoors = should_be_in
	# Villagers slip away quietly: fade out, appear at the other spot, fade in.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		global_position = night_spot if _indoors else day_spot
		_target = global_position
		_wait = 1.0)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)


func snap_to_schedule() -> void:
	_indoors = not is_daytime_out() and night_spot != Vector2.ZERO
	global_position = night_spot if _indoors else day_spot
	_target = global_position


func can_interact(_player: Node2D) -> bool:
	return modulate.a > 0.9


func get_prompt() -> String:
	return "TALK TO " + display_name.to_upper()


func interact(player: Node2D) -> void:
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	if not ui:
		return
	_talking = true
	_face(player.global_position - global_position)
	talks_today += 1
	var options: Array = []
	if role != "":
		options.append({"text": "BROWSE WARES", "action": "shop"})
	options.append({"text": "CHAT", "action": "talk"})
	options.append({"text": "GOODBYE", "action": "bye"})
	ui.open_dialogue(self, _next_line(), options, _on_dialogue_choice)


func _next_line() -> String:
	if lines.is_empty():
		return "..."
	var l = lines[_line_index % lines.size()]
	_line_index += 1
	if l is Callable:
		return str(l.call())
	return str(l)


func _on_dialogue_choice(action: String) -> void:
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	match action:
		"shop":
			_talking = false
			if ui:
				ui.close_dialogue()
			var shop := get_tree().get_first_node_in_group("shop_ui")
			if shop:
				shop.open_shop(role, self)
		"talk":
			if ui:
				ui.set_text(_next_line())
		_:
			_talking = false
			if ui:
				ui.close_dialogue()


func end_talk() -> void:
	_talking = false


func portrait() -> Texture2D:
	if not idle_strip.is_empty():
		return UIKit.atlas(sheet, Rect2(8, int(idle_strip["row"]) * 32 + 2, 16, 16))
	return UIKit.atlas(sheet, Rect2(8, 0 if npc_id == "pedro" else 1, 16, 16))
