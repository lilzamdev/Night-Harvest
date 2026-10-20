extends Node2D

## Crossbow bolt fired by a scarecrow turret. Homes in on its target.

var target: Node2D = null
var damage: int = 16
var speed: float = 260.0
var _life: float = 1.2
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://Assets/Generated/bolt.png")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(target) or target.get("is_dead"):
		queue_free()
		return
	var aim := target.global_position + Vector2(0, -4)
	var to := aim - global_position
	if to.length() < 6.0:
		target.take_damage(damage, to.normalized(), 25.0)
		queue_free()
		return
	var step := to.normalized() * speed * delta
	global_position += step
	rotation = to.angle()
