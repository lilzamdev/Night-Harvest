extends CanvasLayer

## Dialogue box for villagers: portrait, name, typewriter text and choices.
## Keyboard: 1-3 pick a choice, E / ENTER skips the typing, ESC closes.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

var is_open: bool = false

var _stage: Control
var _panel: Panel
var _portrait: TextureRect
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _speaker: Node = null
var _on_choice: Callable
var _options: Array = []
var _full_text := ""
var _shown := 0.0
var _blip_t := 0.0
const TEXT_W := 470.0
const TEXT_H := 106.0   # room under the name inside the box


func _ready() -> void:
	layer = 60
	add_to_group("dialogue_ui")
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = UIKit.stage(self)
	_panel = UIKit.panel(_stage, Vector2(96, 448), Vector2(960, 176))
	var frame := UIKit.panel(_panel, Vector2(18, 18), Vector2(140, 140), UIKit.box(Color("120C08"), UIKit.C_GOLD, 3, false))
	_portrait = UIKit.tex(frame, null, Vector2(6, 6), Vector2(128, 128))
	_name = UIKit.label(_panel, "", UIKit.F_BIG, UIKit.C_GOLD_LIGHT, Vector2(182, 16))
	_text = UIKit.wrap_label(_panel, "", UIKit.F_SMALL, UIKit.C_TEXT, Vector2(182, 58), TEXT_W)
	_text.clip_text = true
	_text.size = Vector2(TEXT_W, TEXT_H)
	_choices = VBoxContainer.new()
	_choices.position = Vector2(672, 18)
	_choices.size = Vector2(270, 140)
	_choices.add_theme_constant_override("separation", 6)
	_panel.add_child(_choices)
	visible = false


func open_dialogue(speaker: Node, text: String, options: Array, on_choice: Callable) -> void:
	_speaker = speaker
	_on_choice = on_choice
	_options = options
	_name.text = str(speaker.get("display_name")).to_upper()
	_portrait.texture = speaker.portrait() if speaker.has_method("portrait") else null
	set_text(text)
	_build_choices()
	visible = true
	is_open = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


func set_text(text: String) -> void:
	_full_text = text.to_upper()
	_shown = 0.0
	_text.text = ""
	# v1.4.1: long lines (signs, villagers) shrink to fit inside the box
	UIKit.fit_wrap(_text, _full_text, TEXT_W, TEXT_H)
	_text.size = Vector2(TEXT_W, TEXT_H)


func close_dialogue() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if _speaker and is_instance_valid(_speaker) and _speaker.has_method("end_talk"):
		_speaker.end_talk()
	_speaker = null


func _build_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	for i in _options.size():
		var o: Dictionary = _options[i]
		var b := UIKit.button(null, "%d  %s" % [i + 1, o["text"]], Vector2.ZERO, i == 0, false, 270)
		b.custom_minimum_size = Vector2(270, 40)
		var action: String = o["action"]
		b.pressed.connect(func() -> void: _choose(action))
		_choices.add_child(b)


func _choose(action: String) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ui_click")
	if _on_choice.is_valid():
		_on_choice.call(action)


func _process(delta: float) -> void:
	if not is_open:
		return
	if _shown < _full_text.length():
		_shown = minf(_full_text.length(), _shown + delta * 55.0)
		_text.text = _full_text.left(int(_shown))
		_blip_t -= delta
		if _blip_t <= 0.0 and has_node("/root/GameAudio"):
			_blip_t = 0.09
			get_node("/root/GameAudio").play("hotbar_select", -26.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel"):
		_choose("bye")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < _options.size():
				_choose(str(_options[idx]["action"]))
			get_viewport().set_input_as_handled()
			return
		if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or event.is_action_pressed("interact"):
			if _shown < _full_text.length():
				_shown = _full_text.length()
				_text.text = _full_text
			elif not _options.is_empty():
				_choose(str(_options[0]["action"]))
			get_viewport().set_input_as_handled()
