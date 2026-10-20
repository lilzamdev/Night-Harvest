extends Area2D
class_name WorldItem

const ItemDataClass = preload("res://scripts/item_data.gd")

@export var item_data: Resource
@export var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _base_y: float = 0.0
var _time: float = 0.0
## v1.2 physics: items pop out in an arc, bounce, then get pulled to the player.
var dropped_by_player := false
var _age := 0.0
var _hop := 0.0          # current height above the ground
var _hop_v := 0.0        # vertical speed (up is positive)
var _slide := Vector2.ZERO
var _bounces := 0
var _armed := true       # player-dropped items wait until the player walks away
var _collecting := false


func _ready() -> void:
	add_to_group("world_items")
	if sprite:
		_base_y = sprite.position.y
	_update_visuals()
	if dropped_by_player:
		_armed = false
	else:
		pop()


## Throws the item up with a little sideways slide (called on spawn).
func pop(strength: float = 1.0) -> void:
	_hop = 0.0
	_hop_v = randf_range(70.0, 105.0) * strength
	_slide = Vector2(randf_range(-28.0, 28.0), randf_range(-8.0, 10.0)) * strength
	_bounces = 0


func _process(delta: float) -> void:
	_age += delta
	_time += delta * 4.0
	# Arc + bounce
	if _hop_v != 0.0 or _hop > 0.0:
		_hop_v -= 420.0 * delta
		_hop += _hop_v * delta
		global_position += _slide * delta
		if _hop <= 0.0:
			_hop = 0.0
			_bounces += 1
			_slide *= 0.45
			if _bounces < 3 and absf(_hop_v) > 30.0:
				_hop_v = -_hop_v * 0.38
			else:
				_hop_v = 0.0
				_slide = Vector2.ZERO
	if sprite:
		var bob := sin(_time) * 2.0 if _hop_v == 0.0 and _hop <= 0.0 else 0.0
		sprite.position.y = _base_y - _hop + bob
	_magnet(delta)


func _magnet(delta: float) -> void:
	if _collecting or _age < 0.45 or not is_inside_tree():
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or bool(p.get("_is_dead")):
		return
	var d := global_position.distance_to(p.global_position)
	if not _armed:
		if d > 30.0:
			_armed = true
		return
	if d < 42.0:
		# v1.4.2: a full inventory leaves the drop lying where it is
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		if inv and inv.has_method("has_room_for") and not inv.has_room_for(item_data):
			return
		var pull := clampf(1.0 - d / 42.0, 0.15, 1.0)
		global_position = global_position.move_toward(p.global_position, (60.0 + 260.0 * pull) * delta)
		if d < 7.0:
			_collect(p)


func _collect(p: Node2D) -> void:
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if inv == null or not inv.has_method("add_item") or item_data == null:
		return
	var leftover: int = inv.add_item(item_data, amount)
	if leftover == amount:
		_armed = false  # inventory full: stop pulling until the player walks away
		return
	_collecting = true
	if leftover > 0:
		amount = leftover
		_collecting = false
		_armed = false
		return
	var id: String = str(item_data.get("item_id"))
	if p.has_method("_notify_event_bus"):
		p.call("_notify_event_bus", "item_collected", [id])
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("xp_gain", -18.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice and amount > 1:
		juice.popup_text(p.global_position + Vector2(0, -24), "+%d" % amount, Color("C8F0A0"))
	queue_free()


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
