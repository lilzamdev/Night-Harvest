extends Control
class_name PauseMenuUI

## Pause menu (ESC in game), styled like the title screen: dark wood panel,
## gold borders, the pixel font and the title-menu icons.
## Built in code; Scenes/UI/menu.tscn only holds the root node.
##
## Main view:     Resume · Save Game · Settings · Save & Quit to Title · Save & Quit Game
## Settings view: volumes, screen mode and graphics preset (same values as the title Settings).

signal opened
signal closed

const TITLE_SCENE := "res://Scenes/UI/main_menu.tscn"
const PIXEL_FONT := "res://Assets/Fonts/nh_pixel_font.png"
const ICONS := "res://Assets/UI/MainMenu/menu_icons.png"

const C_TEXT := Color("ECE2C6")
const C_TEXT_SOFT := Color("D8C9AA")
const C_TEXT_DIM := Color("A8916A")
const C_GOLD := Color("F0C266")
const C_GOLD_LIGHT := Color("FFDB80")
const C_PANEL := Color(0.106, 0.075, 0.055, 0.95)
const C_PANEL_HI := Color("3A2814")
const C_ROW := Color("22170F")
const C_BTN_BORDER := Color("6E4F2C")
const C_BORDER := Color("7A5730")
const C_LINE := Color("4A3420")
const C_SHADOW := Color("0A0705")
const C_DANGER := Color("E8A898")

## Pixel font cell is 9 px tall; sizes are whole multiples so text stays crisp.
const F_SMALL := 18
const F_HEAD := 36

const PW := 440.0
const PAD := 24.0
const BTN_W := PW - PAD * 2.0
const BTN_H := 52.0

@export var is_open: bool = false

var _font: Font
var _icons: Texture2D
var _dim: ColorRect
var _panel: Panel
var _main_view: Control
var _settings_view: Control
var _view: String = "main"
var _buttons: Array[Button] = []
var _save_button: Button
var _farm_label: Label
var _status_label: Label
var _tween: Tween


func _ready() -> void:
	add_to_group("menu_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(PIXEL_FONT)
	_icons = load(ICONS)
	var th := Theme.new()
	th.default_font = _font
	th.default_font_size = F_SMALL
	theme = th

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.016, 0.04, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_BORDER, 3, true))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_build_main_view()
	_settings_view = Control.new()
	_settings_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_settings_view)

	resized.connect(_layout)
	visible = is_open
	_show_view("main")


# ==========================================================================
# Open / close
# ==========================================================================

func _unhandled_input(event: InputEvent) -> void:
	var esc: bool = event.is_action_pressed("toggle_menu") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
	if esc:
		if is_open and _view == "settings":
			_show_view("main")
		else:
			toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open or _view != "main":
		return
	if event.is_action_pressed("move_down"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	# Something else (death screen, sleep) already paused the game.
	if get_tree() and get_tree().paused:
		return
	is_open = true
	visible = true
	if get_tree():
		get_tree().paused = true
	_show_view("main")
	_refresh_status()
	_buttons[0].grab_focus()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var target_y := _panel.position.y
	_panel.position.y = target_y + 12.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_panel, "position:y", target_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	if _view == "settings" and has_node("/root/GameSettings"):
		GameSettings.save_settings()
	is_open = false
	visible = false
	if get_tree():
		get_tree().paused = false
	closed.emit()


func _show_view(v: String) -> void:
	_view = v
	_main_view.visible = v == "main"
	_settings_view.visible = v == "settings"
	if v == "settings":
		if has_node("/root/GameSettings"):
			GameSettings.refresh_fullscreen_state()
		_build_settings_view()
	else:
		_panel.size = Vector2(PW, _main_view.size.y)
		if is_open and _buttons.size() > 2:
			_buttons[2].grab_focus()  # back on SETTINGS
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	_panel.position = ((size - _panel.size) * 0.5).floor()


# ==========================================================================
# Main view
# ==========================================================================

func _build_main_view() -> void:
	_main_view = Control.new()
	_main_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_main_view)
	_header(_main_view, "PAUSED")
	_farm_label = _label(_main_view, "", F_SMALL, C_GOLD, Vector2(PAD, 70))
	_status_label = _label(_main_view, "", F_SMALL, C_TEXT_DIM, Vector2(PAD, 94))
	_color_rect(_main_view, C_LINE, Vector2(PAD, 124), Vector2(BTN_W, 3))

	var entries := [
		["RESUME", 0, "resume"],
		["SAVE GAME", 2, "save"],
		["SETTINGS", 3, "settings"],
		["SAVE & QUIT TO TITLE", 4, "title"],
		["SAVE & QUIT GAME", 4, "quit"],
	]
	var y := 140.0
	for e in entries:
		var b := _menu_button(_main_view, e[0], e[1], Vector2(PAD, y), e[2] == "quit")
		var action: String = e[2]
		b.pressed.connect(func() -> void: _on_action(action))
		if action == "save":
			_save_button = b
		_buttons.append(b)
		y += BTN_H + 8.0
	_main_view.size = Vector2(PW, y - 8.0 + PAD)


