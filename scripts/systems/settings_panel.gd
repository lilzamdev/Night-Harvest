extends Control

## SettingsPanel (v1.3.1): the full settings screen, used by the in-game pause menu.
## Tabs: AUDIO · DISPLAY · CONTROLS (click a key to change it) · GAMEPLAY.
## Everything reads and writes GameSettings, which saves to user://settings.cfg.
## The controls list can also be built on its own (see build_controls_into) so the
## title screen shows the same rebindable keys.

signal back_pressed

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const F := 18
const ROW_H := 46.0

## true: only the rebindable key list (the title screen embeds it like this)
var controls_only := false
var tab := "audio"
var _ctrl_parent: Control
var _ctrl_w := 0.0
var _tabs := {}
var _body: Control
var _waiting_action := ""
var _waiting_chip: Label
var _note: Label


func _ready() -> void:
	if controls_only:
		mouse_filter = Control.MOUSE_FILTER_PASS
		build_controls_into(self, size.x)
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UIKit.panel(self, Vector2.ZERO, size, UIKit.box(UIKit.C_PANEL, UIKit.C_BORDER, 3, true))
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.label(self, "SETTINGS", 36, UIKit.C_TEXT, Vector2(26, 18))
	var x := 26.0
	for t in [["audio", "AUDIO"], ["display", "DISPLAY"], ["controls", "CONTROLS"], ["gameplay", "GAMEPLAY"]]:
		var w := UIKit.text_w(t[1], F) + 36.0
		var b := _flat_button(self, Vector2(x, 70), Vector2(w, 38))
		UIKit.label(b, t[1], F, UIKit.C_TEXT_DIM, Vector2(18, 10)).name = "T"
		var id: String = t[0]
		b.pressed.connect(func() -> void: select_tab(id))
		_tabs[id] = b
		x += w + 6.0
	UIKit.color_rect(self, UIKit.C_LINE, Vector2(26, 108), Vector2(size.x - 52, 3))
	_body = Control.new()
	_body.position = Vector2(26, 122)
	_body.size = Vector2(size.x - 52, size.y - 190)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_body)
	var back := UIKit.button(self, "< BACK  ESC", Vector2(26, size.y - 60), false, false, 190)
	back.pressed.connect(func() -> void: back_pressed.emit())
	_note = UIKit.label(self, "", 9, UIKit.C_TEXT_DIM, Vector2(240, size.y - 44))
	select_tab(tab)


func select_tab(id: String) -> void:
	tab = id
	_cancel_wait()
	for k in _tabs:
		var on: bool = k == id
		var b: Button = _tabs[k]
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.C_PANEL_HI if on else Color(0, 0, 0, 0), UIKit.C_GOLD if on else Color(0, 0, 0, 0), 2, false))
		(b.get_node("T") as Label).add_theme_color_override("font_color", UIKit.C_GOLD_LIGHT if on else UIKit.C_TEXT_DIM)
	for c in _body.get_children():
		c.queue_free()
	_note.text = ""
	if not has_node("/root/GameSettings"):
		return
	var gs := get_node("/root/GameSettings")
	var y := 0.0
	match id:
		"audio":
			y = _slider(y, "MASTER VOLUME", "master_volume", gs.master_volume)
			y = _slider(y, "MUSIC", "music_volume", gs.music_volume)
			y = _slider(y, "SOUND EFFECTS", "sfx_volume", gs.sfx_volume)
		"display":
			gs.refresh_fullscreen_state()
			y = _seg(y, "SCREEN", [["WINDOWED", false], ["FULLSCREEN", true]], gs.fullscreen, "fullscreen")
			y = _seg(y, "V-SYNC", [["OFF", false], ["ON", true]], gs.vsync, "vsync")
			y = _seg(y, "PIXEL PERFECT SCALING", [["OFF", false], ["ON", true]], gs.pixel_perfect, "pixel_perfect")
			y = _seg(y, "GRAPHICS", [["LOW", "low"], ["MEDIUM", "medium"], ["HIGH", "high"]], gs.quality, "quality")
			_note.text = "LOW: 30 FPS, no shadows or particles.  MEDIUM: 60 FPS.  HIGH: everything on."
		"controls":
			build_controls_into(_body, _body.size.x)
		"gameplay":
			y = _seg(y, "CAMERA ZOOM", [["FAR", 2.5], ["NORMAL", 3.0], ["NEAR", 4.0]], gs.camera_zoom, "camera_zoom")
			y = _seg(y, "SHOW COORDINATES", [["OFF", false], ["ON", true]], gs.show_coords, "show_coords")
			y = _seg(y, "SCREEN SHAKE", [["OFF", false], ["ON", true]], gs.screen_shake, "screen_shake")
			y = _seg(y, "DAMAGE NUMBERS", [["OFF", false], ["ON", true]], gs.damage_numbers, "damage_numbers")


