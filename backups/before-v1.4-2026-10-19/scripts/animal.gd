extends CharacterBody2D
class_name Animal

## Relaxed wandering with smooth steering, grazing pauses and local avoidance.
@export var walk_speed: float = 25.0
@export var min_walk_time: float = 2.0
@export var max_walk_time: float = 5.0
@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0
@export var acceleration: float = 45.0
@export var roam_radius: float = 120.0
@export var personal_space: float = 24.0

var direction: Vector2 = Vector2.ZERO
var state: String = "idle"
var timer: float = 0.0
var _pace: float = 1.0
var _home: Vector2
var _home_initialized := false
var _steering_timer := 0.0
var _desired_direction := Vector2.ZERO
var _stuck_elapsed := 0.0
var _stuck_origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("animals")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.randomize()
	start_idle()

func _physics_process(delta: float) -> void:
	# SpawnManager assigns position after add_child, so capture home on first tick.
	if not _home_initialized:
		_home = global_position
		_stuck_origin = global_position
		_home_initialized = true
	timer -= delta
	if timer <= 0.0:
		if state == "idle":
			start_walking()
		else:
			start_idle()

	var desired_velocity := Vector2.ZERO
	if state == "walking":
		_steering_timer -= delta
		if _steering_timer <= 0.0:
			_steering_timer = _rng.randf_range(0.15, 0.25)
			var heading := direction
			var home_offset := _home - global_position
			if home_offset.length() > roam_radius:
				heading = heading.lerp(home_offset.normalized(), 0.65).normalized()
			heading = (heading + _separation() * 1.5).normalized()
			_desired_direction = _clear_heading(heading)
		if _desired_direction == Vector2.ZERO:
			start_idle()
		else:
			direction = Vector2.from_angle(lerp_angle(direction.angle(), _desired_direction.angle(), minf(delta * 3.0, 1.0)))
			desired_velocity = direction * walk_speed * _pace

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()
	var actual := get_real_velocity()
	if actual.length() > 2.0:
		_update_facing(actual.normalized())
		_play_anim("walk")
		animated_sprite.speed_scale = clampf(actual.length() / maxf(walk_speed, 1.0), 0.5, 1.3)
	else:
		_play_anim("idle")
	_stuck_elapsed += delta
	if _stuck_elapsed >= 0.8:
		if state == "walking" and global_position.distance_to(_stuck_origin) < 2.0:
			start_idle()
		_stuck_origin = global_position
		_stuck_elapsed = 0.0

func start_idle() -> void:
	state = "idle"
	timer = _rng.randf_range(min_idle_time, max_idle_time)
	# Physics eases velocity down; the idle pose begins once motion has stopped.
	if velocity.length() < 2.0:
		_play_anim("idle")

func start_walking() -> void:
	state = "walking"
	var angle := _rng.randf_range(-PI, PI)
	if direction != Vector2.ZERO and _rng.randf() < 0.7:
		angle = direction.angle() + _rng.randf_range(-1.0, 1.0)
	direction = Vector2.from_angle(angle)
	_pace = _rng.randf_range(0.75, 1.1)
	timer = _rng.randf_range(min_walk_time, max_walk_time)
	_steering_timer = 0.0
	_stuck_elapsed = 0.0
	_stuck_origin = global_position

func _separation() -> Vector2:
	var force := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("animals"):
		if other == self or not other is Node2D:
			continue
		var away: Vector2 = global_position - other.global_position
		var distance := away.length()
		if distance < 0.01:
			# Coincident spawns choose opposite directions, not the same escape.
			force += Vector2.LEFT if get_instance_id() < other.get_instance_id() else Vector2.RIGHT
		elif distance < personal_space:
			force += away / distance * (1.0 - distance / personal_space)
	return force.limit_length(1.0)

func _clear_heading(heading: Vector2) -> Vector2:
	if heading == Vector2.ZERO:
		return Vector2.ZERO
	var lookahead := maxf(16.0, walk_speed * 0.8)
	# Sweep the actual body so fences, rocks, water and other bodies are avoided.
	for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI * 0.75, -PI * 0.75, PI]:
		var candidate := heading.rotated(angle)
		if not test_move(global_transform, candidate * lookahead):
			return candidate
	return Vector2.ZERO

func _update_facing(dir: Vector2) -> void:
	if not animated_sprite:
		return
	# All four animal sheets face LEFT in their original artwork.
	# A dead zone prevents flip jitter during nearly vertical movement.
	if dir.x < -0.2:
		animated_sprite.flip_h = false
	elif dir.x > 0.2:
		animated_sprite.flip_h = true

func _play_anim(base_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var frames := animated_sprite.sprite_frames
	var animation_name := base_name
	if not frames.has_animation(animation_name):
		# These assets have a single species-named locomotion clip.
		animation_name = "default" if frames.has_animation("default") else String(animated_sprite.animation)
		if base_name == "idle":
			animated_sprite.stop()
			animated_sprite.frame = 0
			animated_sprite.speed_scale = 1.0
			return
	if frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
			animated_sprite.play(animation_name)