func _on_action(action: String) -> void:
	match action:
		"resume":
			close()
		"save":
			_save_now()
		"settings":
			_show_view("settings")
		"title":
			_save_quietly()
			is_open = false
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)
		"quit":
			_save_quietly()
			get_tree().quit()


func _has_save_slot() -> bool:
	var sm := get_node_or_null("/root/SaveManager")
	return sm != null and int(sm.get("active_slot")) >= 0


func _save_now() -> void:
	if not _has_save_slot():
		return
	if SaveManager.save_game(true):
		_refresh_status()
	else:
		_status_label.text = "COULD NOT SAVE RIGHT NOW"


func _save_quietly() -> void:
	if _has_save_slot():
		SaveManager.save_game(false)


## Farm name / day / difficulty line and "saved X ago" line.
func _refresh_status() -> void:
	var can_save := _has_save_slot()
	_set_enabled(_save_button, can_save)
	if not can_save:
		_farm_label.text = "PRACTICE RUN"
		_status_label.text = "NOT SAVING · NO SAVE SLOT"
		return
	var info: Dictionary = SaveManager.active_info
	var day := int(info.get("day", 1))
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock:
		day = int(clock.get("current_day"))
	var diff: Dictionary = SaveManager.DIFFICULTIES.get(str(info.get("difficulty", "normal")), SaveManager.DIFFICULTIES["normal"])
	var line := "%s · DAY %d · %s" % [str(info.get("farm_name", "FARM")).to_upper(), day, diff["label"]]
	_farm_label.text = _fit(line)
	_status_label.text = _saved_ago(float(info.get("saved_at", 0)))


func _saved_ago(t: float) -> String:
	if t <= 0.0:
		return "NOT SAVED YET"
	var secs := int(Time.get_unix_time_from_system() - t)
	if secs < 60:
		return "SAVED JUST NOW"
	var mins := secs / 60
	if mins < 60:
		return "SAVED %d MIN AGO" % mins
	return "SAVED %d H AGO" % (mins / 60)


func _move_focus(step: int) -> void:
	var enabled: Array[Button] = []
	for b in _buttons:
		if not b.disabled:
			enabled.append(b)
	if enabled.is_empty():
		return
	var cur := enabled.find(get_viewport().gui_get_focus_owner())
	var next := 0 if cur == -1 else (cur + step + enabled.size()) % enabled.size()
	enabled[next].grab_focus()


# ==========================================================================
# Settings view
# ==========================================================================

func _build_settings_view() -> void:
	for c in _settings_view.get_children():
		c.queue_free()
	_header(_settings_view, "SETTINGS")
	_color_rect(_settings_view, C_LINE, Vector2(PAD, 78), Vector2(BTN_W, 3))
	var y := 94.0
	if has_node("/root/GameSettings"):
		var gs := GameSettings
		y = _slider_row(y, "MASTER", "master_volume", gs.master_volume)
		y = _slider_row(y, "MUSIC", "music_volume", gs.music_volume)
		y = _slider_row(y, "EFFECTS", "sfx_volume", gs.sfx_volume)
		y = _seg_row(y, "SCREEN", [["WINDOWED", false], ["FULLSCREEN", true]], gs.fullscreen, "fullscreen")
		y = _seg_row(y, "GRAPHICS", [["LOW", "low"], ["MEDIUM", "medium"], ["HIGH", "high"]], gs.quality, "quality")
	var back := _menu_button(_settings_view, "‹ BACK", -1, Vector2(PAD, y + 8.0), false)
	back.pressed.connect(func() -> void: _show_view("main"))
	var h := y + 8.0 + BTN_H + PAD
	_settings_view.size = Vector2(PW, h)
	_panel.size = Vector2(PW, h)
	_layout()
	if is_open:
		back.grab_focus()


func _row(y: float, title: String) -> Panel:
	var row := _panel_box(_settings_view, Vector2(PAD, y), Vector2(BTN_W, BTN_H), _box(C_ROW, Color("3A2818"), 2, false))
	_label(row, title, F_SMALL, C_TEXT, Vector2(14, 17))
	return row


func _slider_row(y: float, title: String, key: String, value: float) -> float:
	var row := _row(y, title)
	var s := HSlider.new()
	s.position = Vector2(150, 14)
	s.size = Vector2(170, 24)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	var track := _box(Color("0E0A08"), Color("574029"), 2, false)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOLD
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grab := _solid_texture(Vector2i(10, 22), C_GOLD_LIGHT)
	s.add_theme_icon_override("grabber", grab)
	s.add_theme_icon_override("grabber_highlight", grab)
	row.add_child(s)
	var val := _label(row, str(int(round(value * 100))), F_SMALL, Color("F6EBCF"), Vector2(334, 17))
	s.value_changed.connect(func(v: float) -> void:
		val.text = str(int(round(v * 100)))
		GameSettings.set(key, v)
		GameSettings.apply_audio())
	s.drag_ended.connect(func(_changed: bool) -> void: GameSettings.save_settings())
	return y + BTN_H + 8.0


