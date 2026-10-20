extends RefCounted

## Shared look for the v1.1 in-game UI (shop, dialogue, prompts, tutorial, reports).
## Matches the title screen / pause menu: dark wood panels, gold borders, pixel font.

const PIXEL_FONT := "res://Assets/Fonts/nh_pixel_font.png"

const C_TEXT := Color("ECE2C6")
const C_TEXT_SOFT := Color("D8C9AA")
const C_TEXT_DIM := Color("A8916A")
const C_GOLD := Color("F0C266")
const C_GOLD_LIGHT := Color("FFDB80")
const C_GREEN := Color("BFE3A0")
const C_RED := Color("E8A898")
const C_PANEL := Color(0.106, 0.075, 0.055, 0.95)
const C_PANEL_HI := Color("3A2814")
const C_ROW := Color("22170F")
const C_BTN_BORDER := Color("6E4F2C")
const C_BORDER := Color("7A5730")
const C_LINE := Color("4A3420")
const C_SHADOW := Color("0A0705")

const F_SMALL := 18
const F_TINY := 9
const F_BIG := 27
const F_HEAD := 36

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(PIXEL_FONT)
	return _font


## v1.3.1: shows the whole name when it can - shrinks the font (10 -> 7) until it fits.
static func fit_label(l: Label, text: String, max_w: float, sizes: Array = [10, 9, 8, 7]) -> void:
	l.text = text
	var f := l.get_theme_font("font")
	for fs in sizes:
		l.add_theme_font_size_override("font_size", fs)
		if f == null or f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			return


static func text_w(text: String, font_size: int = F_SMALL) -> float:
	return float(text.length()) * 6.0 * float(font_size) / 9.0


static func box(bg: Color, border: Color, bw: int = 3, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = false
	if shadow:
		s.shadow_color = Color(C_SHADOW, 0.9)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 4)
	return s


static func label(parent: Node, text: String, font_size: int, color: Color, pos: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	if parent:
		parent.add_child(l)
	return l


static func wrap_label(parent: Node, text: String, font_size: int, color: Color, pos: Vector2, width: float) -> Label:
	var l := label(null, "", font_size, color, pos)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 10)
	l.text = text
	if parent:
		parent.add_child(l)
	return l


static func panel(parent: Node, pos: Vector2, sz: Vector2, style: StyleBox = null) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", style if style else box(C_PANEL, C_BORDER))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if parent:
		parent.add_child(p)
	return p


static func button(parent: Node, text: String, pos: Vector2, primary: bool = false, danger: bool = false, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.position = pos
	var w := maxf(min_w, text_w(text) + 36.0)
	b.size = Vector2(w, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border := C_GOLD if primary else (Color("7A3A2E") if danger else C_BTN_BORDER)
	b.add_theme_stylebox_override("normal", box(C_PANEL_HI if primary else C_ROW, border, 3, true))
	var hv := box(C_PANEL_HI, C_GOLD_LIGHT if primary else C_GOLD, 3, true)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", box(Color(0.07, 0.05, 0.03, 0.8), Color("3A2818"), 3, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if parent:
		parent.add_child(b)
	var col := C_GOLD_LIGHT if primary else (C_RED if danger else C_TEXT)
	var l := label(b, text, F_SMALL, col, Vector2(roundf((w - text_w(text)) * 0.5), 13))
	l.name = "Text"
	return b


static func set_button_text(b: Button, text: String) -> void:
	var l := b.get_node_or_null("Text") as Label
	if l:
		l.text = text
		l.position.x = roundf((b.size.x - text_w(text)) * 0.5)


static func tex(parent: Node, t: Texture2D, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = sz
	if parent:
		parent.add_child(r)
	return r


static func color_rect(parent: Node, c: Color, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(r)
	return r


## Fixed-size design canvas centred in the window and scaled to fit (like the menus).
class Stage extends Control:
	var design := Vector2(1152, 648)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = design
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _fit() -> void:
		var vs := get_viewport_rect().size
		var k := minf(vs.x / design.x, vs.y / design.y)
		scale = Vector2(k, k)
		position = ((vs - design * k) * 0.5).floor()


static func stage(layer: CanvasLayer, w: float = 1152.0, h: float = 648.0) -> Control:
	var s := Stage.new()
	s.design = Vector2(w, h)
	s.size = s.design
	layer.add_child(s)
	return s


static func atlas(t: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = region
	return a