# --------------------------------------------------------------------------
# Controls (rebinding)
# --------------------------------------------------------------------------

## Fills parent with the two-column list of rebindable keys. Used here and by the
## title screen. Click a key, then press the new key (or a mouse button). ESC cancels.
func build_controls_into(parent: Control, width: float) -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null:
		return
	_ctrl_parent = parent
	_ctrl_w = width
	var list: Array = gs.REBINDABLE
	var col_w := (width - 12.0) * 0.5
	for i in list.size():
		var action: String = list[i][0]
		var col := i % 2
		var r := i / 2
		var row := UIKit.panel(parent, Vector2(col * (col_w + 12.0), r * 44.0), Vector2(col_w, 38), UIKit.box(UIKit.C_ROW, Color("3A2818"), 2, false))
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		UIKit.label(row, list[i][1], F, UIKit.C_TEXT, Vector2(12, 10))
		var chip := _flat_button(row, Vector2(col_w - 154, 5), Vector2(146, 28))
		chip.add_theme_stylebox_override("normal", UIKit.box(Color("120C08"), UIKit.C_BORDER, 2, false))
		var t := UIKit.label(chip, "", F, Color("F0E0BF"), Vector2(0, 5))
		t.name = "T"
		_set_chip(chip, gs.primary_name(action))
		chip.pressed.connect(func() -> void: _start_wait(action, chip))
	var rows := ceili(list.size() / 2.0)
	var reset := UIKit.button(parent, "RESET KEYS", Vector2(width - 190, rows * 44.0 + 8.0), false, false, 190)
	reset.pressed.connect(func() -> void:
		gs.reset_keybinds()
		_rebuild_controls(parent, width))
	var hint := UIKit.label(parent, "CLICK A KEY, THEN PRESS THE NEW KEY OR MOUSE BUTTON.  ESC CANCELS.\nHOTBAR: 1-8 / MOUSE WHEEL.   PAUSE: ESC.", 9, UIKit.C_TEXT_DIM, Vector2(0, rows * 44.0 + 14.0))
	hint.add_theme_constant_override("line_spacing", 4)
	if _note == null or not is_instance_valid(_note):
		_note = UIKit.label(parent, "", 9, UIKit.C_GOLD_LIGHT, Vector2(0, rows * 44.0 + 44.0))


func _rebuild_controls(parent: Control, width: float) -> void:
	_cancel_wait()
	for c in parent.get_children():
		c.queue_free()
	await get_tree().process_frame
	if is_instance_valid(parent):
		build_controls_into(parent, width)


func _set_chip(chip: Button, text: String) -> void:
	var t := chip.get_node("T") as Label
	UIKit.fit_label(t, text, chip.size.x - 12.0, [18, 9])
	var fs := t.get_theme_font_size("font_size")
	t.position = Vector2(roundf((chip.size.x - UIKit.text_w(text, fs)) * 0.5), 5 if fs >= 18 else 10)


func _start_wait(action: String, chip: Button) -> void:
	_cancel_wait()
	_waiting_action = action
	_waiting_chip = chip.get_node("T") as Label
	_set_chip(chip, "PRESS A KEY")
	(chip.get_node("T") as Label).add_theme_color_override("font_color", UIKit.C_GOLD_LIGHT)


func _cancel_wait() -> void:
	if _waiting_action != "" and is_instance_valid(_waiting_chip):
		var chip := _waiting_chip.get_parent() as Button
		_waiting_chip.add_theme_color_override("font_color", Color("F0E0BF"))
		_set_chip(chip, get_node("/root/GameSettings").primary_name(_waiting_action))
	_waiting_action = ""
	_waiting_chip = null


