extends Area2D

## Tall grass (v1.3). Cut it with anything - even your hands - for Plant Fiber
## (used for torches, fences, traps and beds) and the odd seed.

const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const DECOR := "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png"

var variant := 0
var seed_roll := 0.5
var is_dead := false
var _spr: Sprite2D


func _ready() -> void:
	add_to_group("tall_grass")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 10)
	cs.shape = rs
	cs.position = Vector2(0, -5)
	add_child(cs)
	_spr = Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = load(DECOR)
	a.region = Rect2((variant % 3) * 16, 0, 16, 16)
	_spr.texture = a
	var lw := get_tree().get_first_node_in_group("living_world") if is_inside_tree() else null
	if lw and lw.has_method("season_material"):
		_spr.material = lw.season_material()
	_spr.offset = Vector2(0, -7)
	add_child(_spr)


func take_hit(_tool_power: int = 1, _hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if is_dead:
		return false
	is_dead = true
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -6), Color(0.4, 0.7, 0.3), 6, 40.0)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("crop_harvest", -14.0)
	if seed_roll < 0.75:
		_drop("fiber", 1)
	if seed_roll > 0.9:
		var seeds := ["carrot_seed", "wheat_seed", "potato_seed", "tomato_seed"]
		_drop(seeds[int(seed_roll * 1000.0) % seeds.size()], 1)
	var tw := create_tween()
	tw.tween_property(_spr, "scale", Vector2(1.4, 0.2), 0.12)
	tw.tween_callback(queue_free)
	return true


func _drop(id: String, n: int) -> void:
	var it = ItemDB.get_item(id)
	if it == null:
		return
	var w := WorldItemScene.instantiate()
	get_parent().add_child(w)
	w.global_position = global_position + Vector2(randf_range(-4, 4), 2)
	w.call("set_item", it, n)
