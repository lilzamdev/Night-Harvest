extends Area2D
class_name TorchEntity

@export var item_id: String = "torch"
@export var amount: int = 1

# ============================================================
# TORCH LIGHT SETTINGS
# ============================================================
@export var torch_light_scale: float = 0.5
@export var torch_light_energy: float = 1.5

var item_data: Resource = null
var _base_energy: float = 1.0
var _flicker_time: float = 0.0
var _game_clock: Node = null


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("world_items")
	add_to_group("torches")

	# ------------------------------------------------------------
	# TORCH LIGHT
	# ------------------------------------------------------------
	if point_light:
		point_light.enabled = true
		point_light.texture_scale = torch_light_scale
		point_light.energy = torch_light_energy
		_base_energy = torch_light_energy

	# ------------------------------------------------------------
	# LOAD ITEM DATA
	# ------------------------------------------------------------
	var db = load("res://scripts/item_database.gd")

	if db and db.has_method("get_item"):
		item_data = db.get_item(item_id)

	# ------------------------------------------------------------
	# FLAME ANIMATION
	# ------------------------------------------------------------
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("flicker"):
			animated_sprite.play("flicker")

	# ------------------------------------------------------------
	# CONNECT GAME CLOCK
	# ------------------------------------------------------------
	call_deferred("_connect_game_clock")


func _connect_game_clock() -> void:
	var clock_nodes := get_tree().get_nodes_in_group("game_clock")

	for c in clock_nodes:
		if is_instance_valid(c):
			_game_clock = c
			break

	if _game_clock:
		if _game_clock.has_signal("time_updated"):
			if not _game_clock.time_updated.is_connected(_on_time_updated):
				_game_clock.time_updated.connect(_on_time_updated)

		_update_lighting_state(_game_clock.is_night())
	else:
		_update_lighting_state(true)


func _process(delta: float) -> void:
	if not point_light:
		return

	# ------------------------------------------------------------
	# ALWAYS USE THE SAME TORCH LIGHT SCALE
	# ------------------------------------------------------------
	point_light.texture_scale = torch_light_scale

	# ------------------------------------------------------------
	# NATURAL FLAME FLICKER
	# ------------------------------------------------------------
	if point_light.enabled:
		_flicker_time += delta * 7.0

		var flicker := (
			sin(_flicker_time) * 0.06 +
			sin(_flicker_time * 2.3) * 0.04
		)

		point_light.energy = _base_energy + flicker


func _on_time_updated(_hour: int, _minute: int) -> void:
	if _game_clock:
		_update_lighting_state(_game_clock.is_night())


func _update_lighting_state(is_night_time: bool) -> void:
	if not point_light:
		return

	point_light.enabled = true

	if is_night_time:
		_base_energy = torch_light_energy
	else:
		_base_energy = torch_light_energy * 0.25

	point_light.energy = _base_energy