## options: [[label, value], ...]; pressing one calls GameSettings.set_value(key, value).
func _seg_row(y: float, title: String, options: Array, current: Variant, key: String) -> float:
	var row := _row(y, title)
	var widths: Array = []
	var total := 0.0
	for o in options:
		var w := _text_w(str(o[0])) + 20.0
		widths.append(w)
		total += w + 4.0
	var x := BTN_W - 10.0 - total + 4.0
	for i in options.size():
		var value: Variant = options[i][1]
		var on: bool = value == current
		var b := Button.new()
		b.position = Vector2(x, 10)
		b.size = Vector2(widths[i], 32)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var st := _box(C_PANEL_HI if on else Color("0E0A08"), C_GOLD if on else Color("574029"), 2, false)
		var hv := _box(C_PANEL_HI, C_GOLD, 2, false)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.add_child(b)
		var label_text := str(options[i][0])
		_label(b, label_text, F_SMALL, Color("F6EBCF") if on else Color("8A7454"), Vector2(roundf((float(widths[i]) - _text_w(label_text)) * 0.5), 7))
		b.pressed.connect(func() -> void:
			GameSettings.set_value(key, value)
			_build_settings_view.call_deferred())
		x += float(widths[i]) + 4.0
	return y + BTN_H + 8.0


# ==========================================================================
# Builders
# ==========================================================================

func _header(parent: Control, title: String) -> void:
	_label(parent, title, F_HEAD, C_TEXT, Vector2(PAD, 22))
	var chip_w := _text_w("ESC") + 20.0
	var chip := _panel_box(parent, Vector2(PW - PAD - chip_w, 26), Vector2(chip_w, 30), _box(Color("120C08"), C_BORDER, 2, false))
	_label(chip, "ESC", F_SMALL, Color("F0E0BF"), Vector2(10, 6))


## Title-menu style button: icon slot on the left, label, and an arrow when selected.
## icon = -1 for a text-only button.
func _menu_button(parent: Control, text: String, icon: int, pos: Vector2, danger: bool) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(BTN_W, BTN_H)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	var text_x := 18.0
	if icon >= 0:
		var slot := _panel_box(b, Vector2(6, 6), Vector2(40, 40), _box(Color("120C08"), Color("574029"), 2, false))
		var ic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = _icons
		at.region = Rect2(icon * 16, 0, 16, 16)
		ic.texture = at
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(4, 4)
		ic.size = Vector2(32, 32)
		slot.add_child(ic)
		b.set_meta("slot", slot)
		text_x = 60.0
	var lb := _label(b, text, F_SMALL, C_DANGER if danger else C_TEXT, Vector2(text_x, 17))
	var arrow := _label(b, "›", F_SMALL, C_GOLD_LIGHT, Vector2(BTN_W - 28.0, 17))
	b.set_meta("label", lb)
	b.set_meta("arrow", arrow)
	b.set_meta("danger", danger)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: _style_button(b, true))
	b.focus_exited.connect(func() -> void: _style_button(b, false))
	_style_button(b, false)
	return b


func _style_button(b: Button, selected: bool) -> void:
	var st := _box(C_PANEL_HI, C_GOLD, 3, true) if selected else _box(C_ROW, C_BTN_BORDER, 3, true)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if b.has_meta("slot"):
		(b.get_meta("slot") as Panel).add_theme_stylebox_override("panel", _box(Color("120C08"), C_GOLD if selected else Color("574029"), 2, false))
	var danger: bool = b.get_meta("danger")
	var col := C_GOLD_LIGHT if selected else (C_DANGER if danger else C_TEXT)
	(b.get_meta("label") as Label).add_theme_color_override("font_color", col)
	(b.get_meta("arrow") as Label).visible = selected


func _set_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	b.modulate.a = 1.0 if on else 0.45
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW


func _fit(text: String, max_chars: int = 32) -> String:
	return text if text.length() <= max_chars else text.left(max_chars)


func _text_w(text: String, font_size: int = F_SMALL) -> float:
	return float(text.length()) * 6.0 * float(font_size) / 9.0


func _label(parent: Control, text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	parent.add_child(l)
	return l


func _box(bg: Color, border: Color, bw: int, shadow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = false
	if shadow:
		s.shadow_color = Color(C_SHADOW, 0.9)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 5)
	return s


func _panel_box(parent: Control, pos: Vector2, sz: Vector2, style: StyleBox) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _color_rect(parent: Control, c: Color, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _solid_texture(sz: Vector2i, c: Color) -> ImageTexture:
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
