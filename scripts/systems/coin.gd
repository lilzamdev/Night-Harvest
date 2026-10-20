extends Node2D

## Gold coin dropped by zombies. Pops out, settles, then flies to the player.

var value: int = 1
var _vel := Vector2.ZERO
var _z := 0.0
var _vz := 0.0
var _age := 0.0
var _sprite: Sprite2D
var _frame_t := 0.0
var _frame := 0
var _shadow: Sprite2D


func _ready() -> void:
	z_index = 4
	_shadow = Sprite2D.new()
	var img := Image.create(6, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.35))
	_shadow.texture = ImageTexture.create_from_image(img)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas(0)
	add_child(_sprite)


func _atlas(i: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load("res://Assets/Generated/coin.png")
	a.region = Rect2(i * 8, 0, 8, 8)
	return a


func launch(v: Vector2) -> void:
	_vel = v
	_vz = randf_range(60.0, 90.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_frame_t -= delta
	if _frame_t <= 0.0:
		_frame_t = 0.09
		_frame = (_frame + 1) % 4
		_sprite.texture = _atlas(_frame)
	# Hop
	_vz -= 260.0 * delta
	_z = maxf(0.0, _z + _vz * delta)
	if _z <= 0.0 and _vz < 0.0:
		_vz = -_vz * 0.35 if absf(_vz) > 25.0 else 0.0
	_vel = _vel.move_toward(Vector2.ZERO, 70.0 * delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and _age > 0.45:
		var to := player.global_position - global_position
		var d := to.length()
		if d < 70.0:
			_vel = to.normalized() * lerpf(220.0, 90.0, d / 70.0)
		if d < 8.0:
			_collect()
			return
	global_position += _vel * delta
	_sprite.position = Vector2(0, -4 - _z)
	_shadow.position = Vector2(0, 0)
	if _age > 40.0:
		queue_free()


func _collect() -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_gold(value)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("coin", -10.0)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("coin_collected", {"amount": value})
			break
	queue_free()
