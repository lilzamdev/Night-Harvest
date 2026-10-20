extends Node2D
class_name SwooshEffect

@export var base_offset_distance: float = 8.0

var is_active: bool = false
var current_direction: Vector2 = Vector2.RIGHT
var arc_progress: float = 0.0
var swoosh_duration: float = 0.13
var current_color: Color = Color.WHITE
var current_scale: Vector2 = Vector2.ONE
var _elapsed: float = 0.0


func _ready() -> void:
	visible = false
	# Stay at z 0 so the swoosh is depth-sorted with Ken (it is his last child,
	# so it still draws over his sprite and held item).
	z_index = 0


func play_swoosh(dir: Vector2, p_scale: Vector2 = Vector2.ONE, p_color: Color = Color.WHITE, duration: float = 0.13) -> void:
	if dir == Vector2.ZERO:
		current_direction = Vector2.RIGHT
	else:
		current_direction = dir.normalized()
	
	current_scale = p_scale
	current_color = p_color
	swoosh_duration = max(0.08, duration)
	_elapsed = 0.0
	arc_progress = 0.0
	is_active = true
	visible = true
	
	# Position in front of player
	position = _get_directional_offset(current_direction)
	
	# Rotation and Scale (Uses horizontal flip for Left so slash always starts from TOP)
	rotation = _get_directional_rotation(current_direction)
	scale = _get_directional_scale(current_direction, current_scale)
	
	queue_redraw()


func stop_swoosh() -> void:
	is_active = false
	visible = false
	arc_progress = 0.0


func _get_directional_offset(dir: Vector2) -> Vector2:
	if dir == Vector2.RIGHT:
		return Vector2(10.0, 2.0)
	elif dir == Vector2.LEFT:
		return Vector2(-10.0, 2.0)
	elif dir == Vector2.UP:
		return Vector2(0.0, -12.0)
	return Vector2(0.0, 12.0) # DOWN


func _get_directional_rotation(dir: Vector2) -> float:
	if dir == Vector2.RIGHT:
		return 0.0
	elif dir == Vector2.LEFT:
		return 0.0 # Handled by X-flip so slash starts from top
	elif dir == Vector2.UP:
		return -PI * 0.5
	return PI * 0.5 # DOWN


func _get_directional_scale(dir: Vector2, base_scale: Vector2) -> Vector2:
	if dir == Vector2.LEFT:
		return Vector2(-absf(base_scale.x), absf(base_scale.y))
	return Vector2(absf(base_scale.x), absf(base_scale.y))


func _process(delta: float) -> void:
	if not is_active:
		return
	
	_elapsed += delta
	arc_progress = clampf(_elapsed / swoosh_duration, 0.0, 1.0)
	
	if arc_progress >= 1.0:
		stop_swoosh()
	else:
		queue_redraw()


func _draw() -> void:
	if not is_active or arc_progress >= 1.0:
		return
	
	# Reference-accurate bold, chunky pixel-art crescent slash
	var alpha: float = 1.0
	if arc_progress > 0.55:
		alpha = clampf(1.0 - ((arc_progress - 0.55) / 0.45), 0.0, 1.0)
	
	var main_col: Color = Color(current_color.r, current_color.g, current_color.b, alpha * current_color.a)
	var core_col: Color = Color(1.0, 1.0, 1.0, alpha * 0.98)
	
	var radius: float = 18.0 * absf(current_scale.x)
	var max_sweep: float = deg_to_rad(120.0)
	
	# Head swings from top-back to bottom-front
	var start_angle: float = -deg_to_rad(65.0)
	var sweep_angle: float = max_sweep * clampf(arc_progress * 1.8, 0.2, 1.0)
	
	var segments: int = 16
	var outer_points: PackedVector2Array = PackedVector2Array()
	var inner_points: PackedVector2Array = PackedVector2Array()
	
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = start_angle + (t * sweep_angle)
		
		# Thick profile formula: thick apex (6.5px), tapering to slim tips
		var thickness: float = 0.0
		if t > 0.7:
			thickness = lerpf(6.5, 0.5, (t - 0.7) / 0.3)
		elif t > 0.2:
			thickness = lerpf(2.5, 6.5, (t - 0.2) / 0.5)
		else:
			thickness = lerpf(0.5, 2.5, t / 0.2)
		
		thickness *= absf(current_scale.y)
		
		var outer_r: float = radius + (thickness * 0.5)
		var inner_r: float = maxf(2.0, radius - (thickness * 0.5))
		
		outer_points.push_back(Vector2(cos(angle), sin(angle)) * outer_r)
		inner_points.push_back(Vector2(cos(angle), sin(angle)) * inner_r)
	
	# Construct filled crescent polygon
	var poly: PackedVector2Array = PackedVector2Array()
	for pt in outer_points:
		poly.push_back(pt)
	for i in range(inner_points.size() - 1, -1, -1):
		poly.push_back(inner_points[i])
	
	if poly.size() >= 3:
		draw_colored_polygon(poly, main_col)
	
	# Solid white bright highlight along inner curve
	if outer_points.size() >= 4 and arc_progress < 0.85:
		var core_poly: PackedVector2Array = PackedVector2Array()
		var start_idx: int = int(segments * 0.35)
		var end_idx: int = int(segments * 0.9)
		for i in range(start_idx, end_idx):
			core_poly.push_back(outer_points[i] * 0.96)
		for i in range(end_idx - 1, start_idx - 1, -1):
			core_poly.push_back(inner_points[i] * 1.04)
		if core_poly.size() >= 3:
			draw_colored_polygon(core_poly, core_col)
	
	# Trailing pixel dots / particle sparks (like in reference image)
	if arc_progress > 0.15:
		var spark_col: Color = Color(current_color.r, current_color.g, current_color.b, alpha * 0.9)
		var tail_angle: float = start_angle
		
		var p1: Vector2 = Vector2(cos(tail_angle - 0.12), sin(tail_angle - 0.12)) * (radius - 1.0)
		var p2: Vector2 = Vector2(cos(tail_angle - 0.24), sin(tail_angle - 0.24)) * (radius - 3.0)
		var p3: Vector2 = Vector2(cos(tail_angle - 0.36), sin(tail_angle - 0.36)) * (radius - 5.0)
		var p4: Vector2 = Vector2(cos(tail_angle - 0.48), sin(tail_angle - 0.48)) * (radius - 7.0)
		
		draw_rect(Rect2(p1.x - 1.0, p1.y - 1.0, 2.0, 2.0), spark_col)
		draw_rect(Rect2(p2.x - 1.0, p2.y - 1.0, 2.0, 2.0), spark_col)
		draw_rect(Rect2(p3.x - 0.75, p3.y - 0.75, 1.5, 1.5), spark_col)
		draw_rect(Rect2(p4.x - 0.5, p4.y - 0.5, 1.0, 1.0), spark_col)