func is_waiting_for_key() -> bool:
	return _waiting_action != ""


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not is_visible_in_tree():
		return
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_wait()
			get_viewport().set_input_as_handled()
			return
		var k := InputEventKey.new()
		k.physical_keycode = (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != KEY_NONE else (event as InputEventKey).keycode
		ev = k
	elif event is InputEventMouseButton and event.pressed:
		var mb := (event as InputEventMouseButton).button_index
		if mb in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		# a left click on the chip itself just started the wait; ignore it
		if mb == MOUSE_BUTTON_LEFT and is_instance_valid(_waiting_chip) and _waiting_chip.get_parent().get_global_rect().has_point(event.global_position):
			return
		var m := InputEventMouseButton.new()
		m.button_index = mb
		ev = m
	if ev == null:
		return
	get_viewport().set_input_as_handled()
	var gs := get_node("/root/GameSettings")
	var action := _waiting_action
	var chip := _waiting_chip.get_parent() as Button
	_waiting_action = ""
	_waiting_chip = null
	var clash: String = gs.rebind(action, ev)
	(chip.get_node("T") as Label).add_theme_color_override("font_color", Color("F0E0BF"))
	if clash != "":
		if _note:
			_note.text = "%s WAS USED BY %s - THAT ONE IS NOW UNBOUND." % [gs.event_name(ev), clash]
		_rebuild_controls(_ctrl_parent, _ctrl_w)
	else:
		_set_chip(chip, gs.primary_name(action))
		if _note:
			_note.text = ""


# --------------------------------------------------------------------------
# Rows
# --------------------------------------------------------------------------

func _row(y: float, title: String) -> Panel:
	var row := UIKit.panel(_body, Vector2(0, y), Vector2(_body.size.x, ROW_H), UIKit.box(UIKit.C_ROW, Color("3A2818"), 2, false))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.label(row, title, F, UIKit.C_TEXT, Vector2(14, 14))
	return row


func _slider(y: float, title: String, key: String, value: float) -> float:
	var row := _row(y, title)
	var s := HSlider.new()
	s.position = Vector2(row.size.x - 330, 11)
	s.size = Vector2(240, 24)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	var track := UIKit.box(Color("0E0A08"), Color("574029"), 2, false)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIKit.C_GOLD
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(10, 22, false, Image.FORMAT_RGBA8)
	img.fill(UIKit.C_GOLD_LIGHT)
	var grab := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", grab)
	s.add_theme_icon_override("grabber_highlight", grab)
	row.add_child(s)
	var val := UIKit.label(row, str(int(round(value * 100))), F, Color("F6EBCF"), Vector2(row.size.x - 70, 14))
	var gs := get_node("/root/GameSettings")
	s.value_changed.connect(func(v: float) -> void:
		val.text = str(int(round(v * 100)))
		gs.set(key, v)
		gs.apply_audio())
	s.drag_ended.connect(func(_c: bool) -> void: gs.save_settings())
	return y + ROW_H + 8.0


func _seg(y: float, title: String, options: Array, current: Variant, key: String) -> float:
	var row := _row(y, title)
	var widths: Array = []
	var total := 0.0
	for o in options:
		var w := UIKit.text_w(str(o[0]), F) + 22.0
		widths.append(w)
		total += w + 4.0
	var x := row.size.x - 10.0 - total + 4.0
	for i in options.size():
		var value: Variant = options[i][1]
		var on: bool = (value == current) if typeof(value) != TYPE_FLOAT else is_equal_approx(float(value), float(current))
		var b := _flat_button(row, Vector2(x, 7), Vector2(widths[i], 32))
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.C_PANEL_HI if on else Color("0E0A08"), UIKit.C_GOLD if on else Color("574029"), 2, false))
		var txt := str(options[i][0])
		UIKit.label(b, txt, F, Color("F6EBCF") if on else Color("8A7454"), Vector2(roundf((float(widths[i]) - UIKit.text_w(txt, F)) * 0.5), 7))
		b.pressed.connect(func() -> void:
			get_node("/root/GameSettings").set_value(key, value)
			select_tab.call_deferred(tab))
		x += float(widths[i]) + 4.0
	return y + ROW_H + 8.0


func _flat_button(parent: Control, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hv := UIKit.box(UIKit.C_PANEL_HI, UIKit.C_GOLD, 2, false)
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, false))
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b
