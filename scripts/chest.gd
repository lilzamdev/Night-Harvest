extends Area2D
class_name ChestEntity

const CHEST_SLOT_COUNT: int = 24
const ItemDataClass = preload("res://scripts/item_data.gd")
const ChestUIScene = preload("res://Scenes/UI/chest_ui.tscn")

@export var chest_name: String = "RPG Chest #7"
@export var chest_type_index: int = 7 # Chest #7 from RPG Chests.png
@export var interaction_range: float = 32.0

var storage_slots: Array[Dictionary] = []
var is_open: bool = false
var active_player: Node2D = null
var current_frame_idx: int = 0
var _anim_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("chests")
	_init_storage_slots()
	_update_visuals()


func _init_storage_slots() -> void:
	if storage_slots.is_empty():
		for i in range(CHEST_SLOT_COUNT):
			storage_slots.append({ "item": null, "amount": 0 })


func _update_visuals() -> void:
	if not sprite:
		return
	sprite.texture = ItemDatabase.get_rpg_chest_texture(chest_type_index, current_frame_idx)


func _set_frame(idx: int) -> void:
	current_frame_idx = idx
	_update_visuals()


func can_interact(player: Node2D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	var dist := global_position.distance_to(player.global_position)
	return dist <= interaction_range


func get_prompt() -> String:
	return "[G] Open Chest" if not is_open else "[G] Close Chest"


func interact(player: Node2D) -> void:
	if is_open:
		close_chest()
	else:
		open_chest(player)


func open_chest(player: Node2D) -> void:
	is_open = true
	active_player = player
	_play_open_animation()
	
	var ui_layer = _get_ui_layer()
	if ui_layer:
		var chest_ui: ChestUI = ui_layer.get_node_or_null("ChestUI")
		if not chest_ui:
			chest_ui = ChestUIScene.instantiate()
			ui_layer.add_child(chest_ui)
		
		if chest_ui:
			chest_ui.open_with_chest(self, player)
			if not chest_ui.closed.is_connected(close_chest):
				chest_ui.closed.connect(close_chest)


func close_chest() -> void:
	if not is_open:
		return
	is_open = false
	_play_close_animation()
	
	var ui_layer = _get_ui_layer()
	if ui_layer:
		var chest_ui: ChestUI = ui_layer.get_node_or_null("ChestUI")
		if chest_ui and chest_ui.is_open:
			chest_ui.close()
	
	active_player = null


func _play_open_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_callback(func(): _set_frame(1)).set_delay(0.04)
	_anim_tween.tween_callback(func(): _set_frame(2)).set_delay(0.04)
	_anim_tween.tween_callback(func(): _set_frame(3)).set_delay(0.04)


func _play_close_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_callback(func(): _set_frame(2)).set_delay(0.04)
	_anim_tween.tween_callback(func(): _set_frame(1)).set_delay(0.04)
	_anim_tween.tween_callback(func(): _set_frame(0)).set_delay(0.04)


func get_item_at(index: int) -> Dictionary:
	if index >= 0 and index < storage_slots.size():
		return storage_slots[index]
	return { "item": null, "amount": 0 }


func set_item_at(index: int, item_data: Resource, amount: int) -> void:
	if index >= 0 and index < storage_slots.size():
		if item_data == null or amount <= 0:
			storage_slots[index] = { "item": null, "amount": 0 }
		else:
			storage_slots[index] = { "item": item_data, "amount": amount }


func add_item(item_data: Resource, amount: int) -> int:
	if not item_data or amount <= 0:
		return amount
	
	var max_stk: int = item_data.get("max_stack") if item_data.get("max_stack") != null else 99
	var leftover := amount
	
	# 1. Stack into matching items
	if max_stk > 1:
		for slot in storage_slots:
			if slot["item"] and slot["item"].get("item_id") == item_data.get("item_id") and slot["amount"] < max_stk:
				var space: int = max_stk - slot["amount"]
				var to_add: int = min(leftover, space)
				slot["amount"] += to_add
				leftover -= to_add
				if leftover <= 0:
					return 0
	
	# 2. Place into empty slots
	for slot in storage_slots:
		if slot["item"] == null or slot["amount"] <= 0:
			var to_add: int = min(leftover, max_stk)
			slot["item"] = item_data
			slot["amount"] = to_add
			leftover -= to_add
			if leftover <= 0:
				return 0
	
	return leftover


func _get_ui_layer() -> Node:
	if not get_tree():
		return null
	if get_tree().root:
		var ui = get_tree().root.find_child("UI", true, false)
		if ui and is_instance_valid(ui):
			return ui
	return null
