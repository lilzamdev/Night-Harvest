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

var interact_range := 58.0   # v1.4.2: boats float out on open water, so reach them from the shore
var is_dead := false
var rider: Node2D = null
## loaded from a save made while rowing: the rider gets back in next frame
var pending_ride := false
var _board_ms := -10000
var _spr: Sprite2D
var _shape: CollisionShape2D
var _back: Sprite2D
var _front: Sprite2D
var _vertical := false
var _flip := false
var _down := false          # v1.4.2: rowing down - bow points down
var _vel := Vector2.ZERO    # v1.4.2: the boat glides (speeds up / slows down)
const ACCEL := 260.0
const DRAG := 150.0
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
		_down = dir.y > 0.0
	elif absf(dir.x) > absf(dir.y) * 1.2:
		_vertical = false
		_flip = dir.x < 0.0
	var vname := "boat_vd" if _down else "boat_v"
	var t: Texture2D = load(V131 + (vname + ".png" if _vertical else "boat_h.png"))
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
		_front.texture = load(V131 + (vname + "_front.png" if _vertical else "boat_h_front.png"))
		_front.flip_h = _spr.flip_h
		_front.offset = _back.offset


# --- Water ------------------------------------------------------------------------

## generated terrain never changes, so remember which tiles are water (seed-specific)
static var _wcache := {}
static var _wseed := -1

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
	if wg == null or not wg.has_method("ground_is_water"):
		return false
	var sd := int(wg.get("world_seed"))
	if sd != _wseed or _wcache.size() > 20000:
		_wcache.clear()
		_wseed = sd
	if not _wcache.has(c):
		_wcache[c] = wg.ground_is_water(c)
	return _wcache[c]


## v1.4.2: the WHOLE hull must float on open water. The water tiles along a shore have
## the bank drawn on them, so they don't count - the boat can't ride up onto the edge.
static func open_water(tree: SceneTree, pos: Vector2) -> bool:
	var bm := tree.get_first_node_in_group("build_manager")
	if bm == null:
		return false
	var c: Vector2i = bm.BlockScript.cell_of(pos)
	for o in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not water_at(tree, bm.BlockScript.cell_base(c + o) + Vector2(0, -8)):
			return false
	return true


## Points around the hull outline (relative to the rider) for each way the boat can face.
static func hull_points(vertical: bool) -> Array:
	if vertical:
		return [Vector2(-4, -11), Vector2(4, -11), Vector2(-4, 1), Vector2(4, 1), Vector2(-4, 13), Vector2(4, 13), Vector2(0, 20)]
	return [Vector2(-16, 1), Vector2(-6, 1), Vector2(6, 1), Vector2(16, 1), Vector2(-16, 12), Vector2(-6, 12), Vector2(6, 12), Vector2(16, 12)]


static func hull_fits(tree: SceneTree, pos: Vector2, vertical: bool) -> bool:
	for o in hull_points(vertical):
		if not open_water(tree, pos + o):
			return false
	return true


func _hull_on_water(pos: Vector2, dir: Vector2) -> bool:
	var vertical := _vertical
	if dir != Vector2.ZERO:
		if absf(dir.y) > absf(dir.x) * 1.2:
			vertical = true
		elif absf(dir.x) > absf(dir.y) * 1.2:
			vertical = false
	return hull_fits(get_tree(), pos, vertical)


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
	if Time.get_ticks_msec() - _board_ms < 400:
		return   # the same E press that got you in
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
	_board_ms = Time.get_ticks_msec()
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
	var vroot: Node2D = p.visuals_root() if p.has_method("visuals_root") else p
	vroot.add_child(_back)
	vroot.add_child(_front)
	# keep the way the boat already lies (turning it here could push it onto the shore)
	_set_look((Vector2.DOWN if _down else Vector2.UP) if _vertical else (Vector2.LEFT if _flip else Vector2.RIGHT))
	_vel = Vector2.ZERO
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
		for dist in [16.0, 22.0, 28.0, 34.0, 40.0, 48.0]:
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
	# v1.4.2: the boat picks up speed and glides to a stop instead of moving like a person
	if dir != Vector2.ZERO:
		_vel = _vel.move_toward(dir.normalized() * spd, ACCEL * delta)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, DRAG * delta)
	var step := _vel * delta
	if step.length() > 0.01:
		# turning needs room: only swing the hull round if it fits that way
		if dir != Vector2.ZERO and _hull_on_water(p.global_position, dir):
			_set_look(dir)
		var face := Vector2(0, 1 if _down else -1) if _vertical else Vector2(-1 if _flip else 1, 0)
		var np := p.global_position + step
		if _hull_on_water(np, face):
			p.global_position = np
		elif _hull_on_water(p.global_position + Vector2(step.x, 0), face):
			p.global_position += Vector2(step.x, 0)
			_vel.y = 0.0
		elif _hull_on_water(p.global_position + Vector2(0, step.y), face):
			p.global_position += Vector2(0, step.y)
			_vel.x = 0.0
		else:
			_vel = Vector2.ZERO   # bumped the shore
	if step.length() > 0.5:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = 0.22 if not sprint else 0.15
			_splash(p.global_position - _vel.normalized() * 14.0 + Vector2(0, 2))
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
	var dir: Vector2 = p.get("last_direction") if p.get("last_direction") != null else Vector2.DOWN
	var vert: bool = absf(dir.y) > absf(dir.x)
	if m.distance_to(p.global_position) < 90.0 and (hull_fits(tree, m, vert) or hull_fits(tree, m, not vert)):
		spot = m
	else:
		for d in [32.0, 40.0, 48.0, 56.0, 64.0, 72.0]:
			var pt: Vector2 = p.global_position + dir * d
			if hull_fits(tree, pt, vert) or hull_fits(tree, pt, not vert):
				spot = pt
				break
	var hud := tree.get_first_node_in_group("hud_ui")
	if spot == Vector2.INF:
		if hud:
			hud.show_hud_message("Face open water (away from the shore) to put the boat in.", 2.0)
		return false
	for other in tree.get_nodes_in_group("boats"):
		if (other as Node2D).global_position.distance_to(spot) < 20.0:
			return false
	var bm := tree.get_first_node_in_group("build_manager")
	var b := create()
	(bm if bm else p.get_parent()).add_child(b)
	b.global_position = spot
	b._set_look(dir)
	if not b.hull_fits(tree, spot, b._vertical):
		b._set_look(Vector2(dir.y, dir.x) if dir != Vector2.ZERO else Vector2.RIGHT)
	b._splash(spot)
	if hud:
		hud.show_hud_message("Boat in the water! Walk up to it and press E to get in.", 3.0)
	return true


# --- Save ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var pos := rider.global_position if rider else global_position
	return {"x": pos.x, "y": pos.y, "v": _vertical, "f": _flip, "dn": _down, "ride": rider != null or pending_ride}


func load_data(d: Dictionary) -> void:
	_vertical = bool(d.get("v", false))
	_flip = bool(d.get("f", false))
	_down = bool(d.get("dn", false))
	_set_look((Vector2.DOWN if _down else Vector2.UP) if _vertical else (Vector2.LEFT if _flip else Vector2.RIGHT))


# --- Bits ---------------------------------------------------------------------------

func _splash(pos: Vector2) -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("play_fx"):
		lw.play_fx(pos, "ripple", 8, 6, 2, 6.0)


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
