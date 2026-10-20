extends Node2D

## Rosa's market stall in the village. Opens the general shop while she is out.

const UIKit = preload("res://scripts/systems/ui_kit.gd")

var shop_id: String = "general"
var keeper_id: String = "rosa"
var interact_range: float = 30.0


func _ready() -> void:
	add_to_group("interactables")
	var spr := Sprite2D.new()
	spr.texture = load("res://Assets/Generated/stall.png")
	spr.centered = false
	spr.offset = Vector2(-24, -32)
	add_child(spr)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(44, 12)
	cs.shape = rs
	cs.position = Vector2(0, -6)
	body.add_child(cs)
	add_child(body)
	# Price sign hanging off the stall
	var sign := Sprite2D.new()
	sign.texture = UIKit.atlas(load("res://Assets/Pixel Lands Village Demo/objects_demo.png"), Rect2(4, 4, 24, 16))
	sign.position = Vector2(30, -10)
	add_child(sign)


func _keeper() -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get("npc_id") == keeper_id:
			return n
	return null


func _open() -> bool:
	var k := _keeper()
	return k == null or k.is_daytime_out()


func can_interact(_player: Node2D) -> bool:
	return true


func get_prompt() -> String:
	return "BROWSE ROSA'S STALL" if _open() else "STALL CLOSED"


func interact(_player: Node2D) -> void:
	if not _open():
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud:
			hud.show_hud_message("Rosa has gone home. Knock at Rosa's Goods.", 2.5)
		return
	var shop := get_tree().get_first_node_in_group("shop_ui")
	if shop:
		shop.open_shop(shop_id, _keeper())
