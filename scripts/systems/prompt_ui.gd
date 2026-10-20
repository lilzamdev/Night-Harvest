extends CanvasLayer

## Floating "[E] ENTER ..." prompt above whatever the player can interact with.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

var _box: PanelContainer
var _label: Label
var _key: TextureRect
var _current: Node = null
var _player: Node2D = null


func _ready() -> void:
	layer = 40
	_box = PanelContainer.new()
	var sb := UIKit.box(Color(0.06, 0.045, 0.03, 0.86), UIKit.C_BORDER, 2, false)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(hb)
	_key = TextureRect.new()
	_key.texture = load("res://Assets/Generated/key_e.png")
	_key.custom_minimum_size = Vector2(22, 22)
	_key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_key)
	_label = UIKit.label(hb, "", UIKit.F_SMALL, UIKit.C_TEXT)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.visible = false


func _process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if not _player:
			return
	var blocking: bool = _player.has_method("is_ui_blocking") and _player.is_ui_blocking()
	var target: Node2D = null
	if not blocking and _player.has_method("get_closest_interactable"):
		target = _player.get_closest_interactable()
	if target and target.is_in_group("beds"):
		target = null  # beds draw their own label
	var anchor := Vector2.INF
	var text := ""
	if (not target or not target.has_method("get_prompt")) and not blocking:
		# v1.3.1: flowers you can pick
		var wg := get_tree().get_first_node_in_group("worldgen")
		if wg and wg.has_method("flower_at"):
			var d: Vector2 = _player.get("last_direction") if _player.get("last_direction") != null else Vector2.DOWN
			for pt in [_player.global_position + d * 12.0, _player.global_position + Vector2(0, -2)]:
				var fid: String = wg.flower_at(pt)
				if fid != "":
					var it = load("res://scripts/item_database.gd").get_item(fid)
					text = "PICK " + (str(it.display_name).to_upper() if it else "FLOWER")
					anchor = pt + Vector2(0, -8)
					break
		if text == "":
			_box.visible = false
			return
	else:
		if not target or not target.has_method("get_prompt"):
			_box.visible = false
			return
		text = str(target.get_prompt()).replace("[G] ", "").replace("[E] ", "").to_upper()
		anchor = target.global_position + Vector2(0, -30)
	if _label.text != text:
		_label.text = text
		_box.reset_size()
	var vp := get_viewport()
	var screen := vp.get_canvas_transform() * anchor
	_box.visible = true
	_box.position = (screen - Vector2(_box.size.x * 0.5, _box.size.y)).round()
