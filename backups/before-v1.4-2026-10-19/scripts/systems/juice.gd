extends Node2D

## Juice (v1.2) — the "physics" and game feel layer.
##
##   shake(strength, time)    camera shake
##   hitstop(seconds)         a tiny freeze frame on heavy hits
##   popup_text(pos, text)    floating damage numbers / labels
##   burst(pos, color, n)     debris: wood chips, stone dust, zombie goo, sparks
##   bolt(pos)                lightning strike
## Also kicks up dust behind the player while running.

const FONT := "res://Assets/Fonts/nh_pixel_font.png"

var _shake := 0.0
var _shake_time := 0.0
var _shake_total := 0.0
var _hitstop_until := 0
var _font: Font
var _dust_t := 0.0
var _rng := RandomNumberGenerator.new()
var _pixel: ImageTexture


func _ready() -> void:
	add_to_group("juice")
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 60
	_rng.randomize()
	_font = load(FONT)
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(img)


func _quality() -> float:
	if has_node("/root/GameSettings"):
		return float(get_node("/root/GameSettings").preset()["particles"])
	return 1.0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _camera() -> Camera2D:
	var p := _player()
	return p.get_node_or_null("Camera2D") as Camera2D if p else null


# ==========================================================================
# Camera shake & hit-stop
# ==========================================================================

func shake(strength: float, duration: float = 0.2) -> void:
	if strength > _shake:
		_shake = strength
	_shake_time = maxf(_shake_time, duration)
	_shake_total = maxf(_shake_total, duration)


func hitstop(seconds: float = 0.045) -> void:
	if get_tree().paused:
		return
	_hitstop_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	Engine.time_scale = 0.08


func _process(delta: float) -> void:
	# delta is scaled by time_scale; use real time for hitstop/shake
	var real := get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0
	var cam := _camera()
	var p := _player()
	if cam and _shake_time > 0.0 and not bool(p.get("is_panning_camera")):
		_shake_time -= real
		var k := clampf(_shake_time / maxf(_shake_total, 0.001), 0.0, 1.0)
		var amp := _shake * k
		cam.offset = Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)).round()
		if _shake_time <= 0.0:
			_shake = 0.0
			_shake_total = 0.0
	_running_dust(real, p)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ==========================================================================
# Popups
# ==========================================================================

func popup_text(pos: Vector2, text: String, color: Color = Color.WHITE, big: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 27 if big else 18)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1E1209"))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(240, 40)
	l.pivot_offset = Vector2(120, 20)
	l.scale = Vector2.ONE / 3.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	l.global_position = pos - Vector2(120, 20) + Vector2(_rng.randf_range(-4, 4), 0)
	var tw := l.create_tween()
	var up := l.position + Vector2(0, -16)
	tw.tween_property(l, "scale", Vector2.ONE / 3.0 * 1.35, 0.06)
	tw.tween_property(l, "scale", Vector2.ONE / 3.0, 0.1)
	tw.parallel().tween_property(l, "position", up, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func damage_number(pos: Vector2, amount: int, crit: bool = false) -> void:
	popup_text(pos + Vector2(0, -18), str(amount), Color("FFDB80") if crit else Color("F6EBCF"), crit)


# ==========================================================================
# Particles
# ==========================================================================

## Physical debris: pieces fly out, fall under gravity, bounce once and fade.
func burst(pos: Vector2, color: Color, count: int = 8, speed: float = 70.0, size: float = 1.0, up: float = 1.0) -> void:
	var q := _quality()
	if q <= 0.0:
		return
	var p := CPUParticles2D.new()
	p.texture = _pixel
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(2, int(count * q))
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = speed * 0.5 * up
	p.initial_velocity_max = speed * up
	p.scale_amount_min = 1.0 * size
	p.scale_amount_max = 2.0 * size
	p.color = color
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	p.color_ramp = ramp
	p.z_index = 5
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


func dust(pos: Vector2, count: int = 4) -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("play_fx") and count <= 2:
		lw.play_fx(pos, "dust", 6, 6, 3, 14.0)
		return
	burst(pos, Color(0.85, 0.78, 0.62, 0.8), count, 25.0, 1.2, 0.4)


func _running_dust(real_delta: float, p: Node2D) -> void:
	if p == null or _quality() <= 0.0:
		return
	var v: Vector2 = p.get("velocity") if "velocity" in p else Vector2.ZERO
	if v.length() < 170.0:
		_dust_t = 0.0
		return
	_dust_t -= real_delta
	if _dust_t <= 0.0:
		_dust_t = 0.16
		dust(p.global_position + Vector2(_rng.randf_range(-3, 3), 1), 1)


func bolt(target: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.9, 0.97, 1.0)
	var pts := PackedVector2Array()
	var top := target + Vector2(_rng.randf_range(-30, 30), -220)
	var steps := 9
	for i in steps + 1:
		var k := float(i) / float(steps)
		var pnt := top.lerp(target, k)
		if i > 0 and i < steps:
			pnt.x += _rng.randf_range(-10, 10)
		pts.append(pnt)
	line.points = pts
	line.z_index = 80
	add_child(line)
	var glow := line.duplicate() as Line2D
	glow.width = 6.0
	glow.default_color = Color(0.6, 0.8, 1.0, 0.35)
	add_child(glow)
	for l in [line, glow]:
		var tw := (l as Line2D).create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback((l as Line2D).queue_free)
	burst(target, Color(0.85, 0.95, 1.0), 14, 120.0)
	shake(3.0, 0.3)
