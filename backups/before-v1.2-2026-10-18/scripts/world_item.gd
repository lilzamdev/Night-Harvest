extends Area2D
class_name WorldItem

const ItemDataClass = preload("res://scripts/item_data.gd")

@export var item_data: Resource
@export var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("world_items")
	if sprite:
		_base_y = sprite.position.y
	_update_visuals()


func _process(delta: float) -> void:
	_time += delta * 4.0
	if sprite:
		sprite.position.y = _base_y + sin(_time) * 2.0


func set_item(data: Resource, count: int = 1) -> void:
	item_data = data
	amount = count
	_update_visuals()


func _update_visuals() -> void:
	if not sprite:
		return
	if item_data and item_data.get("icon"):
		sprite.texture = item_data.get("icon")
		sprite.visible = true
	else:
		sprite.texture = null
		sprite.visible = false
