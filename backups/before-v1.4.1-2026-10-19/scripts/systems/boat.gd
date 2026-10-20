extends StaticBody2D

## Boat (v1.4): a rowing boat. Craft it at the workbench, hold it and LEFT CLICK on
## water to put it in. Walk up and press E to get in; WASD rows (SHIFT rows faster),
## E next to the shore gets you out. Zombies can't follow you onto the water, and you
## can fish from the boat. Hit an empty boat with an axe to pick it back up.
## The boat only moves on water: sail across the sea to find the islands.
## Saved by the BuildManager.

const V131 := "res://Assets/Generated/v131/"
const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const SPEED := 118.0
const SPRINT := 1.4

var interact_range := 30.0
var is_dead := false
var rider: Node2D = null
## loaded from a save made while rowing: the rider gets back in next frame
var pending_ride := false
var _spr: Sprite2D
var _shape: CollisionShape2D
var _back: Sprite2D
var _front: Sprite2D
var _vertical := false
var _flip := false
var _hits := 0
var _wake_t := 0.0
var _bob := 0.0
var _saved_mask := 1
var _saved_layer := 1


static func create() -> StaticBody2D:
	var b: StaticBody2D = load("res://scripts/systems/boat.gd").new()
	return b


func _ready() -> void:
	add_to_group("boats")
	add_to_group("interactables")
	collision_layer = 2   # the tool hitbox can hit it; the player walks through
	collision_mask = 0
	_spr = Sprite2D.new()
	add_child(_spr)
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(30, 12)
	_shape.shape = rs
	_shape.position = Vector2(0, -2)
	add_child(_shape)
	_set_look(Vector2.RIGHT)


# --- Looks ----------------------------------------------------------------------

