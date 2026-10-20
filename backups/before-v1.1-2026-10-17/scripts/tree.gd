extends StaticBody2D
class_name TreeEntity

const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDatabaseClass = preload("res://scripts/item_database.gd")

signal hit_received(current_hp: int, max_hp: int)
signal tree_destroyed()

@export var max_health: int = 4
@export var current_health: int = 4
@export var wood_drop_count: int = 4
@export var wood_item_id: String = "wood_log"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox

var is_dead := false
var _initial_sprite_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("trees")
	add_to_group("choppable_trees")
	if sprite:
		_initial_sprite_pos = sprite.position
	current_health = max_health


## Takes a hit. Only an AXE can damage and cut down the tree. Requires exactly 4 hits.
func take_hit(tool_power: int = 1, hit_dir: Vector2 = Vector2.ZERO, is_axe: bool = false) -> bool:
	if is_dead:
		return false
	
	# Only an AXE can damage and fell trees
	if not is_axe:
		# Harmless minor visual bump with no damage
		_play_deflect_reaction(hit_dir)
		return false
	
	# Each axe hit does 1 damage (4 axe hits total to fell the tree)
	current_health -= 1
	hit_received.emit(current_health, max_health)
	
	_play_hit_reaction(hit_dir)
	
	if current_health <= 0:
		_destroy_tree()
	
	return true


func _play_hit_reaction(hit_dir: Vector2) -> void:
	if not sprite:
		return
	
	var tween = create_tween()
	var shake_offset = hit_dir.normalized() * 3.5 if hit_dir != Vector2.ZERO else Vector2(randf_range(-3.0, 3.0), 0)
	
	# Flash wood/chop color and shake
	sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
	tween.tween_property(sprite, "position", _initial_sprite_pos + shake_offset, 0.05)
	tween.tween_property(sprite, "position", _initial_sprite_pos - shake_offset * 0.6, 0.05)
	tween.tween_property(sprite, "position", _initial_sprite_pos, 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _play_deflect_reaction(hit_dir: Vector2) -> void:
	if not sprite:
		return
	var tween = create_tween()
	var shake_offset = hit_dir.normalized() * 1.0 if hit_dir != Vector2.ZERO else Vector2(1, 0)
	tween.tween_property(sprite, "position", _initial_sprite_pos + shake_offset, 0.04)
	tween.tween_property(sprite, "position", _initial_sprite_pos, 0.04)


func _destroy_tree() -> void:
	if is_dead:
		return
	is_dead = true
	tree_destroyed.emit()
	
	# Notify quest system
	var bus_nodes := get_tree().get_nodes_in_group("event_bus")
	for bus in bus_nodes:
		if is_instance_valid(bus) and bus.has_signal("tree_cut"):
			bus.tree_cut.emit()
			break
	
	# Spawn exactly 4 wood logs
	_spawn_wood_drops()
	
	# Fade out sprite and queue free
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _spawn_wood_drops() -> void:
	var wood_data = ItemDatabaseClass.get_item(wood_item_id)
	if not wood_data:
		return
	
	var parent_node = get_parent() if get_parent() else self
	
	for i in range(wood_drop_count):
		var w_item = WorldItemScene.instantiate()
		parent_node.add_child(w_item)
		# Spread around tree base deterministically
		var angle = (float(i) / float(wood_drop_count)) * TAU
		var dist = 16.0
		var offset = Vector2(cos(angle) * dist, sin(angle) * dist + 8.0)
		w_item.global_position = global_position + offset
		w_item.call("set_item", wood_data, 1)
