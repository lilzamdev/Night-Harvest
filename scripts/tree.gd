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
var _last_hit_dir := Vector2.RIGHT


func take_hit(tool_power: int = 1, hit_dir: Vector2 = Vector2.ZERO, is_axe: bool = false) -> bool:
	if is_dead:
		return false
	# v1.3 Creative mode: everything breaks in one hit
	var gm := get_tree().get_first_node_in_group("game_mode") if is_inside_tree() else null
	if gm and gm.get("creative") == true:
		is_axe = true
		tool_power = maxi(tool_power, current_health)
	
	# Only an AXE can damage and fell trees
	if not is_axe:
		# Harmless minor visual bump with no damage
		_play_deflect_reaction(hit_dir)
		return false
	
	# Each axe hit does tool_power damage (wood axe: 4 hits, steel axe: 2 hits)
	current_health -= maxi(1, tool_power)
	hit_received.emit(current_health, max_health)
	
	_play_hit_reaction(hit_dir)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -8), Color(0.62, 0.42, 0.22), 6, 60.0)
		juice.burst(global_position + Vector2(0, -34), Color(0.36, 0.62, 0.25), 4, 30.0, 1.0, 0.3)
		juice.shake(1.0, 0.1)
	_last_hit_dir = hit_dir
	
	if current_health <= 0:
		_destroy_tree()
	
	return true


var _punches := 0


## v1.3: punching a tree with bare hands. Every second punch counts as a weak chop,
## so a tree falls after 8 punches - slow, but enough to get your first wood.
func punch(hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if is_dead:
		return false
	_punches += 1
	if _punches % 2 == 0:
		return take_hit(1, hit_dir, true)
	_play_hit_reaction(hit_dir)
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
	
	# Some map trees are parented to other trees; keep those standing.
	for c in get_children():
		if c.has_method("take_hit") and c != self:
			c.call_deferred("reparent", get_parent(), true)
	# v1.2: the tree topples away from the swing, thuds, then the logs pop out.
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", true)
	var hurt := get_node_or_null("Hurtbox")
	if hurt:
		hurt.set_deferred("monitoring", false)
	var side := 1.0 if _last_hit_dir.x >= 0.0 else -1.0
	if sprite:
		var tween = create_tween()
		tween.tween_property(self, "rotation", side * 1.45, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_on_tree_landed.bind(side))
		tween.tween_property(self, "rotation", side * 1.32, 0.08)
		tween.tween_property(self, "rotation", side * 1.45, 0.08)
		tween.tween_interval(0.25)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		_spawn_wood_drops()
		queue_free()


func _on_tree_landed(side: float) -> void:
	var juice := get_tree().get_first_node_in_group("juice")
	var land := global_position + Vector2(side * 30.0, -4.0)
	if juice:
		juice.shake(3.0, 0.25)
		juice.burst(land, Color(0.36, 0.62, 0.25), 14, 80.0)
		juice.dust(land, 8)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("rock_break", -10.0)
	# Drops spawn from the trunk while the canopy fades (rotation must not skew them)
	var r := rotation
	rotation = 0.0
	_spawn_wood_drops()
	rotation = r


func _spawn_wood_drops() -> void:
	var wood_data = ItemDatabaseClass.get_item(wood_item_id)
	if not wood_data:
		return
	
	var parent_node = get_parent() if get_parent() else self
	
	# v1.4: real trees sometimes drop a sapling you can plant
	if wood_item_id == "wood_log" and randf() < 0.3:
		var tk := str(get_meta("tree_kind", "oak"))
		var sap = ItemDatabaseClass.get_item("pine_sapling" if tk.begins_with("pine") else "sapling")
		if sap:
			var s_item = WorldItemScene.instantiate()
			parent_node.add_child(s_item)
			s_item.global_position = global_position + Vector2(0, 14)
			s_item.call("set_item", sap, 1)
	# v1.4: pines give pine logs, island trees driftwood (set by WorldGen)
	if has_meta("bonus_drop"):
		var bd: Array = get_meta("bonus_drop")
		var bitem = ItemDatabaseClass.get_item(str(bd[0]))
		if bitem:
			for i in randi_range(int(bd[1]), int(bd[2])):
				var b_item = WorldItemScene.instantiate()
				parent_node.add_child(b_item)
				b_item.global_position = global_position + Vector2(-10 + i * 10, 20)
				b_item.call("set_item", bitem, 1)
	for i in range(wood_drop_count):
		var w_item = WorldItemScene.instantiate()
		parent_node.add_child(w_item)
		# Spread around tree base deterministically
		var angle = (float(i) / float(wood_drop_count)) * TAU
		var dist = 16.0
		var offset = Vector2(cos(angle) * dist, sin(angle) * dist + 8.0)
		w_item.global_position = global_position + offset
		w_item.call("set_item", wood_data, 1)