func _set_look(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if absf(dir.y) > absf(dir.x) * 1.2:
		_vertical = true
	elif absf(dir.x) > absf(dir.y) * 1.2:
		_vertical = false
		_flip = dir.x < 0.0
	var t: Texture2D = load(V131 + ("boat_v.png" if _vertical else "boat_h.png"))
	_spr.texture = t
	_spr.flip_h = _flip and not _vertical
	# The rider's origin is mid-body (feet ~16px lower): the near half of the hull
	# (the *_front overlay) starts at their waist so their legs are in the boat.
	var top := -15.0 if _vertical else -5.0
	_spr.offset = Vector2(0, top + t.get_height() * 0.5)
	if _back:
		_back.texture = t
		_back.flip_h = _spr.flip_h
		_back.offset = _spr.offset
		_front.texture = load(V131 + ("boat_v_front.png" if _vertical else "boat_h_front.png"))
		_front.flip_h = _spr.flip_h
		_front.offset = _back.offset


# --- Water ------------------------------------------------------------------------

static func water_at(tree: SceneTree, pos: Vector2) -> bool:
	var bm := tree.get_first_node_in_group("build_manager")
	var wg := tree.get_first_node_in_group("worldgen")
	if bm == null:
		return false
	var c: Vector2i = bm.BlockScript.cell_of(pos)
	if bm.has_method("_village_water") and bm._village_water(c):
		return true
	if bm.has_method("floor_at") and bm.floor_at(c) != null:
		return false   # a bridge / floor block over the water
	return wg != null and wg.has_method("ground_is_water") and wg.ground_is_water(c)


func _hull_on_water(pos: Vector2, dir: Vector2) -> bool:
	var t := get_tree()
	var keel := pos + Vector2(0, 6)
	if not water_at(t, keel):
		return false
	var ahead := dir.normalized() * 9.0 if dir != Vector2.ZERO else Vector2.ZERO
	return water_at(t, keel + ahead)


# --- Getting in and out --------------------------------------------------------------

func can_interact(p: Node2D) -> bool:
	if is_dead:
		return false
	if rider:
		return p == rider
	return p.get("boat") == null


func get_prompt() -> String:
	return "LEAVE BOAT" if rider else "GET IN BOAT"


func interact(p: Node2D) -> void:
	if rider:
		leave(true)
	else:
		board(p)


func board(p: Node2D) -> void:
	if rider or is_dead or p == null:
		return
	if p.has_meta("on_tower"):
		return
	pending_ride = false
	rider = p
	p.set("boat", self)
	_saved_mask = (p as CollisionObject2D).collision_mask
	_saved_layer = (p as CollisionObject2D).collision_layer
	(p as CollisionObject2D).collision_mask = 0   # the boat itself keeps you on the water
	collision_layer = 0
	remove_from_group("interactables")
	p.global_position = global_position
	_spr.visible = false
	_back = Sprite2D.new()
	_back.z_index = -1
	_front = Sprite2D.new()
	_front.z_index = 1
	p.add_child(_back)
	p.add_child(_front)
	_set_look(Vector2.LEFT if _flip else Vector2.RIGHT if not _vertical else Vector2.DOWN)
	_set_look(p.get("last_direction") if p.get("last_direction") != null else Vector2.RIGHT)
	_splash(global_position)
	_msg("WASD to row, SHIFT to row faster, E by the shore to get out.")
	_sfx("splash", -8.0)
	_event("boat_boarded")


## Gets out onto the nearest dry ground. `walk_off` = false just drops the rider
## where they are (used when they die or get teleported).
func leave(walk_off: bool) -> bool:
	if rider == null:
		return false
	var p := rider
	var spot := Vector2.INF
	if walk_off:
		spot = _shore_spot(p)
		if spot == Vector2.INF:
			_msg("Row next to the shore to get out.")
			return false
	global_position = p.global_position
	rider = null
	p.set("boat", null)
	(p as CollisionObject2D).collision_mask = _saved_mask
	(p as CollisionObject2D).collision_layer = _saved_layer
	collision_layer = 2
	add_to_group("interactables")
	for s in [_back, _front]:
		if is_instance_valid(s):
			s.queue_free()
	_back = null
	_front = null
	_spr.visible = true
	_spr.position = Vector2.ZERO
	if walk_off:
		p.global_position = spot
		_splash(global_position)
	return true


func _shore_spot(p: Node2D) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var dir: Vector2 = p.get("last_direction") if p.get("last_direction") != null else Vector2.DOWN
	var dirs: Array[Vector2] = [dir]
	for i in 8:
		dirs.append(Vector2.from_angle(TAU * i / 8.0))
	for d in dirs:
		for dist in [16.0, 22.0, 28.0, 34.0]:
			var pt: Vector2 = p.global_position + d.normalized() * dist
			if water_at(get_tree(), pt) or water_at(get_tree(), pt + Vector2(0, 14)):
				continue
			q.position = pt
			if space.intersect_point(q, 1).is_empty():
				return pt
	return Vector2.INF


# --- Rowing (called by the player every physics frame while riding) -------------------

func steer(p: CharacterBody2D, dir: Vector2, sprint: bool, delta: float) -> void:
	var spd := SPEED * (SPRINT if sprint else 1.0)
	var step := dir * spd * delta
	if step != Vector2.ZERO:
		_set_look(dir)
		var np := p.global_position + step
		if _hull_on_water(np, dir):
			p.global_position = np
		elif _hull_on_water(p.global_position + Vector2(step.x, 0), Vector2(dir.x, 0)):
			p.global_position += Vector2(step.x, 0)
		elif _hull_on_water(p.global_position + Vector2(0, step.y), Vector2(0, dir.y)):
			p.global_position += Vector2(0, step.y)
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = 0.22 if not sprint else 0.15
			_splash(p.global_position - dir * 14.0 + Vector2(0, 2))
	global_position = p.global_position
	# gentle bobbing on the waves
	_bob += delta * 2.4
	var y := roundf(sin(_bob) * 0.6)
	if _back:
		_back.position.y = y
		_front.position.y = y


func _process(_delta: float) -> void:
	if rider and not is_instance_valid(rider):
		rider = null
		_spr.visible = true


# --- Picking it back up --------------------------------------------------------------

func take_hit(_power: int = 1, _dir: Vector2 = Vector2.ZERO, _is_axe: bool = true) -> void:
	if rider or is_dead:
		return
	_hits += 1
	var tw := create_tween()
	tw.tween_property(_spr, "position:x", 2.0, 0.05)
	tw.tween_property(_spr, "position:x", 0.0, 0.05)
	if _hits < 2:
		return
	is_dead = true
	var gm := get_tree().get_first_node_in_group("game_mode")
	if not (gm and gm.get("creative") == true):
		var it = ItemDB.get_item("boat")
		var inv := get_tree().get_first_node_in_group("inventory_ui")
		var left: int = inv.add_item(it, 1) if (inv and it) else 1
		if left > 0 and it:
			var w := WorldItemScene.instantiate()
			get_parent().add_child(w)
			w.global_position = global_position
			w.call("set_item", it, 1)
	queue_free()


# --- Putting a boat in the water (from the item) --------------------------------------

## Returns true if a boat was put in the water.
static func place_from_item(p: Node2D) -> bool:
	var tree := p.get_tree()
	var spot := Vector2.INF
	var m: Vector2 = p.get_global_mouse_position()
	if m.distance_to(p.global_position) < 70.0 and water_at(tree, m) and water_at(tree, m + Vector2(10, 0)) and water_at(tree, m - Vector2(10, 0)):
		spot = m
	else:
		var dir: Vector2 = p.get("last_direction") if p.get("last_direction") != null else Vector2.DOWN
		for d in [24.0, 32.0, 40.0, 48.0]:
			var pt: Vector2 = p.global_position + dir * d
			if water_at(tree, pt) and water_at(tree, pt + Vector2(10, 0)) and water_at(tree, pt - Vector2(10, 0)):
				spot = pt
				break
	var hud := tree.get_first_node_in_group("hud_ui")
	if spot == Vector2.INF:
		if hud:
			hud.show_hud_message("Face open water to put the boat in.", 2.0)
		return false
	for other in tree.get_nodes_in_group("boats"):
		if (other as Node2D).global_position.distance_to(spot) < 20.0:
			return false
	var bm := tree.get_first_node_in_group("build_manager")
	var b := create()
	(bm if bm else p.get_parent()).add_child(b)
	b.global_position = spot
	b._set_look(p.get("last_direction") if p.get("last_direction") != null else Vector2.RIGHT)
	b._splash(spot)
	if hud:
		hud.show_hud_message("Boat in the water! Walk up to it and press E to get in.", 3.0)
	return true


# --- Save ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var pos := rider.global_position if rider else global_position
	return {"x": pos.x, "y": pos.y, "v": _vertical, "f": _flip, "ride": rider != null or pending_ride}


func load_data(d: Dictionary) -> void:
	_vertical = bool(d.get("v", false))
	_flip = bool(d.get("f", false))
	_set_look(Vector2.DOWN if _vertical else (Vector2.LEFT if _flip else Vector2.RIGHT))


# --- Bits ---------------------------------------------------------------------------

func _splash(pos: Vector2) -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("play_fx"):
		lw.play_fx(pos, "ripple", 8, 8, 4, 10.0)


func _msg(t: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 2.5)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)


func _event(t: String) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, {})
			break
