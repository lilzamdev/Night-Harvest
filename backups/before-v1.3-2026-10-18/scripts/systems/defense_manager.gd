extends Node2D

## Places, previews, saves and restores farm defenses.
## Hold a defense item (barricade, spike trap, scarecrow crossbow) in the hotbar,
## aim with the mouse (or face a tile) and LEFT CLICK / SPACE to build it.

const StructureScript = preload("res://scripts/systems/defense_structure.gd")
const ItemDataClass = preload("res://scripts/item_data.gd")
const ItemDB = preload("res://scripts/item_database.gd")
const GEN := "res://Assets/Generated/"
const REACH := 56.0

var save_key := "defenses"
var _ghost: Sprite2D
var _ghost_ok := false
var _ghost_pos := Vector2.ZERO
var _player: Node2D


func _ready() -> void:
	add_to_group("defense_manager")
	add_to_group("save_extension")
	y_sort_enabled = true
	_ghost = Sprite2D.new()
	_ghost.centered = false
	_ghost.z_index = 30
	_ghost.visible = false
	add_child(_ghost)


func _process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if not _player:
			return
	var item: Resource = _player.get("current_held_item")
	if item == null or item.get("item_type") != ItemDataClass.ItemType.PLACEABLE or _player.is_ui_blocking():
		_ghost.visible = false
		return
	var kind := str(item.get("item_id"))
	_ghost_pos = _target_cell(_player)
	_ghost_ok = _can_place(_ghost_pos, kind) == ""
	match kind:
		"barricade":
			_ghost.texture = _atlas("barricade.png", 0, 16, 16)
			_ghost.offset = Vector2(-8, -14)
		"spike_trap":
			_ghost.texture = _atlas("spikes.png", 0, 16, 16)
			_ghost.offset = Vector2(-8, -11)
		"stone_wall":
			_ghost.texture = load("res://Assets/Generated/v12/stone_wall.png")
			_ghost.offset = Vector2(-8, -14)
		"iron_spikes":
			_ghost.texture = load("res://Assets/Generated/v12/iron_spikes.png")
			_ghost.offset = Vector2(-8, -13)
		"lantern_post":
			_ghost.texture = load("res://Assets/Generated/v12/lantern_post.png")
			_ghost.offset = Vector2(-8, -19)
		"sprinkler":
			_ghost.texture = load("res://Assets/Generated/v12/icon_sprinkler.png")
			_ghost.offset = Vector2(-8, -10)
		_:
			_ghost.texture = _atlas("turret.png", 0, 16, 32)
			_ghost.offset = Vector2(-8, -29)
	_ghost.global_position = _ghost_pos
	_ghost.modulate = Color(0.6, 1.0, 0.6, 0.6) if _ghost_ok else Color(1.0, 0.4, 0.4, 0.55)
	_ghost.visible = true


func _atlas(file: String, idx: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(GEN + file)
	a.region = Rect2(idx * w, 0, w, h)
	return a


func _target_cell(player: Node2D) -> Vector2:
	var m := player.get_global_mouse_position()
	var p: Vector2
	if m.distance_to(player.global_position) <= REACH:
		p = m
	else:
		var dir: Vector2 = player.get("last_direction")
		p = player.global_position + dir * 20.0 + Vector2(0, 6)
	return Vector2(floorf(p.x / 16.0) * 16.0 + 8.0, floorf(p.y / 16.0) * 16.0 + 14.0)


## "" when the spot is fine, otherwise a reason.
func _can_place(pos: Vector2, _kind: String) -> String:
	var world := get_tree().get_first_node_in_group("nh_world")
	if world and world.is_player_indoors():
		return "Build defenses outside."
	var mines := get_tree().get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return "Build on your farm, not in the mines."
	if _player and pos.distance_to(_player.global_position) < 8.0:
		return "Step aside first."
	for d in get_tree().get_nodes_in_group("defenses"):
		if (d as Node2D).global_position.distance_to(pos) < 12.0:
			return "Something is already built there."
	var fm := get_tree().get_first_node_in_group("farming_manager")
	if fm and fm.has_method("get_crop_at") and fm.get_crop_at(pos + Vector2(0, -6)) != null:
		return "Don't build on your crops."
	var q := PhysicsShapeQueryParameters2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 8)
	q.shape = rs
	q.transform = Transform2D(0.0, pos + Vector2(0, -5))
	q.collision_mask = 1
	q.collide_with_areas = false
	if _player:
		q.exclude = [(_player as CollisionObject2D).get_rid()]
	if not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "That spot is blocked."
	return ""


func try_place_from_player(player: Node2D, item: Resource) -> bool:
	_player = player
	var kind := str(item.get("item_id"))
	var pos := _target_cell(player)
	var why := _can_place(pos, kind)
	if why != "":
		_msg(why)
		return false
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui")
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if not hotbar or not inv:
		return false
	var slot: int = hotbar.get("selected_slot")
	var removed = inv.remove_hotbar_item_at(slot, 1)
	if removed == null:
		return false
	spawn(kind, pos)
	if player.has_method("_on_hotbar_slot_selected"):
		player._on_hotbar_slot_selected(slot, hotbar.get_selected_item())
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("build", -6.0)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("defense_built", {"kind": kind})
			break
	return true


func spawn(kind: String, pos: Vector2, hp: int = -1) -> Node2D:
	var s: StaticBody2D = StructureScript.new()
	s.kind = kind
	if hp > 0:
		s.hp = hp
	add_child(s)
	s.global_position = pos
	if hp <= 0:
		var tw := s.create_tween()
		s.scale = Vector2(0.6, 0.6)
		tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return s


## Every barricade and turret back to full health (bought from Ben, or after sleeping).
func repair_all() -> int:
	var n := 0
	for d in get_tree().get_nodes_in_group("defenses"):
		if d.hp < d.max_hp:
			d.repair_full()
			n += 1
	return n


func count_alive() -> int:
	return get_tree().get_nodes_in_group("defenses").size()


func _msg(t: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 1.8)


func get_save_data() -> Dictionary:
	var list: Array = []
	for d in get_tree().get_nodes_in_group("defenses"):
		if is_ancestor_of(d) and not d.is_dead:
			list.append(d.get_save_data())
	var torches: Array = []
	for t in get_tree().get_nodes_in_group("torches"):
		if t.has_meta("placed_by_player"):
			torches.append({"x": t.global_position.x, "y": t.global_position.y})
	return {"list": list, "torches": torches}


func load_save_data(data: Dictionary) -> void:
	for d in get_tree().get_nodes_in_group("defenses"):
		if is_ancestor_of(d):
			d.queue_free()
	for e in data.get("list", []):
		spawn(str(e.get("kind", "barricade")), Vector2(float(e.get("x", 0)), float(e.get("y", 0))), int(e.get("hp", -1)))
	var torch_scene: PackedScene = load("res://Scenes/Torch.tscn")
	for t in data.get("torches", []):
		var node := torch_scene.instantiate()
		node.set_meta("placed_by_player", true)
		get_parent().add_child(node)
		node.global_position = Vector2(float(t["x"]), float(t["y"]))
